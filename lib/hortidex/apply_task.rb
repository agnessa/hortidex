# frozen_string_literal: true

require "csv"
require "zlib"

module Hortidex
  class ApplyTask
    DATA_DIR = File.expand_path("../../data", __dir__)
    BATCH_SIZE = 500

    def initialize(data_dir: DATA_DIR)
      @data_dir = data_dir
    end

    def run
      conn = ActiveRecord::Base.connection
      check_version!(conn)

      conn.transaction do
        conn.execute("SET CONSTRAINTS ALL DEFERRED")
        apply_concordance(conn)
        upsert_taxon_concepts(conn)
        upsert_common_names(conn)
        record_run(conn)
      end
    end

    private

    def check_version!(conn)
      last = conn.select_one(
        "SELECT hortidex_version FROM taxonomy_apply_runs ORDER BY started_at DESC LIMIT 1"
      )
      return unless last

      last_ver = Gem::Version.new(last["hortidex_version"])
      this_ver = Gem::Version.new(Hortidex::VERSION)
      if this_ver < last_ver
        raise "Downgrade refused: current gem #{Hortidex::VERSION} < last applied #{last["hortidex_version"]}"
      end
    end

    def apply_concordance(conn)
      path = File.join(@data_dir, "concordance.csv.gz")
      rows = Zlib::GzipReader.open(path) { |gz| CSV.new(gz, headers: true).to_a }
      return if rows.empty?

      conn.execute("CREATE TEMP TABLE temp_concordance (old_uuid TEXT, new_uuid TEXT, reason TEXT)")

      rows.each_slice(BATCH_SIZE) do |slice|
        values = slice.map { |r| "(#{conn.quote(r["old_uuid"])}, #{conn.quote(r["new_uuid"])}, #{conn.quote(r["reason"])})" }.join(", ")
        conn.execute("INSERT INTO temp_concordance VALUES #{values}")
      end

      # Remap built-in FK columns before touching the primary key.
      [
        ["taxon_concepts", "parent_id"],
        ["taxon_concepts", "accepted_name_id"],
        ["common_names", "taxon_concept_id"]
      ].each do |table, column|
        conn.execute(<<~SQL)
          UPDATE #{table} SET #{column} = c.new_uuid::uuid
          FROM temp_concordance c WHERE #{table}.#{column} = c.old_uuid::uuid
        SQL
      end

      # Remap client-registered tables.
      Hortidex.configuration.taxon_reference_columns.each do |entry|
        conn.execute(<<~SQL)
          UPDATE #{entry[:table]} SET #{entry[:column]} = c.new_uuid::uuid
          FROM temp_concordance c WHERE #{entry[:table]}.#{entry[:column]} = c.old_uuid::uuid
        SQL
      end

      # Remap the primary key itself last.
      conn.execute(<<~SQL)
        UPDATE taxon_concepts SET id = c.new_uuid::uuid
        FROM temp_concordance c WHERE taxon_concepts.id = c.old_uuid::uuid
      SQL

      conn.execute("DROP TABLE temp_concordance")
    end

    def upsert_taxon_concepts(conn)
      path = File.join(@data_dir, "taxon_concepts.csv.gz")

      conn.execute(<<~SQL)
        CREATE TEMP TABLE temp_taxon_concepts (
          id TEXT, rank TEXT, source TEXT, status TEXT,
          scientific_name TEXT, authorship TEXT,
          parent_id TEXT, accepted_name_id TEXT,
          ancestor_path TEXT, powo_id TEXT, upov_code TEXT, gbif_id TEXT
        )
      SQL

      Zlib::GzipReader.open(path) do |gz|
        CSV.new(gz, headers: true).each_slice(BATCH_SIZE) do |slice|
          values = slice.map { |r| row_values(conn, r, %w[id rank source status scientific_name authorship parent_id accepted_name_id ancestor_path powo_id upov_code gbif_id]) }.join(", ")
          conn.execute("INSERT INTO temp_taxon_concepts VALUES #{values}")
        end
      end

      version = conn.quote(Hortidex::VERSION)
      upsert_sql = <<~SQL
        INSERT INTO taxon_concepts
          (id, rank, source, status, scientific_name, authorship,
           parent_id, accepted_name_id, ancestor_path, powo_id, upov_code, gbif_id,
           hortidex_version)
        SELECT id::uuid, rank, source, status, scientific_name, authorship,
               parent_id::uuid, accepted_name_id::uuid, ancestor_path::ltree, powo_id, upov_code, gbif_id,
               #{version}
        FROM temp_taxon_concepts
        WHERE %{filter}
        ORDER BY COALESCE(LENGTH(ancestor_path) - LENGTH(REPLACE(ancestor_path, '.', '')), 0) ASC
        ON CONFLICT (id) DO UPDATE SET
          rank             = excluded.rank,
          source           = excluded.source,
          status           = excluded.status,
          scientific_name  = excluded.scientific_name,
          authorship       = excluded.authorship,
          parent_id        = excluded.parent_id,
          accepted_name_id = excluded.accepted_name_id,
          ancestor_path    = excluded.ancestor_path,
          upov_code        = excluded.upov_code,
          hortidex_version = excluded.hortidex_version
      SQL
      # Accepted taxa first (no accepted_name_id self-reference to satisfy), ordered
      # shallowest-first so parent rows exist before their children.
      # Synonyms second — all accepted targets are already present.
      conn.execute(upsert_sql % {filter: "accepted_name_id IS NULL"})
      conn.execute(upsert_sql % {filter: "accepted_name_id IS NOT NULL"})

      conn.execute("DROP TABLE temp_taxon_concepts")
    end

    def upsert_common_names(conn)
      paths = locale_files
      return if paths.empty?

      conn.execute(<<~SQL)
        CREATE TEMP TABLE temp_common_names
          (id TEXT, taxon_concept_id TEXT, locale TEXT, name TEXT, source TEXT, preferred TEXT)
      SQL

      paths.each do |path|
        Zlib::GzipReader.open(path) do |gz|
          CSV.new(gz, headers: true).each_slice(BATCH_SIZE) do |slice|
            values = slice.map { |r| row_values(conn, r, %w[id taxon_concept_id locale name source preferred]) }.join(", ")
            conn.execute("INSERT INTO temp_common_names VALUES #{values}")
          end
        end
      end

      conn.execute(<<~SQL)
        INSERT INTO common_names (id, taxon_concept_id, locale, name, source, preferred)
        SELECT id::uuid, taxon_concept_id::uuid, locale, name, source, preferred::boolean
        FROM temp_common_names
        ON CONFLICT (id) DO UPDATE SET
          name      = excluded.name,
          locale    = excluded.locale,
          source    = excluded.source,
          preferred = excluded.preferred
      SQL

      conn.execute("DROP TABLE temp_common_names")
    end

    def record_run(conn)
      conn.execute(
        "INSERT INTO taxonomy_apply_runs (hortidex_version, started_at) VALUES (#{conn.quote(Hortidex::VERSION)}, NOW())"
      )
    end

    def locale_files
      locales = Hortidex.configuration.locales
      all_files = Dir[File.join(@data_dir, "common_names_*.csv.gz")].sort

      if locales
        skipped = all_files.reject { |f| locales.include?(locale_from_path(f)) }
        skipped.each do |f|
          warn "[hortidex] locale '#{locale_from_path(f)}' is available in the gem but not configured — " \
               "existing rows in common_names for this locale were not updated"
        end
        all_files.select { |f| locales.include?(locale_from_path(f)) }
      else
        all_files
      end
    end

    def locale_from_path(path)
      File.basename(path, ".csv.gz").delete_prefix("common_names_")
    end

    def row_values(conn, row, columns)
      vals = columns.map { |c| conn.quote(row[c].presence) }
      "(#{vals.join(", ")})"
    end
  end
end

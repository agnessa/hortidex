# frozen_string_literal: true

require "spec_helper"
require "csv"
require "fileutils"
require "securerandom"
require "tmpdir"
require "zlib"

TC_HEADERS = %w[id rank source status scientific_name authorship
  parent_id accepted_name_id ancestor_path powo_id upov_code gbif_id hortidex_version].freeze
CN_HEADERS = %w[id taxon_concept_id locale name source preferred].freeze
CO_HEADERS = %w[old_uuid new_uuid reason version].freeze

RSpec.describe Hortidex::ApplyTask do
  def gz_csv(path, headers, rows = [])
    Zlib::GzipWriter.open(path) do |gz|
      csv = CSV.new(gz)
      csv << headers
      rows.each { |r| csv << r }
    end
  end

  before(:all) do
    conn = ActiveRecord::Base.connection
    conn.execute(<<~SQL)
      CREATE TABLE taxon_concepts (
        id uuid PRIMARY KEY,
        rank text, source text, status text,
        scientific_name text, authorship text,
        parent_id uuid, accepted_name_id uuid,
        ancestor_path ltree,
        powo_id text, upov_code text, gbif_id text,
        hortidex_version text
      )
    SQL
    conn.execute(<<~SQL)
      CREATE TABLE common_names (
        id uuid PRIMARY KEY,
        taxon_concept_id uuid,
        locale text, name text, source text, preferred boolean
      )
    SQL
    conn.execute(<<~SQL)
      CREATE TABLE taxonomy_apply_runs (
        id bigserial PRIMARY KEY,
        hortidex_version text NOT NULL,
        started_at timestamp NOT NULL
      )
    SQL
  end

  after(:all) do
    ActiveRecord::Base.connection.execute(
      "DROP TABLE IF EXISTS taxon_concepts, common_names, taxonomy_apply_runs CASCADE"
    )
  end

  let(:conn) { ActiveRecord::Base.connection }
  let(:data_dir) { Dir.mktmpdir("hortidex_spec") }

  after do
    FileUtils.rm_rf(data_dir)
    conn.execute("TRUNCATE taxon_concepts, common_names, taxonomy_apply_runs RESTART IDENTITY CASCADE")
  end

  def task
    Hortidex::ApplyTask.new(data_dir: data_dir)
  end

  def empty_concordance
    gz_csv(File.join(data_dir, "concordance.csv.gz"), CO_HEADERS)
  end

  describe "basic upsert" do
    let(:id) { SecureRandom.uuid }

    before do
      empty_concordance
      gz_csv(File.join(data_dir, "taxon_concepts.csv.gz"), TC_HEADERS,
        [[id, "family", "powo", "accepted", "Rosaceae", "Juss.",
          nil, nil, nil, nil, nil, nil, "2.0.0"]])
    end

    it "inserts taxon concepts into the database" do
      task.run
      row = conn.select_one("SELECT scientific_name FROM taxon_concepts WHERE id = #{conn.quote(id)}::uuid")
      expect(row["scientific_name"]).to eq("Rosaceae")
    end

    it "stamps hortidex_version per row from the data file, not the running gem version" do
      carried = SecureRandom.uuid
      # A carry-over row whose source backing froze in an earlier release.
      gz_csv(File.join(data_dir, "taxon_concepts.csv.gz"), TC_HEADERS,
        [[carried, "species", "eupvp", "accepted", "Rosa vetus", nil,
          nil, nil, nil, nil, nil, nil, "1.0.0"]])
      task.run
      row = conn.select_one("SELECT hortidex_version FROM taxon_concepts WHERE id = #{conn.quote(carried)}::uuid")
      expect(row["hortidex_version"]).to eq("1.0.0")
    end

    it "records the run in taxonomy_apply_runs" do
      task.run
      row = conn.select_one("SELECT hortidex_version FROM taxonomy_apply_runs ORDER BY started_at DESC LIMIT 1")
      expect(row["hortidex_version"]).to eq(Hortidex::VERSION)
    end

    it "inserts accepted taxa before synonyms (no FK violation in sequence)" do
      accepted_id = SecureRandom.uuid
      synonym_id = SecureRandom.uuid
      # synonym appears before its accepted target in the CSV — task must reorder
      gz_csv(File.join(data_dir, "taxon_concepts.csv.gz"), TC_HEADERS, [
        [synonym_id, "species", "powo", "synonym", "Rosa vulgaris", "Mill.", nil, accepted_id, nil, nil, nil, nil, "2.0.0"],
        [accepted_id, "species", "powo", "accepted", "Rosa canina", "L.", id, nil, nil, nil, nil, nil, "2.0.0"]
      ])
      expect { task.run }.not_to raise_error
      expect(conn.select_value("SELECT COUNT(*) FROM taxon_concepts").to_i).to eq(2)
    end
  end

  describe "concordance remapping" do
    let(:old_id) { SecureRandom.uuid }
    let(:new_id) { SecureRandom.uuid }

    before do
      conn.execute(<<~SQL)
        INSERT INTO taxon_concepts (id, rank, source, status, scientific_name, authorship, hortidex_version)
        VALUES ('#{old_id}'::uuid, 'family', 'powo', 'accepted', 'Rosaceae', 'Juss.', '#{Hortidex::VERSION}')
      SQL
      gz_csv(File.join(data_dir, "concordance.csv.gz"), CO_HEADERS,
        [[old_id, new_id, "merge", "2.0.0"]])
      gz_csv(File.join(data_dir, "taxon_concepts.csv.gz"), TC_HEADERS)
    end

    it "remaps the primary key from old_uuid to new_uuid" do
      task.run
      expect(conn.select_value("SELECT COUNT(*) FROM taxon_concepts WHERE id = '#{new_id}'::uuid").to_i).to eq(1)
      expect(conn.select_value("SELECT COUNT(*) FROM taxon_concepts WHERE id = '#{old_id}'::uuid").to_i).to eq(0)
    end
  end

  describe "version check" do
    before do
      conn.execute("INSERT INTO taxonomy_apply_runs (hortidex_version, started_at) VALUES ('999.0.0', NOW())")
      empty_concordance
      gz_csv(File.join(data_dir, "taxon_concepts.csv.gz"), TC_HEADERS)
    end

    it "raises when the gem is older than the last applied version" do
      expect { task.run }.to raise_error(RuntimeError, /Downgrade refused/)
    end
  end

  describe "common names" do
    let(:tc_id) { SecureRandom.uuid }
    let(:cn_id) { SecureRandom.uuid }

    before do
      empty_concordance
      gz_csv(File.join(data_dir, "taxon_concepts.csv.gz"), TC_HEADERS,
        [[tc_id, "family", "powo", "accepted", "Rosaceae", "Juss.", nil, nil, nil, nil, nil, nil, "2.0.0"]])
      gz_csv(File.join(data_dir, "common_names_en.csv.gz"), CN_HEADERS,
        [[cn_id, tc_id, "en", "Rose family", "powo", "true"]])
    end

    it "inserts common names for configured locales" do
      task.run
      row = conn.select_one("SELECT name FROM common_names WHERE id = #{conn.quote(cn_id)}::uuid")
      expect(row["name"]).to eq("Rose family")
    end

    it "emits a warning for locale files not in config.locales" do
      gz_csv(File.join(data_dir, "common_names_fr.csv.gz"), CN_HEADERS)
      Hortidex.configuration.locales = %w[en]
      expect { task.run }.to output(/locale 'fr' is available/).to_stderr
    ensure
      Hortidex.configuration.locales = nil
    end
  end
end

# frozen_string_literal: true

module Hortidex
  module TaxonConcept
    extend ActiveSupport::Concern

    included do
      Hortidex::RANKS.each do |rank|
        define_method(:"#{rank}_rank?") { self.rank == rank }
      end

      Hortidex::SOURCES.each do |source|
        define_method(:"#{source}_source?") { self.source == source }
      end

      belongs_to :parent, class_name: base_class.name, optional: true
      has_many :children, class_name: base_class.name, foreign_key: :parent_id
      belongs_to :accepted_name, class_name: base_class.name, optional: true
      has_many :other_names, class_name: base_class.name, foreign_key: :accepted_name_id
      has_many :common_names

      scope :accepted, -> { where(accepted_name_id: nil) }

      validates :scientific_name, presence: true
      validates :scientific_name, uniqueness: {scope: :authorship, conditions: -> { where(status: "accepted") }}
      validates :rank, presence: true
      validates :status, presence: true
      validates :parent_id, presence: true, unless: -> { family_rank? || accepted_name_id? }
      validate :parent_rank_must_be_higher_than_self

      after_commit :reindex, on: [:create, :update], if: -> { saved_change_to_scientific_name? || saved_change_to_authorship? }
      after_commit :reindex_ancestor_path, on: [:create, :update], if: -> { previously_new_record? || saved_change_to_parent_id? }
    end

    module ClassMethods
      def reindex(taxon_concept_id = nil)
        scope = taxon_concept_id ? where(id: taxon_concept_id) : all
        scope.update_all(
          "search_vector = setweight(to_tsvector('simple', coalesce(scientific_name, '')), 'B') || " \
          "setweight(to_tsvector('simple', coalesce((SELECT string_agg(name, ' ') FROM common_names WHERE taxon_concept_id = #{table_name}.id), '')), 'A')"
        )
      end

      def reindex_ancestor_path(root_id)
        connection.execute(<<~SQL)
          WITH RECURSIVE subtree(id, path) AS (
            SELECT tc.id,
              COALESCE(
                p.ancestor_path || replace(tc.id::text, '-', '_')::ltree,
                replace(tc.id::text, '-', '_')::ltree
              ) AS path
            FROM #{table_name} tc
            LEFT JOIN #{table_name} p ON p.id = tc.parent_id
            WHERE tc.id = #{connection.quote(root_id)}
            UNION ALL
            SELECT tc.id, s.path || replace(tc.id::text, '-', '_')::ltree
            FROM #{table_name} tc
            JOIN subtree s ON tc.parent_id = s.id
          )
          UPDATE #{table_name} tc
          SET ancestor_path = s.path
          FROM subtree s
          WHERE tc.id = s.id
        SQL
      end

      def reindex_ancestor_paths
        connection.execute(<<~SQL)
          WITH RECURSIVE ancestry(id, path) AS (
            SELECT id, replace(id::text, '-', '_')::ltree
            FROM #{table_name}
            WHERE parent_id IS NULL
            UNION ALL
            SELECT tc.id, (a.path || replace(tc.id::text, '-', '_'))::ltree
            FROM #{table_name} tc
            JOIN ancestry a ON tc.parent_id = a.id
          )
          UPDATE #{table_name} tc
          SET ancestor_path = a.path
          FROM ancestry a
          WHERE tc.id = a.id
        SQL
      end
    end

    # Returns an array of [text, italic?] pairs describing how to render the
    # scientific name; delegates all botanical parsing to NameFormatter.
    def name_parts
      Hortidex::NameFormatter.parts(scientific_name, rank, trusted: powo_id?)
    end

    # Returns self for canonical taxa; follows accepted_name for non-canonical ones.
    def canonical
      accepted_name || self
    end

    def current?
      accepted_name_id.nil?
    end

    def reindex
      self.class.reindex(id)
    end

    def reindex_ancestor_path
      self.class.reindex_ancestor_path(id)
    end

    private

    def parent_rank_must_be_higher_than_self
      return if parent.nil? || rank.nil?

      allowed = VALID_PARENT_RANKS[rank]
      return unless allowed&.any?

      unless allowed.include?(parent.rank)
        errors.add(:parent, "rank must be one of: #{allowed.join(", ")}")
      end
    end
  end
end

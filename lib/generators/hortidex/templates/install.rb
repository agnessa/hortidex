# frozen_string_literal: true

class HortidexInstall < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    enable_extension "ltree" unless extension_enabled?("ltree")

    create_table :taxon_concepts, id: :uuid do |t|
      t.uuid   :parent_id
      t.uuid   :accepted_name_id
      t.string :rank,             null: false
      t.string :source,           null: false, default: "powo"
      t.string :status,           null: false, default: "accepted"
      t.string :scientific_name,  null: false
      t.string :authorship
      t.string :powo_id
      t.string :upov_code
      t.string :gbif_id
      t.string :hortidex_version
      t.column :ancestor_path,    :ltree
      t.column :search_vector,    :tsvector
    end

    add_index :taxon_concepts, :parent_id
    add_index :taxon_concepts, :accepted_name_id
    add_index :taxon_concepts, :powo_id,  unique: true, where: "powo_id IS NOT NULL",
      name: "index_taxon_concepts_on_powo_id_not_null"
    add_index :taxon_concepts, :gbif_id,  unique: true, where: "gbif_id IS NOT NULL",
      name: "index_taxon_concepts_on_gbif_id_not_null"
    add_index :taxon_concepts, %i[scientific_name authorship],
      name: "index_taxon_concepts_on_scientific_name_and_authorship_accepted",
      unique: true,
      where: "status = 'accepted'"

    add_foreign_key :taxon_concepts, :taxon_concepts, column: :parent_id,       deferrable: :deferred
    add_foreign_key :taxon_concepts, :taxon_concepts, column: :accepted_name_id, deferrable: :deferred

    create_table :common_names, id: :uuid do |t|
      t.references :taxon_concept, null: false, type: :uuid
      t.boolean :preferred, default: false
      t.string :locale,    null: false
      t.string :name,      null: false
      t.string :source
    end

    add_foreign_key :common_names, :taxon_concepts, deferrable: :deferred

    create_table :taxonomy_apply_runs, id: :uuid do |t|
      t.datetime :started_at,    null: false
      t.datetime :completed_at
      t.integer  :status,        limit: 2, null: false, default: 0  # 0=running 1=succeeded 2=failed
      t.string   :hortidex_version, null: false
    end
  end
end

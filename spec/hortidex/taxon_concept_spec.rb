# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hortidex::TaxonConcept do
  with_model :TaxonConcept do
    table do |t|
      t.string :rank
      t.string :source
      t.string :status
      t.string :scientific_name
      t.string :authorship
      t.integer :parent_id
      t.integer :accepted_name_id
      t.column :ancestor_path, :ltree
      t.column :search_vector, :tsvector
      t.string :hortidex_version
      t.string :powo_id
    end

    model do
      include Hortidex::TaxonConcept
    end
  end

  with_table :common_names do |t|
    t.integer :taxon_concept_id
    t.string :locale
    t.string :name
    t.string :source
    t.boolean :preferred
  end

  let(:family) do
    TaxonConcept.create!(rank: "family", source: "powo", status: "accepted",
      scientific_name: "Rosaceae", authorship: "Juss.")
  end
  let(:genus) do
    TaxonConcept.create!(rank: "genus", source: "powo", status: "accepted",
      scientific_name: "Rosa", authorship: "L.", parent_id: family.id)
  end

  describe "rank predicates" do
    Hortidex::RANKS.each do |rank|
      it "#{rank}_rank? returns true for rank = #{rank}" do
        expect(TaxonConcept.new(rank: rank).public_send(:"#{rank}_rank?")).to be true
      end

      it "#{rank}_rank? returns false for a different rank" do
        other = (Hortidex::RANKS - [rank]).first
        expect(TaxonConcept.new(rank: other).public_send(:"#{rank}_rank?")).to be false
      end
    end
  end

  describe "source predicates" do
    Hortidex::SOURCES.each do |source|
      it "#{source}_source? returns true for source = #{source}" do
        expect(TaxonConcept.new(source: source).public_send(:"#{source}_source?")).to be true
      end

      it "#{source}_source? returns false for a different source" do
        other = (Hortidex::SOURCES - [source]).first
        expect(TaxonConcept.new(source: other).public_send(:"#{source}_source?")).to be false
      end
    end
  end

  describe "#canonical" do
    it "returns self for a canonical taxon" do
      tc = TaxonConcept.new
      expect(tc.canonical).to be tc
    end

    it "returns accepted_name for a synonym" do
      synonym = TaxonConcept.new(accepted_name: family)
      expect(synonym.canonical).to be family
    end
  end

  describe "#current?" do
    it "returns true when accepted_name_id is nil" do
      expect(TaxonConcept.new(accepted_name_id: nil).current?).to be true
    end

    it "returns false when accepted_name_id is set" do
      expect(TaxonConcept.new(accepted_name_id: 99).current?).to be false
    end
  end

  describe "scope :accepted" do
    it "includes taxa with no accepted_name_id" do
      expect(TaxonConcept.accepted).to include(family)
    end

    it "excludes taxa with an accepted_name_id" do
      synonym = TaxonConcept.create!(rank: "species", source: "powo", status: "synonym",
        scientific_name: "Rosa vulgaris", authorship: "Mill.", accepted_name_id: family.id)
      expect(TaxonConcept.accepted).not_to include(synonym)
    end
  end

  describe "validations" do
    it "requires scientific_name" do
      tc = TaxonConcept.new(rank: "family", source: "powo", status: "accepted")
      expect(tc).not_to be_valid
      expect(tc.errors[:scientific_name]).not_to be_empty
    end

    it "requires rank" do
      tc = TaxonConcept.new(source: "powo", status: "accepted", scientific_name: "Foo")
      expect(tc).not_to be_valid
      expect(tc.errors[:rank]).not_to be_empty
    end

    it "requires parent_id for non-family accepted taxa" do
      tc = TaxonConcept.new(rank: "genus", source: "powo", status: "accepted",
        scientific_name: "Rubus", authorship: "L.")
      expect(tc).not_to be_valid
      expect(tc.errors[:parent_id]).not_to be_empty
    end

    it "does not require parent_id for synonyms (accepted_name_id present)" do
      tc = TaxonConcept.new(rank: "species", source: "powo", status: "synonym",
        scientific_name: "Rosa vulgaris", authorship: "Mill.", accepted_name_id: family.id)
      expect(tc.errors[:parent_id]).to be_empty
    end

    it "enforces uniqueness of (scientific_name, authorship) among accepted taxa" do
      TaxonConcept.create!(rank: "species", source: "powo", status: "accepted",
        scientific_name: "Rosa canina", authorship: "L.", parent_id: genus.id)
      dup = TaxonConcept.new(rank: "species", source: "powo", status: "accepted",
        scientific_name: "Rosa canina", authorship: "L.", parent_id: genus.id)
      expect(dup).not_to be_valid
      expect(dup.errors[:scientific_name]).not_to be_empty
    end

    it "does not enforce uniqueness among synonyms" do
      accepted = TaxonConcept.create!(rank: "species", source: "powo", status: "accepted",
        scientific_name: "Rosa canina", authorship: "L.", parent_id: genus.id)
      TaxonConcept.create!(rank: "species", source: "powo", status: "synonym",
        scientific_name: "Rosa vulgaris", authorship: "Mill.", accepted_name_id: accepted.id)
      dup = TaxonConcept.new(rank: "species", source: "powo", status: "synonym",
        scientific_name: "Rosa vulgaris", authorship: "Mill.", accepted_name_id: accepted.id)
      expect(dup).to be_valid
    end

    it "rejects a genus whose parent rank is not family" do
      bad = TaxonConcept.new(rank: "genus", source: "powo", status: "accepted",
        scientific_name: "Rubus", authorship: "L.", parent_id: genus.id)
      expect(bad).not_to be_valid
      expect(bad.errors[:parent]).not_to be_empty
    end

    it "accepts a genus whose parent rank is family" do
      expect(genus).to be_valid
    end
  end

  describe "#name_parts" do
    it "passes trusted: true when powo_id is present" do
      tc = TaxonConcept.new(rank: "subspecies", scientific_name: "Allium senescens L. subsp. senescens", powo_id: "12345-1")
      expect(tc.name_parts).to eq(Hortidex::NameFormatter.parts("Allium senescens L. subsp. senescens", "subspecies", trusted: true))
    end

    it "passes trusted: false when powo_id is absent" do
      tc = TaxonConcept.new(rank: "subspecies", scientific_name: "Allium senescens L. subsp. senescens", powo_id: nil)
      expect(tc.name_parts).to eq(Hortidex::NameFormatter.parts("Allium senescens L. subsp. senescens", "subspecies", trusted: false))
    end
  end

  describe ".reindex" do
    it "updates search_vector without raising" do
      family
      expect { TaxonConcept.reindex }.not_to raise_error
    end
  end

  describe ".reindex_ancestor_path" do
    it "updates ancestor_path without raising" do
      expect { TaxonConcept.reindex_ancestor_path(family.id) }.not_to raise_error
    end
  end
end

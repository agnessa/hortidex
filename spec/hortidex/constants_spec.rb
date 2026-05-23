# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Hortidex constants" do
  describe "RANKS" do
    it "is a frozen array of strings" do
      expect(Hortidex::RANKS).to be_a(Array)
      expect(Hortidex::RANKS).to be_frozen
      expect(Hortidex::RANKS).to all(be_a(String))
    end

    it "includes the standard botanical ranks" do
      expect(Hortidex::RANKS).to include("family", "genus", "species", "subspecies",
        "variety", "subvariety", "form", "cultivar")
    end

    it "includes notho- ranks" do
      expect(Hortidex::RANKS).to include("nothosubspecies", "nothovariety", "nothoform")
    end

    it "includes convariety" do
      expect(Hortidex::RANKS).to include("convariety")
    end

    it "does not include group (superseded by convariety)" do
      expect(Hortidex::RANKS).not_to include("group")
    end
  end

  describe "SOURCES" do
    it "is a frozen array of strings" do
      expect(Hortidex::SOURCES).to be_a(Array)
      expect(Hortidex::SOURCES).to be_frozen
    end

    it "includes powo, upov, eupvp" do
      expect(Hortidex::SOURCES).to contain_exactly("powo", "upov", "eupvp")
    end
  end

  describe "VALID_PARENT_RANKS" do
    it "only enforces rules for genus and species" do
      expect(Hortidex::VALID_PARENT_RANKS.keys).to contain_exactly("genus", "species")
    end

    it "requires genus under family" do
      expect(Hortidex::VALID_PARENT_RANKS["genus"]).to eq(["family"])
    end

    it "requires species under genus" do
      expect(Hortidex::VALID_PARENT_RANKS["species"]).to eq(["genus"])
    end

    it "all allowed parent ranks are themselves valid ranks" do
      Hortidex::VALID_PARENT_RANKS.each do |rank, parents|
        parents.each do |parent|
          expect(Hortidex::RANKS).to include(parent),
            "#{rank}'s allowed parent '#{parent}' is not in RANKS"
        end
      end
    end
  end

  describe "RANK_CONNECTOR" do
    it "uses standard ICN abbreviations" do
      expect(Hortidex::RANK_CONNECTOR["subspecies"]).to eq("subsp.")
      expect(Hortidex::RANK_CONNECTOR["variety"]).to eq("var.")
      expect(Hortidex::RANK_CONNECTOR["nothosubspecies"]).to eq("nothosubsp.")
      expect(Hortidex::RANK_CONNECTOR["nothovariety"]).to eq("nothovar.")
      expect(Hortidex::RANK_CONNECTOR["nothoform"]).to eq("nothof.")
      expect(Hortidex::RANK_CONNECTOR["form"]).to eq("f.")
      expect(Hortidex::RANK_CONNECTOR["convariety"]).to eq("convar.")
    end

    it "does not include family, genus, species, or cultivar (no connector for these)" do
      expect(Hortidex::RANK_CONNECTOR.keys).not_to include("family", "genus", "species", "cultivar")
    end

    it "all keys are valid ranks" do
      Hortidex::RANK_CONNECTOR.each_key do |rank|
        expect(Hortidex::RANKS).to include(rank)
      end
    end
  end
end

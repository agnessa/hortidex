# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hortidex::NameFormatter do
  describe ".parts" do
    context "family rank" do
      it "returns the whole name as a single italic segment" do
        expect(described_class.parts("Rosaceae", "family")).to eq([["Rosaceae", true]])
      end
    end

    context "genus rank" do
      it "returns the whole name as a single italic segment" do
        expect(described_class.parts("Amelanchier", "genus")).to eq([["Amelanchier", true]])
      end

      it "keeps a leading × roman" do
        expect(described_class.parts("× Takasakiara", "genus")).to eq(
          [["× ", false], ["Takasakiara", true]]
        )
      end
    end

    context "species rank" do
      it "returns the whole binomial as a single italic segment" do
        expect(described_class.parts("Amelanchier alnifolia", "species")).to eq(
          [["Amelanchier alnifolia", true]]
        )
      end

      it "splits on a hybrid × keeping it roman" do
        expect(described_class.parts("Phragmipedium × conchiferum", "species")).to eq(
          [["Phragmipedium", true], [" × ", false], ["conchiferum", true]]
        )
      end

      it "handles UPOV 'Hybrids between A × B' with unicode ×" do
        expect(described_class.parts("Hybrids between Achillea millefolium × Achillea tomentosa", "species")).to eq(
          [["Hybrids between ", false], ["Achillea millefolium", true], [" × ", false], ["Achillea tomentosa", true]]
        )
      end

      it "handles UPOV 'Hybrids between A x B' with ascii x" do
        expect(described_class.parts("Hybrids between Achillea millefolium x Achillea tomentosa", "species")).to eq(
          [["Hybrids between ", false], ["Achillea millefolium", true], [" x ", false], ["Achillea tomentosa", true]]
        )
      end

      it "matches case-insensitively for hybrid prefix" do
        expect(described_class.parts("hybrids between Rosa canina x Rosa rugosa", "species")).to eq(
          [["hybrids between ", false], ["Rosa canina", true], [" x ", false], ["Rosa rugosa", true]]
        )
      end
    end

    context "subspecies rank" do
      it "splits on subsp., leaving it roman" do
        expect(described_class.parts("Agrimonia eupatoria subsp. grandis", "subspecies")).to eq(
          [["Agrimonia eupatoria", true], [" subsp. ", false], ["grandis", true]]
        )
      end
    end

    context "variety rank" do
      it "splits on var., leaving it roman" do
        expect(described_class.parts("Prunus fasciculata var. punctata", "variety")).to eq(
          [["Prunus fasciculata", true], [" var. ", false], ["punctata", true]]
        )
      end
    end

    context "form rank" do
      it "splits on f., leaving it roman" do
        expect(described_class.parts("Rubus praecox f. rutiliflorus", "form")).to eq(
          [["Rubus praecox", true], [" f. ", false], ["rutiliflorus", true]]
        )
      end
    end

    context "infraspecific rank with embedded authorship, trusted: false (give up)" do
      it "returns the whole name italic when the binomial has authorship" do
        expect(described_class.parts("Allium senescens L. subsp. senescens", "subspecies", trusted: false)).to eq(
          [["Allium senescens L. subsp. senescens", true]]
        )
      end

      it "returns the whole name italic when the infraepithet has authorship" do
        expect(described_class.parts("Vicia faba L. var. minuta (hort. ex Alef.) Mansf.", "variety", trusted: false)).to eq(
          [["Vicia faba L. var. minuta (hort. ex Alef.) Mansf.", true]]
        )
      end

      it "falls through to a × split when the after-part is complex but a cross is present" do
        expect(described_class.parts("Chrysanthemum zawadskii subsp. lucidum × Chrysanthemum zawadskii subsp. latilobum", "subspecies", trusted: false)).to eq(
          [["Chrysanthemum zawadskii subsp. lucidum", true], [" × ", false], ["Chrysanthemum zawadskii subsp. latilobum", true]]
        )
      end
    end

    context "infraspecific rank with embedded authorship, trusted: true (powo_id present)" do
      it "splits on the connector even when the binomial contains authorship" do
        expect(described_class.parts("Allium senescens L. subsp. senescens", "subspecies", trusted: true)).to eq(
          [["Allium senescens L.", true], [" subsp. ", false], ["senescens", true]]
        )
      end
    end

    context "cultivar rank (no connector)" do
      it "falls through to full italic when no × present" do
        expect(described_class.parts("Salix caprea", "cultivar")).to eq(
          [["Salix caprea", true]]
        )
      end

      it "splits on a hybrid × when present" do
        expect(described_class.parts("Prunus × cistena", "cultivar")).to eq(
          [["Prunus", true], [" × ", false], ["cistena", true]]
        )
      end
    end

    context "cultivar denominations in single quotes" do
      it "returns the denomination as a separate non-italic segment" do
        expect(described_class.parts("Rosa 'Peace'", "cultivar")).to eq(
          [["Rosa ", true], ["'Peace'", false]]
        )
      end
    end

    it "accepts rank as a symbol" do
      expect(described_class.parts("Rosaceae", :family)).to eq([["Rosaceae", true]])
    end
  end
end

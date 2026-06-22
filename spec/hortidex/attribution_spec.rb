# frozen_string_literal: true

require "spec_helper"

RSpec.describe Hortidex::Attribution do
  describe ".sources" do
    it "loads one source per upstream dataset, in order" do
      expect(described_class.sources.map(&:id)).to eq(%w[powo upov eupvp])
    end

    it "exposes the structured fields for a source" do
      powo = described_class["powo"]

      expect(powo.name).to eq("WCVP: World Checklist of Vascular Plants")
      expect(powo.rightsholder).to eq("Royal Botanic Gardens, Kew")
      expect(powo.url).to eq("https://powo.science.kew.org")
      expect(powo.description).to be_a(String)
    end

    it "exposes the licence as a structured record" do
      license = described_class["upov"].license

      expect(license.name).to eq("CC BY 4.0")
      expect(license.url).to eq("https://creativecommons.org/licenses/by/4.0/")
    end

    it "exposes the citation as a structured record" do
      citation = described_class["powo"].citation

      expect(citation.author).to eq("Govaerts R (ed.)")
      expect(citation.year).to eq(2026)
      expect(citation.title).to eq("WCVP: World Checklist of Vascular Plants")
      expect(citation.url).to eq("https://doi.org/10.34885/egs6-cp24")
      expect(citation.accessed_on).to eq("2026-06-04")
    end
  end

  describe ".[]" do
    it "looks up a source by id" do
      expect(described_class["eupvp"].name).to eq("EU Plant Variety Portal")
    end

    it "returns nil for an unknown id" do
      expect(described_class["does_not_exist"]).to be_nil
    end
  end

  describe Hortidex::Attribution::Citation do
    let(:citation) do
      described_class.new(
        author: "Govaerts R (ed.)",
        year: 2026,
        title: "WCVP: World Checklist of Vascular Plants",
        container: "Facilitated by the Royal Botanic Gardens, Kew",
        url: "https://doi.org/10.34885/rvc3-4d77",
        accessed_on: "2026-01-06"
      )
    end

    describe "#to_s" do
      it "joins the parts into a plain-text citation" do
        expect(citation.to_s).to eq(
          "Govaerts R (ed.) (2026). WCVP: World Checklist of Vascular Plants. " \
          "Facilitated by the Royal Botanic Gardens, Kew. " \
          "Available at: https://doi.org/10.34885/rvc3-4d77. Accessed 2026-01-06."
        )
      end

      it "skips parts that are missing" do
        sparse = described_class.new(author: "European Commission", year: nil, title: "EU Plant Variety Portal",
          container: nil, url: "https://ec.europa.eu/food/plant-variety-portal/", accessed_on: "2026-05-15")

        expect(sparse.to_s).to eq(
          "European Commission. EU Plant Variety Portal. " \
          "Available at: https://ec.europa.eu/food/plant-variety-portal/. Accessed 2026-05-15."
        )
      end
    end

    describe "#to_html" do
      it "wraps the title in <cite> and the URL in a link, escaping HTML-sensitive characters" do
        html = citation.to_html

        expect(html).to include("<cite>WCVP: World Checklist of Vascular Plants</cite>")
        expect(html).to include('<a href="https://doi.org/10.34885/rvc3-4d77">https://doi.org/10.34885/rvc3-4d77</a>')
        expect(html).to start_with("Govaerts R (ed.) (2026). ")
        expect(html).to end_with("Accessed 2026-01-06.")
      end

      it "escapes HTML-sensitive characters in free-text fields" do
        unsafe = described_class.new(author: "A & B <evil>", year: nil, title: nil, container: nil,
          url: nil, accessed_on: nil)

        expect(unsafe.to_html).to eq("A &amp; B &lt;evil&gt;.")
      end
    end
  end
end

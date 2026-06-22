# frozen_string_literal: true

require "yaml"
require "cgi"

module Hortidex
  # Structured licence and citation details for the upstream taxonomy sources
  # (POWO/WCVP, UPOV GENIE, EU Plant Variety Portal), loaded from
  # data/attribution.yml. That file is hand-maintained in hortidex_admin and
  # bundled into each gem release, so the citation wording and access dates
  # shown to consumers always match the data they received.
  #
  # Use the structured fields directly to build your own layout, or call
  # Citation#to_s / #to_html for ready-made renderings of the citation text.
  module Attribution
    DATA_FILE = File.expand_path("../../data/attribution.yml", __dir__)

    License = Data.define(:name, :url)

    Citation = Data.define(:author, :year, :title, :container, :url, :accessed_on) do
      def to_s
        sentence(
          [author, year && "(#{year})"].compact.join(" "),
          title,
          container,
          url && "Available at: #{url}",
          accessed_on && "Accessed #{accessed_on}"
        )
      end

      def to_html
        sentence(
          CGI.escapeHTML([author, year && "(#{year})"].compact.join(" ")),
          title && "<cite>#{CGI.escapeHTML(title)}</cite>",
          container && CGI.escapeHTML(container),
          url && %(Available at: <a href="#{CGI.escapeHTML(url)}">#{CGI.escapeHTML(url)}</a>),
          accessed_on && "Accessed #{CGI.escapeHTML(accessed_on)}"
        )
      end

      private

      def sentence(*parts)
        text = parts.reject { |part| part.nil? || part.empty? }.join(". ")
        text.empty? ? text : "#{text}."
      end
    end

    Source = Data.define(:id, :name, :rightsholder, :url, :license, :description, :citation)

    class << self
      # Returns the Source records described in data/attribution.yml, in the
      # order they are listed there (POWO, UPOV, EU PVP).
      def sources
        @sources ||= YAML.load_file(DATA_FILE).map { |entry| build_source(entry) }
      end

      # Looks up a single source by id, e.g. Hortidex::Attribution["powo"].
      def [](id)
        sources.find { |source| source.id == id.to_s }
      end

      private

      def build_source(entry)
        license = entry["license"] || {}
        citation = entry["citation"] || {}

        Source.new(
          id: entry["id"],
          name: entry["name"],
          rightsholder: entry["rightsholder"],
          url: entry["url"],
          description: entry["description"],
          license: License.new(name: license["name"], url: license["url"]),
          citation: Citation.new(
            author: citation["author"],
            year: citation["year"],
            title: citation["title"],
            container: citation["container"],
            url: citation["url"],
            accessed_on: citation["accessed_on"]
          )
        )
      end
    end
  end
end

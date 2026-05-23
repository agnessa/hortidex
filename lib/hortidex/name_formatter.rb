# frozen_string_literal: true

module Hortidex
  # Decomposes a scientific name into segments for display, following botanical
  # nomenclature conventions. Returns an array of [text, italic?] pairs so that
  # callers can render the segments in any format without repeating the parsing
  # logic.
  #
  # Conventions applied:
  #   - Family and genus: whole name italic; leading × hybrid sign stays roman.
  #   - Species (binomial): whole name italic; × hybrid sign stays roman and
  #     splits the name. UPOV "Hybrids between A ×/x B" notation is also handled.
  #   - Infraspecific: binomial prefix and infraepithet italic; connector roman.
  #   - Cultivar: binomial/uninomial prefix italic; denomination in single quotes roman.
  module NameFormatter
    HYBRID_PREFIX_RE = /\A(hybrids? between\s+)(.*?)\s+(×|x)\s+(.*)\z/i
    private_constant :HYBRID_PREFIX_RE

    def self.parts(scientific_name, rank, trusted: false)
      case rank.to_s
      when "family", "genus" then uninomial_parts(scientific_name)
      when "species" then binomial_parts(scientific_name)
      else infraspecific_parts(scientific_name, rank.to_s, trusted: trusted)
      end
    end

    class << self
      private

      def uninomial_parts(name)
        if name.start_with?("× ")
          [["× ", false], [name.delete_prefix("× "), true]]
        else
          [[name, true]]
        end
      end

      def binomial_parts(name)
        if (m = name.match(HYBRID_PREFIX_RE))
          [[m[1], false], [m[2], true], [" #{m[3]} ", false], [m[4], true]]
        elsif name.include?(" × ")
          genus, epithet = name.split(" × ", 2)
          [[genus, true], [" × ", false], [epithet, true]]
        else
          [[name, true]]
        end
      end

      def infraspecific_parts(name, rank, trusted:)
        cultivar_re = /.+('.*')$/
        cultivar_part = if (m = name.match(cultivar_re))
          name = m[0].sub(m[1], "")
          [m[1], false]
        end
        connector = RANK_CONNECTOR[rank]
        if connector && name.include?(" #{connector} ")
          before, after = name.split(" #{connector} ", 2)
          # For untrusted names (no powo_id), a standard trinomial has exactly
          # "Genus species" before and one epithet after. More tokens indicate
          # embedded authorship — fall through rather than produce wrong markup.
          if trusted || (before.split.length <= 2 && after.split.length <= 1)
            return [[before, true], [" #{connector} ", false], [after, true], cultivar_part].compact
          end
          # Fall through: may still be a hybrid cross separable by ×.
        end
        if name.include?(" × ")
          before, after = name.split(" × ", 2)
          [[before, true], [" × ", false], [after, true], cultivar_part].compact
        else
          [[name, true], cultivar_part].compact
        end
      end
    end
  end
end

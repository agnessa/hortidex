# frozen_string_literal: true

module Hortidex
  RANKS = %w[
    family genus species subspecies variety subvariety form subform
    nothosubspecies nothovariety nothoform convariety cultivar
  ].freeze

  SOURCES = %w[powo upov eupvp].freeze

  # Enforced parent rank rules. Only ranks where we have reliable data are listed;
  # infraspecific ranks below species are left unconstrained in practice.
  VALID_PARENT_RANKS = {
    "genus" => %w[family].freeze,
    "species" => %w[genus].freeze
  }.freeze

  # ICBN abbreviation inserted between genus/species and the infraspecific epithet.
  # Ranks not listed here have no connector (e.g. cultivar uses quote notation).
  RANK_CONNECTOR = {
    "subspecies" => "subsp.",
    "variety" => "var.",
    "subvariety" => "subvar.",
    "form" => "f.",
    "subform" => "subf.",
    "nothosubspecies" => "nothosubsp.",
    "nothovariety" => "nothovar.",
    "nothoform" => "nothof.",
    "convariety" => "convar."
  }.freeze
end

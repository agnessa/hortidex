# hortidex

A curated, versioned snapshot of plant taxonomy data derived from:

- [Plants of the World Online / WCVP](https://powo.science.kew.org/) — accepted names, synonyms, and the full taxonomic hierarchy from family down to infraspecific rank
- [UPOV GENIE](https://www.upov.int/genie/) — UPOV codes for genera, species, and infraspecific taxa used in plant variety protection and their common names
- [EU Plant Variety Database](https://ec.europa.eu/food/plant-variety-portal/) — registered EU variety denominations

The gem ships CSV data files and an ActiveRecord-compatible apply task that upserts the dataset into a Postgres database.

## Requirements

- Ruby 3.3+
- PostgreSQL with the `ltree` extension
- ActiveRecord 7+

## Installation

```ruby
gem 'hortidex', '~> 1.0'
```

## Database setup

Generate the migration and run it:

```
bin/rails generate hortidex:install
bin/rails db:migrate
```

This creates three tables.

**`taxon_concepts`** — the main taxonomy table. Each row is a name record from the source datasets.

| Column             | Type     | Notes                                                                          |
|--------------------|----------|--------------------------------------------------------------------------------|
| `id`               | uuid     | Stable across versions within a MAJOR release                                  |
| `rank`             | string   | `family`, `genus`, `species`, `subspecies`, `variety`, `subvariety`, `form`, `subform`, `cultivar`, `nothosubspecies`, `nothovariety`, `nothoform`, `convariety` |
| `source`           | string   | `powo`, `upov`, `eupvp`                                                        |
| `status`           | string   | `accepted`, `synonym`, `orthographic`, `illegitimate`, `invalid`, `misapplied` |
| `scientific_name`  | string   | Full name including rank connector for infraspecific taxa                      |
| `authorship`       | string   | May be nil for cultivars and some variety records                              |
| `parent_id`        | uuid     | FK → `taxon_concepts`; nil for family-rank records                             |
| `accepted_name_id` | uuid     | FK → `taxon_concepts`; nil for accepted taxa                                   |
| `powo_id`          | string   | POWO plant identifier; unique where present                                    |
| `upov_code`        | string   | UPOV code; present for taxa sourced from GENIE                                 |
| `gbif_id`          | string   | GBIF taxon key; unique where present                                           |
| `ancestor_path`    | ltree    | Materialised path of `id` segments for ancestor/descendant queries             |
| `search_vector`    | tsvector | Full-text index over `scientific_name`                                         |
| `hortidex_version` | string   | Gem version that last wrote this row                                           |

**`common_names`** — vernacular names, one row per name per locale per taxon.

| Column             | Type    | Notes                                             |
|--------------------|---------|---------------------------------------------------|
| `taxon_concept_id` | uuid    | FK → `taxon_concepts`                             |
| `locale`           | string  | BCP 47 language tag (`en`, `de`, `fr`, `es`)      |
| `name`             | string  | Common name                                       |
| `preferred`        | boolean | Whether this is the preferred name for the locale |
| `source`           | string  | Source dataset                                    |

**`taxonomy_apply_runs`** — internal table tracking each `taxonomy:apply` run; no application code needs to read this directly.

Both FKs on `taxon_concepts` are `DEFERRABLE DEFERRED` to allow the apply task to upsert rows without ordering constraints.

## Setup

Register any app tables that hold `taxon_concept_id` foreign keys in an initializer. The apply task uses this list to remap IDs during concordance steps:

```ruby
# config/initializers/hortidex.rb
Hortidex.configure do |config|
  config.taxon_reference_columns << {table: "trees",     column: "taxon_concept_id"}
  config.taxon_reference_columns << {table: "specimens", column: "taxon_concept_id"}
end
```

Optionally restrict which common-name locales are written to the database:

```ruby
config.locales = %w[en de fr]  # nil (default) imports all available locales
```

The Railtie registers the rake tasks automatically when used inside a Rails app.

## Usage

Apply the current gem version to the database:

```
bin/rails taxonomy:apply
```

## Versioning

| Bump      | When                                                                                  |
|-----------|---------------------------------------------------------------------------------------|
| **MAJOR** | UUID scheme or schema changes — requires concordance step, test against a clone first |
| **MINOR** | New dataset update or new source — safe upsert, no ID remapping                       |
| **PATCH** | Data corrections — authorship fixes, matching errors, wrong accepted name             |

A MAJOR bump means the concordance step is non-optional. Run `taxonomy:apply` against a database clone before applying to production.

## Data contract

`rank`, `source`, and `status` are stored as plain strings. New values introduced by future POWO releases arrive as new strings without requiring a gem update or code change in the consuming app.

Available constants for validation and display logic:

```ruby
Hortidex::RANKS               # => ["family", "genus", "species", ...]
Hortidex::SOURCES             # => ["powo", "upov", "eupvp"]
Hortidex::VALID_PARENT_RANKS  # => {"species" => ["genus"], ...}
Hortidex::RANK_CONNECTOR      # => {"subspecies" => "subsp.", "variety" => "var.", ...}
```

## Model concern

Include `Hortidex::TaxonConcept` in the app's model to get associations, scopes, predicate methods, and name formatting:

```ruby
class TaxonConcept < ApplicationRecord
  include Hortidex::TaxonConcept

  # App-specific additions:
  has_many :trees
end
```

The concern provides:

- `belongs_to :parent`, `has_many :children`
- `belongs_to :accepted_name`, `has_many :other_names`
- `has_many :common_names`
- `scope :accepted` — taxa with no `accepted_name_id` (the canonical records)
- `canonical` — returns self for canonical taxa; follows `accepted_name` for all others regardless of status
- `current?` — true when `accepted_name_id` is nil
- `family_rank?`, `genus_rank?`, `species_rank?` … predicate methods for each rank
- `powo_source?`, `upov_source?`, `eupvp_source?` … predicate methods for each source
- `name_parts` — see [Name formatting](#name-formatting) below

`canonical` is built around `accepted_name_id`, not status strings, so it works for all POWO status values (`synonym`, `orthographic`, `illegitimate`, `invalid`, `misapplied`) without changes.

## Name formatting

`taxon_concept.name_parts` returns an array of `[text, italic?]` pairs that describe how to render the scientific name following botanical nomenclature conventions:

- Family and genus names are fully italicised; a leading hybrid `×` stays roman.
- Species (binomial) names are italicised; the hybrid `×` stays roman and splits the name.
- Infraspecific names italicise the binomial prefix and the infraepithet separately, leaving the rank connector (`subsp.`, `var.`, `f.`, etc.) roman.

```ruby
tc.name_parts
# family:       [["Rosaceae", true]]
# genus:        [["Rosa", true]]
# hybrid genus: [["× ", false], ["Takasakiara", true]]
# species:      [["Rosa canina", true]]
# hybrid sp.:   [["Rosa", true], [" × ", false], ["hibernica", true]]
# subspecies:   [["Rosa canina", true], [" subsp. ", false], ["vosagiaca", true]]
```

For POWO-sourced names (`powo_id` present) the split is always applied. For names from other sources (UPOV, EU PVP) that may contain verbatim authorship strings within the name field, the formatter applies a conservative heuristic: if the segments around the rank connector do not look like a standard two-part binomial and a single-word infraepithet, it falls back to returning the whole name as a single italic segment rather than producing incorrect markup. Complex cross-hybrid names at infraspecific rank fall through further to a `×`-based split if one is present.

To render as HTML in a Rails view:

```ruby
safe_join(taxon_concept.name_parts.map { |text, italic|
  italic ? content_tag(:em, text) : text
})
```

`Hortidex::NameFormatter.parts(scientific_name, rank, trusted: false)` is also available as a standalone class method for callers that do not go through the model concern.

## Known gaps

`import_issues.csv` is shipped with each gem version and lists taxa that could not be resolved during the import — unmatched UPOV entries, unresolvable parents, retired POWO IDs with no replacement found. These are known gaps, not failures. Inspect this file if a taxon you expect is absent from the dataset.

## Attribution

Licence and citation details for each upstream source (POWO/WCVP, UPOV GENIE, EU Plant Variety Portal) are shipped with the gem and available as structured data via `Hortidex::Attribution`:

```ruby
Hortidex::Attribution.sources.each do |source|
  puts source.name           # "WCVP: World Checklist of Vascular Plants"
  puts source.rightsholder   # "Royal Botanic Gardens, Kew"
  puts source.license.name   # "CC BY 3.0"
  puts source.description
  puts source.citation.to_s  # plain-text citation, e.g. "Govaerts R (ed.) (2026). WCVP: ... Accessed 2026-01-06."
  puts source.citation.to_html
end

Hortidex::Attribution["powo"] # look up a single source by id
```

Each `citation` is a structured object (`author`, `year`, `title`, `container`, `url`, `accessed_on`) so that consumers can lay the parts out themselves, or use the ready-made `to_s` / `to_html` renderings. This data is hand-maintained alongside each taxonomy update — see [data/attribution.yml](data/attribution.yml) — so the wording and access dates always match the data you received with this gem version.

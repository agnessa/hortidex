# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] — 2026-05-22

Initial release.

- POWO/WCVP accepted names, synonyms, and full taxonomic hierarchy from family to infraspecific rank
- UPOV GENIE codes for genera, species, and infraspecific taxa
- EU Plant Variety Database registered variety denominations
- `Hortidex::TaxonConcept` concern — associations, scopes, predicate methods, `name_parts`
- `Hortidex::NameFormatter` — botanical name decomposition for display (italic/roman segments)
- `taxonomy:apply` rake task — upserts dataset into Postgres using ltree and tsvector
- Rails generator (`hortidex:install`) for migration and initializer

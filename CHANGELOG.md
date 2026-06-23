# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] — 2026-06-22

Refreshed dataset from new upstream snapshots (WCVP 2026-06-04, UPOV GENIE 2026-06-12,
EU Plant Variety Portal 2026-06-12).

This is a MAJOR release: some `taxon_concepts` ids changed as upstream reclassified,
retired, or merged taxa. The bundled `concordance.csv.gz` now carries 166 redirects
(old uuid → new uuid) and `taxonomy:apply` automatically remaps both built-in and
client-registered foreign keys, so following an old id lands on its successor.

- Updated POWO/WCVP, UPOV, and EU PVP data to the June 2026 snapshots
- Ship `concordance.csv.gz` redirects for ids changed/retired/merged since 1.0.0
  (`powo_id_change`, `powo_adoption`, `powo_retirement`, `powo_reclassified`,
  `powo_autonym_to_parent`, `powo_synonym_to_accepted`, `powo_typo_fix`, `upov_remap`)
- Families now ship only as ancestors of published taxa; emptied "phantom" families
  are retired (redirected to the surviving family or dropped)
- Bundle `dataset_info.yml` — a summary/provenance card for the snapshot
- `taxon_concepts.hortidex_version` now carries per-row provenance — the release each
  row was last backed by an upstream source — instead of the running gem version.
  Carry-over rows (shipped but no longer in the current source) keep an older value;
  the gem version that performed an apply is still recorded in `taxonomy_apply_runs`
- Add `Hortidex::Attribution` — structured licence and citation records for each upstream
  source (POWO/WCVP, UPOV GENIE, EU PVP), loaded from the bundled `attribution.yml`, with
  `to_s` / `to_html` citation renderings so the wording and access dates always match the
  shipped data

## [1.0.0] — 2026-05-22

Initial release.

- POWO/WCVP accepted names, synonyms, and full taxonomic hierarchy from family to infraspecific rank
- UPOV GENIE codes for genera, species, and infraspecific taxa
- EU Plant Variety Database registered variety denominations
- `Hortidex::TaxonConcept` concern — associations, scopes, predicate methods, `name_parts`
- `Hortidex::NameFormatter` — botanical name decomposition for display (italic/roman segments)
- `taxonomy:apply` rake task — upserts dataset into Postgres using ltree and tsvector
- Rails generator (`hortidex:install`) for migration and initializer

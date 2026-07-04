# Changelog

All notable changes to this project will be documented in this file.

## [2.0.1] — 2026-07-04

Maintenance release: packaging cleanup, an attribution correction, and a data
regeneration from the same upstream snapshot as 2.0.0. Taxonomy counts and ids are
unchanged, so this applies as a straight upsert with no concordance step.

- Slim the published gem to its runtime payload — library code, the bundled data
  files, the rake task, and the root docs. Dev-only files (`.github/`, `.gitignore`,
  `.standard.yml`) are no longer shipped, and `homepage` metadata is now set.
- Correct the EU Plant Variety Portal licence URL in `attribution.yml` to point to
  the CC BY 4.0 deed (it previously linked the European Commission legal-notice
  page), and tighten the EU PVP modifications wording.
- Normalise casing in `import_issues.csv.gz`: the `source` column is now lowercase
  (`powo`/`upov`/`eupvp`) to match `taxon_concepts.source`, and `source_status` now
  consistently carries the verbatim upstream Title Case.

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

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Ruby gem that ships a curated, versioned snapshot of plant taxonomy data
(POWO/WCVP, UPOV GENIE, EU Plant Variety Portal) as gzipped CSVs in `data/`, plus
an ActiveRecord-compatible rake task that upserts that data into a PostgreSQL
database. The gem is **distributed via GitHub release tags, not RubyGems** —
consumers pin `gem "hortidex", github: "agnessa/hortidex", tag: "vX.Y.Z"`.

## Commands

```sh
bundle exec rspec                              # full test suite
bundle exec rspec spec/hortidex/apply_task_spec.rb        # one file
bundle exec rspec spec/hortidex/apply_task_spec.rb:118    # one example (by line)
bundle exec standardrb                         # lint (add --fix to autocorrect)
bundle exec bundle-audit check --update        # dependency vuln audit
gem build hortidex.gemspec                      # build the gem
```

Tests need a local **PostgreSQL** with a `hortidex_test` database and the `ltree`
extension; the connection is configured in [spec/support/database.rb](spec/support/database.rb)
(set `CI=true` to use the `localhost` / `postgres` / `postgres` credentials the CI
Postgres service uses). SimpleCov enforces a **98% minimum coverage** in
[spec/spec_helper.rb](spec/spec_helper.rb), so a run can fail on coverage alone even when every example passes.

## The data files are generated upstream — do not hand-edit them

Everything in `data/` (`*.csv.gz`, `attribution.yml`, `dataset_info.yml`) is
**produced by a separate private repo, `hortidex_admin`**, and copied into this
repo at release time. Corrections to data content, casing, counts, or attribution
belong in `hortidex_admin`'s generator, not here — hand-editing a gzipped CSV in
this repo creates drift and is silently overwritten on the next regeneration.
`dataset_info.yml` is a provenance/summary card; diff two versions of it to review
what a data refresh changed.

`import_issues.csv.gz` is **not read by any gem code** — it's a human-inspection
diagnostics file listing taxa that couldn't be resolved during import.

## Architecture

The gem is a thin, mostly-SQL layer over generated data:

- **`ApplyTask`** ([lib/hortidex/apply_task.rb](lib/hortidex/apply_task.rb)) is the core. `taxonomy:apply` runs it.
  It streams the gzipped CSVs through temp tables with batched inserts, inside one
  transaction with `SET CONSTRAINTS ALL DEFERRED`. Order matters and is deliberate:
  (1) apply `concordance.csv.gz` UUID remaps, (2) upsert `taxon_concepts` — accepted
  taxa first (shallowest `ancestor_path` first so parents exist before children),
  then synonyms, (3) upsert `common_names`. Each run is recorded in a
  `taxonomy_apply_runs` row (`:running` → `:succeeded`/`:failed`) that lives *outside*
  the data transaction, and `check_version!` uses the latest succeeded run as a
  **downgrade guard**.
- **Concordance remapping** rewrites old→new UUIDs across the built-in FK columns
  *and* any app tables the consumer registered via
  `Hortidex.configuration.taxon_reference_columns` — that config exists specifically
  so a MAJOR data update can repoint an app's own foreign keys. See
  [README.md](README.md) "Setup".
- **`TaxonConcept`** ([lib/hortidex/taxon_concept.rb](lib/hortidex/taxon_concept.rb)) is an ActiveSupport concern the
  consuming app mixes into its own model. It metaprograms `<rank>_rank?` /
  `<source>_source?` predicates from `RANKS`/`SOURCES` ([lib/hortidex/constants.rb](lib/hortidex/constants.rb)),
  defines associations/validations, and maintains the `search_vector` (tsvector)
  and `ancestor_path` (ltree) columns via raw recursive SQL in `reindex*`.
- **`NameFormatter`** ([lib/hortidex/name_formatter.rb](lib/hortidex/name_formatter.rb)) turns a scientific name into
  `[text, italic?]` segments per botanical convention. The `trusted:` flag (set from
  `powo_id?`) controls how aggressively it splits names that may embed authorship.
- **`Attribution`** ([lib/hortidex/attribution.rb](lib/hortidex/attribution.rb)) loads `data/attribution.yml` into
  structured `Source`/`License`/`Citation` records with `to_s`/`to_html` renderings.
- **Rails integration**: the `Railtie` loads [tasks/taxonomy.rake](tasks/taxonomy.rake); the
  `hortidex:install` generator emits the migration ([lib/generators/hortidex/templates/install.rb](lib/generators/hortidex/templates/install.rb))
  creating `taxon_concepts`, `common_names`, `taxonomy_apply_runs` (uuid PKs, ltree,
  tsvector, deferrable FKs).

The gemspec builds `spec.files` from `git ls-files` filtered to `lib/`, `data/`,
`tasks/` plus the root docs — a new runtime file must live under one of those paths
(or be added to the docs list) to actually ship in the gem.

## "status" means three different things

Be careful: the word *status* spans three unrelated vocabularies.
- `taxon_concepts.status` and the `database`/`published` blocks of `dataset_info.yml`
  use **normalized lowercase** values (`accepted`, `artificial_hybrid`, …).
- `import_issues.source_status` and the `source` blocks of `dataset_info.yml` carry
  the **verbatim upstream Title Case** value (`Accepted`, `Artificial Hybrid`, …).
- `taxonomy_apply_runs.status` is an **integer enum** (`0` running, `1` succeeded,
  `2` failed) — the apply-run lifecycle, nothing to do with taxon status.

## Versioning and release

Bump policy (see [README.md](README.md) "Versioning"): **MAJOR** = UUID scheme or schema change
(requires a `concordance.csv.gz` step); **MINOR** = new dataset snapshot or source;
**PATCH** = data corrections. The gem version ([lib/hortidex/version.rb](lib/hortidex/version.rb)) and the
data's own `dataset_info.yml` `version` are set together at release.

To cut a release: update `lib/hortidex/version.rb`, add a `CHANGELOG.md` entry, copy
in the regenerated `data/` files, commit, then `git tag vX.Y.Z`. Because the gem is
consumed by GitHub tag, **also bump the pinned `tag:` in the README Installation
example** ([README.md](README.md), `gem "hortidex", github: …, tag: "vX.Y.Z"`) — it names a specific
version and goes stale otherwise. Optionally create a matching GitHub Release so
downstream Dependabot PRs get a "Release notes" section (the "Changelog" section is
driven by `CHANGELOG.md`).

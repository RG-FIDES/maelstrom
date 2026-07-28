# Maelstrom Catalogue Pipeline Project Specification

## Project Purpose

This pipeline acquires public metadata for all individual studies declared by the
Maelstrom Research catalogue. It preserves the source API payloads, materializes
normalized SQLite tables, and derives analysis-ready rectangles for assessing the
harmonization potential of longitudinal studies relevant to dementia and cognitive
decline.

## Source System

| Property | Value |
| --- | --- |
| Provider | Maelstrom Research |
| Base URL | `https://www.maelstrom-research.org` |
| Source type | Public JSON API |
| Inventory endpoint | `/ws/studies/_rql` |
| Detail endpoint | `/ws/study/{study_id}` |
| Declared individual-study count | 455 as observed on 2026-07-28 |
| Authentication | None required for the public endpoints used here |

The inventory query restricts records to `Mica_study.className = Study`. Harmonization
initiatives are outside the current extraction scope.

## Active Lane Sequence

| Order | Lane | File | Input | Output | Status |
| --- | --- | --- | --- | --- | --- |
| 0 | Ferry | `manipulation/0-ferry-extract.R` | Public Maelstrom APIs | Staging SQLite database | Active |
| 1 | Ellis | `manipulation/1-ellis-1.R` | Ferry staging database | Analytic SQLite database, parquet mirrors, ontology profiles | Active |

Each lane has a version-controlled schema companion executed at build time, so the
physical data contract can be inspected without reading the R orchestration:

| Lane | Schema companion |
| --- | --- |
| `0-ferry-extract.R` | `manipulation/maelstrom-catalog-schema.sql` |
| `1-ellis-1.R` | `manipulation/maelstrom-analytic-schema.sql` |

## Ferry Contract

### Inputs

- Paginated inventory summaries from `/ws/studies/_rql`.
- One detailed JSON payload from `/ws/study/{study_id}` for every inventory study.
- The local schema in `manipulation/maelstrom-catalog-schema.sql`.
- The target path in `config.yml` at `database.maelstrom_catalog.staging`.

### Permitted Processing

The Ferry lane performs only transport and technical normalization:

- requests public JSON payloads with browser-compatible HTTP headers;
- selects English localized strings for convenient relational columns;
- parses JSON containers into normalized child tables without semantic recoding;
- retains complete inventory and detail payloads as JSON for provenance;
- converts API booleans to SQLite-compatible integer flags;
- creates indexes declared by the schema.

No harmonization score, study eligibility decision, taxonomy collapse, or analytical
variable is created in the Ferry lane.

### Outputs

The canonical Ferry output is:

`data-private/derived/maelstrom/maelstrom-catalog.sqlite`

The database is rebuilt atomically. The lane writes a temporary `.building` database,
validates successful completion of all writes, and replaces the canonical database only
after the build succeeds.

The lane also regenerates a set of machine-readable ontology profiles in
`data-public/metadata/ferry-ontology/`:

| Artifact | Contents |
| --- | --- |
| `ontology-provenance.csv` | Run identifier, timestamps, database size, profile totals |
| `ontology-tables.csv` | Group, grain, row count, column count, primary key per table |
| `ontology-columns.csv` | Fill rate, distinct count, range, example value per column |
| `ontology-relationships.csv` | Observed cardinality and orphan counts per parent-child edge |
| `ontology-vocabularies.csv` | Every distinct value of every controlled-vocabulary column |

These files are the deterministic corroboration for every figure quoted in
`data-public/metadata/INPUT-manifest.md`. They describe the delivered database only; the
profiler never modifies it. A bounded run does not overwrite them unless `--ontology-dir`
is passed explicitly.

## SQLite Table Contract

| Table | Grain | Purpose |
| --- | --- | --- |
| `extraction_runs` | One row per extraction | Source and run provenance |
| `study_inventory` | One row per run and study | Inventory summary and raw summary JSON |
| `study_detail_raw` | One row per run and study | Complete detail payload JSON |
| `studies` | One row per run and study | Core study design, access, and participant metadata |
| `study_memberships` | One row per role assignment | Investigators and contacts |
| `study_attributes` | One row per study attribute | Maelstrom annotation namespaces and terms |
| `study_populations` | One row per study population | Population and sample metadata |
| `population_countries` | One row per population-country pairing | Geographic coverage |
| `population_recruitment_terms` | One row per recruitment term | Recruitment source metadata |
| `data_collection_events` | One row per population event | Event names, years, and descriptions |
| `dce_data_sources` | One row per event-source pairing | Questionnaires, measures, databases, and other sources |
| `dce_biosamples` | One row per event-biosample pairing | Biosample availability by event |

## Rebuild Contract — Ferry

Run the Ferry lane from the repository root:

```powershell
Rscript ./manipulation/0-ferry-extract.R
```

The lane applies `manipulation/maelstrom-catalog-schema.sql` automatically. Together,
these two version-controlled pipeline files regenerate the full contents of
`data-private/derived/maelstrom/`.

For a bounded validation run, override the target path so the canonical database is not
replaced:

```powershell
Rscript ./manipulation/0-ferry-extract.R `
  --db-path=./data-private/derived/maelstrom/test-maelstrom-catalog.sqlite `
  --max-studies=3 `
  --page-size=3
```

## Ferry Validation Expectations

Every complete Ferry run must satisfy these checks:

- inventory total reported by the API equals the extracted inventory row count;
- one `study_detail_raw` row and one `studies` row exist per inventory study;
- every child row references a study present in `studies` for the same run;
- the extraction run finishes with `status = 'completed'`;
- no `.building` file remains after successful promotion.

The observed baseline on 2026-07-28 is 455 individual studies. This is a source
observation, not a hard-coded invariant: future runs must preserve the current API total
and report changes.

## Ellis Contract

### Ellis Inputs

- The latest `status = 'completed'` run in the Ferry staging database, read through
  `database.maelstrom_catalog.staging`.
- The local schema in `manipulation/maelstrom-analytic-schema.sql`.
- The target path in `config.yml` at `database.maelstrom_catalog.analytic`.

### Required Processing

The Ellis lane owns every semantic decision in the pipeline:

- aggregates data collection events into wave, population, and study rectangles;
- applies readable factor taxonomies to source design codes and derived tiers;
- derives longitudinal depth, age reach, geography, and measurement-source coverage;
- crosses studies against research areas to produce a complete coverage matrix;
- screens free text against a version-controlled concept lexicon;
- scores dementia and cognitive-decline relevance and assigns a tier;
- records the screening funnel and the evidence behind every textual signal.

The lane makes exactly one opinionated judgement — whether a study is relevant to dementia
or cognitive decline — and materializes the evidence for it in `screening_evidence`.

### Ellis Outputs

| Artifact | Contents |
| --- | --- |
| `data-private/derived/maelstrom/maelstrom-analytic.sqlite` | 8 tables and the `dementia_frame` view |
| `data-private/derived/ellis/*.parquet` | Type-preserving mirrors of every rectangle plus `dementia_frame` |
| `data-public/metadata/ellis-ontology/*.csv` | Provenance, tables, columns, relationships, vocabularies, screening flow |
| `data-public/metadata/CACHE-manifest.md` | Human-readable description of the delivered store |

The analytic database is rebuilt atomically using the same `.building` promotion the
Ferry lane uses.

### Analytic Rectangle Contract

| Object | Grain | Purpose |
| --- | --- | --- |
| `ellis_runs` | One row per Ellis run | Run and source provenance |
| `concept_lexicon` | One row per concept and term | The exact patterns the run used |
| `screening_evidence` | One row per study, concept, term, and field | Auditable basis for every textual signal |
| `screening_flow` | One row per screening step | The exclusion funnel |
| `study_profile` | One row per study | The 69-column analytic spine |
| `study_population` | One row per study population | Age, geography, recruitment, follow-up window |
| `study_wave` | One row per data collection event | Temporal spine and instrument coverage |
| `study_domain` | One row per study and research area | Complete coverage matrix |
| `dementia_frame` | One row per in-frame study | View over `study_profile` where `flag_in_frame = 1` |

### Frame Definition

Frame membership is a three-step funnel recorded in `screening_flow` and reproduced in
`data-public/metadata/CACHE-manifest.md`:

1. relevance tier is `probable` or `core`;
2. the study has at least two data collection events;
3. the study declares `cognitive_measures` at an event or matches a dementia lexicon term.

Studies failing any step remain in `study_profile` with `flag_in_frame = 0` and a populated
`frame_exclusion_reason`, so an alternative frame definition needs no re-run.

### Ellis Validation Expectations

Every complete Ellis run must satisfy these checks, all asserted in the lane:

- `study_profile` has exactly one row per Ferry study, with no duplicate `study_id`;
- every `study_population` and `screening_evidence` row resolves to a study;
- every `study_wave` row resolves to a population;
- `study_domain` is a complete study-by-area rectangle;
- `relevance_tier` is never missing;
- `flag_in_frame` equals the conjunction of its three criteria;
- `frame_exclusion_reason` is NA exactly when `flag_in_frame` is TRUE;
- `screening_flow` ends at the frame size;
- `n_waves` on the spine equals the `study_wave` rows delivered for that study;
- every rectangle's columns match `maelstrom-analytic-schema.sql` exactly, checked before
  the write so drift is reported as a named column difference.

The observed baseline on 2026-07-28 is 455 studies profiled and 155 in the frame.

## Rebuild Contract — Ellis

```powershell
Rscript ./manipulation/1-ellis-1.R
```

For a scratch run that does not replace the canonical store:

```powershell
Rscript ./manipulation/1-ellis-1.R `
  --target-db=./data-private/derived/maelstrom/test-maelstrom-analytic.sqlite `
  --parquet-dir=./data-private/derived/ellis-test/ `
  --ontology-dir=./data-private/derived/ellis-test-ontology/
```

## Companion Artifacts

All stable-contract artifacts now exist:

| Artifact | Status |
| --- | --- |
| `data-public/metadata/INPUT-manifest.md` | Populated from the 2026-07-28 Ferry run |
| `data-public/metadata/CACHE-manifest.md` | Populated from the 2026-07-28 Ellis run |
| `manipulation/pipeline-validation.dcf` | Bound to `data-private/derived/ellis/study_profile.parquet` |
| `manipulation/1-ellis-1.R` | Active |

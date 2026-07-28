# Maelstrom Catalogue Pipeline Project Specification

## Project Purpose

This pipeline acquires public metadata for all individual studies declared by the
Maelstrom Research catalogue. It preserves the source API payloads and materializes
normalized SQLite tables for subsequent assessment of cross-study harmonization
potential.

## Source System

| Property | Value |
| --- | --- |
| Provider | Maelstrom Research |
| Base URL | `https://www.maelstrom-research.org` |
| Source type | Public JSON API |
| Inventory endpoint | `/ws/studies/_rql` |
| Detail endpoint | `/ws/study/{study_id}` |
| Declared individual-study count | 455 as observed on 2026-07-27 |
| Authentication | None required for the public endpoints used here |

The inventory query restricts records to `Mica_study.className = Study`. Harmonization
initiatives are outside the current extraction scope.

## Active Lane Sequence

| Order | Lane | File | Input | Output | Status |
| --- | --- | --- | --- | --- | --- |
| 0 | Ferry | `manipulation/0-ferry-extract.R` | Public Maelstrom APIs | Staging SQLite database | Active |
| 1 | Ellis | Not yet implemented | Ferry SQLite database | Harmonization-ready relational views or tables | Planned |

The schema companion `manipulation/maelstrom-catalog-schema.sql` is executed by the
Ferry lane when constructing the SQLite database. It is version-controlled separately
so the physical data contract can be inspected without reading the R orchestration.

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

## Rebuild Contract

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

## Validation Expectations

Every complete Ferry run must satisfy these checks:

- inventory total reported by the API equals the extracted inventory row count;
- one `study_detail_raw` row and one `studies` row exist per inventory study;
- every child row references a study present in `studies` for the same run;
- the extraction run finishes with `status = 'completed'`;
- no `.building` file remains after successful promotion.

The observed baseline on 2026-07-27 is 455 individual studies. This is a source
observation, not a hard-coded invariant: future runs must preserve the current API total
and report changes.

## Planned Ellis Boundary

The future Ellis lane will consume the Ferry database and may create standardized
harmonization features, study eligibility rules, topic coverage matrices, overlap scores,
and analytical views. Those semantic transformations must not be added to
`0-ferry-extract.R`.

## Pending Companion Artifacts

The following stable-contract artifacts will be created when the Ellis target is defined:

- `data-public/metadata/INPUT-manifest.md`;
- `data-public/metadata/CACHE-manifest.md`;
- `manipulation/pipeline-validation.dcf`;
- at least one numbered Ellis lane.

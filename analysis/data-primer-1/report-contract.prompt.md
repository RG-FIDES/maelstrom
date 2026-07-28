# Report Contract: data-primer-1

## Type

Data Primer

## Date

2026-07-27 created | Last updated: 2026-07-27

## Status

draft

## Mission

Give any reader — analyst, reviewer, or future maintainer — the fundamental and
authoritative description of the data as it emerges from `manipulation/1-ellis-1.R`:
what the nine objects are, what one row of each means, how they join, what every
column of the study spine holds, and where the metadata is thin. Every EDA and
Report in `analysis/` links here rather than re-explaining the data.

## Data Sources

### Primary

Nine parquet mirrors of the Ellis analytic store, in `data-private/derived/ellis/`:

| File | Group | Grain |
| --- | --- | --- |
| `ellis_runs.parquet` | 1 — Run provenance | One row per Ellis run |
| `concept_lexicon.parquet` | 2 — Screening apparatus | One row per run, concept, term |
| `screening_evidence.parquet` | 2 — Screening apparatus | One row per run, study, concept, term, field |
| `screening_flow.parquet` | 2 — Screening apparatus | One row per run and screening step |
| `study_profile.parquet` | 3 — Study spine | One row per run and study |
| `study_population.parquet` | 4 — Population layer | One row per run, study, population |
| `study_wave.parquet` | 5 — Wave layer | One row per run, study, population, event |
| `study_domain.parquet` | 6 — Coverage matrix | One row per run, study, research area |
| `dementia_frame.parquet` | 7 — Analytic frame | One row per run and in-frame study |

The parquet mirrors are preferred over the SQLite store because they carry real
logicals and ordered factors, whereas SQLite flattens them to 0/1 integers and text.

### Supporting

- `data-public/metadata/ellis-ontology/cache-tables.csv` — declared group, grain, primary key
- `data-public/metadata/ellis-ontology/cache-relationships.csv` — declared cardinality and orphan counts
- `data-public/metadata/ellis-ontology/cache-provenance.csv` — run identifiers and profile totals
- `data-public/metadata/CACHE-manifest.md` — the prose contract this primer renders as evidence
- `manipulation/1-ellis-1.R` — the lane that produced the objects
- `manipulation/maelstrom-analytic-schema.sql` — the physical table, key, view, and index contract
- `ai/project/glossary.md` — Ferry / Ellis / CACHE terminology

## Research Questions

1. What did this store come from — which Ellis run, which Ferry run, and when?
2. What objects exist, and does each one hold the grain the manifest declares?
3. How do the objects join, and does any child row lack a parent?
4. What does the data look like for one study, followed down through all five layers?
5. What does every column of `study_profile` mean, and how completely is it populated?
6. What are the controlled vocabularies, and how did the screening funnel narrow 455 studies to 155?

## Target Artifact Families

- `out1` — Run provenance, printed from `ellis_runs`
- `t1` — Object inventory: declared grain versus observed rows and columns
- `out2` / `out21` — Grain proof and referential integrity, per object and per edge
- `t2` — Observed parent-child cardinality
- `out3` — Single-study view down all five layers
- `out4` / `t3` / `t31` / `g1` — The study spine: dictionary reconciliation, full 69-column reference, reading warnings, sparsity profile
- `t4` / `t41` — Companion objects, summarized
- `t5` — Controlled vocabularies
- `t6` / `t61` — The screening funnel and the tier distribution behind it

## Artifact Inventory

| ID | Type | Title | Purpose |
| --- | --- | --- | --- |
| out1 | Output | Run provenance | Names the Ellis and Ferry runs this primer describes |
| t1 | Table | Object inventory | Declared grain and primary key beside observed rows and columns |
| out2 | Output | Grain proof | Composite-key uniqueness for all nine objects |
| t2 | Table | Observed relationships | Children per parent, parents without children, orphan rows |
| out21 | Output | Referential integrity | Raw orphan counts per parent-child edge |
| out3 | Output | Single-study view | One in-frame study across profile, populations, waves, areas, evidence |
| out4 | Output | Dictionary reconciliation | Documented-but-absent and present-but-undocumented spine columns |
| t3 | Table | Study spine variable reference | All 69 `study_profile` columns: block, description, type, fill, distinct, example |
| t31 | Table | Columns that cannot be read at face value | The subset of spine columns carrying a reading warning |
| g1 | Graph | Where the spine is thin | Fill rate of every incompletely populated spine column |
| t4 | Table | Companion object summary | One row per non-spine object: column counts and sparsest column |
| t41 | Table | Companion column reference | Column-level listing for population, wave, domain, evidence layers |
| t5 | Table | Controlled vocabularies | Distinct values of every vocabulary column |
| t6 | Table | Screening funnel | The four screening steps as delivered |
| t61 | Table | Tier against frame membership | Relevance tier crossed with `flag_in_frame` |

Numbering is nominal — it follows the order in which a reader meets the data
(provenance, inventory, grain, joins, one study, the spine, the companions, the
vocabularies), not a ranking of importance.

## Output Format

HTML — standalone, self-contained, code-fold, table of contents. This is a
reference document read on screen and searched, not printed.

## Upstream EDAs

None. This primer is upstream of every EDA and Report in the project.

## Scope Boundaries

### Included

- Every object, every grain, every join in the Ellis analytic store
- Full column reference for `study_profile`, the validation target
- Summarized column reference for the eight companion objects
- Controlled vocabularies and the screening funnel
- Sparsity of the spine, shown rather than asserted

### Excluded

- Substantive findings about harmonization potential — those belong in EDAs
- The Ferry staging database — documented in `data-public/metadata/INPUT-manifest.md`
- Variable-level Maelstrom metadata (instrument names) — out of the current Ferry scope
- Any inferential analysis

## Notes

- **Numbers are computed, prose is authored.** The column dictionary in
  `local-functions.R` supplies block membership and description only. Every count,
  fill rate, distinct value, and example is read from the parquet at render time.
  `out4` fails loudly if the dictionary and the physical spine disagree.
- **Declared versus observed.** Where the ontology CSVs in
  `data-public/metadata/ellis-ontology/` state a contract, this primer renders the
  contract beside what it measured, so drift is visible rather than assumed away.
- **Every figure is dated.** The catalogue grows and the lexicon will be revised.
  `out1` stamps the run so no figure in this document is read as an invariant.
- The rendered page is linked from the Data Context section of every EDA and
  Report as `../data-primer-1/data-primer-1.html`.

# Maelstrom Harmonization

<!-- Contract produced by the Publishing Interviewer on 2026-07-27. -->
<!-- Intent source: _frontend-1/README.md, section "2026-07-27 — Initial Intent". -->

## Purpose

A project documentation site for the Maelstrom harmonization metadata pipeline,
aimed at collaborators, reviewers, and research planners who need to understand
what the project is trying to establish, how the data pipeline is constructed,
and what the analytic store actually contains.

This is a deliberately small first frontend. It publishes the project's stated
mission and method, the pipeline architecture and its two data manifests, and
the single analytical artifact that exists so far — Data Primer 1. There is no
Analysis section yet: no EDA beyond the `eda-1` scaffold has been composed. The
navigation is structured so that an **Analysis** entry can be inserted between
**Pipeline** and **Primers** once `analysis/eda-2/` exists, without disturbing
any existing page.

## Navigation

<!-- Five navbar entries were specified by the human: home, project, pipeline, -->
<!-- primers, site map. Home lives in content/ but is not a navbar item. -->
<!-- Site Map is a single-page section, so it renders as a direct navbar link. -->

### index (Home Page)

- **Protocol**: Narrative Bridge
- **Intent**: Orient a first-time visitor in under a minute. Establish that this
  is an engineering-disciplined metadata project, not a loose collection of
  scripts. Lead with the architecture diagram, then give just enough prose to
  explain what the diagram shows and where to go next.
- **Goal**: Home page — the first thing a visitor sees.
- **Spirit**: Professional, spare, engineering-forward. Visuals before prose.
  Short paragraphs. No marketing register. The diagram is the hero; text serves
  it rather than competing with it.
- **Inputs**:
  - `./manipulation/images/pipeline-architecture.png` — the hero image. Render
    full-width. The image is approximately 3.5:1 aspect ratio and will be
    illegible if constrained to body width, so give it the full page column and
    enable lightbox so readers can enlarge it.
  - `./ai/project/mission.md` — draw the one-sentence framing of what the
    project is building, and 3–5 of the objectives. Do not reproduce the file.
  - `./manipulation/pipeline.md` — draw the "Purpose" and "Architecture"
    paragraphs to caption the diagram: two lanes, four-part anatomy, the single
    opinionated judgement (dementia relevance).
  - `./README.md` — draw framing context only if it adds something the above
    do not supply.
- **Required structure**:
  - Title and a one-sentence statement of what the project builds.
  - The pipeline diagram, full-width, with a short caption.
  - A brief prose passage (2–3 short paragraphs) explaining the Ferry → staging
    → Ellis → analytic store flow and the corroboration lane.
  - A short "Where to go next" list pointing to Project, Pipeline, and Primers.
- **Constraints**:
  - Do not claim any analytical findings. None have been produced.
  - Do not reference an Analysis or EDA section; it does not exist in this site.

### Project

<!-- The human asked that Project show the documents in ai/project/. -->
<!-- ai/project/README.md is excluded: it documents the directory as a template, -->
<!-- not the project. Confirmed with the human 2026-07-27. -->

#### Mission

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./ai/project/mission.md`

#### Method

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./ai/project/method.md`

#### Glossary

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./ai/project/glossary.md`

### Pipeline

#### Pipeline Guide

- **Protocol**: Technical Bridge
- **Source**: `./manipulation/pipeline.md`
- **allowed_transforms**: `[link_rewrite, shortcode_injection, sanitize, extension_promotion, frontmatter_add]`
- **Transforms**:
  - Inject the mermaid shortcode so the `flowchart LR` block marked
    `<!-- PIPELINE-DIAGRAM-SOURCE -->` renders as a diagram rather than a code
    fence.
  - Rewrite internal repository links to their in-site equivalents where a
    corresponding page exists: `ai/project/glossary.md` → Glossary,
    `data-public/metadata/CACHE-manifest.md` → Cache Manifest,
    `data-public/metadata/INPUT-manifest.md` → Input Manifest,
    `analysis/data-primer-1/` → Data Primer 1.
  - Links to files with no in-site page (`.R` scripts, `.sql` schemas,
    `pipeline-validation.dcf`, `pipeline-project-spec.md`) must be rewritten to
    the public GitHub repository, not left as broken relative paths.
  - Sanitize developer-only noise: local absolute paths, TODO markers, and any
    reference to `data-private/` contents.
- **Constraints**: Prose must not be rewritten. Transformations are mechanical.

#### Cache Manifest

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./data-public/metadata/CACHE-manifest.md`

#### Input Manifest

- **Protocol**: Direct Line (VERBATIM)
- **Source**: `./data-public/metadata/INPUT-manifest.md`

### Primers

<!-- Dropdown with a single entry for now. The section is named in the plural -->
<!-- because further primers are anticipated. -->

#### Data Primer 1

- **Protocol**: Direct Line (REDIRECTED)
- **Source**: `./analysis/data-primer-1/data-primer-1.html`
- **Blocking prerequisite**: This file does not exist at contract time. The
  human has undertaken to render `analysis/data-primer-1/data-primer-1.qmd`
  before the Writer runs. The Writer must halt on this page and report if the
  HTML is still absent — it must not silently substitute the `.qmd`, and it
  must not render the `.qmd` itself.
- **Rationale**: `data-primer-1.qmd` is authored as a standalone artifact
  (`self-contained: true`, `embed-resources: true`, `theme: yeti`,
  `code-fold: show`, `page-layout: full`) whose numbers are computed from the
  parquet at render time. Redirecting preserves it exactly as composed.

### Site Map

<!-- Single page, so this becomes a direct navbar link rather than a dropdown. -->

- **Protocol**: Narrative Bridge
- **Intent**: Help visitors navigate the site and understand what each section
  contains and where its content came from. Must include an **Output Types**
  table defining VERBATIM, COMPOSED, ADAPTED, and REDIRECT, and a **Navigation
  Structure** ASCII tree annotating every page with its output type and source
  provenance.
- **Goal**: Site map — an oriented index of all pages.
- **Spirit**: Concise, functional, factual. No persuasion.
- **Inputs**: The navigation structure of this contract file.
- **Required structure**:
  - Output Types table (four rows: VERBATIM, COMPOSED, ADAPTED, REDIRECT).
  - Navigation Structure ASCII tree covering all eight pages: index, Mission,
    Method, Glossary, Pipeline Guide, Cache Manifest, Input Manifest, Data
    Primer 1, Site Map.
  - A short closing note stating that an Analysis section is deferred until the
    first EDA (`analysis/eda-2/`) is composed.

## Exclusions

- `analysis/eda-1/` — always excluded; mtcars learning scaffold, not an
  analytical product
- `data-private/` — never published under any circumstance
- `*.R` — all R sources, including `analysis/data-primer-1/*.R`
- `*.sql`
- `*_cache/`, `*_files/`
- `nonflow/`
- `_frontend-*/` — publishing working directories
- `.github/` — agent harness; Publisher Notes deferred from this frontend
- `ai/` except the three named files under `ai/project/`
- `guides/`, `philosophy/`, `libs/`, `scripts/`, `utility/` — deferred
- `README.md` inside subfolders (`ai/project/README.md`,
  `manipulation/README.md`, `data-public/metadata/README.md`, and all others)
- `analysis/data-primer-1/report-contract.prompt.md`
- `data-public/metadata/TEMPLATE-manifest.md`
- `manipulation/pipeline-project-spec.md`
- Root `README.md` — no Docs section in this frontend

## Theme

cosmo

## Footer

none

## Repo URL

<https://github.com/RG-FIDES/maelstrom>

## Interviewer Warnings

<!-- Carried forward for the Writer and for the FIDELITY_REPORT. -->

1. **Maturity requirement unmet.** No EDA beyond `eda-1` and no `report-1/`
   exist. This frontend publishes infrastructure and data description without
   analytical findings. This is an accepted, deliberate condition of
   frontend-1, not an oversight.
2. **`analysis/data-primer-1/data-primer-1.html` is absent at contract time.**
   The Data Primer 1 page will fail until it is rendered.
3. **No `source_sha256` values recorded.** Hashing was not available to the
   Interviewer in this session. The Writer should not assume source stability
   and should record actual hashes in `FIDELITY_REPORT.md`.
4. **`manipulation/images/pipeline-architecture.png` must be re-rendered from
   `pipeline.md` if the mermaid source changes.** The Home page uses the static
   PNG while the Pipeline Guide renders the live mermaid; the two can drift.
   `utility/render-pipeline-diagram.R` regenerates the PNG.

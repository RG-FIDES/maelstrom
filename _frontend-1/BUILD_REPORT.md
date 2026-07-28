# Build Report

Writer run 1 — 2026-07-27. Site rendered successfully; no blocking errors.
This report records deliberate deviations from the default rules and one
outstanding warning, so a reviewer can see where judgement was applied.

Overall fidelity status: **WARN** (see `FIDELITY_REPORT.md`). No `fail` checks.

---

## Deviations From Publishing Rules

### 1. Index Component 3 merged into Component 1

- **Severity**: Informational
- **Affected page**: `content/index.qmd`
- **Rule**: Publishing rules 4b require three index components in order — Key
  Image (hero), Welcome, then the Pipeline Architecture Diagram rendered from a
  Mermaid partial.
- **What was done**: The hero image *is* the pipeline architecture diagram. The
  contract specifies the pre-rendered `pipeline-architecture.png`, chosen by the
  human over live Mermaid. Rendering the Mermaid version again after the Welcome
  would place the identical diagram on the page twice.
- **Resolution**: Component 1 and Component 3 are satisfied by the same visual.
  The `## How It Works` section that would have carried the diagram carries the
  prose explanation of it instead, and links onward to the Pipeline Guide, where
  the live Mermaid version does render.
- **Consequence to watch**: the PNG and the Mermaid source can drift. Regenerate
  the PNG with `utility/render-pipeline-diagram.R` whenever the diagram in
  `manipulation/pipeline.md` changes.

### 2. Duplicate title suppression on VERBATIM pages

- **Severity**: Informational
- **Affected pages**: all five VERBATIM pages and the ADAPTED Pipeline Guide
- **Problem**: VERBATIM requires the source body to be preserved exactly, so each
  page retains its source `#` H1. Frontmatter also requires a `title:`. Rendered
  naively, every page shows its title twice.
- **Options considered**: (a) delete the source H1 — rejected, it breaks body
  equivalence and the VERBATIM guarantee; (b) omit `title:` — rejected, it is
  required and feeds the navbar, TOC, and browser title.
- **Resolution**: added `title-block-style: none` alongside `title:` in the
  frontmatter. The frontmatter block is the one permitted addition under the
  VERBATIM rule, and its contents are the Writer's to set. The body is untouched;
  the page renders with the source's own H1 as its visible heading.
- **Verification**: all five VERBATIM pages pass line-by-line body equivalence
  against their sources (`FIDELITY_REPORT.md`, checks 7–11).

### 3. `link_rewrite` recorded as a no-op

- **Severity**: Informational
- **Affected page**: `content/pipeline/pipeline-guide.qmd`
- **Contract instruction**: rewrite internal repository links to in-site
  equivalents, and point links with no in-site page at the public GitHub repo.
- **Finding**: `manipulation/pipeline.md` contains no Markdown links at all.
  Every repository path in it appears as an inline code span. There is nothing to
  rewrite and nothing broken to repair.
- **Decision**: converting code spans into hyperlinks would change the source's
  markup on the Writer's initiative, which the Technical Bridge rule forbids
  ("do not editorially revise the content"). The transform is logged as a no-op
  in `TRANSFORM_LOG.md` rather than silently skipped.
- **If you want those links**: add them to `manipulation/pipeline.md` itself. The
  Writer will then rewrite them on the next run, and the repository keeps a
  single source of truth.

### 4. Root `README.md` not used as an index input

- **Severity**: Informational
- **Contract instruction**: draw framing context from `./README.md` "only if it
  adds something the above do not supply."
- **Finding**: the root README is the generic *Quick Start Template for
  AI-Augmented Reproducible Research* — persona system, memory system, setup
  instructions. It contains nothing about the Maelstrom harmonization project.
- **Decision**: not used. The index is grounded entirely in
  `ai/project/mission.md`, `manipulation/pipeline.md`, and the two manifests.

---

## Warnings

### W1. No `source_sha256` values in the contract

- **Severity**: Warning (the single non-pass check in `FIDELITY_REPORT.md`)
- **Effect**: the Writer cannot detect that a source file changed between the
  contract being written and the site being built. Drift would go unnoticed.
- **Resolution available now**: the audit computed SHA-256 for all seven Direct
  Line and Technical Bridge sources and printed them in `FIDELITY_REPORT.md`.
  Paste them into the contract as `source_sha256` fields and the next run
  enforces them.

### W2. Repository maturity

- **Severity**: Warning, accepted by the human
- **Effect**: no EDA beyond the `eda-1` scaffold and no `report-1/` exist. The
  site presents pipeline infrastructure and data description without analytical
  findings. The index says so explicitly in its Status section, and the site map
  records the absent Analysis section rather than hiding it.

---

## Audit Script Note

`scripts/audit-fidelity.R` was bootstrapped from
`.github/templates/audit-fidelity-template.R` and then extended, because the
template performs only structural checks and would have reported PASS on a site
whose pages had silently drifted from their sources.

One template behaviour was corrected rather than inherited: the template counted
any line containing the token `source_sha256` as evidence that the contract
supplies hashes. This contract *discusses* `source_sha256` in its warnings
section, which produced a false PASS on the first audit run. The check now
requires an actual 64-character digest in field position. The first run reported
PASS on that check; after the fix it correctly reports WARN.

Checks added beyond the template:

- VERBATIM line-by-line body equivalence against source, frontmatter excluded
- ADAPTED transform-log coverage, allowed-transform compliance, Mermaid partial
  resolution, and residual `data-private` detection
- REDIRECT source existence, `_site/` placement, stub URL resolution followed to
  the file it points at, and stub construction rules (meta refresh, no iframe,
  no `target="_blank"`)
- COMPOSED brief-field completeness, required page structure, grounding-source
  resolvability
- Self-containment scan of every `content/**/*.qmd` for references escaping
  `content/`
- SHA-256 fingerprint capture for all Direct Line and Technical Bridge sources

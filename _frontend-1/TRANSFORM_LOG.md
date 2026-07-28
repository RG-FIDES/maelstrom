# Transform Log

Record of every Technical Bridge (ADAPTED) transformation applied during assembly
of `_frontend-1/content/`. One entry per transform per page.

Transform vocabulary is defined in
`.github/instructions/publishing-rules.instructions.md`, Section 3.

---

## 2026-07-27 — Writer Run 1

### content/pipeline/pipeline-guide.qmd

**Source**: `manipulation/pipeline.md`
**Allowed transforms (from contract)**: `link_rewrite`, `shortcode_injection`,
`sanitize`, `extension_promotion`, `frontmatter_add`

| # | Transform | Applied | Detail |
|---|-----------|---------|--------|
| 1 | `extension_promotion` | Yes | `pipeline.md` written as `pipeline-guide.qmd`. Required because the page now carries a `{{< include >}}` shortcode, which Quarto only processes in `.qmd`. |
| 2 | `frontmatter_add` | Yes | Prepended `title: "Pipeline Guide"` and `title-block-style: none`. The source has no frontmatter; `title-block-style: none` prevents the added title from duplicating the preserved body `# Maelstrom Catalogue Metadata Pipeline` heading. |
| 3 | `shortcode_injection` | Yes | The ```` ```mermaid ```` fence (source lines 20–82, immediately after the `<!-- PIPELINE-DIAGRAM-SOURCE -->` marker) was extracted verbatim into `content/pipeline/_mermaid-pipeline.qmd`, converted to a ```` ```{mermaid} ```` executable cell with label `fig-pipeline-architecture`, and replaced in place with `{{< include _mermaid-pipeline.qmd >}}`. A plain `mermaid` fence renders as a code block rather than a diagram. Diagram content is byte-identical to the source. |
| 4 | `sanitize` | Yes | Four references to `data-private/` removed. See table below. |
| 5 | `link_rewrite` | No-op | The source contains no Markdown links. All repository paths appear as inline code spans, not hyperlinks, so there is nothing to rewrite and nothing broken to repair. Converting code spans into links would be an editorial change and was not performed. |

#### Sanitize detail

| Location | Before | After |
|----------|--------|-------|
| Current Artifacts table | `` `data-private/derived/maelstrom/maelstrom-catalog.sqlite` `` | `` `maelstrom-catalog.sqlite` `` — role text gains "(private derived output)" |
| Current Artifacts table | `` `data-private/derived/maelstrom/maelstrom-analytic.sqlite` `` | `` `maelstrom-analytic.sqlite` `` — role text gains "(private derived output)" |
| Current Artifacts table | `` `data-private/derived/ellis/*.parquet` `` | `Parquet mirrors` — role text gains "(private derived output)" |
| Manifest Validation | "The report is written to `` `data-private/derived/manifest-validation/validation-report.md` ``." | "The report is written to the private derived validation directory." |

**Rationale**: Publishing rule 5b requires pipeline outputs to be described
generically without exposing file system paths, and the contract's `sanitize` scope
names `data-private/` references explicitly. Counts, dates, and all surrounding prose
are unchanged.

#### Not applied

- No prose was rewritten, reordered, or removed.
- The Execution and Diagnostic Checkpoints sections, including their PowerShell and
  SQL blocks, were retained. The contract scoped `sanitize` to local absolute paths,
  TODO markers, and `data-private/` references; none of those appear in those
  sections, and the execution guidance is the substance of a pipeline guide.
- No section headings were altered.

---

## Asset Resolution

No ADAPTED or VERBATIM source referenced any local image, include, or other asset
(verified by scanning for `![...]()`, `<img>`, and `{{< include >}}` in all seven
Direct Line and Technical Bridge sources). The only co-located binary asset is
`content/images/pipeline-architecture.png`, referenced by the COMPOSED index page.

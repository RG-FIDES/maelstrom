# Frontend 1 — Intent Record

Canonical log of human intent for `_frontend-1/`. The Interviewer appends a
timestamped section each time intent is expressed in chat. The most recent
section is authoritative.

---

## 2026-07-27 — Initial Intent

### Stated Request

> "Design frontend-1. Navbar: home, project, pipeline, primers, site map. Home
> features pipeline diagram. Project shows docs in `ai/project/`. Primers has a
> dropdown, but only one document for now — primer 1. Site map is a single doc.
> For now we keep things simple, in preparation for composing the first EDA
> (eda-2)."

### Audience and Use Case

- Primary audience: collaborators and reviewers who need to understand what the
  Maelstrom harmonization project is, how its data pipeline works, and what the
  analytic store contains.
- Use case: an orientation site that stands on its own before any EDA exists,
  and that can absorb an Analysis section once `analysis/eda-2/` is composed.

### Messaging Goals and Tone

- Lead with the pipeline architecture — the diagram is the hero of the home page.
- Establish credibility through provenance: schema-declared contracts, atomic
  promotion, self-profiling evidence.
- Tone: professional, spare, engineering-forward. Visuals before prose.

### Required Sections

- **Home** (`index`, not in navbar) — features the pipeline diagram.
- **Project** — the documents in `ai/project/`.
- **Pipeline** — pipeline guide and data manifests.
- **Primers** — dropdown; Data Primer 1 is the only entry for now.
- **Site Map** — single top-level page, not a dropdown.

### Deliberate Deviations From Default Architecture

- **No Analysis section.** No EDA beyond `eda-1` exists yet. The section is
  deferred until `analysis/eda-2/` is composed.
- **No Docs section.** Site Map is promoted to a top-level navbar entry;
  README and Publisher Notes are deferred to keep the first frontend simple.
- **Story / Materials / Philosophy** — not included.

### Exclusions and Caveats

- `analysis/eda-1/` — permanently excluded (mtcars learning scaffold).
- `data-private/` — never published.
- All `.R` sources, caches, and prompt/contract working files excluded.

### Open Issues at Time of Writing

- `analysis/data-primer-1/data-primer-1.html` has not been rendered. A
  REDIRECT page for Primer 1 requires the rendered HTML to exist.

### Interview Resolutions

| Question | Resolution |
|----------|------------|
| Page inventory | Accepted as proposed. `ai/project/README.md` excluded; Input Manifest included under Pipeline; no Docs section. |
| Primer 1 delivery | Direct Line (REDIRECTED). Human will render the `.qmd` before the Writer runs. |
| Home page hero | Pre-rendered `manipulation/images/pipeline-architecture.png`, full width with lightbox. |
| Site title | Maelstrom Harmonization |
| Theme | `cosmo` |
| Footer | none |
| Repository | `https://github.com/RG-FIDES/maelstrom` — confirmed public, linked from the site. |

### Outcome

Contract written to `_frontend-1/publishing-contract.prompt.md` on 2026-07-27.
Nine pages across four navbar entries plus the home page.

---

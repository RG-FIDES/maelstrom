# Fidelity Report

- Overall Status: **WARN**
- Generated: 2026-07-27 21:27:22
- Frontend Path: `C:/Users/andriy.koval/Documents/GitHub/rg-fides/maelstrom/_frontend-1`
- Fingerprint algorithm: `sha256`
- Taxonomy Source: `.github/instructions/publishing-rules.instructions.md` (Section "Taxonomy and Mapping Registry" — designates Protocol, Mode, Output Type concepts)

## Contract Protocol Counts

- VERBATIM pages: 5
- REDIRECTED pages: 1
- ADAPTED pages: 1
- COMPOSED pages: 2

## VERBATIM Body Equivalence

| Page | Source | Body lines | Result | Source sha256 |
| --- | --- | --- | --- | --- |
| content/project/mission.qmd | ai/project/mission.md | 38 | pass | 18bb17a36420b73826756b1fd5bfd6233fae0d22aed38f20cc5c1c4317142c46 |
| content/project/method.qmd | ai/project/method.md | 57 | pass | 70abf4da04d76516f2a2acbb4d7ff73e26b92435bd9f7748cb3cf31bba010566 |
| content/project/glossary.qmd | ai/project/glossary.md | 166 | pass | 728f5c48463be6d24c7afcefff3ab0c66243621af580ffcf08004498e99be70d |
| content/pipeline/cache-manifest.qmd | data-public/metadata/CACHE-manifest.md | 606 | pass | 180dc5ef4a69fd9ecdd7fc80b33e06a5c9e7dbae85a9c780586977efadc9e37b |
| content/pipeline/input-manifest.qmd | data-public/metadata/INPUT-manifest.md | 405 | pass | ad9cef9720247f53d5ef4a87594e4b265ea0fc6e305a018493842baf915984fc |

## ADAPTED Transform Compliance

| Page | Source | Transforms logged | Source sha256 |
| --- | --- | --- | --- |
| content/pipeline/pipeline-guide.qmd | manipulation/pipeline.md | link_rewrite, shortcode_injection, sanitize, extension_promotion, frontmatter_add | d820af5ecdeb44a86a5dc2b1f48c7b89449a22b66fddce8a8e3cba48dc2d75e5 |

## REDIRECT Placement

| Stub | Source HTML | Placed at | Bytes | Source sha256 |
| --- | --- | --- | --- | --- |
| content/primers/data-primer-1.qmd | analysis/data-primer-1/data-primer-1.html | _site/reports/data-primer-1.html | 3,380,879 | bdd06df4c2d39d45342d5cd9eae786f1a70ec6a35f6c406a80b1b1e639c068f7 |

## COMPOSED Grounding

| Page | Grounding inputs | Structure |
| --- | --- | --- |
| content/index.qmd | ai/project/mission.md<br>manipulation/pipeline.md<br>data-public/metadata/INPUT-manifest.md<br>data-public/metadata/CACHE-manifest.md | pass |
| content/site-map.qmd | publishing-contract.prompt.md | pass |

## Check Results

1. [PASS] Contract file found.
2. [PASS] content/ exists.
3. [PASS] _site/ exists.
4. [PASS] Transform log requirement satisfied.
5. [WARN] No source_sha256 fields found in contract (recommended for deterministic drift checks). Fingerprints captured below can seed them.
6. [PASS] allowed_transforms metadata present for Technical Bridge pages.
7. [PASS] VERBATIM body equivalence: content/project/mission.qmd
8. [PASS] VERBATIM body equivalence: content/project/method.qmd
9. [PASS] VERBATIM body equivalence: content/project/glossary.qmd
10. [PASS] VERBATIM body equivalence: content/pipeline/cache-manifest.qmd
11. [PASS] VERBATIM body equivalence: content/pipeline/input-manifest.qmd
12. [PASS] ADAPTED page has TRANSFORM_LOG coverage: content/pipeline/pipeline-guide.qmd
13. [PASS] ADAPTED transforms all within the allowed list: content/pipeline/pipeline-guide.qmd
14. [PASS] ADAPTED mermaid partial resolved: content/pipeline/_mermaid-pipeline.qmd
15. [PASS] ADAPTED sanitize removed all data-private references: content/pipeline/pipeline-guide.qmd
16. [PASS] REDIRECT source HTML exists: analysis/data-primer-1/data-primer-1.html
17. [PASS] REDIRECT target placed in _site: _site/reports/data-primer-1.html
18. [PASS] REDIRECT stub URL resolves to the placed target: content/primers/data-primer-1.qmd
19. [PASS] REDIRECT stub uses meta refresh, no iframe, no target=_blank: content/primers/data-primer-1.qmd
20. [PASS] COMPOSED page authored: content/index.qmd
21. [PASS] COMPOSED brief fields present in contract for: content/index.qmd
22. [PASS] COMPOSED required structure present: content/index.qmd
23. [PASS] COMPOSED grounding sources all resolvable: content/index.qmd
24. [PASS] COMPOSED page authored: content/site-map.qmd
25. [PASS] COMPOSED brief fields present in contract for: content/site-map.qmd
26. [PASS] COMPOSED required structure present: content/site-map.qmd
27. [PASS] COMPOSED grounding sources all resolvable: content/site-map.qmd
28. [PASS] Self-containment: no content/ page references a path outside content/ (the REDIRECT stub target is placed by a post-render hook and is exempt).

## Notes

- VERBATIM equivalence compares the page body against the source line by line,
  after removing the added YAML frontmatter and blank edges. Any difference is a
  `fail`, not a `warn`.
- The contract records no `source_sha256` values. The fingerprints above are the
  current source digests and can be pasted into the contract to enable drift
  detection on the next run.
- The REDIRECT resolution check follows the `url=` value out of the rendered stub
  and confirms a file exists at that location inside `_site/`.

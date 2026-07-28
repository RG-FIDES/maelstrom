# Methodology

## Analytical Approach

The project proceeds from source preservation to progressively more interpretive layers.

1. **Ferry acquisition:** retrieve the public study inventory and study detail payloads;
   preserve complete JSON and normalize repeated entities into SQLite tables.
2. **Ellis standardization:** standardize study designs, geography, recruitment frames,
   follow-up structure, data sources, biosamples, and annotation terms without erasing
   source values.
3. **Study-level screening:** describe structural overlap and identify candidate study
   pairs or groups using explicit inclusion criteria.
4. **Variable-level assessment:** retrieve dataset and variable metadata for shortlisted
   studies and assess construct, temporal, population, and measurement compatibility.
5. **Sensitivity analysis:** compare candidate rankings under alternative definitions,
   missing-metadata assumptions, and weighting schemes.

Study-level similarity is treated as a discovery signal, not proof of harmonizability.

## Reproducibility Standards

- Keep extraction, schema, transformation, validation, and analysis code under version
  control.
- Preserve raw API payloads alongside normalized fields for audit and reparsing.
- Record extraction timestamps, endpoint URLs, expected source totals, and completion
  status.
- Rebuild derived assets from code rather than editing SQLite tables manually.
- Use stable study, population, and event identifiers as source keys.
- Declare seeds for any stochastic matching or clustering method.
- Store sensitive or bulky generated assets under `data-private/derived/`.

## Data Quality Standards

- Reconcile inventory, raw-detail, and normalized-study counts on every complete run.
- Treat source-count changes as reviewable events rather than automatic failures.
- Distinguish `No`, `Not applicable`, `Unknown`, and missing metadata where the source does.
- Retain original HTML and code values when producing cleaned analytical labels.
- Report completeness by field before comparing studies.
- Validate foreign-key relationships and uniqueness at each entity grain.

## Harmonization Assessment Principles

- Separate structural feasibility from substantive construct compatibility.
- Compare information at the population and data-collection-event levels when available.
- Require temporal alignment to be explicit rather than inferred from study start year.
- Use Maelstrom annotations as source-provided descriptors, not exhaustive truth.
- Document every taxonomy mapping and scoring weight in the future Ellis layer.
- Prefer interpretable component scores over a single opaque similarity metric.

## Documentation & Reporting

- Use `manipulation/pipeline.md` as the canonical execution guide.
- Keep source and output contracts in `manipulation/pipeline-project-spec.md`.
- Use Quarto documents for exploratory and presentation analyses.
- Document major methodological decisions in project memory and analysis prose.
- Generate manifests from actual delivered outputs rather than code intention alone.

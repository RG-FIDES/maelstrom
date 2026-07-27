# Rendering an HTML Report from a .qmd + .R Pair

This guide walks you through rendering an HTML document from the dual-file pattern used in this project.

## Prerequisites

- **R** installed: <https://cran.r-project.org/>
- **Quarto** installed: <https://quarto.org/docs/get-started/>
- Required R packages installed (each `.R` script declares its dependencies via `library()` calls)

## The Dual-File Pattern

Every analysis in `analysis/` consists of two files that work together:

| File | Role |
|------|------|
| `.R` script | **Analytical laboratory.** All code lives here: data loading, wrangling, plotting. Chunks are delimited by `# ---- chunk-name ---` comments. |
| `.qmd` document | **Publication layer.** Contains YAML front matter, narrative text, and empty code chunks that pull code from the `.R` script via `read_chunk()`. |

The `.qmd` file calls `read_chunk()` in its setup chunk to register all named chunks from the `.R` script. Each subsequent chunk in `.qmd` has a matching `label` and an empty body; code executes from the sourced `.R` file.

## Rendering Step by Step

### 1. Open a terminal at the project root

All paths are relative to the project root (`quick-start-template/`).

### 2. Render with Quarto CLI

```powershell
quarto render analysis/eda-1/eda-1.qmd
```

This command:

1. Starts an R session.
2. Executes the `.qmd`, which calls `read_chunk("analysis/eda-1/eda-1.R")`.
3. Runs each named chunk in order.
4. Produces an HTML file in the same directory (`analysis/eda-1/eda-1.html`).

### 3. Open the output

Open `analysis/eda-1/eda-1.html` in any browser.

## Rendering from VS Code

Use **Tasks: Run Task** and select **Render EDA-1 Quarto Report**.

## Common Issues

| Problem | Solution |
|---------|----------|
| `Error: package 'X' not found` | Install the missing package: `install.packages("X")` |
| Working directory errors | Ensure terminal is at project root |
| `read_chunk()` cannot find `.R` file | Verify path in `read_chunk()` is project-root relative |
| Plots not rendering | Verify plotting packages are installed |

## How It Works Under the Hood

```text
analysis/eda-1/
|- eda-1.R
|- eda-1.qmd
|- eda-1.html
`- figure-png-iso/
```

The `.qmd` setup chunk contains:

```r
read_chunk("analysis/eda-1/eda-1.R")
```

This tells `knitr` to scan for chunk markers such as `# ---- load-packages ---` and register each section as a named chunk.

## Next Steps

- Read `analysis/eda-1/eda-style-guide.md` for chunk naming and graph family conventions.
- See `guides/flow-usage.md` for how analysis fits into the broader pipeline.
- Modify a chunk in the `.R` file and re-render to validate the workflow.

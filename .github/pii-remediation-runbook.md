# PII Remediation Runbook

This runbook describes how to investigate and remediate potential exposure of personally identifiable information (PII) in a repository.

## Trigger

A security reviewer or automated scan flags one or more repository files for potential sensitive data exposure.

Treat flagged files as leads, not final conclusions.

## Investigation Workflow

### 1. Search source files for risky identifiers

```powershell
Select-String -Path "manipulation\*.R","manipulation\*.Rmd" -Pattern "\b\d{9}\b"
```

References to a column name such as `social_insurance_number` are not automatically an exposure.

### 2. Check rendered outputs

Rendered markdown and HTML commonly leak row-level values during debugging output.

```powershell
git ls-files "*.md" | ForEach-Object { Select-String -Path $_ -Pattern "\b\d{9}\b" }
```

### 3. Check tracked data files

```powershell
git ls-files | Select-String -Pattern "\.(rds|csv|parquet|xlsx)$"
```

Tracked raw/derived data files should generally be treated as high risk and reviewed immediately.

### 4. Check Git history

```powershell
git log --all -S "<SENSITIVE_VALUE>" --name-only --format=""
```

If values appear in history, removal from the latest commit alone is insufficient.

## Scope Classification

| Category | Example | Action |
|---|---|---|
| Hardcoded sensitive value in source | Test value in code condition | Replace with synthetic placeholder |
| Sensitive value in rendered output | `glimpse()` or printed rows | Untrack output and scrub history |
| Sensitive value in tracked data file | `.csv` or `.rds` in repo | Remove and scrub history |
| Field-name reference only | `"social_insurance_number"` string | Usually no action |

## Remediation Steps

### 1. Replace real identifiers with synthetic placeholders

Use deterministic fake values and annotate replacements.

### 2. Untrack generated outputs

```powershell
git rm --cached manipulation/example-output.md
```

### 3. Update ignore rules

Add generated outputs to `.gitignore` where appropriate:

```text
*.html
*.md
*.png
*.jpg
```

Retain explicit allow-list entries for required documentation files.

### 4. Commit working-tree cleanup

```powershell
git add .gitignore
git commit -m "security: remove tracked outputs with potential PII and update ignore rules"
```

### 5. Purge from history when required

Use a history-rewrite tool such as `git filter-repo` to remove sensitive paths from all commits.

After rewriting history, force-push and instruct collaborators to re-clone.

## Prevention Controls

- Add pre-commit checks for sensitive patterns.
- Keep data artifacts in private, ignored directories.
- Avoid printing raw identifiers in rendered reports.
- Perform periodic repository scans for high-risk patterns.

## Verification Checklist

- [ ] Sensitive values no longer exist in tracked files.
- [ ] Sensitive values no longer exist in Git history.
- [ ] `.gitignore` blocks generated and data-leak-prone outputs.
- [ ] Team informed if history rewrite was performed.

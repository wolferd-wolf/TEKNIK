# TEKNIK CI Reports

GitHub Actions updates this branch after every completed, failed, skipped, or cancelled TEKNIK CI run.

- `latest.md` — human-readable latest result
- `latest.json` — machine-readable latest result
- `runs/` — historical run summaries

Full job logs are kept in the `TEKNIK-CI-Report-<run-id>-attempt-<attempt>` workflow artifact to avoid permanently bloating Git history.

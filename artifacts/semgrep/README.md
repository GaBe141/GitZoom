# Semgrep scan artifacts

This folder documents where Semgrep scan results are stored and how to retrieve them.

Recommendations:

- Local runs: semgrep outputs such as `semgrep-results.json` and `semgrep-workflows.json` are intentionally ignored in the repository. Keep them locally or move them into `artifacts/semgrep/` if you want to check them in (not recommended).
- CI runs: GitHub Actions jobs (like the full repository Semgrep run) should upload scan artifacts using `actions/upload-artifact`. Download artifacts from the workflow run page in Actions.

To remove the local semgrep virtualenv that may be created during scans, run:

```powershell
.\scripts\clean-venv.ps1
```

If you want to permanently store a semgrep report in the repo, move the JSON into this folder and commit it intentionally (avoid large or frequently changing scan outputs).

# Plan: Monitoring Upload (Push) Speeds

## Current baseline (from first run)

| Operation        | Duration | Notes                    |
| ---------------- | -------- | ------------------------- |
| Git Fetch        | 439 ms   | From remote               |
| Git Push         | 2,223 ms | Push to origin            |
| Lightning Push   | ~2,456 ms| Stage + commit + push     |

Push dominates total time (~2 s); local stage+commit are already fast (~270 ms). Monitoring upload speed means tracking **push duration** (and optionally fetch) over time.

---

## 1. What to measure

- **Push duration (ms)** – Time for `git push` to complete. Primary metric.
- **Fetch duration (ms)** – Optional; useful to see network vs remote slowness.
- **Payload context (optional)** – Commit count or “nothing to push” so you can filter no-op pushes.
- **Throughput (MB/s)** – Only if you want to derive it (e.g. from `git push` verbose output and object count/size). Not required for “is push getting slower?”.

Recommendation: Start with **push duration** and **fetch duration** only; add payload/throughput later if needed.

---

## 2. Where to run tests

**Existing scripts:**

- **`experiments/performance-benchmark.ps1`**
  - `-TestScenario network` – Measures fetch + push only (good for upload monitoring).
  - `-TestScenario lightning` – Full stage + commit + push (realistic workflow).
  - `-GenerateReport` – Writes `experiments/performance-report-YYYYMMDD-HHMMSS.json`.
- **`experiments/continuous-testing.ps1`**
  - Includes **Git Fetch** and **Git Push** in `Invoke-CorePerformanceTests`; also measures file I/O, git status, git log, memory, pipeline.
  - Modes: `watch`, `single`, `benchmark`, `regression`. Results go to `test-results/continuous-test-*.json`.
- **`experiments/record-upload-speed.ps1`**
  - Runs the network benchmark, parses the latest report, and appends one row to `test-results/upload-speed.csv`. Use for scheduled or on-demand logging.

So today, **one-off upload speed tests** = run `performance-benchmark.ps1 -TestScenario network` (and optionally `lightning`) with `-GenerateReport`. **Ongoing monitoring** = run `record-upload-speed.ps1` (or schedule it; see section 8).

---

## 3. Where to store results

- **Current:** `experiments/performance-report-*.json` (one-off) and `test-results/continuous-test-*.json` (continuous-testing; no push in there yet).
- **Proposed:** Use a single place for “upload speed” metrics so trends are easy:
  - **Option A:** Keep using `experiments/performance-report-*.json` for all benchmark runs (including network). Add a simple script or doc that “last N reports” = upload speed history.
  - **Option B:** New folder `metrics/` or `test-results/upload/` with a dedicated naming convention, e.g. `upload-YYYYMMDD-HHMMSS.json`, and ensure it’s gitignored (like `test-results/`) so local runs don’t clutter the repo.
  - **Option C:** Append push/fetch duration to a single **rolling log file** (e.g. `test-results/upload-speed.log` or `metrics/push-durations.csv`) with columns: timestamp, push_ms, fetch_ms, scenario. Easy to plot or ingest later.

Recommendation: **Option C** (one rolling log/CSV) for monitoring; keep **Option A** for full benchmark reports. Document both in this plan.

### 3.1 CSV format (rolling log)

- **Path:** `test-results/upload-speed.csv` (directory `test-results/` is gitignored).
- **Header and columns:**

```csv
timestamp_utc,scenario,fetch_ms,push_ms,fetch_success,push_success
```

- `timestamp_utc` – ISO 8601 (e.g. `2026-02-13T19:30:00Z`).
- `scenario` – e.g. `network` for runs from `record-upload-speed.ps1`.
- `fetch_ms`, `push_ms` – integer milliseconds; `-1` if not recorded.
- `fetch_success`, `push_success` – `true` or `false`.

The script `experiments/record-upload-speed.ps1` creates the file and header on first run, then appends one data row per run.

---

## 4. How often to measure

- **On-demand** – When you want a quick check: run `.\experiments\performance-benchmark.ps1 -TestScenario network -GenerateReport`.
- **Scheduled** – e.g. daily or weekly: Task Scheduler (Windows) or cron running the same command; results appended to the rolling log (Option C) or new report files (Option A).
- **On every push (optional)** – Lightweight: wrap `zoom` / lightning-push so that after each push it appends one line (timestamp, push_ms) to a log file. No separate scheduled job; real-world trend.

Recommendation: Start with **on-demand** + **weekly scheduled** run; add “on every push” logging later if you want per-push trends.

---

## 5. Implementation steps (short)

1. **Baseline (done)** – You already ran network + lightning and have two reports; keep them as the first baseline.
2. **Add push/fetch to continuous-testing (optional)** – In `experiments/continuous-testing.ps1`, add one or two operations to `Invoke-CorePerformanceTests`: e.g. “Git Fetch” and “Git Push” (same as in performance-benchmark). Then watch/benchmark/regression modes will include upload speed. Be aware: push can fail if there’s nothing to push; handle “already up-to-date” so it doesn’t count as a failure.
3. **Define a rolling log format** – e.g. CSV: `timestamp, scenario, push_ms, fetch_ms, success`. Create a small helper script that runs `performance-benchmark.ps1 -TestScenario network`, parses the generated report (or captures stdout), and appends one line to `test-results/upload-speed.csv` (or `metrics/push-durations.csv`). Ensure that path is gitignored.
4. **Schedule the script** – Use Windows Task Scheduler to run the helper (or the benchmark directly and then a parser) on a schedule (e.g. weekly). Document the task name and schedule in this doc or in `docs/STRUCTURE.md`.
5. **Optional: log push time from zoom** – In `scripts/enhanced-lightning-push.ps1` (or the script that runs on `zoom`), after a successful push, append `(Get-Date), $pushStopwatch.ElapsedMilliseconds` to a log file. Minimal code; gives real-user upload trend.

---

## 6. Quick reference: run speed tests now

From repo root (PowerShell):

```powershell
# Network only (fetch + push) – best for upload monitoring
.\experiments\performance-benchmark.ps1 -TestScenario network -GenerateReport

# Full lightning workflow (stage + commit + push)
.\experiments\performance-benchmark.ps1 -TestScenario lightning -GenerateReport

# All scenarios (small files, large files, lightning, network, VS Code)
.\experiments\performance-benchmark.ps1 -TestScenario all -GenerateReport
```

Reports are written under `experiments/` as `performance-report-YYYYMMDD-HHMMSS.json`. To append one row to the CSV: `.\experiments\record-upload-speed.ps1`.

---

## 7. Scheduling the upload-speed log

Use Windows Task Scheduler to run `record-upload-speed.ps1` on a schedule so `test-results/upload-speed.csv` gets one row per run.

**Task settings:**

- **Task name:** e.g. `GitZoom Upload Speed Log`
- **Program:** `pwsh.exe` (or full path, e.g. `C:\Program Files\PowerShell\7\pwsh.exe`). Use `powershell.exe` if you use Windows PowerShell 5.
- **Arguments:** `-NoProfile -ExecutionPolicy Bypass -File "C:\Users\gabe_\Documents\GitZoom\experiments\record-upload-speed.ps1"` (replace with your repo path).
- **Start in:** `C:\Users\gabe_\Documents\GitZoom` (your repo root).
- **Trigger:** e.g. Weekly on Sunday at 3:00 AM, or Daily at 2:00 AM.
- **Conditions:** Run when user is logged on (or “Run whether user is logged on or not” if you want it to run in the background).
- **Settings:** Enable “Allow task to be run on demand” so you can run it manually to test.

**One-time registration via schtasks (edit paths before running):**

```powershell
schtasks /Create /TN "GitZoom Upload Speed Log" /TR "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\Users\gabe_\Documents\GitZoom\experiments\record-upload-speed.ps1\"" /SC WEEKLY /D SUN /ST 03:00 /RU "%USERNAME%" /RP "" /F
```

Replace `C:\Users\gabe_\Documents\GitZoom` with your repo path. `/RU` and `/RP` may be omitted if the task runs only when you are logged on. Run the command from an elevated prompt if you create a task for another user.

---

## 8. Out of scope (for later)

- Parsing `git push --verbose` for object count/size to compute MB/s.
- Dashboard or real-time graph (could consume the rolling log or JSON reports).
- Alerts when push duration exceeds a threshold (e.g. > 5 s); could be added to the scheduled script or to continuous-testing regression mode.

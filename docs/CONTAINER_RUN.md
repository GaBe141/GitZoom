# Running the containerized bench harness (local + fallback)

This document explains how to build and run the containerized CLI + measurement harness locally (PowerShell on Windows), and provides a fallback to run the harness directly if Docker isn't available.

## Requirements

- PowerShell 7+ (`pwsh`) available on PATH for local harness runs.
- Docker (Engine or Desktop) if you want to build/run the container locally.
- Node.js 18+ (only required if you run the CLI locally outside of Docker).

---

## Build the container locally (PowerShell)

Open a PowerShell prompt at the repository root (this repo) and run:

```powershell
# Build image (from repo root)
docker build -t gitzoom/cli:local-test -f tools/gitzoom-cli/Dockerfile .

# Run the harness (example runs the default command in the image)
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  --name gitzoom-bench \
  gitzoom/cli:local-test
```

Notes:
 
- The Docker image will mount the repository at `/workspace` so the harness can read/write `artifacts/`.
- On Windows PowerShell, `${PWD}` expands to the current path; if you use plain `cmd.exe` or WSL, adjust mounting syntax accordingly.

## Run the harness locally without Docker (PowerShell fallback)

If Docker is not available (e.g., on CI-lite machines), you can run the measurement harness directly using PowerShell and the repository scripts.

```powershell
# Run the measurement harness (example: 10 iterations) from repo root
pwsh -NoProfile -ExecutionPolicy Bypass -File experiments/measurement-harness.ps1 -Iterations 10 -OutDir artifacts

# Validate generated artifact shape
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/validate-measurement.ps1 -InputFile artifacts\measurement-<timestamp>.json
```

## CI notes and secrets

The included GitHub Actions workflow `.github/workflows/bench-container.yml` will build and run this image. To publish the built image to a registry (optional), provide one of the following repository secrets and update the workflow to enable the publish step:

- For GitHub Container Registry (GHCR): `CR_PAT` or `GHCR_TOKEN` (personal access token with `packages:write` scope)
- For Docker Hub: `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`

If you want me to add the publish step to the workflow and a short docs section showing how to register those secrets, say so and I'll update `.github/workflows/bench-container.yml` and the README.

## Troubleshooting

- Local Docker build fails with "'docker' is not recognized": Docker is not installed or not on PATH. Install Docker Desktop for Windows or use a CI runner (GitHub Actions) where Docker is available.
- If the harness cannot write to `artifacts/`, ensure the mounted volume is writable by the container user (adjust mount options or run container as a user with proper permissions).

---

File created by the repo automation to document local container and fallback run instructions.

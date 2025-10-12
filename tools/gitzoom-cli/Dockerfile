### Build stage: use PowerShell image to allow running ps scripts during build if needed
FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04 AS builder

WORKDIR /src

# Copy repository so we can install deps and run any build steps
COPY . /src

# Install node and npm (required to install JS deps). Keep layer small and clean caches.
RUN apt-get update \
  && apt-get install -y curl ca-certificates gnupg lsb-release git build-essential \
  && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get install -y nodejs \
  && if [ -f package.json ]; then npm ci --production || true; fi \
  && apt-get purge -y --auto-remove curl gnupg lsb-release build-essential \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /root/.npm /root/.cache

### Runtime stage: slim Node image and drop to non-root user
FROM node:18-slim

# Create a non-root user (idempotent). Try Debian helpers first, fall back to groupadd/useradd.
RUN set -eux; \
  if ! id -u gitzoom >/dev/null 2>&1; then \
    if command -v addgroup >/dev/null 2>&1 && command -v adduser >/dev/null 2>&1; then \
      addgroup --gid 1000 gitzoom; \
      adduser --uid 1000 --gid 1000 --disabled-password --gecos "" gitzoom; \
    else \
      groupadd -g 1000 gitzoom || true; \
      useradd -m -u 1000 -g gitzoom -s /bin/sh gitzoom || true; \
    fi; \
  fi

WORKDIR /workspace

# Copy only necessary files from builder to keep image small
COPY --from=builder /src /workspace

# Ensure proper ownership for non-root user. If name lookup fails, fall back to numeric uid:gid.
RUN set -eux; \
  chown -R gitzoom:gitzoom /workspace 2>/dev/null || chown -R 1000:1000 /workspace

USER gitzoom

# Default entry runs the measurement harness via pwsh if available in PATH inside the container.
# The image does not include pwsh; the harness scripts can still run with Node/PowerShell Core if installed in runtime.
ENTRYPOINT ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]
CMD ["/workspace/experiments/measurement-harness.ps1", "-Iterations", "10", "-OutDir", "/workspace/artifacts"]

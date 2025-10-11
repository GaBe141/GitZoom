FROM mcr.microsoft.com/powershell:7.4-ubuntu-22.04

# Install node (for the CLI) and common tools
RUN apt-get update \
  && apt-get install -y curl ca-certificates gnupg lsb-release git build-essential \
  && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get install -y nodejs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Copy repository into the image so the harness and tools are available
COPY . /workspace

# Install node deps if any (safe to ignore failures for optional dev deps)
RUN if [ -f package.json ]; then npm install --production || true; fi

# Default entry runs the measurement harness; override to run other commands
ENTRYPOINT ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File"]
CMD ["/workspace/experiments/measurement-harness.ps1", "-Iterations", "10", "-OutDir", "/workspace/artifacts"]

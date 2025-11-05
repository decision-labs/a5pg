# Docker Setup for a5pg

This directory contains Docker configurations for building and testing the a5pg extension on Linux.

## Files

- `Dockerfile` - Multi-version Postgres build environment (pg15, pg16, pg17)
- `docker-compose.yml` - Service definitions for testing each Postgres version

## Quick Start

### Build the Docker image:
```bash
make docker-build
```

### Run tests for all Postgres versions:
```bash
make docker-test
```

### Open a shell in the build environment:
```bash
make docker-shell
```

## Manual Usage

### Build the image:
```bash
docker build -t a5pg:latest -f docker/Dockerfile .
```

### Run tests:
```bash
# Single version
docker-compose -f docker/docker-compose.yml run --rm test-pg17
docker-compose -f docker/docker-compose.yml run --rm test-pg16
docker-compose -f docker/docker-compose.yml run --rm test-pg15

# Or use Makefile target to run all (pg15, pg16, pg17)
make docker-test
```

### Interactive development:
```bash
# Open a shell in the container
make docker-shell

# Or manually:
docker-compose -f docker/docker-compose.yml run --rm test-pg17 /bin/bash
```

## Environment

The Docker image includes:
- Rust 1.89
- PostgreSQL 15, 16, 17 with dev packages
- cargo-pgrx pre-installed and initialized
- sccache for faster compilation (shared compilation cache)
- All build dependencies

## Performance

**Compilation Speed:**
- First build: ~2-3 minutes (compiling all dependencies)
- Subsequent builds: ~10-30 seconds (with sccache cache hits)
- sccache cache is persisted in a Docker volume across runs

**Image Size:**
- `Dockerfile` (all 3 PG versions): ~3.4GB
- `Dockerfile.slim` (single PG version): ~3.5GB
- Size breakdown: Rust toolchain (1.5GB) + PostgreSQL (500MB) + cargo tools (1GB+)

## Smaller runtime image (production)

If you want a small image only to run PostgreSQL with the a5pg extension pre-installed (no Rust toolchain or build tools), use the multi-stage runtime Dockerfile:

```bash
# Build a Postgres 17 runtime image with the compiled extension
docker build -t a5pg:pg17-runtime -f docker/Dockerfile.runtime --build-arg PG_VERSION=17 .

# Run it
docker run --rm -e POSTGRES_PASSWORD=postgres -p 5432:5432 a5pg:pg17-runtime
```

This produces a much smaller image (hundreds of MB) because it contains only:
- Postgres server
- Compiled `a5pg.so`
- Extension control and SQL files

Note: The development images (Dockerfile, Dockerfile.slim) are intentionally large to enable fast local builds/tests.

## Notes

- The image is built with all three Postgres versions pre-initialized for fast testing
- Tests run as non-root user `pgrxuser` (required by PostgreSQL's `initdb`)
- Volume mounts allow live editing on the host with testing in the container
- Extension directories have write permissions for non-root testing
- Cargo registry is writable by `pgrxuser` for dependency management
- **Compilation speedup**: sccache is included for faster incremental builds (persisted in `sccache` volume)
- **Image size**: ~3.4GB (includes Rust toolchain, 3 PostgreSQL versions, cargo-pgrx, sccache)
  - For a smaller image with just pg17: use `Dockerfile.slim` (~3.5GB with single PG version)
  - Image size is large due to: Rust toolchain (1.5GB), PostgreSQL dev packages (500MB), cargo binaries (1GB+)
- `.dockerignore` excludes `target/` directory to speed up builds
- Persistent `sccache` volume keeps compilation cache between runs
- Each `test-pgXX` compose service clears `target/test-pgdata` before running to avoid stale clusters/roles

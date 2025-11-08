# Packaging and Distribution Guide for a5pg

## Overview

For pgrx extensions, there are several ways to package and distribute:

1. **Source distribution** (recommended for now) - Users build from source
2. **pgxman** - Package manager for PostgreSQL extensions
3. **Manual packaging** - Create .deb/.rpm packages
4. **Docker images** - Pre-built runtime images

## Option 1: Source Distribution (Current Approach)

Users install from source using `cargo pgrx`:

```bash
# User installation steps:
git clone https://github.com/decision-labs/a5pg.git
cd a5pg
cargo pgrx install pg17  # or pg15, pg16
```

**Pros:**
- Simple, no packaging needed
- Works on all platforms
- Users get latest code

**Cons:**
- Requires Rust toolchain
- Slower installation

## Option 2: pgxman (Recommended for Binary Distribution)

[pgxman](https://pgxman.com/) is a package manager for PostgreSQL extensions.

### Current Setup

a5pg uses pgxman's buildkit format with `extension.yaml` in the project root. This file defines:
- Extension metadata (name, version, description, license)
- Source code location
- Build steps (Rust setup, pgrx initialization, compilation, file installation)
- Supported architectures and PostgreSQL versions

**Current configuration:**
- File: `extension.yaml`
- Supported architectures: `arm64` (can add `amd64`)
- Supported PostgreSQL versions: `15` (can add `16`, `17`)
- Build system: Uses `cargo pgrx package` to create extension packages

### Building Packages

```bash
# Install pgxman CLI
cargo install pgxman

# Build packages for all configured PostgreSQL versions and architectures
pgxman build

# Build with limited parallelism (faster for local testing)
pgxman build --parallel 1

# This creates packages in `out/` directory:
# - out/debian/bookworm/postgresql-15-pgxman-a5pg_0.2.0_arm64.deb
# - out/ubuntu/jammy/postgresql-15-pgxman-a5pg_0.2.0_arm64.deb
# - out/ubuntu/noble/postgresql-15-pgxman-a5pg_0.2.0_arm64.deb
# - etc.
```

### Testing Packages

```bash
# Test in Docker (Debian Bookworm example)
docker run -it --rm debian:bookworm bash
apt-get update && apt-get install -y ./out/debian/bookworm/postgresql-15-pgxman-a5pg_0.2.0_arm64.deb

# Or test locally if you have PostgreSQL installed
pgxman install --local ./out/debian/bookworm/postgresql-15-pgxman-a5pg_0.2.0_arm64.deb
```

### Publishing to Registry

```bash
# Publish all built packages to pgxman registry
pgxman publish

# Requires authentication (API token)
```

### User Installation

Once published, users can install via:

```bash
# Install latest version
pgxman install a5pg

# Install specific version
pgxman install a5pg@0.2.0

# Install for specific PostgreSQL version
pgxman install a5pg --pg-version 16
```

See [PGXMAN_GUIDE.md](PGXMAN_GUIDE.md) for detailed information about the pgxman workflow.

## Option 3: Manual Package Creation

### For Debian/Ubuntu (.deb)

1. **Create package structure**:
```bash
mkdir -p a5pg-0.2.0/usr/lib/postgresql/17/lib
mkdir -p a5pg-0.2.0/usr/share/postgresql/17/extension
```

2. **Build extension package**:
```bash
# Use cargo pgrx package to create the extension package structure
cargo pgrx package --pg-config /usr/lib/postgresql/17/bin/pg_config

# This creates: target/release/a5pg-pg17/
#   - usr/lib/postgresql/17/lib/a5pg.so
#   - usr/share/postgresql/17/extension/a5pg--0.2.0.sql
#   - usr/share/postgresql/17/extension/a5pg.control
```

3. **Copy files from package directory**:
```bash
# Copy compiled library
cp target/release/a5pg-pg17/usr/lib/postgresql/17/lib/a5pg.so \
   a5pg-0.2.0/usr/lib/postgresql/17/lib/a5pg.so

# Copy SQL and control files
cp target/release/a5pg-pg17/usr/share/postgresql/17/extension/a5pg--*.sql \
   a5pg-0.2.0/usr/share/postgresql/17/extension/
cp target/release/a5pg-pg17/usr/share/postgresql/17/extension/a5pg.control \
   a5pg-0.2.0/usr/share/postgresql/17/extension/
```

4. **Create DEBIAN/control**:
```bash
mkdir -p a5pg-0.2.0/DEBIAN
cat > a5pg-0.2.0/DEBIAN/control <<EOF
Package: postgresql-17-a5pg
Version: 0.2.0
Section: database
Priority: optional
Architecture: amd64
Depends: postgresql-17
Maintainer: Your Name <your@email.com>
Description: Equal-area A5 spatial index for PostgreSQL
 A5 is a Discrete Global Grid System based on irregular pentagons.
 This extension provides SQL functions for A5 spatial indexing.
Homepage: https://github.com/decision-labs/a5pg
EOF
```

5. **Build package**:
```bash
dpkg-deb --build a5pg-0.2.0
```

### For RHEL/CentOS (.rpm)

Use `rpmbuild` or `fpm` (easier):
```bash
# Install fpm
gem install fpm

# Build RPM
fpm -s dir -t rpm \
  -n postgresql-17-a5pg \
  -v 0.2.0 \
  --depends postgresql17-server \
  -C a5pg-0.2.0 \
  usr/
```

## Option 4: Docker Runtime Images

You already have `Dockerfile.runtime` - this creates a minimal runtime image:

```bash
# Build runtime image
docker build -t a5pg:0.2.0-pg17 -f docker/Dockerfile.runtime --build-arg PG_VERSION=17 .

# Users can use it:
docker run -d -e POSTGRES_PASSWORD=postgres a5pg:0.2.0-pg17
```

## Recommended Approach

For v0.2.0 release:

1. **Short term**: Source distribution (current approach)
   - Document installation in README
   - Works immediately, no packaging overhead

2. **Medium term**: Add pgxman support
   - Create `pgxman.yaml`
   - Build and test packages
   - Publish to pgxman registry (if desired)

3. **Long term**: Consider official PostgreSQL packaging
   - Debian/Ubuntu packages
   - RPM packages
   - Homebrew formula (for macOS)

## Quick Start: pgxman Setup

1. **Install pgxman**:
```bash
cargo install pgxman
```

2. **Configure `extension.yaml`** (already exists in project root)

3. **Build**:
```bash
pgxman build
# Or with limited parallelism: pgxman build --parallel 1
```

4. **Test locally**:
```bash
# Install in test PostgreSQL
pgxman install --local ./out/debian/bookworm/postgresql-15-pgxman-a5pg_0.2.0_arm64.deb
```

## Files Needed for Packaging

For any packaging method, you need:

1. **Compiled library**: Created by `cargo pgrx package` at:
   - `target/release/a5pg-pg{VERSION}/usr/lib/postgresql/{VERSION}/lib/a5pg.so`
2. **SQL file**: `sql/a5pg--0.2.0.sql` (auto-generated by pgrx)
3. **Control file**: `a5pg.control` (with version template)
4. **Documentation**: README.md, CHANGELOG.md
5. **Buildkit config**: `extension.yaml` (for pgxman)

## Current Status

- ✅ Source distribution ready (users can `cargo pgrx install`)
- ✅ pgxman support: Configured with `extension.yaml`
- ✅ Binary packages: Can be built with `pgxman build` (packages created in `out/`)
- ✅ Docker images: Available (Dockerfile.runtime)

## Next Steps

1. **For immediate release**: Source distribution is ready
2. **For binary packages**: Run `pgxman build` to create packages, then `pgxman publish` to distribute
3. **For Docker**: Already available via Dockerfile.runtime
4. **To add more PostgreSQL versions**: Edit `pgVersions` in `extension.yaml`
5. **To add more architectures**: Edit `arch` in `extension.yaml`


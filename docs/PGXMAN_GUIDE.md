# How pgxman Packages are Published and Installed

## Overview

pgxman is a package manager for PostgreSQL extensions that automates building, publishing, and installing extensions across different distributions and PostgreSQL versions.

## 1. Building Packages

### Developer Workflow

**Step 1: Create Buildkit Configuration**

Create an `extension.yaml` file (also called a "buildkit") that defines:
- Extension metadata (name, version, description)
- Source code location
- Build instructions
- Supported architectures and PostgreSQL versions

Example `extension.yaml`:
```yaml
apiVersion: v1
name: a5pg
version: "0.2.0"
source: https://github.com/decision-labs/a5pg/archive/refs/tags/v0.2.0.tar.gz
arch:
  - amd64
  - arm64
pgVersions:
  - "15"
  - "16"
build:
  main:
    - name: Build extension
      run: cargo pgrx package --pg-config /usr/lib/postgresql/${PG_VERSION}/bin/pg_config
```

**Step 2: Build Packages Locally**

```bash
# Install pgxman CLI
cargo install pgxman

# Build packages
pgxman build

# This creates packages in out/ directory:
# - out/a5pg_0.2.0-1_amd64.deb (Debian/Ubuntu)
# - out/a5pg-0.2.0-1.x86_64.rpm (RHEL/CentOS)
# - Packages for each architecture × PostgreSQL version combination
```

**What Happens During Build:**

1. **Docker-based builds**: Uses Docker containers for isolated, reproducible builds
2. **Multi-platform**: Builds for each specified architecture (amd64, arm64)
3. **Multi-version**: Builds for each PostgreSQL version (15, 16, 17)
4. **Package creation**: Creates native packages:
   - `.deb` files for Debian/Ubuntu systems
   - `.rpm` files for RHEL/CentOS systems
5. **Package contents**:
   - Compiled `.so` library file
   - SQL migration files (`extension--version.sql`)
   - Control file (`extension.control`)
   - Metadata (dependencies, maintainer, description)

## 2. Publishing to Registry

### Option A: Manual Publishing

After building packages locally:

```bash
pgxman publish
```

This uploads all built packages to the pgxman registry at `https://registry.pgxman.com/v1`.

**Requirements:**
- You need to be authenticated (usually via API token)
- Packages must be successfully built
- Extension metadata must be valid

### Option B: Automated Publishing (Recommended)

**GitHub Actions Integration:**

1. **Buildkit Repository**: Buildkits (`extension.yaml` files) are stored in a GitHub repository
2. **Automatic Triggers**: When a buildkit is added or updated:
   - GitHub Actions automatically triggers
   - Builds extension for all architectures/PostgreSQL versions
   - Runs tests (if configured)
   - Publishes to pgxman registry on success

**Benefits:**
- No manual publishing needed
- Consistent builds
- Automatic versioning
- CI/CD integration

## 3. Installing Packages

### User Workflow

**Step 1: Install pgxman CLI**

```bash
cargo install pgxman
```

**Step 2: Install Extension**

```bash
# Install latest version
pgxman install a5pg

# Install specific version
pgxman install a5pg@0.2.0

# Install for specific PostgreSQL version
pgxman install a5pg --pg-version 16
```

**What Happens During Installation:**

1. **System Detection**: pgxman detects your system:
   - Distribution (Debian/Ubuntu/RHEL/CentOS)
   - Architecture (amd64/arm64)
   - PostgreSQL version (if installed)

2. **Repository Setup**: Adds pgxman repository to your system package manager:
   - Debian/Ubuntu: Adds to `/etc/apt/sources.list.d/`
   - RHEL/CentOS: Adds to `/etc/yum.repos.d/`

3. **Package Download**: Downloads the appropriate package from registry:
   - Matches your system architecture
   - Matches your PostgreSQL version
   - Handles dependencies automatically

4. **Installation**: Uses system package manager to install:
   ```bash
   # On Debian/Ubuntu
   apt-get install postgresql-16-pgxman-a5pg
   
   # On RHEL/CentOS
   yum install postgresql16-pgxman-a5pg
   ```

5. **File Placement**: Extension files are installed to:
   - Library: `/usr/lib/postgresql/{version}/lib/a5pg.so`
   - SQL files: `/usr/share/postgresql/{version}/extension/a5pg--*.sql`
   - Control file: `/usr/share/postgresql/{version}/extension/a5pg.control`

**Step 3: Enable in PostgreSQL**

```sql
CREATE EXTENSION a5pg;
```

## 4. Architecture Flow

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Developer  │         │   Registry   │         │     User     │
└──────┬──────┘         └──────┬───────┘         └──────┬───────┘
       │                       │                         │
       │ 1. extension.yaml     │                         │
       │──────────────────────>│                         │
       │                       │                         │
       │ 2. pgxman build       │                         │
       │    (creates .deb/.rpm) │                         │
       │                       │                         │
       │ 3. pgxman publish     │                         │
       │──────────────────────>│                         │
       │                       │                         │
       │                       │ 4. pgxman install      │
       │                       │<────────────────────────│
       │                       │    (queries registry)   │
       │                       │                         │
       │                       │ 5. Package download    │
       │                       │─────────────────────────>│
       │                       │    (via apt/yum)       │
       │                       │                         │
       │                       │ 6. Install package      │
       │                       │─────────────────────────>│
       │                       │                         │
```

## 5. Key Benefits

### For Developers

- ✅ **No Manual Packaging**: Buildkit defines everything
- ✅ **Multi-Platform**: Automatic builds for all architectures
- ✅ **Version Management**: Easy versioning and updates
- ✅ **CI/CD Ready**: Integrates with GitHub Actions
- ✅ **Standardized**: Consistent packaging format

### For Users

- ✅ **Simple Installation**: One command: `pgxman install a5pg`
- ✅ **No Build Tools**: No Rust toolchain needed
- ✅ **System Integration**: Uses native package managers
- ✅ **Dependency Resolution**: Automatic dependency handling
- ✅ **Version Control**: Easy to install specific versions
- ✅ **Updates**: Simple upgrade path

## 6. Package Structure

### Built Package Contents

```
a5pg_0.2.0-1_amd64.deb
├── DEBIAN/
│   └── control          # Package metadata
└── usr/
    ├── lib/
    │   └── postgresql/
    │       └── 16/
    │           └── lib/
    │               └── a5pg.so          # Compiled library
    └── share/
        └── postgresql/
            └── 16/
                └── extension/
                    ├── a5pg--0.2.0.sql # SQL migration
                    └── a5pg.control     # Extension control file
```

## 7. Versioning and Updates

### Version Format

- Extension version: `0.2.0` (semantic versioning)
- Package version: `0.2.0-1` (version-revision format)
- PostgreSQL version: `16` (major version)

### Updating Extensions

**For Users:**
```bash
# Update to latest version
pgxman install a5pg --upgrade

# Or reinstall specific version
pgxman install a5pg@0.2.0
```

**For Developers:**
1. Update version in `extension.yaml`
2. Build new packages: `pgxman build`
3. Publish: `pgxman publish`

## 8. Local Testing

Before publishing, test packages locally:

```bash
# Build packages
pgxman build

# Test installation locally
pgxman install --local ./out/a5pg_0.2.0-1_amd64.deb

# Or test in Docker
docker run -it --rm ubuntu:22.04 bash
apt-get update && apt-get install -y ./out/a5pg_0.2.0-1_amd64.deb
```

## 9. Current Status for a5pg

Based on your `extension.yaml`:

- ✅ **Build Configuration**: Ready (`extension.yaml` configured)
- ✅ **Local Builds**: Working (with recent fixes)
- ⏳ **Registry Publishing**: Not yet done (run `pgxman publish` after successful builds)
- ⏳ **User Installation**: Will work once published to registry

## 10. Next Steps

1. **Complete Build**: Ensure `pgxman build` succeeds for all architectures/versions
2. **Test Locally**: Test packages before publishing
3. **Publish**: Run `pgxman publish` to make available to users
4. **Documentation**: Update README with installation instructions
5. **CI/CD**: Set up automated publishing via GitHub Actions (optional)

## References

- [pgxman Documentation](https://docs.pgxman.com)
- [pgxman Registry](https://registry.pgxman.com)
- [Buildkit Specification](https://docs.pgxman.com/spec/buildkit)


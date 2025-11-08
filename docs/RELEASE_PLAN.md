# Release Plan for a5pg

## Pre-Release Checklist

### 1. Code Quality ✅
- [x] All tests passing (`make test-all`)
- [x] Linter passing (`make lint`)
- [x] Code formatted (`make fmt-check`)
- [x] No clippy warnings
- [x] SQL tests passing (`tests/pg_regress/run_tests.sh`) - verified, edge cases correctly error

### 2. Version Update ✅
- [x] Update version in `Cargo.toml` (e.g., `0.2.0` → `0.3.0`)
- [x] Update version in `extension.yaml` (for pgxman)
- [x] Update source URL in `extension.yaml` to point to new tag
- [x] Note: `a5pg.control` uses `@CARGO_VERSION@` template (auto-updated by pgrx)
- [x] Regenerate SQL schema: `make schema` (updates `sql/a5pg--<version>.sql`)
- [x] Update `README.md` if version mentioned
- [x] Update `Makefile` schema target if hardcoded version

### 3. Documentation ✅
- [x] Create `CHANGELOG.md` with:
  - Breaking changes (removed hex strings, renamed functions)
  - New features
  - Bug fixes (cell ID 0 deadlock fix)
  - Migration guide
- [x] Review `README.md` for accuracy
- [x] Update any version-specific examples

### 4. SQL Schema Generation ✅
- [x] **Regenerate SQL schema** (current `sql/a5pg--0.2.0.sql` has correct function names):
  ```bash
  make schema  # Uses PG_VERSION=17 by default
  # OR manually:
  cargo pgrx schema pg17 2>/dev/null > sql/a5pg--0.2.0.sql
  ```
- [x] Verify SQL schema has correct function names (no `_id` suffixes)
- [x] SQL schema is clean (no ANSI color codes)

### 5. Build Artifacts
- [ ] Build release binaries (optional, for distribution):
  ```bash
  cargo build --release --no-default-features --features pg15
  cargo build --release --no-default-features --features pg16
  cargo build --release --no-default-features --features pg17
  ```
- [ ] Verify `.so`/`.dylib` files are generated correctly

### 6. Testing
- [ ] Run full test suite:
  ```bash
  make test-all  # Tests pg15, pg16, pg17
  ```
- [ ] Test installation on clean PostgreSQL instances
- [ ] Test upgrade path from previous version (if applicable)
- [ ] Verify all SQL functions work correctly

## Release Steps

### Step 1: Create Release Branch
```bash
git checkout -b release/v<version>
```

### Step 2: Update Versions
1. Edit `Cargo.toml`: `version = "<version>"`
2. Note: `a5pg.control` will auto-update via `@CARGO_VERSION@` template

### Step 3: Update extension.yaml for pgxman
1. Update `version` field in `extension.yaml`
2. Update `source` URL to point to new tag (e.g., `v0.3.0`)
3. Ensure all build steps are correct

### Step 4: Regenerate SQL Schema ⚠️ CRITICAL
```bash
# Current SQL file has old function names - MUST regenerate!
make schema
# This generates: sql/a5pg--<version>.sql
```

### Step 5: Create CHANGELOG.md
```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2024-XX-XX

### Breaking Changes
- **Removed hex string support**: All functions now use `bigint` cell IDs
- **Renamed functions**: Dropped `_id` suffix from all function names
  - `a5_lonlat_to_cell_id` → `a5_lonlat_to_cell`
  - `a5_cell_to_lonlat_id` → `a5_cell_to_lonlat`
  - `a5_cell_to_boundary_id` → `a5_cell_to_boundary`
  - `a5_point_to_cell_id` → `a5_point_to_cell`

### Fixed
- Fixed deadlock issue when handling cell ID 0 (WORLD_CELL)
- Functions now return immediately for cell ID 0 without calling library

### Changed
- Function names now match DuckDB a5 extension API
- All functions use native PostgreSQL types (bigint, arrays) instead of strings

### Migration Guide
If upgrading from 0.1.0:
1. Update all function calls to remove `_id` suffix
2. Replace hex string cell IDs with bigint values
3. Use `a5_lonlat_to_cell()` to convert coordinates to cell IDs

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- Core A5 spatial indexing functions
```

### Step 6: Final Testing
```bash
# Run all tests
make test-all

# Verify linting
make lint

# Check formatting
make fmt-check

# Test SQL schema installation
psql -d testdb -f sql/a5pg--<version>.sql
```

### Step 7: Commit and Tag
```bash
git add .
git commit -m "chore: release v<version>"
git tag -a v<version> -m "Release v<version>"
```

### Step 8: Push to GitHub
```bash
git push origin release/v<version>
git push origin v<version>
```

### Step 9: Create GitHub Release
1. Go to GitHub repository → Releases → Draft a new release
2. Tag: `v<version>`
3. Title: `Release v<version>`
4. Description: Copy from CHANGELOG.md
5. Mark as "Latest release" if this is the newest version

### Step 9b: Update pgxman Buildkit (if applicable)
- [ ] Ensure `extension.yaml` is up to date with correct version and source URL
- [ ] Submit/update PR to pgxman buildkit repository:
  - PR: https://github.com/pgxman/buildkit/pull/112/
  - This makes the extension available via `pgxman install a5pg`
- [ ] Wait for PR approval and merge

### Step 9c: Add Documentation to Official a5 Repo (pending)
- [ ] Add PostgreSQL extension documentation to Felix Palmer's a5 repository:
  - Repository: https://github.com/felixpalmer/a5
  - Document a5pg as a PostgreSQL implementation of the A5 DGGS
  - Include installation instructions and usage examples
  - Link to this repository for full documentation

### Step 10: Merge to Main
```bash
git checkout main
git merge release/v<version>
git push origin main
```

### Step 11: Publish to crates.io (if applicable)
```bash
# Verify package
cargo package --dry-run

# Publish
cargo publish
```

## Quick Release Script

Save as `scripts/release.sh`:

```bash
#!/bin/bash
set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

echo "🚀 Preparing release v$VERSION"

# Update Cargo.toml
echo "📝 Updating Cargo.toml..."
sed -i '' "s/^version = \".*\"/version = \"$VERSION\"/" Cargo.toml

# Regenerate SQL schema
echo "📄 Generating SQL schema..."
make schema

# Run tests
echo "🧪 Running tests..."
make test-all

# Check linting
echo "🔍 Checking linting..."
make lint

# Commit
echo "💾 Committing changes..."
git add .
git commit -m "chore: release v$VERSION" || echo "No changes to commit"

# Tag
echo "🏷️  Creating tag..."
git tag -a v$VERSION -m "Release v$VERSION"

echo ""
echo "✅ Release v$VERSION prepared!"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff HEAD~1"
echo "  2. Push branch: git push origin release/v$VERSION"
echo "  3. Push tag: git push origin v$VERSION"
echo "  4. Create GitHub release at: https://github.com/<org>/a5pg/releases/new"
```

## Current Status

- ✅ Code refactored (removed hex strings, renamed functions)
- ✅ Tests updated and passing
- ✅ Documentation updated (README.md, CHANGELOG.md)
- ✅ SQL schema regenerated (`sql/a5pg--0.2.0.sql` with correct function names, no ANSI codes)
- ✅ Version updated to 0.3.0
- ✅ Makefile updated
- ✅ Extension.yaml updated with version 0.3.0
- ✅ pgxman buildkit PR: https://github.com/pgxman/buildkit/pull/112/
- ⏳ Pending: Add documentation to official a5 repo (https://github.com/felixpalmer/a5)
- ✅ All pre-release checks complete

## Ready for Release! 🚀

All pre-release tasks are complete. Next steps:

1. **Commit changes**:
   ```bash
   git add .
   git commit -m "chore: release v0.3.0"
   ```

2. **Create tag**:
   ```bash
   git tag -a v0.3.0 -m "Release v0.3.0"
   ```

3. **Push to GitHub**:
   ```bash
   git push origin main
   git push origin v0.3.0
   ```

4. **Create GitHub Release**:
   - Go to: https://github.com/decision-labs/a5pg/releases/new
   - Tag: `v0.3.0`
   - Title: `Release v0.3.0`
   - Description: Copy from `CHANGELOG.md`
   - Mark as "Latest release"

5. **Update pgxman Buildkit PR** (if needed):
   - PR: https://github.com/pgxman/buildkit/pull/112/
   - Ensure `extension.yaml` in the PR matches the current version (0.3.0)
   - Update source URL to point to v0.3.0 tag

6. **Add Documentation to Official a5 Repo** (pending):
   - Repository: https://github.com/felixpalmer/a5
   - Add PostgreSQL extension documentation
   - Include installation and usage examples
   - Link to this repository for full documentation

## Notes

- PostgreSQL extension versioning follows the pattern: `a5pg--<version>.sql`
- The `--` separator is required by PostgreSQL
- Version should follow semantic versioning (MAJOR.MINOR.PATCH)
- Breaking changes should increment MAJOR version (0.1.0 → 0.2.0 for this release)
- `a5pg.control` uses `@CARGO_VERSION@` template - pgrx handles this automatically
- Test on all supported PostgreSQL versions (15, 16, 17) before release


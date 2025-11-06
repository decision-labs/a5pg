![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/decision-labs/a5pg/.github%2Fworkflows%2Fci.yml)


# a5pg

<p align="center">
  <img src="./a5pg-elephant.gif" width="600" />
</p>


Equal-area A5 spatial index functions for PostgreSQL, implemented with pgrx.

A5 is a new Discrete Global Grid System (DGGS) proposed by Felix Palmer https://github.com/felixpalmer. It is based on irregular pentagons, and offers a low areal distortion, making the grid more useful than H3 when the goal is to map densities across different cities and continents. For more see a5geo.org

![A5 Visuals](docs/a5-visuals.png)

This extension wraps the A5 equal-area spatial index Rust crate and exposes a small set of convenient SQL functions. The API is designed to be compatible with the DuckDB a5 extension for cross-database query portability.

## Why A5?

Equal-area indexing ensures each cell covers the same surface area on the globe, so counts, densities, and aggregations are comparable across latitudes without distortion—ideal for analytics, dashboards, and geostatistics.

## Source libraries

- A5 project/site: https://a5geo.org/
- Rust crate docs: https://docs.rs/a5/latest/a5/

## Quick start

### Prerequisites
- Rust, cargo, and cargo-pgrx installed
- PostgreSQL 15, 16, or 17 with dev packages

### Using Make (recommended)
```bash
# Show all available targets
make help

# Run tests (default: pg17)
make test

# Run tests for all versions
make test-all

# Build and run tests in Docker (Linux)
make docker-test

# Generate SQL schema
make schema
```

### Manual commands
- Run tests against specific Postgres versions:
  - `cargo pgrx test pg15`
  - `cargo pgrx test pg16`
  - `cargo pgrx test pg17`

- Generate extension SQL (example for 0.2.0 and pg17):
  - `cargo pgrx schema pg17 > sql/a5pg--0.2.0.sql`

- Install and try in psql (example for pg17):
  - `cargo pgrx install pg17`
  - In psql: `CREATE EXTENSION a5pg;`

### Docker (Linux testing)
```bash
# Build Docker image with all Postgres versions
make docker-build

# Run tests for pg15, pg16, pg17
make docker-test

# Open interactive shell
make docker-shell
```

See [docker/README.md](docker/README.md) for more Docker options.

## Testing matrix (macOS)

Run the test suite against multiple Postgres versions on macOS.

- Using Homebrew-installed Postgres (Apple Silicon prefix shown):

```bash
# Install Postgres versions (if needed)
brew install postgresql@15 postgresql@16 postgresql@17

# Initialize cargo-pgrx with Homebrew pg_config paths
cargo pgrx init \
  --pg15 /opt/homebrew/opt/postgresql@15/bin/pg_config \
  --pg16 /opt/homebrew/opt/postgresql@16/bin/pg_config \
  --pg17 /opt/homebrew/opt/postgresql@17/bin/pg_config

# Run the full matrix
for v in pg15 pg16 pg17; do cargo pgrx test "$v" || exit 1; done
```

- Or let pgrx download test servers (if you don’t have local installs):

```bash
cargo pgrx init --pg15 download --pg16 download \
  --pg17 /opt/homebrew/opt/postgresql@17/bin/pg_config

for v in pg15 pg16 pg17; do cargo pgrx test "$v" || exit 1; done
```

Notes:
- On Intel macOS, the Homebrew prefix is usually `/usr/local` instead of `/opt/homebrew`.
- `cargo pgrx test <pgver>` spins up a temporary Postgres, runs `#[pg_test]` tests in-process, then tears it down.

## Functions

### Core Functions (DuckDB-compatible API)

**Cell ID Conversion:**
- `a5_lonlat_to_cell(lon double precision, lat double precision, res int) -> bigint` - Convert lon/lat to bigint cell ID

**Reverse Conversion (returns native arrays):**
- `a5_cell_to_lonlat(cell_id bigint) -> double precision[]` - Convert bigint cell ID to [lon, lat] array

**Cell Hierarchy:**
- `a5_get_resolution(cell_id bigint) -> int` - Get resolution of a cell
- `a5_cell_to_parent(cell_id bigint, target_resolution int) -> bigint` - Get parent cell at target resolution
- `a5_cell_to_children(cell_id bigint, target_resolution int) -> bigint[]` - Get children cells at target resolution

**Boundaries (returns native arrays):**
- `a5_cell_to_boundary(cell_id bigint) -> double precision[][]` - Get boundary as array of [lon, lat] coordinate pairs

**Version Info:**
- `a5pg_version() -> text` - Extension version
- `a5pg_info() -> jsonb` - Extension and library version info

### Extras

- Numeric overload:
  - `a5_lonlat_to_cell(lon numeric, lat numeric, res int) -> bigint`
- PostGIS wrapper (created only if `geometry` type exists):
  - `a5_point_to_cell(geom geometry, res int) -> bigint`

## Examples

**Get a cell ID:**
```sql
SELECT a5_lonlat_to_cell(-73.9857, 40.7580, 10);
-- Returns: 2742822465196523520
```

**Get center point as array [lon, lat]:**
```sql
SELECT a5_cell_to_lonlat(2742822465196523520);
-- Returns: {-73.96422570580987, 40.750993086983314}
```

**Get boundary as array of coordinate pairs:**
```sql
SELECT a5_cell_to_boundary(2742822465196523520);
-- Returns: {{-74.01466735453606, 40.72977833231509}, {-73.95656875648214, 40.72969872633765}, ...}
```

**Get parent and children:**
```sql
SELECT a5_get_resolution(2742822465196523520);  -- Returns: 10
SELECT a5_cell_to_parent(2742822465196523520, 8);  -- Get parent at resolution 8
SELECT a5_cell_to_children(2742822465196523520, 12);  -- Get children at resolution 12
```

**Convert boundary array to GeoJSON (using PostgreSQL functions):**
```sql
SELECT jsonb_build_object(
    'type', 'Polygon',
    'coordinates', jsonb_build_array(
        (SELECT jsonb_agg(jsonb_build_array(point[1], point[2]))
         FROM unnest(a5_cell_to_boundary(2742822465196523520)) AS point)
    )
);
```

## Development notes

- Feature flags in `Cargo.toml` are set up for pg13-pg18 and `pg_test`.
- Tests use `#[pg_test]` and a per-test schema via `#[pg_schema]`.
- Versioned SQL is written to `sql/a5pg--<version>.sql` using `cargo pgrx schema <pgver>`.

## Credits

Made with ❤️ by the [geobase.app](https://geobase.app) team.

## CI

GitHub Actions CI is configured to test on:
- OS: `ubuntu-latest`, `macos-latest`
- Postgres: `pg15`, `pg16`, `pg17`

The workflow runs on every push/PR to `main` and includes:
- Rust stable toolchain
- cargo-pgrx installation and initialization (download test servers)
- Full test suite via `cargo pgrx test <pgver>`
- Linting (rustfmt, clippy)
- Cargo caching to speed up builds

See [`.github/workflows/ci.yml`](.github/workflows/ci.yml) for details.
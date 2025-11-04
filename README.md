# a5pg

Equal-area A5 spatial index functions for PostgreSQL, implemented with pgrx.

## Quick start

- Prereqs: Rust, cargo, and cargo-pgrx installed and initialized for your local Postgres versions.
  - If needed: `cargo pgrx init`

- Run tests against specific Postgres versions:
  - `cargo pgrx test pg15`
  - `cargo pgrx test pg16`
  - `cargo pgrx test pg17`

- Generate extension SQL (example for 0.1.0 and pg17):
  - `cargo pgrx schema pg17 > sql/a5pg--0.1.0.sql`

- Install and try in psql (example for pg17):
  - `cargo pgrx install pg17`
  - In psql: `CREATE EXTENSION a5pg;`

## Functions

- hello_a5pg() -> text
- a5_lonlat_to_cell(lon double precision, lat double precision, res int) -> text (hex id)
- a5_cell_to_lonlat_json(cell_hex text) -> jsonb
- a5_cell_boundary_geojson(cell_hex text) -> text (GeoJSON Polygon)
- a5_lonlat_to_cell_id(lon double precision, lat double precision, res int) -> bigint
- a5_cell_id_to_lonlat_json(cell_id bigint) -> jsonb
- a5_cell_resolution(cell_id bigint) -> int
- a5_cell_parent_id(cell_id bigint, target_resolution int) -> bigint
- a5_cell_children_ids(cell_id bigint, target_resolution int) -> bigint[]
- a5_cell_id_boundary_geojson(cell_id bigint) -> text (GeoJSON Polygon)

### Extras

- Numeric overload:
  - a5_lonlat_to_cell_id(numeric, numeric, int) -> bigint
- PostGIS wrapper (created only if `geometry` type exists):
  - a5_point_to_cell_id(geom geometry, res int) -> bigint

## Examples

- Get a cell id:
  - `SELECT a5_lonlat_to_cell_id(-73.9857, 40.7580, 10);`
- Get center point as JSON:
  - `SELECT a5_cell_id_to_lonlat_json(123456789012345);`
- Get boundary as GeoJSON:
  - `SELECT a5_cell_id_boundary_geojson(123456789012345);`

## Development notes

- Feature flags in `Cargo.toml` are set up for pg13–pg18 and `pg_test`.
- Tests use `#[pg_test]` and a per-test schema via `#[pg_schema]`.
- Versioned SQL is written to `sql/a5pg--<version>.sql` using `cargo pgrx schema <pgver>`.
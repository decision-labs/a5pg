# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2024-12-XX

### Added
- **Utility functions** for DuckDB API compatibility:
  - `a5_cell_area(resolution)` - Returns cell area in square meters for a resolution level
  - `a5_get_num_cells(resolution)` - Returns total number of cells at a resolution
  - `a5_get_res0_cells()` - Returns all 12 base cells at resolution 0
  - `a5_compact(cell_ids)` - Compacts cells by replacing complete sibling groups with parents
  - `a5_uncompact(cell_ids, target_resolution)` - Expands cells to target resolution
- **PostGIS geometry conversion functions**:
  - `a5_cell_to_point(cell_id)` - Convert cell ID to PostGIS point geometry
  - `a5_cell_to_geom(cell_id)` - Convert cell ID to PostGIS polygon geometry
- **Optional parameters for `a5_cell_to_boundary`**:
  - `a5_cell_to_boundary(cell_id, closed_ring)` - Control whether ring is closed
  - `a5_cell_to_boundary(cell_id, closed_ring, segments)` - Control ring closure and segment count

### Changed
- `a5_cell_to_boundary()` now returns `double precision[][]` (2D array) to match DuckDB API, enabling `coords[1][1]` syntax
- Improved PostGIS integration with schema-aware function creation

### Fixed
- Code formatting standardized with `cargo fmt`

## [0.2.0] - 2024-11-07

### Breaking Changes
- **Removed hex string support**: All functions now use `bigint` cell IDs exclusively
  - `a5_lonlat_to_cell()` now returns `bigint` instead of hex string
  - `a5_cell_to_lonlat()` now takes `bigint` instead of hex string
  - `a5_cell_to_boundary()` now takes `bigint` instead of hex string
- **Renamed functions**: Dropped `_id` suffix from all function names to match DuckDB API
  - `a5_lonlat_to_cell_id` → `a5_lonlat_to_cell`
  - `a5_cell_to_lonlat_id` → `a5_cell_to_lonlat`
  - `a5_cell_to_boundary_id` → `a5_cell_to_boundary`
  - `a5_point_to_cell_id` → `a5_point_to_cell`

### Fixed
- Fixed deadlock issue when handling cell ID 0 (WORLD_CELL)
- Functions now return immediately for cell ID 0 without calling underlying library, preventing potential deadlocks in `DodecahedronProjection::get_global()` initialization

### Changed
- Function names now match DuckDB a5 extension API for cross-database query portability
- All functions use native PostgreSQL types (`bigint`, arrays) instead of strings for better performance and type safety
- Improved error handling for cell IDs that exceed `BIGINT` range (i64::MAX)

### Migration Guide

If upgrading from 0.1.0:

1. **Update function names**: Remove `_id` suffix from all function calls
   ```sql
   -- Old (0.1.0)
   SELECT a5_lonlat_to_cell_id(-73.9857, 40.7580, 10);
   SELECT a5_cell_to_lonlat_id(cell_id);
   
   -- New (0.2.0)
   SELECT a5_lonlat_to_cell(-73.9857, 40.7580, 10);
   SELECT a5_cell_to_lonlat(cell_id);
   ```

2. **Replace hex string cell IDs**: If you stored hex strings, convert them to bigint:
   ```sql
   -- Convert hex to bigint (if you have hex strings stored)
   -- Note: You'll need to use a hex-to-bigint conversion function
   -- or regenerate cell IDs using a5_lonlat_to_cell()
   ```

3. **Update function signatures**: All functions now use `bigint` instead of `text`:
   ```sql
   -- Old: a5_cell_to_boundary(cell_hex text)
   -- New: a5_cell_to_boundary(cell_id bigint)
   ```

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- Core A5 spatial indexing functions:
  - `a5_lonlat_to_cell()` - Convert longitude/latitude to cell ID
  - `a5_cell_to_lonlat()` - Convert cell ID to longitude/latitude
  - `a5_cell_to_boundary()` - Get cell boundary coordinates
  - `a5_cell_to_parent()` - Get parent cell at target resolution
  - `a5_cell_to_children()` - Get children cells at target resolution
  - `a5_get_resolution()` - Get cell resolution
- PostGIS wrapper function for geometry types
- Numeric overload for convenience
- Version info functions (`a5pg_version()`, `a5pg_info()`)


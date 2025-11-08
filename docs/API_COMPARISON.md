# API Comparison: a5pg vs DuckDB a5 Extension

## Overview

a5pg is designed to be API-compatible with DuckDB's a5 extension, allowing queries to be ported between PostgreSQL and DuckDB with minimal changes. This document details the similarities and differences based on the [DuckDB a5 extension documentation](https://raw.githubusercontent.com/Query-farm/a5/refs/heads/main/docs/README.md).

## Core Functions (DuckDB-Compatible)

| Function | DuckDB Signature | a5pg Signature | Status |
|----------|-----------------|----------------|--------|
| `a5_lonlat_to_cell` | `(longitude, latitude, resolution) -> UBIGINT` | `(lon, lat, resolution) -> bigint` | ✅ Compatible (docs say lat/lon but examples use lon/lat) |
| `a5_cell_to_lonlat` | `(cell_id) -> DOUBLE[2]` returns `[longitude, latitude]` | `(cell_id) -> double precision[]` returns `[lon, lat]` | ✅ Compatible |
| `a5_cell_to_boundary` | `(cell_id, [closed_ring, [segments]]) -> DOUBLE[2][]` returns `[longitude, latitude]` pairs | `(cell_id) -> double precision[][]` or `(cell_id, closed_ring) -> double precision[][]` or `(cell_id, closed_ring, segments) -> double precision[][]` returns `[lon, lat]` pairs | ✅ Compatible (overloaded functions) |
| `a5_get_resolution` | `(cell_id) -> INTEGER` | `(cell_id) -> int` | ✅ Compatible |
| `a5_cell_to_parent` | `(cell_id, target_resolution) -> UBIGINT` | `(cell_id, target_resolution) -> bigint` | ✅ Compatible |
| `a5_cell_to_children` | `(cell_id, target_resolution) -> UBIGINT[]` | `(cell_id, target_resolution) -> bigint[]` | ✅ Compatible |

## Key Differences from DuckDB

**Note:** The DuckDB documentation has inconsistencies. The API reference says `a5_lonlat_to_cell(latitude, longitude, resolution)`, but all examples show longitude first: `a5_lonlat_to_cell(-74.0060, 40.7128, 15)`. Similarly, `a5_cell_to_boundary` documentation says it returns `[latitude, longitude]` pairs, but the GeoJSON example shows `[longitude, latitude]` pairs. This comparison is based on the **actual behavior** shown in the examples, not the documentation text.

### 1. Parameter Order: `a5_lonlat_to_cell`

**✅ Compatible:** Both DuckDB (based on examples) and a5pg use `(longitude, latitude, resolution)` order:

```sql
-- Both DuckDB and a5pg use the same order
SELECT a5_lonlat_to_cell(-74.0060, 40.7128, 15);  -- longitude, latitude, resolution
```

### 2. Cell ID Type: `bigint` (signed) vs `UBIGINT` (unsigned)

**DuckDB:** Uses `UBIGINT` (unsigned 64-bit integer) for cell IDs  
**a5pg:** Uses `bigint` (signed 64-bit integer) for cell IDs

**Note:** PostgreSQL doesn't have a native unsigned integer type. a5pg uses `bigint` and casts unsigned values from the underlying a5 library. Most cell IDs fit within the signed range, but very large cell IDs may cause errors.

**Limitation:** Cell IDs must fit within `BIGINT` range (`-2^63` to `2^63-1`). Functions error if a cell ID exceeds this range.

### 3. Optional Parameters: `a5_cell_to_boundary`

**✅ Compatible:** Both DuckDB and a5pg support optional parameters via function overloading:

**DuckDB:** `a5_cell_to_boundary(cell_id, [closed_ring, [segments]])`  
**a5pg:** Three overloaded functions:
- `a5_cell_to_boundary(cell_id)` - Uses defaults (closed_ring=true, segments=auto)
- `a5_cell_to_boundary(cell_id, closed_ring)` - With closed_ring option
- `a5_cell_to_boundary(cell_id, closed_ring, segments)` - With both options

- `closed_ring` (BOOLEAN): Whether to close the ring by repeating the first point. Defaults to `true`.
- `segments` (INTEGER): Number of segments per edge for smoother boundaries. If <= 0, uses resolution-appropriate value (default).

**Examples:**
```sql
-- Default behavior (closed ring, auto segments)
SELECT a5_cell_to_boundary(cell_id);

-- Open ring, auto segments
SELECT a5_cell_to_boundary(cell_id, false);

-- Closed ring, 10 segments per edge
SELECT a5_cell_to_boundary(cell_id, true, 10);
```

### 4. Boundary Coordinate Order

**✅ Compatible:** Both DuckDB (based on GeoJSON example) and a5pg return `[longitude, latitude]` pairs:

The DuckDB documentation says `a5_cell_to_boundary()` returns `[latitude, longitude]` pairs, but the GeoJSON example shows:
```sql
x -> ST_Point(x[1], x[2])  -- x[1] is longitude, x[2] is latitude
```
With resulting coordinates `[-3.639321611065313,40.44502900567739]` which is `[longitude, latitude]`.

**Both implementations return `[longitude, latitude]` pairs:**
```sql
-- Both DuckDB and a5pg return [lon, lat] pairs
SELECT boundary[1] AS lon, boundary[2] AS lat 
FROM unnest(a5_cell_to_boundary(cell_id)) AS boundary;
```

### 5. Missing Utility Functions

The following DuckDB functions are **not yet implemented** in a5pg:

- `a5_cell_area(resolution) -> DOUBLE` - Returns cell area in square meters for a resolution level
- `a5_get_num_cells(resolution) -> UBIGINT` - Returns total number of cells at a resolution
- `a5_get_res0_cells() -> UBIGINT[]` - Returns all 12 base cells at resolution 0
- `a5_compact(cell_ids) -> UBIGINT[]` - Compacts cells by replacing complete sibling groups with parents
- `a5_uncompact(cell_ids, target_resolution) -> UBIGINT[]` - Expands cells to target resolution

### 6. NULL Handling

All functions are marked `STRICT` in PostgreSQL, meaning:
- If any input parameter is NULL, the function returns NULL immediately
- No computation is performed with NULL inputs
- This matches PostgreSQL's standard behavior

Functions that can return NULL for valid inputs:
- `a5_cell_to_lonlat()` - Returns NULL for invalid cell IDs
- `a5_cell_to_boundary()` - Returns NULL for invalid cell IDs

## PostgreSQL-Specific Features

### 1. Numeric Overload

a5pg provides a `numeric` overload for `a5_lonlat_to_cell()` to avoid explicit casts:

```sql
-- Works without explicit cast
SELECT a5_lonlat_to_cell(-73.9857::numeric, 40.7580::numeric, 10);

-- Internally calls the double precision version
```

### 2. PostGIS Integration (Optional)

If PostGIS is installed, a5pg automatically creates a PostGIS wrapper function:

```sql
-- Only available if geometry type exists
a5_point_to_cell(geom geometry, res int) 
  RETURNS bigint
```

This function extracts coordinates from PostGIS geometry and calls `a5_lonlat_to_cell()` internally.

### 3. Extension Metadata Functions

a5pg includes additional utility functions not in DuckDB:

```sql
-- Get extension version
a5pg_version() RETURNS text

-- Get version info as JSONB
a5pg_info() RETURNS jsonb
```

## Error Handling

**a5pg behavior:**
- Invalid coordinates → Error (via underlying a5 library)
- Invalid resolution → Error
- Cell ID exceeds BIGINT range → Error with descriptive message
- Invalid cell ID → Returns NULL (for `a5_cell_to_lonlat`, `a5_cell_to_boundary`)

## Migration Notes

### From DuckDB to a5pg

1. **✅ Parameter order:** Both use `(longitude, latitude, resolution)` - no changes needed.

2. **Cell ID type:** DuckDB uses `UBIGINT` (unsigned), a5pg uses `BIGINT` (signed). Most cell IDs work fine, but very large IDs may cause errors.

3. **✅ Boundary coordinates:** Both return `[longitude, latitude]` pairs - no changes needed.

4. **Missing functions:** Functions like `a5_cell_area()`, `a5_get_num_cells()`, `a5_compact()`, etc. are not yet available in a5pg.

5. **✅ Optional parameters:** `a5_cell_to_boundary()` supports optional `closed_ring` and `segments` parameters via function overloading in both DuckDB and a5pg.

## Conclusion

✅ **API Compatibility:** Core function names and parameter orders match DuckDB (based on actual examples), enabling query portability.

⚠️ **Important Differences:**
- Cell ID type differs (`UBIGINT` vs `BIGINT`) - PostgreSQL limitation
- Several utility functions not yet implemented (`a5_cell_area`, `a5_get_num_cells`, `a5_compact`, etc.)

✅ **PostgreSQL Integration:** Additional features (numeric overload, PostGIS wrapper) enhance usability in PostgreSQL environments.

**Note:** The DuckDB documentation has inconsistencies between the API reference text and the examples. This comparison is based on the actual behavior shown in the examples, which shows both implementations use `(longitude, latitude)` parameter order and `[longitude, latitude]` coordinate pairs.


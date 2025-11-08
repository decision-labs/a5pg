# API Comparison: a5pg vs DuckDB a5 Extension

a5pg is API-compatible with DuckDB's a5 extension, enabling query portability between PostgreSQL and DuckDB.

**Reference:** [DuckDB a5 Extension Documentation](https://duckdb.org/community_extensions/extensions/a5)

**Note:** DuckDB's documentation has inconsistencies. The API reference says `a5_lonlat_to_cell(latitude, longitude, resolution)`, but examples show longitude first. This comparison is based on **actual behavior** from examples, not documentation text.

## Core Functions

| Function | DuckDB Signature | a5pg Signature | Status |
|----------|-----------------|----------------|--------|
| `a5_lonlat_to_cell` | `(longitude, latitude, resolution) -> UBIGINT` | `(lon, lat, resolution) -> bigint` | ✅ Compatible |
| `a5_cell_to_lonlat` | `(cell_id) -> DOUBLE[2]` | `(cell_id) -> double precision[]` | ✅ Compatible |
| `a5_cell_to_boundary` | `(cell_id, [closed_ring, [segments]]) -> DOUBLE[2][]` | Overloaded: `(cell_id)`, `(cell_id, closed_ring)`, `(cell_id, closed_ring, segments)` | ✅ Compatible |
| `a5_get_resolution` | `(cell_id) -> INTEGER` | `(cell_id) -> int` | ✅ Compatible |
| `a5_cell_to_parent` | `(cell_id, target_resolution) -> UBIGINT` | `(cell_id, target_resolution) -> bigint` | ✅ Compatible |
| `a5_cell_to_children` | `(cell_id, target_resolution) -> UBIGINT[]` | `(cell_id, target_resolution) -> bigint[]` | ✅ Compatible |
| `a5_cell_area` | `(resolution) -> DOUBLE` | `(resolution) -> double precision` | ✅ Compatible |
| `a5_get_num_cells` | `(resolution) -> UBIGINT` | `(resolution) -> bigint` | ✅ Compatible |
| `a5_get_res0_cells` | `() -> UBIGINT[]` | `() -> bigint[]` | ✅ Compatible |
| `a5_compact` | `(cell_ids) -> UBIGINT[]` | `(cell_ids) -> bigint[]` | ✅ Compatible |
| `a5_uncompact` | `(cell_ids, target_resolution) -> UBIGINT[]` | `(cell_ids, target_resolution) -> bigint[]` | ✅ Compatible |

## Key Differences

### Cell ID Type: `bigint` (signed) vs `UBIGINT` (unsigned)

**DuckDB:** Uses `UBIGINT` (unsigned 64-bit)  
**a5pg:** Uses `bigint` (signed 64-bit) - PostgreSQL limitation

Most cell IDs fit within the signed range. Functions error if a cell ID exceeds `BIGINT` range (`-2^63` to `2^63-1`).

**Recommended practice:** When storing cell IDs in tables, use `BIGINT` with a `CHECK` constraint to enforce non-negative values:

```sql
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    cell_id BIGINT NOT NULL CHECK (cell_id >= 0),
    ...
);
```

### Coordinate Order

**✅ Compatible:** Both use `(longitude, latitude, resolution)` order and return `[longitude, latitude]` pairs, despite DuckDB docs saying otherwise.

### Optional Parameters

**✅ Compatible:** `a5_cell_to_boundary()` supports optional `closed_ring` (bool) and `segments` (int) via function overloading in both implementations.

```sql
SELECT a5_cell_to_boundary(cell_id);                    -- defaults: closed_ring=true, segments=auto
SELECT a5_cell_to_boundary(cell_id, false);             -- open ring
SELECT a5_cell_to_boundary(cell_id, true, 10);          -- closed ring, 10 segments
```

### NULL Handling

All functions are `STRICT` in PostgreSQL (NULL inputs return NULL). `a5_cell_to_lonlat()` and `a5_cell_to_boundary()` return NULL for invalid cell IDs.

## PostgreSQL-Specific Features

- **Numeric overload:** `a5_lonlat_to_cell(lon numeric, lat numeric, res)` - no explicit casts needed
- **PostGIS wrapper:** `a5_point_to_cell(geom geometry, res)` - auto-created if PostGIS is installed
- **Metadata:** `a5pg_version()` and `a5pg_info()` - extension version info

## Migration Notes

**From DuckDB to a5pg:**

1. ✅ Parameter order and coordinate pairs match - no changes needed
2. ⚠️ Cell ID type: `UBIGINT` → `BIGINT` (PostgreSQL limitation - most values work fine)
3. ✅ All utility functions available (`a5_cell_area`, `a5_get_num_cells`, `a5_compact`, `a5_uncompact`, `a5_get_res0_cells`)

## Conclusion

✅ **Full API compatibility** - All DuckDB a5 functions are implemented with matching signatures (except `UBIGINT` → `BIGINT`).  
✅ **Query portability** - Queries can be ported between DuckDB and PostgreSQL with minimal changes.


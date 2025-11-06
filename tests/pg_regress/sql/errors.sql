-- Error handling tests
-- Note: pg_regress may not support error testing directly
-- These tests verify STRICT behavior and edge cases
-- Keep output stable & diff-friendly
-- Note: Run with: psql -X -t -A -f errors.sql

-- Test NULL handling for STRICT functions
-- These should return NULL when given NULL inputs
SELECT a5_lonlat_to_cell(NULL::double precision, 40.7580::double precision, 10) IS NULL AS null_lon_returns_null;
SELECT a5_lonlat_to_cell(-73.9857::double precision, NULL::double precision, 10) IS NULL AS null_lat_returns_null;
SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, NULL::int) IS NULL AS null_res_returns_null;

SELECT a5_cell_to_lonlat(NULL::bigint) IS NULL AS null_cell_id_returns_null;

SELECT a5_get_resolution(NULL::bigint) IS NULL AS null_resolution_returns_null;
SELECT a5_cell_to_parent(NULL::bigint, 8) IS NULL AS null_parent_returns_null;
SELECT a5_cell_to_children(NULL::bigint, 10) IS NULL AS null_children_returns_null;

SELECT a5_cell_to_boundary(NULL::bigint) IS NULL AS null_boundary_returns_null;

-- Test extreme coordinates (may or may not error depending on implementation)
-- Very high latitude
SELECT a5_lonlat_to_cell(0.0::double precision, 90.0::double precision, 10) IS NOT NULL AS north_pole_handled;

-- Very low latitude  
SELECT a5_lonlat_to_cell(0.0::double precision, -90.0::double precision, 10) IS NOT NULL AS south_pole_handled;

-- Very high longitude (should wrap)
SELECT a5_lonlat_to_cell(360.0::double precision, 0.0::double precision, 10) IS NOT NULL AS high_lon_handled;

-- Very low longitude (should wrap)
SELECT a5_lonlat_to_cell(-360.0::double precision, 0.0::double precision, 10) IS NOT NULL AS low_lon_handled;


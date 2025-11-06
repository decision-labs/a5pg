-- Edge cases and special scenarios
-- Keep output stable & diff-friendly
-- Note: Run with: psql -X -t -A -f edge_cases.sql

-- World cell (resolution 0, cell 0)
SELECT a5_lonlat_to_cell(0.0::double precision, 0.0::double precision, 0) AS world_cell_id;

-- World cell center should be (0, 0)
SELECT a5_cell_to_lonlat(a5_lonlat_to_cell(0.0::double precision, 0.0::double precision, 0)) AS world_cell_center;

-- Antimeridian crossing cells
-- Test known antimeridian cell IDs (convert hex to bigint)
SELECT 
  a5_lonlat_to_cell(180.0::double precision, 0.0::double precision, 5) AS antimeridian_cell_1,
  a5_cell_to_lonlat(a5_lonlat_to_cell(180.0::double precision, 0.0::double precision, 5)) AS coords_1;

SELECT 
  a5_lonlat_to_cell(-180.0::double precision, 0.0::double precision, 5) AS antimeridian_cell_2,
  a5_cell_to_lonlat(a5_lonlat_to_cell(-180.0::double precision, 0.0::double precision, 5)) AS coords_2;

-- Test antimeridian boundary (longitude span should be handled correctly)
WITH antimeridian_cell AS (
  SELECT a5_lonlat_to_cell(180.0::double precision, 0.0::double precision, 5) AS cell_id
)
SELECT 
  array_length(a5_cell_to_boundary((SELECT cell_id FROM antimeridian_cell)), 1) AS boundary_point_count_1;

WITH antimeridian_cell AS (
  SELECT a5_lonlat_to_cell(-180.0::double precision, 0.0::double precision, 5) AS cell_id
)
SELECT 
  array_length(a5_cell_to_boundary((SELECT cell_id FROM antimeridian_cell)), 1) AS boundary_point_count_2;

-- Boundary cases: lon=0, lat=0
SELECT a5_lonlat_to_cell(0.0::double precision, 0.0::double precision, 10) AS origin_cell;

-- Boundary cases: lon=180, lat=90 (North Pole)
SELECT a5_lonlat_to_cell(180.0::double precision, 90.0::double precision, 5) AS north_pole_cell;

-- Boundary cases: lon=-180, lat=-90 (South Pole)
SELECT a5_lonlat_to_cell(-180.0::double precision, -90.0::double precision, 5) AS south_pole_cell;

-- Test multiple resolutions for same point
WITH 
  point AS (
    SELECT -73.9857::double precision AS lon, 40.7580::double precision AS lat
  ),
  resolutions AS (
    SELECT generate_series(0, 10) AS res
  )
SELECT 
  res,
  a5_lonlat_to_cell(point.lon, point.lat, res) AS cell_id
FROM point, resolutions
ORDER BY res;

-- Test polar regions (lat > 80 or < -80)
-- High latitude point
SELECT a5_lonlat_to_cell(0.0::double precision, 85.0::double precision, 5) AS high_lat_cell;

-- Low latitude point
SELECT a5_lonlat_to_cell(0.0::double precision, -85.0::double precision, 5) AS low_lat_cell;

-- Verify polar cells can be converted back
WITH 
  high_lat AS (
    SELECT a5_lonlat_to_cell(0.0::double precision, 85.0::double precision, 5) AS cell_id
  )
SELECT 
  (a5_cell_to_lonlat((SELECT cell_id FROM high_lat)))[2] AS rt_lat;

-- Edge case: Equator at different longitudes
SELECT a5_lonlat_to_cell(0.0::double precision, 0.0::double precision, 10) AS equator_0;
SELECT a5_lonlat_to_cell(90.0::double precision, 0.0::double precision, 10) AS equator_90;
SELECT a5_lonlat_to_cell(180.0::double precision, 0.0::double precision, 10) AS equator_180;
SELECT a5_lonlat_to_cell(-90.0::double precision, 0.0::double precision, 10) AS equator_neg90;

-- Edge case: Prime meridian at different latitudes
SELECT a5_lonlat_to_cell(0.0::double precision, 0.0::double precision, 10) AS prime_0;
SELECT a5_lonlat_to_cell(0.0::double precision, 45.0::double precision, 10) AS prime_45;
SELECT a5_lonlat_to_cell(0.0::double precision, -45.0::double precision, 10) AS prime_neg45;


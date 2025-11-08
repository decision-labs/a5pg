-- Boundary and GeoJSON tests
-- Keep output stable & diff-friendly
-- Note: Run with: psql -X -t -A -f boundary.sql

-- Verify boundary array structure (array of [lon, lat] pairs)
WITH 
  cell_id AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS id
  ),
  boundary AS (
    SELECT a5_cell_to_boundary((SELECT id FROM cell_id)) AS coords
  )
SELECT 
  array_length(coords, 1) AS num_points,
  array_length(coords[1:1], 1) AS coords_per_point
FROM boundary;

-- Test boundary at multiple resolutions
WITH 
  point AS (
    SELECT -73.9857::double precision AS lon, 40.7580::double precision AS lat
  ),
  resolutions AS (
    SELECT generate_series(5, 10) AS res
  ),
  boundaries AS (
    SELECT 
      res,
      a5_cell_to_boundary(a5_lonlat_to_cell(point.lon, point.lat, res)) AS coords
    FROM point, resolutions
  )
SELECT 
  res,
  array_length(coords, 1) AS num_coords
FROM boundaries
ORDER BY res;

-- Test antimeridian handling (longitude span < 180)
-- Extract longitude values from boundary array and check span
WITH 
  antimeridian_cell AS (
    SELECT a5_lonlat_to_cell(180.0::double precision, 0.0::double precision, 5) AS cell_id
  ),
  boundary_array AS (
    SELECT a5_cell_to_boundary((SELECT cell_id FROM antimeridian_cell)) AS coords
  ),
  points AS (
    SELECT (coords)[i:i] AS point
    FROM boundary_array, generate_series(1, array_length(coords, 1)) AS i
  ),
  lons AS (
    SELECT (point)[1] AS lon FROM points
  )
SELECT 
  MIN(lon) AS min_lon,
  MAX(lon) AS max_lon,
  MAX(lon) - MIN(lon) AS lon_span,
  (MAX(lon) - MIN(lon) < 180.0) AS span_valid
FROM lons;

-- Test another antimeridian cell
WITH 
  antimeridian_cell AS (
    SELECT a5_lonlat_to_cell(-180.0::double precision, 0.0::double precision, 5) AS cell_id
  ),
  boundary_array AS (
    SELECT a5_cell_to_boundary((SELECT cell_id FROM antimeridian_cell)) AS coords
  ),
  points AS (
    SELECT (coords)[i:i] AS point
    FROM boundary_array, generate_series(1, array_length(coords, 1)) AS i
  ),
  lons AS (
    SELECT (point)[1] AS lon FROM points
  )
SELECT 
  MIN(lon) AS min_lon,
  MAX(lon) AS max_lon,
  MAX(lon) - MIN(lon) AS lon_span,
  (MAX(lon) - MIN(lon) < 180.0) AS span_valid
FROM lons;

-- Verify boundary coordinates are valid (lon between -180 and 180, lat between -90 and 90)
WITH 
  cell_id AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS id
  ),
  boundary_array AS (
    SELECT a5_cell_to_boundary((SELECT id FROM cell_id)) AS coords
  ),
  points AS (
    SELECT (coords)[i:i] AS point
    FROM boundary_array, generate_series(1, array_length(coords, 1)) AS i
  )
SELECT 
  MIN((point)[1]) AS min_lon,
  MAX((point)[1]) AS max_lon,
  MIN((point)[2]) AS min_lat,
  MAX((point)[2]) AS max_lat,
  BOOL_AND((point)[1] BETWEEN -180 AND 180) AS lons_valid,
  BOOL_AND((point)[2] BETWEEN -90 AND 90) AS lats_valid
FROM points;

-- Test boundary for world cell (should be empty or minimal)
SELECT 
  array_length(a5_cell_to_boundary(a5_lonlat_to_cell(0.0::double precision, 0.0::double precision, 0)), 1) AS world_cell_boundary_length;

-- Test optional parameters: closed_ring
WITH 
  cell_id AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS id
  )
SELECT 
  array_length(a5_cell_to_boundary((SELECT id FROM cell_id)), 1) AS default_closed_ring_count,
  array_length(a5_cell_to_boundary((SELECT id FROM cell_id), true), 1) AS explicit_closed_ring_count,
  array_length(a5_cell_to_boundary((SELECT id FROM cell_id), false), 1) AS open_ring_count,
  -- Closed ring should have one more point (repeats first point)
  (array_length(a5_cell_to_boundary((SELECT id FROM cell_id), true), 1) = 
   array_length(a5_cell_to_boundary((SELECT id FROM cell_id), false), 1) + 1) AS closed_ring_adds_point;

-- Test optional parameters: segments
WITH 
  cell_id AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS id
  )
SELECT 
  array_length(a5_cell_to_boundary((SELECT id FROM cell_id)), 1) AS default_segments_count,
  array_length(a5_cell_to_boundary((SELECT id FROM cell_id), true, 1), 1) AS segments_1_count,
  array_length(a5_cell_to_boundary((SELECT id FROM cell_id), true, 5), 1) AS segments_5_count,
  array_length(a5_cell_to_boundary((SELECT id FROM cell_id), true, 10), 1) AS segments_10_count,
  -- More segments should produce more points
  (array_length(a5_cell_to_boundary((SELECT id FROM cell_id), true, 10), 1) > 
   array_length(a5_cell_to_boundary((SELECT id FROM cell_id), true, 1), 1)) AS more_segments_produces_more_points;


-- Tests matching DuckDB a5 extension examples from documentation
-- https://raw.githubusercontent.com/Query-farm/a5/refs/heads/main/docs/README.md
-- Keep output stable & diff-friendly

-- Example 1: Get the A5 cell for a specific location (Times Square, NYC)
-- DuckDB: SELECT a5_lonlat_to_cell(-74.0060, 40.7128, 15) as nyc_cell;
-- Expected: 2742821848331845632
-- Note: DuckDB docs say (latitude, longitude) but examples use (longitude, latitude)
SELECT a5_lonlat_to_cell(-74.0060::double precision, 40.7128::double precision, 15) AS nyc_cell;

-- Example 2: Get the center coordinates of a cell
-- DuckDB: SELECT a5_cell_to_lonlat(a5_lonlat_to_cell(-74.0060, 40.7128, 15)) as center_coords;
-- Expected: [-74.00764805615836, 40.71280225138428] (approximately)
WITH nyc_cell AS (
  SELECT a5_lonlat_to_cell(-74.0060::double precision, 40.7128::double precision, 15) AS cell_id
)
SELECT 
  a5_cell_to_lonlat((SELECT cell_id FROM nyc_cell)) AS center_coords,
  -- Verify it's an array of 2 elements [lon, lat]
  array_length(a5_cell_to_lonlat((SELECT cell_id FROM nyc_cell)), 1) AS coords_length;

-- Example 3: Find parent cell at lower resolution
-- DuckDB: SELECT a5_cell_to_parent(a5_lonlat_to_cell(-74.0060, 40.7128, 15), 10) as parent_cell;
-- Expected: 2742821365684895744
WITH nyc_cell AS (
  SELECT a5_lonlat_to_cell(-74.0060::double precision, 40.7128::double precision, 15) AS cell_id
)
SELECT a5_cell_to_parent((SELECT cell_id FROM nyc_cell), 10) AS parent_cell;

-- Example 4: Get all children cells at higher resolution
-- DuckDB: SELECT a5_cell_to_children(a5_lonlat_to_cell(-74.0060, 40.7128, 10), 11) as child_cells;
-- Expected: [2742820953368035328, 2742821228245942272, 2742821503123849216, 2742821778001756160]
WITH parent_cell AS (
  SELECT a5_lonlat_to_cell(-74.0060::double precision, 40.7128::double precision, 10) AS cell_id
)
SELECT 
  a5_cell_to_children((SELECT cell_id FROM parent_cell), 11) AS child_cells,
  array_length(a5_cell_to_children((SELECT cell_id FROM parent_cell), 11), 1) AS num_children;

-- Example 5: London cell
-- DuckDB: SELECT a5_lonlat_to_cell(-0.1278, 51.5074, 12) as london_cell;
-- Expected: 7161033366718906368
SELECT a5_lonlat_to_cell(-0.1278::double precision, 51.5074::double precision, 12) AS london_cell;

-- Example 6: Get resolution of a cell
-- DuckDB: SELECT a5_get_resolution(207618739568) as resolution;
-- Expected: 27
SELECT a5_get_resolution(207618739568::bigint) AS resolution;

-- Example 7: Get parent cell
-- DuckDB: SELECT a5_cell_to_parent(207618739568, 10) as parent_cell;
-- Expected: 549755813888
SELECT a5_cell_to_parent(207618739568::bigint, 10) AS parent_cell;

-- Example 8: Get center coordinates
-- DuckDB: SELECT a5_cell_to_lonlat(207618739568) as center;
-- Expected: [-129.0078555564143, 52.76769886727584] (approximately)
SELECT 
  a5_cell_to_lonlat(207618739568::bigint) AS center,
  -- Verify coordinates are reasonable (lon between -180 and 180, lat between -90 and 90)
  (a5_cell_to_lonlat(207618739568::bigint))[1] BETWEEN -180 AND 180 AS lon_valid,
  (a5_cell_to_lonlat(207618739568::bigint))[2] BETWEEN -90 AND 90 AS lat_valid;

-- Example 9: Get boundary (default - closed ring, auto segments)
-- DuckDB: SELECT unnest(a5_cell_to_boundary(207618739568)) as boundary_points;
-- Expected: Array of [longitude, latitude] pairs (6 points with closed ring)
WITH boundary AS (
  SELECT 
    a5_cell_to_boundary(207618739568::bigint) AS coords,
    array_length(a5_cell_to_boundary(207618739568::bigint), 1) AS num_points
)
SELECT 
  num_points,
  -- First and last should be same for closed ring (default) - compare individual elements
  (coords[1][1] = coords[num_points][1] AND coords[1][2] = coords[num_points][2]) AS is_closed_ring
FROM boundary;

-- Example 10: Get boundary with closed_ring=false and segments=5
-- DuckDB: SELECT unnest(a5_cell_to_boundary(207618739568, false, 5)) as boundary_points;
-- Expected: 25 points (5 segments per edge * 5 edges)
WITH boundary AS (
  SELECT a5_cell_to_boundary(207618739568::bigint, false, 5) AS coords
)
SELECT 
  array_length(coords, 1) AS num_points,
  -- First and last should be different for open ring - compare individual elements
  (coords[1][1] != coords[array_length(coords, 1)][1] OR coords[1][2] != coords[array_length(coords, 1)][2]) AS is_open_ring,
  -- Should have more points than default due to segments=5
  (array_length(coords, 1) > 5) AS has_more_segments
FROM boundary;

-- Example 11: GeoJSON example - Madrid cell boundary
-- DuckDB example uses: a5_lonlat_to_cell(-3.7037, 40.41677, 10)
-- Then: a5_cell_to_boundary(...) with x -> ST_Point(x[1], x[2])
-- This tests that coordinates are in [lon, lat] order (x[1] = lon, x[2] = lat)
WITH madrid_cell AS (
  SELECT a5_lonlat_to_cell(-3.7037::double precision, 40.41677::double precision, 10) AS cell_id
),
boundary AS (
  SELECT a5_cell_to_boundary((SELECT cell_id FROM madrid_cell)) AS coords
)
SELECT 
  coords[1][1] AS longitude,
  coords[1][2] AS latitude,
  -- Verify lon is negative (west of prime meridian) and lat is positive (north of equator)
  (coords[1][1] < 0 AND coords[1][2] > 0) AS coordinates_valid,
  -- Verify coordinates match expected range for Madrid
  (coords[1][1] BETWEEN -4 AND -3 AND coords[1][2] BETWEEN 40 AND 41) AS madrid_range_valid
FROM boundary;


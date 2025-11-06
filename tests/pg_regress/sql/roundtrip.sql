-- Comprehensive round-trip tests
-- Keep output stable & diff-friendly
-- Note: Run with: psql -X -t -A -f roundtrip.sql

-- Round-trip test: lonlat -> cell_id -> lonlat (BIGINT)
-- NYC coordinates
WITH 
  original AS (
    SELECT -73.9857::double precision AS lon, 40.7580::double precision AS lat, 10 AS res
  ),
  cell_id AS (
    SELECT a5_lonlat_to_cell(original.lon, original.lat, original.res) AS id
    FROM original
  ),
  roundtrip AS (
    SELECT 
      (a5_cell_to_lonlat((SELECT id FROM cell_id)))[1] AS rt_lon,
      (a5_cell_to_lonlat((SELECT id FROM cell_id)))[2] AS rt_lat
  )
SELECT 
  original.lon AS orig_lon,
  original.lat AS orig_lat,
  roundtrip.rt_lon,
  roundtrip.rt_lat,
  ABS(original.lon - roundtrip.rt_lon) < 0.1 AS lon_close,
  ABS(original.lat - roundtrip.rt_lat) < 0.1 AS lat_close
FROM original, roundtrip;

-- Test multiple resolutions (0-10) for NYC
WITH 
  point AS (
    SELECT -73.9857::double precision AS lon, 40.7580::double precision AS lat
  ),
  resolutions AS (
    SELECT generate_series(0, 10) AS res
  ),
  roundtrips AS (
    SELECT 
      res,
      a5_lonlat_to_cell(point.lon, point.lat, res) AS cell_id,
      (a5_cell_to_lonlat(a5_lonlat_to_cell(point.lon, point.lat, res)))[1] AS rt_lon,
      (a5_cell_to_lonlat(a5_lonlat_to_cell(point.lon, point.lat, res)))[2] AS rt_lat
    FROM point, resolutions
  )
SELECT 
  res,
  ABS(rt_lon - point.lon) < 1.0 AS lon_valid,
  ABS(rt_lat - point.lat) < 1.0 AS lat_valid
FROM roundtrips, point
ORDER BY res;

-- Test known coordinates: London
WITH 
  original AS (
    SELECT -0.1276::double precision AS lon, 51.5074::double precision AS lat, 10 AS res
  ),
  cell_id AS (
    SELECT a5_lonlat_to_cell(original.lon, original.lat, original.res) AS id
    FROM original
  ),
  roundtrip AS (
    SELECT 
      (a5_cell_to_lonlat((SELECT id FROM cell_id)))[1] AS rt_lon,
      (a5_cell_to_lonlat((SELECT id FROM cell_id)))[2] AS rt_lat
  )
SELECT 
  ABS(original.lon - roundtrip.rt_lon) < 0.1 AS lon_close,
  ABS(original.lat - roundtrip.rt_lat) < 0.1 AS lat_close
FROM original, roundtrip;

-- Test known coordinates: Tokyo
WITH 
  original AS (
    SELECT 139.6503::double precision AS lon, 35.6762::double precision AS lat, 10 AS res
  ),
  cell_id AS (
    SELECT a5_lonlat_to_cell(original.lon, original.lat, original.res) AS id
    FROM original
  ),
  roundtrip AS (
    SELECT 
      (a5_cell_to_lonlat((SELECT id FROM cell_id)))[1] AS rt_lon,
      (a5_cell_to_lonlat((SELECT id FROM cell_id)))[2] AS rt_lat
  )
SELECT 
  ABS(original.lon - roundtrip.rt_lon) < 0.1 AS lon_close,
  ABS(original.lat - roundtrip.rt_lat) < 0.1 AS lat_close
FROM original, roundtrip;



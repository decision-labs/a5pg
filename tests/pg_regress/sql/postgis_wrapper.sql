\pset tuples_only on
\pset format unaligned

-- Test PostGIS wrapper functions (only if PostGIS is installed)
-- Drop and reinstall extensions to ensure clean state
-- Order matters: drop a5pg first (removes wrapper functions), then postgis, then recreate postgis, then a5pg
DROP EXTENSION IF EXISTS a5pg CASCADE;
DROP EXTENSION IF EXISTS postgis CASCADE;
CREATE EXTENSION postgis;
CREATE EXTENSION a5pg;

-- Test actual function calls and verify outputs
-- Test a5_point_to_cell: convert PostGIS point to cell ID
SELECT a5_point_to_cell(ST_SetSRID(ST_MakePoint(-73.9857, 40.7580), 4326), 10) AS point_to_cell_result;

-- Test a5_cell_to_point: convert cell ID to PostGIS point
SELECT 
  ST_X(a5_cell_to_point(2742822465196523520)) AS cell_to_point_lon,
  ST_Y(a5_cell_to_point(2742822465196523520)) AS cell_to_point_lat;

-- Test a5_cell_to_geom: convert cell ID to PostGIS polygon
SELECT 
  ST_GeometryType(a5_cell_to_geom(2742822465196523520)) AS cell_to_geom_type,
  ST_NPoints(a5_cell_to_geom(2742822465196523520)) AS cell_to_geom_num_points,
  ST_AsText(a5_cell_to_geom(2742822465196523520)) AS cell_to_geom_wkt;

-- Test a5_cell_to_geom: GeoJSON output
SELECT ST_AsGeoJSON(a5_cell_to_geom(2742822465196523520)) AS cell_to_geom_geojson;

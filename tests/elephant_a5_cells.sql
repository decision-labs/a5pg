-- elephant_a5_cells.sql
-- Usage:
--   psql "$DATABASE_URL" -f elephant_a5_cells.sql -v res=11 -v method=fill
-- Vars:
--   :res    -> target a5 resolution (integer)
--   :method -> 'boundary' or 'fill' (default 'fill')

\set res 11
\set method fill

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS a5pg;  -- a5pg extension

-- Drop old
DROP TABLE IF EXISTS public.elephant_features CASCADE;
DROP TABLE IF EXISTS public.elephant_points CASCADE;
DROP TABLE IF EXISTS public.elephant_vertices CASCADE;
DROP TABLE IF EXISTS public.elephant_cells CASCADE;

-- 1) Load FeatureCollection from embedded JSON
WITH fc AS (
  SELECT '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"part":"head_trunk"},"geometry":{"type":"Polygon","coordinates":[[[0.0,1.0],[-0.28,0.95],[-0.55,0.8],[-0.7,0.6],[-0.45,0.55],[-0.35,0.05],[-0.24,-0.05],[-0.18,-0.25],[-0.14,-0.5],[-0.1,-0.75],[-0.06,-1.0],[0.0,-1.15],[0.06,-1.0],[0.1,-0.75],[0.14,-0.5],[0.18,-0.25],[0.24,-0.05],[0.35,0.05],[0.45,0.55],[0.7,0.6],[0.55,0.8],[0.28,0.95],[0.0,1.0]]]}},{"type":"Feature","properties":{"part":"ear_left"},"geometry":{"type":"Polygon","coordinates":[[[-0.45,0.55],[-0.72,0.88],[-0.98,0.68],[-1.08,0.4],[-0.98,0.12],[-0.78,-0.02],[-0.56,0.02],[-0.35,0.05],[-0.42,0.33],[-0.45,0.55]]]}},{"type":"Feature","properties":{"part":"ear_right"},"geometry":{"type":"Polygon","coordinates":[[[0.45,0.55],[0.72,0.88],[0.98,0.68],[1.08,0.4],[0.98,0.12],[0.78,-0.02],[0.56,0.02],[0.35,0.05],[0.42,0.33],[0.45,0.55]]]}},{"type":"Feature","properties":{"part":"eye_left"},"geometry":{"type":"Point","coordinates":[-0.2,0.35]}},{"type":"Feature","properties":{"part":"eye_right"},"geometry":{"type":"Point","coordinates":[0.2,0.35]}}]}'::jsonb AS j
),
features AS (
  SELECT
    (f->'properties'->>'part')::text AS part,
    ST_SetSRID(ST_GeomFromGeoJSON((f->'geometry')::text), 4326) AS geom
  FROM fc, jsonb_array_elements(fc.j->'features') AS f
)
SELECT * INTO TEMP tmp_features FROM features;

-- Persist polygon + point geom into public
CREATE TABLE public.elephant_features AS
SELECT * FROM tmp_features;

-- Extract point geometries for eyes
CREATE TABLE public.elephant_points AS
SELECT part, geom
FROM public.elephant_features
WHERE GeometryType(geom) = 'POINT';

-- Extract vertices from polygon geometries
CREATE TABLE public.elephant_vertices AS
WITH polys AS (
    SELECT part, geom
    FROM public.elephant_features
    WHERE GeometryType(geom) LIKE 'POLYGON%'
),
vertices AS (
    SELECT
        part,
        (ST_DumpPoints(geom)).geom::geometry(Point, 4326) AS pt
    FROM polys
)
SELECT
    part,
    ST_X(pt) AS lon,
    ST_Y(pt) AS lat
FROM vertices;

-- 2) Produce sampling points
WITH
poly AS (
  SELECT part, geom
  FROM public.elephant_features
  WHERE GeometryType(geom) LIKE 'POLYGON%'
),
boundary_pts AS (
  SELECT part,
         (ST_DumpPoints(ST_Segmentize(geom, 0.02))).geom::geometry(Point,4326) AS pt
  FROM poly
),
fill_pts AS (
  SELECT part,
         (ST_Dump(ST_GeneratePoints(geom, GREATEST(200, round(ST_Area(geom::geography)/1e8)::int)))).geom::geometry(Point,4326) AS pt
  FROM poly
),
grid_pts AS (
  SELECT part,
         ST_SetSRID(ST_MakePoint(
           ST_XMin(geom) + (ST_XMax(geom) - ST_XMin(geom)) * (x::float / 50),
           ST_YMin(geom) + (ST_YMax(geom) - ST_YMin(geom)) * (y::float / 50)
         ), 4326)::geometry(Point,4326) AS pt
  FROM poly,
       generate_series(0, 50) AS x,
       generate_series(0, 50) AS y
  WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(
    ST_XMin(geom) + (ST_XMax(geom) - ST_XMin(geom)) * (x::float / 50),
    ST_YMin(geom) + (ST_YMax(geom) - ST_YMin(geom)) * (y::float / 50)
  ), 4326))
),
pts AS (
  SELECT * FROM boundary_pts WHERE :'method'='boundary'
  UNION ALL
  SELECT * FROM fill_pts     WHERE :'method'='fill'
  UNION ALL
  SELECT * FROM grid_pts     WHERE :'method'='fill'  -- Additional dense grid for complete coverage
  UNION ALL
  SELECT part, geom::geometry(Point,4326) AS pt FROM public.elephant_points
)

-- 3) Map to A5 cell ids (✅ correct lon/lat: X=lon, Y=lat)
-- Using full resolution for finer detail
SELECT DISTINCT
  part,
  a5_lonlat_to_cell(ST_X(pt), ST_Y(pt), :res::int) AS cell_id
INTO public.elephant_cells
FROM pts;

CREATE INDEX ON public.elephant_cells(cell_id);
CREATE INDEX ON public.elephant_cells(part);

COMMIT;

-- Export GeoJSON file (outside transaction block)
CREATE TEMP TABLE geojson_export AS
SELECT jsonb_build_object(
         'type','FeatureCollection',
         'features', jsonb_agg(
           jsonb_build_object(
             'type','Feature',
             'properties', jsonb_build_object(
                 'part', part,
                 'cell_id', cell_id
             ),
             'geometry', ST_AsGeoJSON(a5_cell_to_geom(cell_id), 6)::jsonb
           )
         )
       )::text AS geojson
FROM public.elephant_cells;

\copy geojson_export TO 'tests/elephant_cells.geojson';

-- Inspect:
-- SELECT * FROM public.elephant_cells ORDER BY part, cell_id LIMIT 50;
-- SELECT part, a5_cell_to_boundary(cell_id) FROM public.elephant_cells LIMIT 5;
-- SELECT part, a5_cell_to_geom(cell_id) FROM public.elephant_cells LIMIT 5;  -- PostGIS geometry

-- elephant_a5_cells.sql
-- Usage:
--   psql "$DATABASE_URL" -f elephant_a5_cells.sql -v res=10 -v method=fill
-- Vars:
--   :res    -> target a5 resolution (integer)
--   :method -> 'boundary' or 'fill' (default 'fill')

\set res 10
\set method fill

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;
-- CREATE EXTENSION IF NOT EXISTS a5;  -- uncomment if your a5 extension isn't loaded

-- Drop old
DROP TABLE IF EXISTS public.elephant_features CASCADE;
DROP TABLE IF EXISTS public.elephant_points CASCADE;
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
         (ST_Dump(ST_GeneratePoints(geom, GREATEST(50, round(ST_Area(geom::geography)/1e9)::int)))).geom::geometry(Point,4326) AS pt
  FROM poly
),
pts AS (
  SELECT * FROM boundary_pts WHERE :'method'='boundary'
  UNION ALL
  SELECT * FROM fill_pts     WHERE :'method'='fill'
  UNION ALL
  SELECT part, geom::geometry(Point,4326) AS pt FROM public.elephant_points
)

-- 3) Map to A5 cell ids (✅ correct lon/lat: X=lon, Y=lat)
SELECT DISTINCT
  part,
  a5_lonlat_to_cell(ST_X(pt), ST_Y(pt), :res::int) AS cell_id
INTO public.elephant_cells
FROM pts;

CREATE INDEX ON public.elephant_cells(cell_id);
CREATE INDEX ON public.elephant_cells(part);

COMMIT;

-- Inspect:
-- SELECT * FROM public.elephant_cells ORDER BY part, cell_id LIMIT 50;
-- SELECT part, a5_cell_to_boundary(cell_id) FROM public.elephant_cells LIMIT 5;

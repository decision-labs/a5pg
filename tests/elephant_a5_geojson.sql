DROP TABLE IF EXISTS public.elephant_vertices;

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

DROP TABLE IF EXISTS public.elephant_vertices_cells;

CREATE TABLE public.elephant_vertices_cells AS
SELECT DISTINCT
    part,
    a5_lonlat_to_cell(lon, lat, :res::int) AS cell_id
FROM public.elephant_vertices;

DROP TABLE IF EXISTS public.elephant_vertex_cell_geom;

CREATE TABLE public.elephant_vertex_cell_geom AS
SELECT
    part,
    cell_id,
    -- Use PostGIS wrapper function for simpler geometry creation
    a5_cell_to_geom(cell_id) AS geom
FROM public.elephant_vertices_cells;

\copy (
  SELECT jsonb_build_object(
           'type','FeatureCollection',
           'features', jsonb_agg(
             jsonb_build_object(
               'type','Feature',
               'properties', jsonb_build_object(
                   'part', part,
                   'cell_id', cell_id
               ),
               'geometry', ST_AsGeoJSON(geom, 6)::jsonb
             )
           )
         )::text
  FROM public.elephant_vertex_cell_geom
) TO 'elephant_vertex_cells.geojson';

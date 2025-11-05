-- Keep output stable & diff-friendly
\pset tuples_only on
\pset format unaligned

-- Sanity: BIGINT id
SELECT a5_lonlat_to_cell_id(-73.9857::double precision, 40.7580::double precision, 10);

WITH id AS (
  SELECT a5_lonlat_to_cell_id(-73.9857::double precision, 40.7580::double precision, 10) AS id
)
SELECT a5_cell_resolution((SELECT id FROM id)) AS res,
       a5_cell_resolution(a5_cell_parent_id((SELECT id FROM id), 8)) AS parent_res,
       array_length(a5_cell_children_ids((SELECT id FROM id), 12), 1) AS n_children;

-- Boundary prefix (deterministic prefix only)
SELECT 
  a5_cell_id_boundary_geojson(
    a5_lonlat_to_cell_id(-73.9857::double precision, 40.7580::double precision, 10)
  );

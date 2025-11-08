-- Keep output stable & diff-friendly
-- Note: Run with: psql -X -t -A -f basic.sql

-- Sanity: BIGINT id
SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10);

WITH id AS (
  SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS id
)
SELECT a5_get_resolution((SELECT id FROM id)) AS res,
       a5_get_resolution(a5_cell_to_parent((SELECT id FROM id), 8)) AS parent_res,
       array_length(a5_cell_to_children((SELECT id FROM id), 12), 1) AS n_children;

-- Boundary prefix (deterministic prefix only)
SELECT 
  array_length(a5_cell_to_boundary(
    a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10)
  ), 1) AS boundary_point_count;

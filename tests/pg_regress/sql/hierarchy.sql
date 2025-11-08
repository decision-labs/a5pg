-- Cell hierarchy operations
-- Keep output stable & diff-friendly
-- Note: Run with: psql -X -t -A -f hierarchy.sql

-- Basic parent/children relationships
WITH 
  original AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS cell_id
  ),
  parent AS (
    SELECT a5_cell_to_parent((SELECT cell_id FROM original), 8) AS parent_id
  )
SELECT 
  a5_get_resolution((SELECT cell_id FROM original)) AS orig_res,
  a5_get_resolution((SELECT parent_id FROM parent)) AS parent_res;

-- Verify children count matches expected (4^(delta_res))
-- Resolution 10 -> 12 should have 4^(12-10) = 16 children
WITH 
  original AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS cell_id
  ),
  children AS (
    SELECT a5_cell_to_children((SELECT cell_id FROM original), 12) AS children_array
  )
SELECT 
  array_length((SELECT children_array FROM children), 1) AS num_children,
  16 AS expected_count;

-- Verify parent of children equals original
WITH 
  original AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS cell_id
  ),
  children AS (
    SELECT a5_cell_to_children((SELECT cell_id FROM original), 12) AS children_array
  ),
  first_child AS (
    SELECT (SELECT children_array FROM children)[1] AS child_id
  ),
  child_parent AS (
    SELECT a5_cell_to_parent((SELECT child_id FROM first_child), 10) AS parent_id
  )
SELECT 
  (SELECT cell_id FROM original) = (SELECT parent_id FROM child_parent) AS parent_matches;

-- Test with different target resolutions
WITH 
  original AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS cell_id
  )
SELECT 
  target_res,
  a5_get_resolution(a5_cell_to_parent((SELECT cell_id FROM original), target_res)) AS parent_res
FROM generate_series(5, 9) AS target_res
ORDER BY target_res;

-- Test children at different target resolutions
WITH 
  original AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 8) AS cell_id
  )
SELECT 
  target_res,
  array_length(a5_cell_to_children((SELECT cell_id FROM original), target_res), 1) AS num_children
FROM generate_series(9, 11) AS target_res
ORDER BY target_res;

-- Verify hierarchy consistency: parent -> children -> parent
WITH 
  original AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS cell_id
  ),
  parent AS (
    SELECT a5_cell_to_parent((SELECT cell_id FROM original), 8) AS parent_id
  ),
  children AS (
    SELECT a5_cell_to_children((SELECT parent_id FROM parent), 10) AS children_array
  )
SELECT 
  EXISTS(
    SELECT 1 FROM unnest((SELECT children_array FROM children)) AS child_id
    WHERE child_id = (SELECT cell_id FROM original)
  ) AS found_in_children;

-- Test resolution changes: verify resolution matches expected
WITH 
  original AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS cell_id
  ),
  parent_8 AS (
    SELECT a5_cell_to_parent((SELECT cell_id FROM original), 8) AS parent_id
  ),
  parent_5 AS (
    SELECT a5_cell_to_parent((SELECT cell_id FROM original), 5) AS parent_id
  )
SELECT 
  a5_get_resolution((SELECT cell_id FROM original)) AS orig_res,
  a5_get_resolution((SELECT parent_id FROM parent_8)) AS parent_8_res,
  a5_get_resolution((SELECT parent_id FROM parent_5)) AS parent_5_res;

-- Test multiple levels of hierarchy
WITH 
  level_10 AS (
    SELECT a5_lonlat_to_cell(-73.9857::double precision, 40.7580::double precision, 10) AS cell_id
  ),
  level_8 AS (
    SELECT a5_cell_to_parent((SELECT cell_id FROM level_10), 8) AS cell_id
  ),
  level_5 AS (
    SELECT a5_cell_to_parent((SELECT cell_id FROM level_8), 5) AS cell_id
  ),
  level_0 AS (
    SELECT a5_cell_to_parent((SELECT cell_id FROM level_5), 0) AS cell_id
  )
SELECT 
  a5_get_resolution((SELECT cell_id FROM level_10)) AS res_10,
  a5_get_resolution((SELECT cell_id FROM level_8)) AS res_8,
  a5_get_resolution((SELECT cell_id FROM level_5)) AS res_5,
  a5_get_resolution((SELECT cell_id FROM level_0)) AS res_0;


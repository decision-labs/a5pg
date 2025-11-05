\pset tuples_only on
\pset format unaligned

-- Only run if geometry type exists (same guard your extension uses)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'geometry') THEN
    EXECUTE $q$
      SELECT a5_point_to_cell_id(ST_SetSRID(ST_MakePoint(-73.9857, 40.7580), 4326), 10);
    $q$;
  END IF;
END;
$$ LANGUAGE plpgsql;

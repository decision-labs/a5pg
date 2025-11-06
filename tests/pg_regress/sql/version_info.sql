-- Version and info functions
-- Keep output stable & diff-friendly
-- Note: Run with: psql -X -t -A -f version_info.sql

-- Test a5pg_version() returns string
SELECT a5pg_version() AS version;

-- Test a5pg_info() returns JSONB with both versions
SELECT a5pg_info() AS info;

-- Verify JSON structure of a5pg_info()
SELECT 
  (a5pg_info()->>'a5pg_version') IS NOT NULL AS has_a5pg_version,
  (a5pg_info()->>'a5_version') IS NOT NULL AS has_a5_version;

-- Verify version values are non-empty strings
SELECT 
  (a5pg_info()->>'a5pg_version') != '' AS a5pg_version_not_empty,
  (a5pg_info()->>'a5_version') != '' AS a5_version_not_empty;

-- Verify a5pg_version() matches the a5pg_version field in a5pg_info()
SELECT 
  a5pg_version() = (a5pg_info()->>'a5pg_version') AS versions_match;


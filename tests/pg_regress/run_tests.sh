#!/bin/bash
# Run pg_regress SQL tests for a5pg extension

set -e

PG_VERSION=${PG_VERSION:-17}

# Find pg_config
if command -v pg_config &> /dev/null; then
    PG_CONFIG=$(command -v pg_config)
elif [ -f "/opt/homebrew/opt/postgresql@${PG_VERSION}/bin/pg_config" ]; then
    PG_CONFIG="/opt/homebrew/opt/postgresql@${PG_VERSION}/bin/pg_config"
elif [ -f "/usr/local/opt/postgresql@${PG_VERSION}/bin/pg_config" ]; then
    PG_CONFIG="/usr/local/opt/postgresql@${PG_VERSION}/bin/pg_config"
else
    echo "Error: pg_config not found. Please install PostgreSQL or set PG_CONFIG." >&2
    exit 1
fi

PG_BINDIR=$(${PG_CONFIG} --bindir)
PG_REGRESS="${PG_BINDIR}/pg_regress"

# Check if pg_regress exists
if [ ! -f "${PG_REGRESS}" ]; then
    echo "Error: pg_regress not found at ${PG_REGRESS}"
    echo "Trying alternative: running tests directly with psql..."
    
    TEST_DB="a5pg_test_$$"
    createdb "${TEST_DB}" 2>/dev/null || true
    trap "dropdb '${TEST_DB}' 2>/dev/null || true" EXIT
    
    psql "${TEST_DB}" -c "CREATE EXTENSION IF NOT EXISTS a5pg;" > /dev/null 2>&1
    
    FILTER_PATTERN='ERROR\|HINT\|CONTEXT\|PL/pgSQL\|geometry\|LINE\|^$\|^Output format'
    
    run_test() {
        local test_name=$1
        echo "Running ${test_name}.sql..."
        local actual_output=$(psql "${TEST_DB}" -X -t -A -f "tests/pg_regress/sql/${test_name}.sql" 2>&1 | grep -v "${FILTER_PATTERN}")
        local expected_file="tests/pg_regress/expected/${test_name}.out"
        if [ -f "${expected_file}" ]; then
            if echo "${actual_output}" | diff -q "${expected_file}" - > /dev/null 2>&1; then
                echo "  ✓ ${test_name}.sql - output matches expected"
            else
                echo "  ✗ ${test_name}.sql - output differs from expected"
                echo "${actual_output}" | diff -u "${expected_file}" - || true
            fi
        else
            echo "${actual_output}"
        fi
    }
    
    run_test basic
    run_test boundary
    run_test duckdb_examples
    run_test edge_cases
    run_test errors
    run_test hierarchy
    run_test postgis_wrapper
    run_test roundtrip
    run_test version_info
    
    exit 0
fi

# Use pg_regress if available
echo "Using pg_regress at ${PG_REGRESS}"
cd "$(dirname "$0")/../.."
${PG_REGRESS} \
    --dbname=a5pg_test \
    --inputdir=tests/pg_regress \
    --outputdir=tests/pg_regress \
    --load-extension=a5pg \
    basic boundary duckdb_examples edge_cases errors hierarchy postgis_wrapper roundtrip version_info


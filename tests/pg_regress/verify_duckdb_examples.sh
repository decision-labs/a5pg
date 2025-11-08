#!/bin/bash
# Verify duckdb_examples test output matches expected

set -e

cd "$(dirname "$0")/../.."

TEST_DB="a5pg_test_duckdb_verify_$$"
SQL_FILE="tests/pg_regress/sql/duckdb_examples.sql"
EXPECTED_FILE="tests/pg_regress/expected/duckdb_examples.out"
ACTUAL_FILE="/tmp/duckdb_examples_actual_$$.txt"

# Cleanup function
cleanup() {
    dropdb "${TEST_DB}" 2>/dev/null || true
    rm -f "${ACTUAL_FILE}"
}
trap cleanup EXIT

# Create test database and install extension
createdb "${TEST_DB}" 2>/dev/null || true
psql "${TEST_DB}" -c "CREATE EXTENSION IF NOT EXISTS a5pg;" > /dev/null 2>&1

# Run test and capture output
psql "${TEST_DB}" -X -t -A -f "${SQL_FILE}" 2>&1 | \
    grep -v "ERROR\|HINT\|CONTEXT\|PL/pgSQL\|geometry\|LINE\|^$" > "${ACTUAL_FILE}"

# Compare with expected output
if diff -q "${EXPECTED_FILE}" "${ACTUAL_FILE}" > /dev/null 2>&1; then
    echo "✓ duckdb_examples test PASSED - output matches expected"
    exit 0
else
    echo "✗ duckdb_examples test FAILED - output differs from expected"
    echo ""
    echo "Diff:"
    diff -u "${EXPECTED_FILE}" "${ACTUAL_FILE}" || true
    exit 1
fi


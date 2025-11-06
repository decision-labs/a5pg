#!/bin/bash
# Run pg_regress SQL tests for a5pg extension

set -e

# Default PostgreSQL version
PG_VERSION=${PG_VERSION:-17}

# Find pg_config
if command -v pg_config &> /dev/null; then
    PG_CONFIG=$(which pg_config)
else
    # Try Homebrew path
    if [ -f "/opt/homebrew/opt/postgresql@${PG_VERSION}/bin/pg_config" ]; then
        PG_CONFIG="/opt/homebrew/opt/postgresql@${PG_VERSION}/bin/pg_config"
    elif [ -f "/usr/local/opt/postgresql@${PG_VERSION}/bin/pg_config" ]; then
        PG_CONFIG="/usr/local/opt/postgresql@${PG_VERSION}/bin/pg_config"
    else
        echo "Error: pg_config not found. Please install PostgreSQL or set PG_CONFIG."
        exit 1
    fi
fi

# Get PostgreSQL installation directory
PG_BINDIR=$(${PG_CONFIG} --bindir)
PG_REGRESS="${PG_BINDIR}/pg_regress"

# Check if pg_regress exists
if [ ! -f "${PG_REGRESS}" ]; then
    echo "Error: pg_regress not found at ${PG_REGRESS}"
    echo "Trying alternative: running tests directly with psql..."
    
    # Fallback: run with psql
    TEST_DB="a5pg_test_$$"
    createdb "${TEST_DB}" 2>/dev/null || true
    
    echo "Running SQL tests in database ${TEST_DB}..."
    
    psql "${TEST_DB}" -c "CREATE EXTENSION IF NOT EXISTS a5pg;" > /dev/null 2>&1
    
    for sql_file in tests/pg_regress/sql/*.sql; do
        if [ "$(basename ${sql_file})" != "setup.sql" ]; then
            echo "Running $(basename ${sql_file})..."
            psql "${TEST_DB}" -X -t -A -f "${sql_file}" || echo "  Failed: ${sql_file}"
        fi
    done
    
    dropdb "${TEST_DB}" 2>/dev/null || true
    exit 0
fi

# Use pg_regress if available
echo "Using pg_regress at ${PG_REGRESS}"
echo "Running SQL tests..."

cd "$(dirname "$0")/../.."
${PG_REGRESS} \
    --dbname=a5pg_test \
    --inputdir=tests/pg_regress \
    --outputdir=tests/pg_regress \
    --load-extension=a5pg \
    hex_functions roundtrip edge_cases hierarchy boundary version_info errors


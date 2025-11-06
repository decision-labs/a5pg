# Run SQL tests manually with psql
# 
# First, make sure the extension is installed and you have a test database:
# 
#   createdb a5pg_test
#   psql a5pg_test -c "CREATE EXTENSION a5pg;"
#
# Then run each test file (use -X -t -A flags for clean output):
#
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/hex_functions.sql
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/roundtrip.sql
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/edge_cases.sql
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/hierarchy.sql
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/boundary.sql
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/version_info.sql
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/errors.sql
#
# Or run all tests at once:
#
#   for sql in tests/pg_regress/sql/*.sql; do 
#     [ "$(basename $sql)" != "setup.sql" ] && \
#       echo "Running $(basename $sql)..." && \
#       psql a5pg_test -X -t -A -f "$sql"
#   done
#
# To generate expected output files, redirect output:
#
#   psql a5pg_test -X -t -A -f tests/pg_regress/sql/hex_functions.sql > tests/pg_regress/expected/hex_functions.out 2>&1
#
# Flags explanation:
#   -X  : Skip reading .psqlrc files
#   -t  : Print rows only (tuples only)
#   -A  : Unaligned output format


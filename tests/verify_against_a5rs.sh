#!/bin/bash
# Verify SQL test outputs against a5-rs library expectations

set -e

cd "$(dirname "$0")/.."
PG_DB=${PG_DB:-a5pg_test}

echo "=== Verifying SQL outputs against a5-rs library ==="
echo ""

# Test 1: World cell center (note: a5-rs expects cell ID 0 to work, but we block it)
echo "Test 1: World cell (0,0) at resolution 0"
CELL_ID=$(psql $PG_DB -X -t -A -c "SELECT a5_lonlat_to_cell(0.0::double precision, 0.0::double precision, 0);")
CENTER=$(psql $PG_DB -X -t -A -c "SELECT a5_cell_to_lonlat($CELL_ID);")
echo "  Cell ID: $CELL_ID"
echo "  Center: $CENTER"
echo ""

# Test 2: Antimeridian cells - verify longitude span < 180
echo "Test 2: Antimeridian cell longitude spans"
for LON in "180.0" "-180.0"; do
    echo "  Testing lon: $LON"
    CELL_ID=$(psql $PG_DB -X -t -A -c "SELECT a5_lonlat_to_cell($LON::double precision, 0.0::double precision, 5);")
    BOUNDARY_LEN=$(psql $PG_DB -X -t -A -c "SELECT array_length(a5_cell_to_boundary($CELL_ID), 1);")
    echo "    Cell ID: $CELL_ID"
    echo "    Boundary points: $BOUNDARY_LEN"
    
    # Get longitude span
    LON_SPAN=$(psql $PG_DB -X -t -A <<EOF
WITH boundary_array AS (
    SELECT a5_cell_to_boundary($CELL_ID) AS coords
),
points AS (
    SELECT (coords)[i:i] AS point
    FROM boundary_array, generate_series(1, array_length(coords, 1)) AS i
),
lons AS (
    SELECT (point)[1] AS lon FROM points
)
SELECT MAX(lon) - MIN(lon) AS lon_span FROM lons;
EOF
)
    echo "    Longitude span: $LON_SPAN"
    if (( $(echo "$LON_SPAN < 180.0" | bc -l) )); then
        echo "    ✓ Span is valid (< 180)"
    else
        echo "    ✗ Span is invalid (>= 180)"
    fi
done
echo ""

# Test 3: Round-trip tests
echo "Test 3: Round-trip tests (lonlat -> cell -> lonlat)"
TEST_POINTS=("-73.9857,40.7580" "-0.1276,51.5074" "139.6503,35.6762")
for POINT in "${TEST_POINTS[@]}"; do
    IFS=',' read -r LON LAT <<< "$POINT"
    echo "  Testing point: ($LON, $LAT)"
    CELL_ID=$(psql $PG_DB -X -t -A -c "SELECT a5_lonlat_to_cell($LON::double precision, $LAT::double precision, 10);")
    RT_COORDS=$(psql $PG_DB -X -t -A -c "SELECT a5_cell_to_lonlat($CELL_ID);")
    RT_LON=$(echo $RT_COORDS | cut -d',' -f1 | tr -d '{')
    RT_LAT=$(echo $RT_COORDS | cut -d',' -f2 | tr -d '}')
    LON_DIFF=$(echo "scale=6; $LON - $RT_LON" | bc | tr -d '-')
    LAT_DIFF=$(echo "scale=6; $LAT - $RT_LAT" | bc | tr -d '-')
    echo "    Cell ID: $CELL_ID"
    echo "    Round-trip: ($RT_LON, $RT_LAT)"
    echo "    Difference: lon=$LON_DIFF, lat=$LAT_DIFF"
    if (( $(echo "$LON_DIFF < 0.1 && $LAT_DIFF < 0.1" | bc -l) )); then
        echo "    ✓ Round-trip is accurate"
    else
        echo "    ✗ Round-trip difference too large"
    fi
done
echo ""

echo "=== Verification complete ==="


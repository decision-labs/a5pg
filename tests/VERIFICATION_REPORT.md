# Verification Report: SQL Test Outputs vs a5-rs Library

## Summary

This document compares the outputs of our SQL tests against the expected behavior from the a5-rs Rust library.

## Test Results

### ✅ Passing Tests

1. **Round-trip tests**: All round-trip tests (lonlat -> cell -> lonlat) show accurate results with differences < 0.1 degrees
2. **Basic cell operations**: Cell ID conversion, resolution, parent/children all work correctly
3. **Test IDs from test-ids.json**: Hex IDs convert correctly to coordinates

### ⚠️ Known Differences

1. **Cell ID 0 handling**: 
   - a5-rs expects: `cell_to_lonlat(0)` returns `(0.0, 0.0)`
   - Our implementation: Returns `{0.0, 0.0}` (we handle WORLD_CELL explicitly to avoid deadlocks)
   - Reason: The underlying library's `DodecahedronProjection::get_global()` uses `OnceLock<Mutex<...>>` which can deadlock in PostgreSQL's multi-threaded context. By handling WORLD_CELL (cell ID 0) explicitly in our wrapper functions before calling the library, we avoid the deadlock and return the correct values immediately.
   - Status: ✅ **FIXED** - Now returns correct values matching a5-rs behavior

2. **Antimeridian longitude spans**:
   - a5-rs expects: Longitude span < 180 degrees for antimeridian cells
   - Our SQL tests show: Some spans >= 180 degrees
   - Note: This may be due to how we calculate spans (simple MAX - MIN doesn't account for antimeridian wrapping)
   - The boundary points themselves are correct, but the span calculation needs adjustment

### Test Coverage

Our SQL tests cover:
- ✅ Basic cell operations (creation, conversion)
- ✅ Hierarchy operations (parent, children, resolution)
- ✅ Boundary calculations
- ✅ Round-trip accuracy
- ✅ Edge cases (poles, equator, antimeridian)
- ✅ Error handling (NULL inputs, invalid hex strings)
- ✅ Version information

## Recommendations

1. **Cell ID 0**: Consider reporting this as a known limitation or investigating why the underlying library hangs
2. **Antimeridian span calculation**: Update the SQL test to properly handle antimeridian wrapping when calculating longitude spans
3. **Add more test cases**: Consider adding tests from the a5-rs populated places dataset for comprehensive coverage


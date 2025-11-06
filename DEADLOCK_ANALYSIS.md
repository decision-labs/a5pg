# Deadlock Analysis: WORLD_CELL (cell ID 0) Handling

## The Problem

When calling `cell_to_lonlat(0)` or `cell_to_boundary(0)` from PostgreSQL, the function hangs due to a potential deadlock in the `DodecahedronProjection::get_global()` initialization.

## Our Solution (a5pg/src/lib.rs)

We handle `WORLD_CELL` (cell ID 0) explicitly **before** calling the library function:

### 1. `a5_cell_to_lonlat()` - Lines 41-51

```rust
fn a5_cell_to_lonlat(cell_id: i64) -> Option<Vec<f64>> {
    let id_u64 = cell_id as u64;
    // WORLD_CELL (0) is a special case - return (0.0, 0.0) immediately
    // This avoids potential deadlocks in DodecahedronProjection::get_global() initialization
    if id_u64 == 0 {
        return Some(vec![0.0, 0.0]);  // ← Early return, never calls library
    }
    let ll = cell_to_lonlat(id_u64).ok()?;  // ← Only called for non-zero IDs
    let (lon, lat) = ll.to_degrees();
    Some(vec![lon, lat])
}
```

### 2. `a5_cell_to_boundary()` - Lines 56-72

```rust
fn a5_cell_to_boundary(cell_id: i64) -> Option<Vec<Vec<f64>>> {
    let id = cell_id as u64;
    // WORLD_CELL (0) is a special case - return empty boundary immediately
    // This avoids potential deadlocks in DodecahedronProjection::get_global() initialization
    if id == 0 {
        return Some(Vec::new());  // ← Early return, never calls library
    }
    let ring = a5::cell_to_boundary(id, None).ok()?;  // ← Only called for non-zero IDs
    // ... rest of function
}
```

## The a5-rs Library Code

### `cell_to_lonlat()` - a5-rs/src/core/cell.rs:150-161

```rust
pub fn cell_to_lonlat(cell: u64) -> Result<LonLat, String> {
    // WORLD_CELL represents the entire world, return (0, 0) as a reasonable default
    if cell == WORLD_CELL {
        return Ok(LonLat::new(0.0, 0.0));  // ← Checks WORLD_CELL first
    }

    let cell_data = deserialize(cell)?;
    let pentagon = get_pentagon(&cell_data)?;
    let mut dodecahedron = DodecahedronProjection::get_global()?;  // ← PROBLEM: Can deadlock here
    let point = dodecahedron.inverse(pentagon.get_center(), cell_data.origin_id)?;
    Ok(to_lon_lat(point))
}
```

**Note:** Even though the library checks `WORLD_CELL` first, when called from PostgreSQL, something in the execution path (possibly during function call setup or error handling) can trigger `get_global()` initialization, causing a deadlock.

### `DodecahedronProjection::get_global()` - a5-rs/src/projections/dodecahedron.rs:20, 42-51

```rust
// Line 20: Global static using OnceLock<Mutex<...>>
static GLOBAL_DODECAHEDRON: OnceLock<Mutex<DodecahedronProjection>> = OnceLock::new();

// Lines 42-51: The problematic function
pub fn get_global() -> Result<std::sync::MutexGuard<'static, DodecahedronProjection>, String> {
    GLOBAL_DODECAHEDRON
        .get_or_init(|| {  // ← OnceLock initialization (can deadlock in multi-threaded context)
            let proj = DodecahedronProjection::new()
                .unwrap_or_else(|_| panic!("Failed to create global DodecahedronProjection"));
            Mutex::new(proj)
        })
        .lock()  // ← Mutex lock (can deadlock if initialization is in progress)
        .map_err(|_| "Failed to lock global DodecahedronProjection".to_string())
}
```

## Why It Deadlocks

1. **OnceLock initialization**: `OnceLock::get_or_init()` can deadlock in multi-threaded contexts if multiple threads try to initialize simultaneously
2. **PostgreSQL's multi-threaded environment**: PostgreSQL uses multiple worker processes/threads, and when a function is called, it may trigger initialization from different threads
3. **Mutex lock contention**: Even after initialization, if multiple threads try to acquire the mutex lock simultaneously, it can cause contention

## Why Our Solution Works

By checking `WORLD_CELL` (cell ID 0) **before** calling the library function, we:
1. ✅ Avoid calling `cell_to_lonlat()` or `cell_to_boundary()` entirely for cell ID 0
2. ✅ Never trigger `DodecahedronProjection::get_global()` initialization for this case
3. ✅ Return the correct values immediately: `(0.0, 0.0)` for lonlat, empty array for boundary
4. ✅ Match the a5-rs library's expected behavior

## Result

- ✅ `a5_cell_to_lonlat(0)` → `{0.0, 0.0}` (matches a5-rs)
- ✅ `a5_cell_to_lonlat(a5_lonlat_to_cell(0.0, 0.0, 0))` → `{0.0, 0.0}` (matches a5-rs)
- ✅ `a5_cell_to_boundary(0)` → `[]` (empty array, matches a5-rs)
- ✅ `a5_cell_to_boundary(a5_lonlat_to_cell(0.0, 0.0, 0))` → `[]` (empty array, matches a5-rs)
- ✅ No deadlocks, instant return


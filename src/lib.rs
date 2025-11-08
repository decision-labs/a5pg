use pgrx::prelude::*;

use a5::{cell_to_lonlat, lonlat_to_cell, LonLat};

pgrx::pg_module_magic!();

#[pg_extern]
fn a5pg_version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

/// Returns version information for a5pg extension and a5 library as JSONB.
#[pg_extern]
fn a5pg_info() -> pgrx::JsonB {
    pgrx::JsonB(serde_json::json!({
        "a5pg_version": env!("CARGO_PKG_VERSION"),
        "a5_version": "0.6.1"
    }))
}

/// lon/lat -> A5 cell id as BIGINT (signed i64). Errors if id > i64::MAX.
#[pg_extern]
fn a5_lonlat_to_cell(lon: f64, lat: f64, resolution: i32) -> i64 {
    let ll = LonLat::new(lon, lat);
    let id_u64 = match lonlat_to_cell(ll, resolution) {
        Ok(id) => id,
        Err(e) => pgrx::error!("{e}"),
    };
    if id_u64 > i64::MAX as u64 {
        pgrx::error!(
            "A5 cell id {} does not fit into BIGINT (signed 64-bit)",
            id_u64
        );
    }
    id_u64 as i64
}

/// reverse: cell id (BIGINT) -> [lon, lat] as double precision array.
#[pg_extern]
fn a5_cell_to_lonlat(cell_id: i64) -> Option<Vec<f64>> {
    let id_u64 = cell_id as u64;
    let ll = cell_to_lonlat(id_u64).ok()?;
    let (lon, lat) = ll.to_degrees();
    Some(vec![lon, lat])
}

/// Boundary of a cell id (BIGINT) as array of [lon, lat] coordinate pairs.
/// Returns double precision[][] where each inner array is [lon, lat].
/// Uses default options: closed_ring=true, segments=auto.
#[pg_extern]
fn a5_cell_to_boundary(cell_id: i64) -> Option<Vec<Vec<f64>>> {
    a5_cell_to_boundary_with_options(cell_id, true, None)
}

/// Boundary of a cell id with closed_ring option.
/// closed_ring: if true, closes the ring by repeating the first point at the end.
#[pg_extern(name = "a5_cell_to_boundary")]
fn a5_cell_to_boundary_closed_ring(cell_id: i64, closed_ring: bool) -> Option<Vec<Vec<f64>>> {
    a5_cell_to_boundary_with_options(cell_id, closed_ring, None)
}

/// Boundary of a cell id with closed_ring and segments options.
/// closed_ring: if true, closes the ring by repeating the first point at the end.
/// segments: number of segments per edge (if <= 0, uses resolution-appropriate value).
#[pg_extern(name = "a5_cell_to_boundary")]
fn a5_cell_to_boundary_full(cell_id: i64, closed_ring: bool, segments: i32) -> Option<Vec<Vec<f64>>> {
    a5_cell_to_boundary_with_options(cell_id, closed_ring, Some(segments))
}

/// Internal helper function that constructs CellToBoundaryOptions and calls the a5 library.
fn a5_cell_to_boundary_with_options(
    cell_id: i64,
    closed_ring: bool,
    segments: Option<i32>,
) -> Option<Vec<Vec<f64>>> {
    let id = cell_id as u64;
    
    // Construct options manually since CellToBoundaryOptions is not exported
    // We need to use the internal API or construct via Option
    // Since we can't access CellToBoundaryOptions directly, we'll use a workaround:
    // Call with None and handle closed_ring manually, or use the internal module
    
    // For now, let's use the a5::core::cell module directly
    use a5::core::cell::{cell_to_boundary as a5_cell_to_boundary_internal, CellToBoundaryOptions};
    
    let options = CellToBoundaryOptions {
        closed_ring,
        segments: segments.filter(|&s| s > 0),
    };
    
    let ring = a5_cell_to_boundary_internal(id, Some(options)).ok()?;
    Some(
        ring.into_iter()
            .map(|p| {
                let (lon, lat) = p.to_degrees();
                vec![lon, lat]
            })
            .collect(),
    )
}

// 1) Resolution: get_resolution returns i32 directly (not a Result)
#[pg_extern]
fn a5_get_resolution(cell_id: i64) -> i32 {
    let id = cell_id as u64;
    a5::get_resolution(id)
}

// 2) Parent: second arg is Option<i32>
#[pg_extern]
fn a5_cell_to_parent(cell_id: i64, target_resolution: i32) -> i64 {
    let id = cell_id as u64;
    match a5::cell_to_parent(id, Some(target_resolution)) {
        Ok(parent) => {
            let Ok(as_i64) = i64::try_from(parent) else {
                pgrx::error!("parent id does not fit into BIGINT");
            };
            as_i64
        }
        Err(e) => pgrx::error!("{e}"),
    }
}

// 3) Children: second arg is Option<i32>
#[pg_extern]
fn a5_cell_to_children(cell_id: i64, target_resolution: i32) -> Vec<i64> {
    let id = cell_id as u64;
    match a5::cell_to_children(id, Some(target_resolution)) {
        Ok(children) => children
            .into_iter()
            .map(|c| {
                let Ok(as_i64) = i64::try_from(c) else {
                    pgrx::error!("child id does not fit into BIGINT");
                };
                as_i64
            })
            .collect(),
        Err(e) => pgrx::error!("{e}"),
    }
}

use pgrx::prelude::extension_sql;

//
// POSTGIS WRAPPER (optional – only installed if PostGIS / geometry exists)
//
extension_sql!(
    r#"
DO $wrapper$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'geometry') THEN
    EXECUTE '
      CREATE OR REPLACE FUNCTION a5_point_to_cell(geom geometry, res int)
      RETURNS bigint
      LANGUAGE sql
      IMMUTABLE
      PARALLEL SAFE
      STRICT
      AS $f$
        SELECT a5_lonlat_to_cell(ST_X(geom), ST_Y(geom), res);
      $f$;
    ';
  END IF;
END;
$wrapper$;
"#,
    name = "a5_postgis_wrapper",
);

//
// NUMERIC OVERLOAD (allows calling a5_lonlat_to_cell(-73.9, 40.7, 10) without casts)
//
extension_sql!(
    r#"
CREATE OR REPLACE FUNCTION a5_lonlat_to_cell(lon numeric, lat numeric, res int)
RETURNS bigint
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
STRICT
AS $$
  SELECT a5_lonlat_to_cell(lon::double precision, lat::double precision, res);
$$;
"#,
    name = "a5_numeric_overload",
);

// ---------- Tests ----------
#[cfg(any(test, feature = "pg_test"))]
#[pgrx::pg_schema] // sets up a per-test schema when running pgrx tests
mod tests {
    use super::*;

    #[pg_test]
    fn a5pg_roundtrip_lonlat() {
        let id = a5_lonlat_to_cell(-73.9857_f64, 40.7580_f64, 10);
        let center = a5_cell_to_lonlat(id).expect("center coordinates");
        let lon = center[0];
        let lat = center[1];
        assert!(lon < -73.90 && lon > -74.05, "lon {}", lon);
        assert!(lat > 40.70 && lat < 40.80, "lat {}", lat);
    }

    #[pg_test]
    fn a5pg_parent_children_counts() {
        let id = a5_lonlat_to_cell(-73.9857, 40.7580, 10);
        assert_eq!(a5_get_resolution(id), 10);
        let parent = a5_cell_to_parent(id, 8);
        assert_eq!(a5_get_resolution(parent), 8);
        let kids = a5_cell_to_children(id, 12);
        assert_eq!(kids.len(), 16); // 4^(12-10)
    }

    #[pg_test]
    fn a5pg_boundary_is_polygon() {
        let id = a5_lonlat_to_cell(-73.9857, 40.7580, 10);
        let boundary = a5_cell_to_boundary(id).expect("boundary coordinates");
        assert!(!boundary.is_empty(), "boundary should not be empty");
        assert!(boundary.len() > 3, "boundary should have at least 3 points");
        // Verify each point is [lon, lat]
        for point in &boundary {
            assert_eq!(point.len(), 2, "each boundary point should be [lon, lat]");
        }
    }

    #[pg_test]
    fn a5pg_info_returns_version() {
        let info = a5pg_info();
        let v: &serde_json::Value = &info.0;

        // Verify both version fields exist
        assert!(
            v.get("a5pg_version").is_some(),
            "a5pg_version should be present"
        );
        assert!(
            v.get("a5_version").is_some(),
            "a5_version should be present"
        );

        // Verify a5pg_version matches CARGO_PKG_VERSION
        let a5pg_version = v.get("a5pg_version").and_then(|x| x.as_str()).unwrap();
        assert_eq!(a5pg_version, env!("CARGO_PKG_VERSION"));

        // Verify a5_version is "0.6.1"
        let a5_version = v.get("a5_version").and_then(|x| x.as_str()).unwrap();
        assert_eq!(a5_version, "0.6.1");

        // Print the info for visibility
        eprintln!(
            "a5pg_info() output: {}",
            serde_json::to_string_pretty(v).unwrap()
        );
    }
}

/// This module is required by `cargo pgrx test` invocations and must be at crate root.
#[cfg(test)]
pub mod pg_test {
    pub fn setup(_options: Vec<&str>) {
        // perform one-off initialization when the pg_test framework starts
    }

    #[must_use]
    pub fn postgresql_conf_options() -> Vec<&'static str> {
        // Set valid locale settings for macOS compatibility
        vec![
            "lc_messages='en_US.UTF-8'",
            "lc_monetary='en_US.UTF-8'",
            "lc_numeric='en_US.UTF-8'",
            "lc_time='en_US.UTF-8'",
        ]
    }
}

use pgrx::prelude::*;
use serde_json;

use a5::{cell_to_boundary, cell_to_lonlat, hex_to_u64, lonlat_to_cell, u64_to_hex, LonLat};

pgrx::pg_module_magic!();

#[pg_extern]
fn hello_a5pg() -> &'static str {
    "Hello, a5pg"
}

/// lon/lat in degrees + resolution -> A5 cell id as hex text (e.g. "0x01ab...").
#[pg_extern]
fn a5_lonlat_to_cell(lon: f64, lat: f64, resolution: i32) -> String {
    let ll = LonLat::new(lon, lat);
    match lonlat_to_cell(ll, resolution) {
        Ok(id) => u64_to_hex(id),
        Err(e) => pgrx::error!("{e}"),
    }
}

/// Reverse: hex id -> {"lon": ..., "lat": ...} (center) as JSONB.
#[pg_extern]
fn a5_cell_to_lonlat_json(cell_hex: &str) -> Option<pgrx::JsonB> {
    let id = hex_to_u64(cell_hex).ok()?;
    let ll = cell_to_lonlat(id).ok()?;
    let (lon, lat) = ll.to_degrees();
    Some(pgrx::JsonB(serde_json::json!({ "lon": lon, "lat": lat })))
}

/// Boundary of a cell as GeoJSON Polygon (lon/lat WGS84).
#[pg_extern]
fn a5_cell_boundary_geojson(cell_hex: &str) -> Option<String> {
    let id = hex_to_u64(cell_hex).ok()?;
    let ring = cell_to_boundary(id, None).ok()?; // Vec<LonLat>
    let coords: Vec<[f64; 2]> = ring
        .into_iter()
        .map(|p| {
            let (lon, lat) = p.to_degrees();
            [lon, lat]
        })
        .collect();
    let gj = serde_json::json!({
        "type": "Polygon",
        "coordinates": [coords]
    });
    Some(gj.to_string())
}

/// lon/lat -> A5 cell id as BIGINT (signed i64). Errors if id > i64::MAX.
#[pg_extern]
fn a5_lonlat_to_cell_id(lon: f64, lat: f64, resolution: i32) -> i64 {
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

/// reverse: cell id (BIGINT) -> {"lon":..., "lat":...}
#[pg_extern]
fn a5_cell_id_to_lonlat_json(cell_id: i64) -> Option<pgrx::JsonB> {
    let id_u64 = cell_id as u64;
    let ll = cell_to_lonlat(id_u64).ok()?;
    let (lon, lat) = ll.to_degrees();
    Some(pgrx::JsonB(serde_json::json!({ "lon": lon, "lat": lat })))
}

// 1) Resolution: get_resolution returns i32 directly (not a Result)
#[pg_extern]
fn a5_cell_resolution(cell_id: i64) -> i32 {
    let id = cell_id as u64;
    a5::get_resolution(id)
}

// 2) Parent: second arg is Option<i32>
#[pg_extern]
fn a5_cell_parent_id(cell_id: i64, target_resolution: i32) -> i64 {
    let id = cell_id as u64;
    match a5::cell_to_parent(id, Some(target_resolution)) {
        Ok(parent) => {
            if parent > i64::MAX as u64 {
                pgrx::error!("parent id does not fit into BIGINT");
            }
            parent as i64
        }
        Err(e) => pgrx::error!("{e}"),
    }
}

// 3) Children: second arg is Option<i32>
#[pg_extern]
fn a5_cell_children_ids(cell_id: i64, target_resolution: i32) -> Vec<i64> {
    let id = cell_id as u64;
    match a5::cell_to_children(id, Some(target_resolution)) {
        Ok(children) => children
            .into_iter()
            .map(|c| {
                if c > i64::MAX as u64 {
                    pgrx::error!("child id does not fit into BIGINT");
                }
                c as i64
            })
            .collect(),
        Err(e) => pgrx::error!("{e}"),
    }
}

/// Boundary of a cell id (BIGINT) as GeoJSON Polygon.
#[pg_extern]
fn a5_cell_id_boundary_geojson(cell_id: i64) -> Option<String> {
    let id = cell_id as u64;
    let ring = a5::cell_to_boundary(id, None).ok()?; // Vec<LonLat>
    let coords: Vec<[f64; 2]> = ring
        .into_iter()
        .map(|p| {
            let (lon, lat) = p.to_degrees();
            [lon, lat]
        })
        .collect();
    let gj = serde_json::json!({
        "type": "Polygon",
        "coordinates": [coords]
    });
    Some(gj.to_string())
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
      CREATE OR REPLACE FUNCTION a5_point_to_cell_id(geom geometry, res int)
      RETURNS bigint
      LANGUAGE sql
      IMMUTABLE
      PARALLEL SAFE
      STRICT
      AS $f$
        SELECT a5_lonlat_to_cell_id(ST_X(geom), ST_Y(geom), res);
      $f$;
    ';
  END IF;
END;
$wrapper$;
"#,
    name = "a5_postgis_wrapper",
);

//
// NUMERIC OVERLOAD (allows calling a5_lonlat_to_cell_id(-73.9, 40.7, 10) without casts)
//
extension_sql!(
    r#"
CREATE OR REPLACE FUNCTION a5_lonlat_to_cell_id(lon numeric, lat numeric, res int)
RETURNS bigint
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
STRICT
AS $$
  SELECT a5_lonlat_to_cell_id(lon::double precision, lat::double precision, res);
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
    fn a5pg_smoke_hello() {
        assert_eq!(hello_a5pg(), "Hello, a5pg");
    }

    #[pg_test]
    fn a5pg_roundtrip_lonlat() {
        let id = a5_lonlat_to_cell_id(-73.9857_f64, 40.7580_f64, 10);
        let center = a5_cell_id_to_lonlat_json(id).expect("center json");
        let v: &serde_json::Value = &center.0;
        let lon = v.get("lon").and_then(|x| x.as_f64()).unwrap();
        let lat = v.get("lat").and_then(|x| x.as_f64()).unwrap();
        assert!(lon < -73.90 && lon > -74.05, "lon {}", lon);
        assert!(lat > 40.70 && lat < 40.80, "lat {}", lat);
    }

    #[pg_test]
    fn a5pg_parent_children_counts() {
        let id = a5_lonlat_to_cell_id(-73.9857, 40.7580, 10);
        assert_eq!(a5_cell_resolution(id), 10);
        let parent = a5_cell_parent_id(id, 8);
        assert_eq!(a5_cell_resolution(parent), 8);
        let kids = a5_cell_children_ids(id, 12);
        assert_eq!(kids.len(), 16); // 4^(12-10)
    }

    #[pg_test]
    fn a5pg_boundary_is_polygon() {
        let id = a5_lonlat_to_cell_id(-73.9857, 40.7580, 10);
        let gj = a5_cell_id_boundary_geojson(id).expect("geojson");
        let v: serde_json::Value = serde_json::from_str(&gj).expect("parse geojson");
        assert_eq!(v.get("type").and_then(|x| x.as_str()), Some("Polygon"));
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
        // return any postgresql.conf settings that are required for your tests
        vec![]
    }
}

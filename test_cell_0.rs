fn main() {
    use a5::{cell_to_lonlat, hex_to_u64};
    
    // Test what hex '0' converts to
    match hex_to_u64("0") {
        Ok(id) => {
            println!("hex '0' converts to: {}", id);
            match cell_to_lonlat(id) {
                Ok(ll) => {
                    println!("cell_to_lonlat({}) = ({}, {})", id, ll.longitude(), ll.latitude());
                }
                Err(e) => {
                    println!("cell_to_lonlat({}) error: {}", id, e);
                }
            }
        }
        Err(e) => {
            println!("hex_to_u64('0') error: {}", e);
        }
    }
    
    // Test cell ID 0 directly
    match cell_to_lonlat(0) {
        Ok(ll) => {
            println!("cell_to_lonlat(0) = ({}, {})", ll.longitude(), ll.latitude());
        }
        Err(e) => {
            println!("cell_to_lonlat(0) error: {}", e);
        }
    }
}


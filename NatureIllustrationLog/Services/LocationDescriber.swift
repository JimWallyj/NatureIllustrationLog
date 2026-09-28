import CoreLocation
import MapKit

/// Turns a coordinate into a short, human-readable place name (e.g.
/// "Sedona, AZ") for display under the map on the File Screen. This is a
/// one-off reverse geocode of a fixed coordinate and does not require the
/// user's own location permission.
func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
    let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }
        guard let mapItem = try? await request.mapItems.first else {
            return nil
        }
        return mapItem.addressRepresentations?.cityWithContext
    }

import CoreLocation
import MapKit

/// Turns a coordinate into a short, human-readable place name (e.g.
/// "Sedona, AZ") for display under the map. Uses MapKit's reverse geocoding
/// (CLGeocoder is deprecated as of iOS 26). Needs a network connection.
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

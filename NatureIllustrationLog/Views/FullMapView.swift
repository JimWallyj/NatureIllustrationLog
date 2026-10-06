import CoreLocation
import MapKit
import SwiftUI

/// Full-screen, read-only view of a pinned location. Map/Satellite toggle
/// only — no tap-to-move, since the pin isn't editable from here.
struct FullMapView: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var useSatellite = false

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(
                MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            )) {
                Marker(title, coordinate: coordinate)
                    .tint(.red)
            }
            .mapStyle(
                useSatellite
                    ? MapStyle.hybrid(elevation: .realistic)
                    : MapStyle.standard(elevation: .realistic)
            )
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .safeAreaInset(edge: .bottom) {
                Picker("Map Style", selection: $useSatellite) {
                    Text("Map").tag(false)
                    Text("Satellite").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(.regularMaterial)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

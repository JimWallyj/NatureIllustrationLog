import CoreLocation
import MapKit
import SwiftUI

/// Asks for "When In Use" location access so the map can show where the
/// device currently is. Held in @State by the view so the system prompt
/// isn't torn down while it's showing.
@MainActor
final class LocationAuthorizer {
    private let manager = CLLocationManager()

    func requestIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
}

/// Full-screen map where the user drops a pin on the spot where the photo
/// was taken. Opens on the existing pin if there is one, otherwise on the
/// device's current location (if access is granted). Supports pinch-zoom,
/// a Map/Satellite toggle, and a place search to jump somewhere else.
/// Terrain is drawn with realistic elevation in both styles.
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onDone: (CLLocationCoordinate2D) -> Void

    @State private var position: MapCameraPosition
    @State private var selection: CLLocationCoordinate2D?
    @State private var useSatellite = false
    @State private var authorizer = LocationAuthorizer()
    @State private var searchText = ""
    @State private var searchMessage: String?
    @State private var visibleRegion: MKCoordinateRegion?

    init(initialCoordinate: CLLocationCoordinate2D?, onDone: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onDone = onDone
        _selection = State(initialValue: initialCoordinate)
        if let initialCoordinate {
            _position = State(initialValue: .region(
                MKCoordinateRegion(
                    center: initialCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            ))
        } else {
            _position = State(initialValue: .userLocation(fallback: .automatic))
        }
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()
                    if let selection {
                        Marker("Photo Location", coordinate: selection)
                            .tint(.red)
                    }
                }
                .mapStyle(
                    useSatellite
                        ? MapStyle.hybrid(elevation: .realistic)
                        : MapStyle.standard(elevation: .realistic)
                )
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleRegion = context.region
                }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) {
                        selection = coordinate
                    }
                }
            }
            .onChange(of: searchText) {
                searchMessage = nil
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Picker("Map Style", selection: $useSatellite) {
                        Text("Map").tag(false)
                        Text("Satellite").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if let searchMessage {
                        Text(searchMessage)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }

                    Group {
                        if selection == nil {
                            Text("Pinch to zoom, then tap the map to drop a pin on the photo location.")
                        } else {
                            Text("Tap the map again to move the pin.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding()
                .background(.regularMaterial)
            }
            // The app draws its own top bar (title, Cancel, Done, search) on a
            // solid backing that matches the bottom strip, so the controls stay
            // readable over any map or satellite view on both iPhone and Mac.
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                topBar
            }
            .onAppear {
                authorizer.requestIfNeeded()
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            ZStack {
                Text("Photo Location")
                    .font(.headline)
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Done") {
                        if let selection {
                            onDone(selection)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)   // solid blue: the main action
                    .disabled(selection == nil)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search for a place", text: $searchText)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await search() }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    /// Looks up the typed place name (biased toward the area currently on
    /// screen) and moves the map to the top result. It doesn't drop a pin —
    /// the user still taps to place it exactly.
    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let visibleRegion {
            request.region = visibleRegion
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            if let item = response.mapItems.first {
                searchMessage = nil
                position = .region(
                    MKCoordinateRegion(
                        center: item.location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            } else {
                searchMessage = String(localized: "No places found for \"\(query)\".")
            }
        } catch {
            searchMessage = String(localized: "Search failed. Check your connection and try again.")
        }
    }
}

extension View {
    /// Opens the map picker as a sheet on iPhone/iPad. On the Mac it fills the
    /// whole app window, so it grows and shrinks as the window is resized
    /// (or goes full screen with the window's green button).
    @ViewBuilder
    func locationPickerCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if targetEnvironment(macCatalyst)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}

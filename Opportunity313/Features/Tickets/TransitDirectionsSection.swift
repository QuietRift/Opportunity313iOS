import SwiftUI
import CoreLocation
import Combine

@MainActor
private final class TransitOrigin: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var message: String?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: message = "Location is off. Enter a starting address below, or allow location in Settings."
        @unknown default: message = "Enter a starting address below."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        coordinate = last.coordinate
        message = "Starting from your current location. Refresh to update the route."
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        message = "Could not find your location. Enter a starting address below."
    }
}

struct TransitDirectionsSection: View {
    let destination: String
    let venueName: String
    @StateObject private var origin = TransitOrigin()
    @State private var startingAddress = ""
    @Environment(\.openURL) private var openURL

    private var usableDestination: String {
        let address = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? venueName : address
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bus Routes to This Event", systemImage: "bus.fill")
                .font(.headline)
            Text("Destination: \(usableDestination)").font(.subheadline)
            TextField("Starting address (optional)", text: $startingAddress)
                .textContentType(.fullStreetAddress)
                .textInputAutocapitalization(.words)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            Button {
                origin.refresh()
            } label: { Label("Use or Refresh My Location", systemImage: "location") }
            if let message = origin.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            Button {
                var components = URLComponents(string: "https://maps.apple.com/")!
                var items = [URLQueryItem(name: "daddr", value: usableDestination),
                             URLQueryItem(name: "dirflg", value: "r")]
                let entered = startingAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                if !entered.isEmpty {
                    items.append(URLQueryItem(name: "saddr", value: entered))
                } else if let coordinate = origin.coordinate {
                    items.append(URLQueryItem(name: "saddr", value: "\(coordinate.latitude),\(coordinate.longitude)"))
                }
                components.queryItems = items
                if let url = components.url { openURL(url) }
            } label: { Label("View Bus Routes & Transfers", systemImage: "arrow.triangle.turn.up.right.diamond") }
                .buttonStyle(.borderedProminent)
            Text("Apple Maps shows available transit lines, transfers, walking legs and travel times. Refresh your location to recalculate before you leave.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

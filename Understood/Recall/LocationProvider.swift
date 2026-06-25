import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isResolving = false
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<String?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentPlaceName() async -> String? {
        if continuation != nil { return nil }
        isResolving = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else {
            Task { @MainActor in self.finish(nil) }
            return
        }
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            let placemark = placemarks?.first
            let name = [placemark?.name, placemark?.subLocality, placemark?.locality].compactMap { $0 }.first
            Task { @MainActor in self.finish(name) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    private func finish(_ value: String?) {
        isResolving = false
        continuation?.resume(returning: value)
        continuation = nil
    }
}

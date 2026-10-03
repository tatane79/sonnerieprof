import Combine
import CoreLocation
import Foundation

@MainActor
/// Encapsule Core Location et ne demande une autorisation qu'après une action explicite.
final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization = .reducedAccuracy
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private let temporaryAccuracyPurposeKey = "SiteDetection"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
    }

    /// Actualise la position sans jamais afficher de demande d'autorisation.
    /// Cette méthode est utilisée au lancement si l'autorisation existe déjà.
    func refreshLocationIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestBestAvailableLocation()
        default:
            break
        }
    }

    /// Action explicite de l'utilisateur pouvant afficher la demande système.
    func requestCurrentLocation() {
        errorMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestBestAvailableLocation()
        case .denied, .restricted:
            errorMessage = L("location.permission_denied")
        @unknown default:
            errorMessage = L("location.unknown_status")
        }
    }

    func bestMatchingSite(in sites: [BellSite]) -> BellSite? {
        guard let location else { return nil }

        // Évite une sélection automatique si iOS ne fournit qu'une position imprécise.
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 250 else {
            return nil
        }

        let candidates = sites.compactMap { site -> (BellSite, CLLocationDistance)? in
            guard site.latitude != 0 || site.longitude != 0 else { return nil }
            let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
            return (site, location.distance(from: siteLocation))
        }

        guard let nearest = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        return nearest.1 <= nearest.0.detectionRadiusMeters ? nearest.0 : nil
    }

    private func requestBestAvailableLocation() {
        accuracyAuthorization = manager.accuracyAuthorization

        guard manager.accuracyAuthorization == .reducedAccuracy else {
            manager.requestLocation()
            return
        }

        manager.requestTemporaryFullAccuracyAuthorization(
            withPurposeKey: temporaryAccuracyPurposeKey
        ) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.accuracyAuthorization = self.manager.accuracyAuthorization

                if let error {
                    self.errorMessage = L("location.precise_unavailable", error.localizedDescription)
                }

                self.manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization

        if manager.authorizationStatus == .authorizedAlways ||
            manager.authorizationStatus == .authorizedWhenInUse {
            requestBestAvailableLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        accuracyAuthorization = manager.accuracyAuthorization
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}

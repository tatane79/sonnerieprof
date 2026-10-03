import Foundation

/// Couche de persistance des établissements dans l'App Group partagé.
struct SiteRepository {

    private enum Key {
        // La clé v2 est conservée pour ne pas perdre les sites des installations existantes.
        static let sites = "sites.v2"
        static let selectedSiteID = "selectedSiteID.v2"
        static let scheduleSuspendedUntil = "scheduleSuspendedUntil.v1"
        static let scheduleSuspensionStartsAt = "scheduleSuspensionStartsAt.v1"
    }

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)
    ) {
        self.defaults = defaults ?? .standard
    }

    func loadSites() -> [BellSite] {
        guard let data = defaults.data(forKey: Key.sites),
              let sites = try? JSONDecoder().decode([BellSite].self, from: data) else {
            // Au premier lancement commercial, aucun établissement n'est présumé.
            // Les utilisateurs existants retrouvent les données déjà stockées en v2.
            return []
        }

        return sites
    }

    func saveSites(_ sites: [BellSite]) {
        guard let data = try? JSONEncoder().encode(sites) else { return }
        defaults.set(data, forKey: Key.sites)
    }

    func selectedSiteID() -> UUID? {
        guard let string = defaults.string(forKey: Key.selectedSiteID) else {
            return nil
        }
        return UUID(uuidString: string)
    }

    func setSelectedSiteID(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: Key.selectedSiteID)
    }

    func scheduleSuspendedUntil() -> Date? {
        defaults.object(forKey: Key.scheduleSuspendedUntil) as? Date
    }

    func setScheduleSuspendedUntil(_ date: Date?) {
        if let date {
            defaults.set(date, forKey: Key.scheduleSuspendedUntil)
        } else {
            defaults.removeObject(forKey: Key.scheduleSuspendedUntil)
        }
    }

    func scheduleSuspensionStartsAt() -> Date? {
        defaults.object(forKey: Key.scheduleSuspensionStartsAt) as? Date
    }

    func setScheduleSuspensionStartsAt(_ date: Date?) {
        if let date {
            defaults.set(date, forKey: Key.scheduleSuspensionStartsAt)
        } else {
            defaults.removeObject(forKey: Key.scheduleSuspensionStartsAt)
        }
    }

    func activeSite() -> BellSite? {
        let sites = loadSites()

        if let id = selectedSiteID(),
           let selected = sites.first(where: { $0.id == id }) {
            return selected
        }

        return sites.first
    }
}

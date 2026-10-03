import Combine
import Foundation

@MainActor
/// Source de vérité des établissements pour l'interface principale.
/// Chaque mutation est persistée immédiatement.
final class SiteStore: ObservableObject {

    static let maximumSiteCount = 4

    @Published var sites: [BellSite]
    @Published var selectedSiteID: UUID?
    @Published var scheduleSuspensionStartsAt: Date?
    @Published var scheduleSuspendedUntil: Date?

    private let repository = SiteRepository()

    init() {
        let loaded = repository.loadSites()
        self.sites = loaded
        self.selectedSiteID = repository.selectedSiteID() ?? loaded.first?.id

        let storedSuspension = repository.scheduleSuspendedUntil()
        if let storedSuspension, storedSuspension > Date.now {
            self.scheduleSuspensionStartsAt =
                repository.scheduleSuspensionStartsAt() ?? .distantPast
            self.scheduleSuspendedUntil = storedSuspension
        } else {
            self.scheduleSuspensionStartsAt = nil
            self.scheduleSuspendedUntil = nil
        }

        if let selectedSiteID,
           !loaded.contains(where: { $0.id == selectedSiteID }) {
            self.selectedSiteID = loaded.first?.id
        }

        persist()
    }

    var selectedSite: BellSite? {
        if let selectedSiteID,
           let selected = sites.first(where: { $0.id == selectedSiteID }) {
            return selected
        }
        return sites.first
    }

    var canAddSite: Bool {
        sites.count < Self.maximumSiteCount
    }

    var remainingSiteSlots: Int {
        max(0, Self.maximumSiteCount - sites.count)
    }

    var hasScheduledSuspension: Bool {
        guard let until = scheduleSuspendedUntil else { return false }
        return until > Date.now
    }

    var isScheduleSuspended: Bool {
        isScheduleSuspended(at: .now)
    }

    var isScheduleSuspensionPending: Bool {
        guard let startsAt = scheduleSuspensionStartsAt,
              let until = scheduleSuspendedUntil else {
            return false
        }
        return startsAt > Date.now && until > startsAt
    }

    var activeScheduleSuspendedUntil: Date? {
        isScheduleSuspended ? scheduleSuspendedUntil : nil
    }

    func isScheduleSuspended(at date: Date) -> Bool {
        guard let startsAt = scheduleSuspensionStartsAt,
              let until = scheduleSuspendedUntil else {
            return false
        }
        return startsAt <= date && date < until
    }

    func select(_ site: BellSite) {
        selectedSiteID = site.id
        persist()
    }

    func update(_ site: BellSite) {
        var normalizedSite = site
        normalizedSite.name = site.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = sites.firstIndex(where: { $0.id == normalizedSite.id }) {
            sites[index] = normalizedSite
        } else {
            guard canAddSite else { return }
            sites.append(normalizedSite)

            if selectedSiteID == nil {
                selectedSiteID = normalizedSite.id
            }
        }

        persist()
    }

    func delete(_ site: BellSite) {
        sites.removeAll { $0.id == site.id }

        if selectedSiteID == site.id {
            selectedSiteID = sites.first?.id
        }

        persist()
    }

    func restore(sites restoredSites: [BellSite], selectedSiteID: UUID?) {
        sites = Array(restoredSites.prefix(Self.maximumSiteCount))
        self.selectedSiteID = selectedSiteID.flatMap { id in
            sites.contains(where: { $0.id == id }) ? id : nil
        } ?? sites.first?.id
        persist()
    }

    func suspendSchedule(from startDate: Date = .now, until endDate: Date) {
        let normalizedEnd = Calendar.current.startOfDay(for: endDate)
        guard normalizedEnd > startDate else { return }

        scheduleSuspensionStartsAt = startDate
        scheduleSuspendedUntil = normalizedEnd
        persist()
    }

    func updateSuspensionEnd(_ date: Date) {
        guard let startsAt = scheduleSuspensionStartsAt else { return }
        suspendSchedule(from: startsAt, until: date)
    }

    func resumeSchedule() {
        scheduleSuspensionStartsAt = nil
        scheduleSuspendedUntil = nil
        persist()
    }

    func clearExpiredSuspension(at date: Date = .now) {
        guard let until = scheduleSuspendedUntil, until <= date else { return }
        resumeSchedule()
    }

    func persist() {
        repository.saveSites(sites)
        repository.setSelectedSiteID(selectedSiteID)
        repository.setScheduleSuspensionStartsAt(scheduleSuspensionStartsAt)
        repository.setScheduleSuspendedUntil(scheduleSuspendedUntil)
    }
}

import Foundation
import Observation

@MainActor
@Observable
/// Source de vérité observable de l'emploi du temps et de l'alternance des semaines.
final class TimetableStore {
    var sessions: [CourseSession] {
        didSet {
            sortSessions()
            repository.saveSessions(sessions)
        }
    }

    private(set) var sortedSessions: [CourseSession]
    var referenceWeekStart: Date
    var referenceWeek: TeachingWeek
    private(set) var q1Name: String
    private(set) var q2Name: String

    private let repository: TimetableRepository
    private let engine: TimetableEngine

    init(
        repository: TimetableRepository = TimetableRepository(),
        engine: TimetableEngine = TimetableEngine()
    ) {
        self.repository = repository
        self.engine = engine

        let loaded = repository.loadSessions()
        self.sessions = loaded
        self.sortedSessions = loaded.sorted(by: Self.sessionOrder)
        self.referenceWeekStart = repository.referenceWeekStart()
            ?? engine.startOfWeek(containing: .now)
        self.referenceWeek = repository.referenceWeek()
        self.q1Name = repository.weekName(for: .q1)
        self.q2Name = repository.weekName(for: .q2)
    }

    func save(_ session: CourseSession) {
        var normalized = session
        normalized.className = session.className.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.roomName = session.roomName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = sessions.firstIndex(where: { $0.id == normalized.id }) {
            sessions[index] = normalized
        } else {
            sessions.append(normalized)
        }
    }

    func delete(_ session: CourseSession) {
        sessions.removeAll { $0.id == session.id }
    }

    var displayedCurrentWeek: TeachingWeek {
        get { currentWeek() }
        set { setCurrentWeek(newValue) }
    }

    /// Recale l'alternance : la semaine contenant `date` devient la semaine indiquée.
    func setCurrentWeek(_ week: TeachingWeek, at date: Date = .now) {
        referenceWeek = week
        referenceWeekStart = engine.startOfWeek(containing: date)
        repository.setReferenceWeek(week)
        repository.setReferenceWeekStart(referenceWeekStart)
    }

    func currentWeek(at date: Date = .now) -> TeachingWeek {
        engine.teachingWeek(
            on: date,
            referenceWeekStart: referenceWeekStart,
            referenceWeek: referenceWeek
        )
    }

    func weekName(for week: TeachingWeek) -> String {
        let name = week == .q1 ? q1Name : q2Name
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? (week == .q1 ? "Q1" : "Q2") : normalized
    }

    func setWeekName(_ name: String, for week: TeachingWeek) {
        if week == .q1 {
            q1Name = name
        } else {
            q2Name = name
        }

        repository.setWeekName(name, for: week)
    }

    func makeBackup(sites: [BellSite], selectedSiteID: UUID?) -> TimetableBackup {
        TimetableBackup(
            version: TimetableBackup.currentVersion,
            savedAt: .now,
            sessions: sessions,
            referenceWeekStart: referenceWeekStart,
            referenceWeek: referenceWeek,
            q1Name: q1Name,
            q2Name: q2Name,
            sites: sites,
            selectedSiteID: selectedSiteID
        )
    }

    func restore(_ backup: TimetableBackup) {
        sessions = backup.sessions
        referenceWeekStart = backup.referenceWeekStart
        referenceWeek = backup.referenceWeek
        q1Name = backup.q1Name
        q2Name = backup.q2Name
        repository.setReferenceWeekStart(referenceWeekStart)
        repository.setReferenceWeek(referenceWeek)
        repository.setWeekName(q1Name, for: .q1)
        repository.setWeekName(q2Name, for: .q2)
    }

    private func sortSessions() {
        sortedSessions = sessions.sorted(by: Self.sessionOrder)
    }

    private static func sessionOrder(_ lhs: CourseSession, _ rhs: CourseSession) -> Bool {
        if lhs.weekday != rhs.weekday {
            return lhs.weekday < rhs.weekday
        }
        if lhs.startMinutes != rhs.startMinutes {
            return lhs.startMinutes < rhs.startMinutes
        }
        return lhs.className.localizedCaseInsensitiveCompare(rhs.className) == .orderedAscending
    }
}

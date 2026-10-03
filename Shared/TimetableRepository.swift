import Foundation

/// Persiste les séances, la semaine de référence et les noms Q1/Q2 dans l'App Group.
struct TimetableRepository {
    private enum Key {
        static let sessions = "courseSessions.v1"
        static let referenceWeekStart = "courseReferenceWeekStart.v1"
        static let referenceWeek = "courseReferenceWeek.v1"
        static let q1Name = "courseQ1Name.v1"
        static let q2Name = "courseQ2Name.v1"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        self.defaults = defaults ?? .standard
    }

    func loadSessions() -> [CourseSession] {
        guard let data = defaults.data(forKey: Key.sessions),
              let sessions = try? JSONDecoder().decode([CourseSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func saveSessions(_ sessions: [CourseSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: Key.sessions)
    }

    func referenceWeekStart() -> Date? {
        defaults.object(forKey: Key.referenceWeekStart) as? Date
    }

    func setReferenceWeekStart(_ date: Date) {
        defaults.set(date, forKey: Key.referenceWeekStart)
    }

    func referenceWeek() -> TeachingWeek {
        guard let value = defaults.string(forKey: Key.referenceWeek),
              let week = TeachingWeek(rawValue: value) else {
            return .q1
        }
        return week
    }

    func setReferenceWeek(_ week: TeachingWeek) {
        defaults.set(week.rawValue, forKey: Key.referenceWeek)
    }

    func weekName(for week: TeachingWeek) -> String {
        let key = week == .q1 ? Key.q1Name : Key.q2Name
        let fallback = week == .q1 ? "Q1" : "Q2"
        let storedName = defaults.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let storedName, !storedName.isEmpty {
            return storedName
        }
        return fallback
    }

    func setWeekName(_ name: String, for week: TeachingWeek) {
        let key = week == .q1 ? Key.q1Name : Key.q2Name
        let fallback = week == .q1 ? "Q1" : "Q2"
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(normalized.isEmpty ? fallback : normalized, forKey: key)
    }
}

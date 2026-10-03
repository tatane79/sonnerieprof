import Foundation

/// Position logique dans l'alternance bimensuelle, indépendamment du nom affiché.
enum TeachingWeek: String, Codable, CaseIterable, Hashable, Sendable {
    case q1
    case q2

    var other: TeachingWeek {
        self == .q1 ? .q2 : .q1
    }
}

/// Semaines pendant lesquelles une séance doit apparaître.
enum CourseWeekPattern: String, Codable, CaseIterable, Hashable, Sendable {
    case everyWeek
    case q1
    case q2

    func includes(_ week: TeachingWeek) -> Bool {
        self == .everyWeek || rawValue == week.rawValue
    }
}

/// Séance récurrente décrite en minutes depuis minuit pour rester indépendante d'une date.
struct CourseSession: Codable, Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    var className: String
    var roomName: String
    var siteID: UUID
    var weekday: Int
    var startMinutes: Int
    var endMinutes: Int
    var weekPattern: CourseWeekPattern

    init(
        id: UUID = UUID(),
        className: String,
        roomName: String? = nil,
        siteID: UUID,
        weekday: Int,
        startMinutes: Int,
        endMinutes: Int,
        weekPattern: CourseWeekPattern = .everyWeek
    ) {
        self.id = id
        self.className = className
        self.roomName = roomName ?? className
        self.siteID = siteID
        self.weekday = weekday
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.weekPattern = weekPattern
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case className
        case roomName
        case siteID
        case weekday
        case startMinutes
        case endMinutes
        case weekPattern
    }

    /// Décode aussi les anciennes séances dépourvues de salle en reprenant le nom de classe.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        className = try container.decode(String.self, forKey: .className)
        roomName = try container.decodeIfPresent(String.self, forKey: .roomName) ?? className
        siteID = try container.decode(UUID.self, forKey: .siteID)
        weekday = try container.decode(Int.self, forKey: .weekday)
        startMinutes = try container.decode(Int.self, forKey: .startMinutes)
        endMinutes = try container.decode(Int.self, forKey: .endMinutes)
        weekPattern = try container.decode(CourseWeekPattern.self, forKey: .weekPattern)
    }
}

/// Occurrence datée d'une séance récurrente.
struct CourseOccurrence: Equatable, Identifiable {
    let session: CourseSession
    let startDate: Date
    let endDate: Date

    var id: String {
        "\(session.id.uuidString)-\(startDate.timeIntervalSinceReferenceDate)"
    }
}

/// Instantané contenant le cours en cours et le prochain cours connu.
struct CourseStatus: Equatable {
    let current: CourseOccurrence?
    let next: CourseOccurrence?
}

import Foundation

/// Horaires de sonnerie associés à un jour de la semaine.
struct WeekdaySchedule: Codable, Hashable, Identifiable, Sendable {
    /// Convention de `Calendar` : 1 = dimanche, 2 = lundi, …, 7 = samedi.
    var weekday: Int
    var bellTimes: [String]

    var id: Int { weekday }
}

/// Établissement scolaire avec sa position facultative et ses horaires de sonnerie.
struct BellSite: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var detectionRadiusMeters: Double
    var schedules: [WeekdaySchedule]

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double = 0,
        longitude: Double = 0,
        detectionRadiusMeters: Double = 250,
        schedules: [WeekdaySchedule] = []
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.detectionRadiusMeters = detectionRadiusMeters
        self.schedules = schedules
    }

    func bellTimes(for weekday: Int) -> [String] {
        schedules.first(where: { $0.weekday == weekday })?.bellTimes ?? []
    }

    mutating func setBellTimes(_ times: [String], for weekday: Int) {
        if let index = schedules.firstIndex(where: { $0.weekday == weekday }) {
            schedules[index].bellTimes = times
        } else {
            schedules.append(WeekdaySchedule(weekday: weekday, bellTimes: times))
        }
        schedules.sort { $0.weekday < $1.weekday }
    }

    var hasAnyBell: Bool {
        schedules.contains { !$0.bellTimes.isEmpty }
    }


}

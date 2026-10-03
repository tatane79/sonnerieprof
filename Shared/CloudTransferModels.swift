import Foundation

struct SharedBellSchedule: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let siteName: String
    let schedules: [WeekdaySchedule]
    let updatedAt: Date

    init(site: BellSite, updatedAt: Date = .now) {
        version = Self.currentVersion
        siteName = site.name
        schedules = site.schedules
        self.updatedAt = updatedAt
    }

    func makeLocalSite() -> BellSite {
        BellSite(name: siteName, schedules: schedules)
    }
}

struct TimetableBackup: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let savedAt: Date
    let sessions: [CourseSession]
    let referenceWeekStart: Date
    let referenceWeek: TeachingWeek
    let q1Name: String
    let q2Name: String
    let sites: [BellSite]
    let selectedSiteID: UUID?
}

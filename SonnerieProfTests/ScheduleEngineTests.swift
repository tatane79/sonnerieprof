import XCTest
@testable import SonnerieProf

final class ScheduleEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    func testFindsNextBellSameDay() throws {
        let engine = ScheduleEngine(calendar: calendar)
        let site = BellSite(name: "Test", schedules: [
            WeekdaySchedule(weekday: 3, bellTimes: ["08:00", "08:55", "10:00"])
        ])
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 8, minute: 12))!
        let next = try XCTUnwrap(engine.nextBell(after: date, at: site))
        XCTAssertEqual(calendar.component(.hour, from: next), 8)
        XCTAssertEqual(calendar.component(.minute, from: next), 55)
    }

    func testSkipsToSaturdayWhenConfigured() throws {
        let engine = ScheduleEngine(calendar: calendar)
        let site = BellSite(name: "Test", schedules: [
            WeekdaySchedule(weekday: 7, bellTimes: ["09:30"])
        ])
        let friday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 18))!
        let next = try XCTUnwrap(engine.nextBell(after: friday, at: site))
        XCTAssertEqual(calendar.component(.weekday, from: next), 7)
        XCTAssertEqual(calendar.component(.hour, from: next), 9)
        XCTAssertEqual(calendar.component(.minute, from: next), 30)
    }

    func testSkipsWeekendWhenSaturdayIsEmpty() throws {
        let engine = ScheduleEngine(calendar: calendar)
        let site = BellSite(name: "Test", schedules: [
            WeekdaySchedule(weekday: 2, bellTimes: ["08:10"])
        ])
        let friday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 18))!
        let next = try XCTUnwrap(engine.nextBell(after: friday, at: site))
        XCTAssertEqual(calendar.component(.weekday, from: next), 2)
        XCTAssertEqual(calendar.component(.hour, from: next), 8)
        XCTAssertEqual(calendar.component(.minute, from: next), 10)
    }

    func testSuspensionSkipsBellsUntilResumeDate() throws {
        let engine = ScheduleEngine(calendar: calendar)
        let site = BellSite(name: "Test", schedules: (2...6).map {
            WeekdaySchedule(weekday: $0, bellTimes: ["08:10"])
        })
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 7))!
        let resume = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 0))!
        let next = try XCTUnwrap(engine.nextBell(after: monday, at: site, suspendedUntil: resume))
        XCTAssertEqual(calendar.component(.day, from: next), 17)
        XCTAssertEqual(calendar.component(.hour, from: next), 8)
    }

    func testValidationNormalizesSortsAndRemovesDuplicates() {
        let engine = ScheduleEngine(calendar: calendar)
        let result = engine.validateBellTimes(["9:05", "08:10", "09:05", " 10:00 "])
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.duplicateCount, 1)
        XCTAssertEqual(result.normalizedTimes, ["08:10", "09:05", "10:00"])
    }

    func testValidationRejectsImpossibleTimes() {
        let engine = ScheduleEngine(calendar: calendar)
        let result = engine.validateBellTimes(["08:10", "25:00", "09:75", "bonjour"])
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.invalidValues, ["25:00", "09:75", "bonjour"])
        XCTAssertEqual(result.normalizedTimes, ["08:10"])
    }

    func testFiveAMTransitionUsesLocalCalendar() throws {
        let engine = ScheduleEngine(calendar: calendar)
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 8, minute: 10))!
        let five = try XCTUnwrap(engine.fiveAM(onSameDayAs: date))
        XCTAssertEqual(calendar.component(.hour, from: five), 5)
        XCTAssertEqual(calendar.component(.day, from: five), 15)
    }

    func testDSTWeekendStillFindsMondayBell() throws {
        let engine = ScheduleEngine(calendar: calendar)
        let site = BellSite(name: "Test", schedules: [
            WeekdaySchedule(weekday: 2, bellTimes: ["08:10"])
        ])
        // Europe/Paris passe à l'heure d'été le dimanche 29 mars 2026.
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 18))!
        let next = try XCTUnwrap(engine.nextBell(after: saturday, at: site))
        XCTAssertEqual(calendar.component(.weekday, from: next), 2)
        XCTAssertEqual(calendar.component(.hour, from: next), 8)
        XCTAssertEqual(calendar.component(.minute, from: next), 10)
    }

    func testFourteenBellDayIsSupported() {
        let times = [
            "08:10", "09:05", "10:00", "10:15", "11:10", "12:05", "13:00",
            "13:10", "14:05", "15:00", "15:15", "16:10", "17:05", "18:10"
        ]
        let site = BellSite(name: "Test", schedules: [
            WeekdaySchedule(weekday: 2, bellTimes: times)
        ])
        XCTAssertEqual(site.bellTimes(for: 2).count, 14)
    }
}

final class SiteRepositoryTests: XCTestCase {
    func testFreshRepositoryStartsWithoutAssumedSites() {
        let suiteName = "fr.jonathanlafarge.sonnerieprof.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = SiteRepository(defaults: defaults)
        XCTAssertTrue(repository.loadSites().isEmpty)
    }

    func testRepositoryPersistsConfiguredSite() throws {
        let suiteName = "fr.jonathanlafarge.sonnerieprof.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = SiteRepository(defaults: defaults)
        let site = BellSite(name: "Collège Test")
        repository.saveSites([site])

        let loaded = repository.loadSites()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Collège Test")
    }
}

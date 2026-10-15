import Foundation
import Testing
@testable import SonnerieProf

struct TimetableEngineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendar
    }

    @Test
    func countdownMinutesUseTheSameUpwardRoundingEverywhere() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        #expect(BellCountdownClock.remainingMinutes(
            from: now,
            to: now.addingTimeInterval(55)
        ) == 1)
        #expect(BellCountdownClock.remainingMinutes(
            from: now,
            to: now.addingTimeInterval(60)
        ) == 1)
        #expect(BellCountdownClock.remainingMinutes(
            from: now,
            to: now.addingTimeInterval(60.001)
        ) == 2)
        #expect(BellCountdownClock.remainingMinutes(
            from: now,
            to: now.addingTimeInterval(54 * 60 + 1)
        ) == 55)
    }

    @Test
    func countdownComponentsKeepHoursAndMinutes() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        #expect(BellCountdownClock.components(
            from: now,
            to: now.addingTimeInterval(71 * 60)
        ) == .init(days: 0, hours: 1, minutes: 11))
        #expect(BellCountdownClock.components(
            from: now,
            to: now.addingTimeInterval(24 * 60 * 60 + 11 * 60)
        ) == .init(days: 1, hours: 0, minutes: 11))
    }

    @Test
    func countdownShowsSecondsOnlyBelowThreeMinutes() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        #expect(!BellCountdownClock.showsSeconds(
            from: now,
            to: now.addingTimeInterval(3 * 60)
        ))
        #expect(BellCountdownClock.showsSeconds(
            from: now,
            to: now.addingTimeInterval(3 * 60 - 0.001)
        ))
    }

    @Test
    func lockScreenUsesDaysAndHoursOnlyBeyondTwentyFourHours() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        #expect(!BellCountdownClock.showsDaysAndHours(
            from: now,
            to: now.addingTimeInterval(24 * 60 * 60)
        ))
        #expect(BellCountdownClock.showsDaysAndHours(
            from: now,
            to: now.addingTimeInterval(24 * 60 * 60 + 1)
        ))
        #expect(BellCountdownClock.dayHourComponents(
            from: now,
            to: now.addingTimeInterval(2 * 24 * 60 * 60 + 3 * 60 * 60 + 59 * 60)
        ) == .init(days: 2, hours: 3, minutes: 0))
    }

    @Test
    func dynamicCountdownFormatMatchesEveryPresentation() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let target = now.addingTimeInterval(71 * 60)

        #expect(BellCountdownFormatStyle(targetDate: target, presentation: .full).format(now) == "1h11min")
        #expect(BellCountdownFormatStyle(targetDate: target, presentation: .compact).format(now) == "1h11")
        #expect(BellCountdownFormatStyle(
            targetDate: now.addingTimeInterval(2 * 60 + 9),
            presentation: .full
        ).format(now) == "2:09")
    }

    @Test
    func everyWeekSessionAppearsInQ1AndQ2() throws {
        let engine = TimetableEngine(calendar: calendar)
        let siteID = UUID()
        let session = CourseSession(
            className: "5e3",
            siteID: siteID,
            weekday: 2,
            startMinutes: 9 * 60 + 15,
            endMinutes: 10 * 60 + 10
        )
        let q1Monday = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 21, hour: 8)
        ))
        let q2Monday = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 28, hour: 8)
        ))

        let q1Status = engine.status(
            at: q1Monday,
            sessions: [session],
            referenceWeekStart: q1Monday,
            referenceWeek: .q1
        )
        let q2Status = engine.status(
            at: q2Monday,
            sessions: [session],
            referenceWeekStart: q1Monday,
            referenceWeek: .q1
        )

        #expect(q1Status.next?.session.className == "5e3")
        #expect(q2Status.next?.session.className == "5e3")
    }

    @Test
    func q1SessionIsSkippedDuringQ2() throws {
        let engine = TimetableEngine(calendar: calendar)
        let q1Monday = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 21, hour: 8)
        ))
        let q2Monday = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 28, hour: 8)
        ))
        let q1Only = CourseSession(
            className: "4e2",
            siteID: UUID(),
            weekday: 2,
            startMinutes: 9 * 60,
            endMinutes: 10 * 60,
            weekPattern: .q1
        )

        let status = engine.status(
            at: q2Monday,
            sessions: [q1Only],
            referenceWeekStart: q1Monday,
            referenceWeek: .q1
        )

        let next = try #require(status.next)
        // La semaine du 28 septembre est Q2 ; la suivante, le 5 octobre, repasse en Q1.
        #expect(calendar.component(.day, from: next.startDate) == 5)
        #expect(calendar.component(.month, from: next.startDate) == 10)
    }

    @Test
    func statusReturnsCurrentAndFollowingCourse() throws {
        let engine = TimetableEngine(calendar: calendar)
        let monday = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 21, hour: 9, minute: 30)
        ))
        let siteID = UUID()
        let sessions = [
            CourseSession(
                className: "5e3",
                siteID: siteID,
                weekday: 2,
                startMinutes: 9 * 60 + 15,
                endMinutes: 10 * 60 + 10
            ),
            CourseSession(
                className: "6e1",
                siteID: siteID,
                weekday: 2,
                startMinutes: 10 * 60 + 15,
                endMinutes: 11 * 60 + 10
            )
        ]

        let status = engine.status(
            at: monday,
            sessions: sessions,
            referenceWeekStart: monday,
            referenceWeek: .q1
        )

        #expect(status.current?.session.className == "5e3")
        #expect(status.next?.session.className == "6e1")
    }

    @Test
    func countdownTargetsCurrentCourseEndThenNextCourseStart() throws {
        let engine = TimetableEngine(calendar: calendar)
        let mondayStart = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 21, hour: 8)
        ))
        let duringFirstCourse = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 21, hour: 8, minute: 30)
        ))
        let betweenCourses = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 21, hour: 9, minute: 30)
        ))
        let sessions = [
            CourseSession(
                className: "3e1",
                siteID: UUID(),
                weekday: 2,
                startMinutes: 8 * 60,
                endMinutes: 9 * 60
            ),
            CourseSession(
                className: "4e2",
                siteID: UUID(),
                weekday: 2,
                startMinutes: 10 * 60,
                endMinutes: 11 * 60
            )
        ]

        let courseEnd = try #require(engine.countdownTarget(
            at: duringFirstCourse,
            sessions: sessions,
            referenceWeekStart: mondayStart,
            referenceWeek: .q1
        ))
        let nextCourseStart = try #require(engine.countdownTarget(
            at: betweenCourses,
            sessions: sessions,
            referenceWeekStart: mondayStart,
            referenceWeek: .q1
        ))

        #expect(calendar.component(.hour, from: courseEnd) == 9)
        #expect(calendar.component(.hour, from: nextCourseStart) == 10)
    }

    @Test
    func boundaryDatesAlternateCourseStartsAndEnds() throws {
        let engine = TimetableEngine(calendar: calendar)
        let monday = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 21, hour: 7)
        ))
        let session = CourseSession(
            className: "3e1",
            siteID: UUID(),
            weekday: 2,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60
        )

        let boundaries = engine.boundaryDates(
            after: monday,
            sessions: [session],
            referenceWeekStart: monday,
            referenceWeek: .q1
        )

        #expect(calendar.component(.hour, from: boundaries[0]) == 8)
        #expect(calendar.component(.hour, from: boundaries[1]) == 9)
    }

    @Test
    func everyWeekSessionConflictsWithOverlappingQ1Session() {
        let engine = TimetableEngine(calendar: calendar)
        let siteID = UUID()
        let existing = CourseSession(
            className: "3e1",
            siteID: siteID,
            weekday: 2,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60,
            weekPattern: .q1
        )
        let candidate = CourseSession(
            className: "4e2",
            siteID: siteID,
            weekday: 2,
            startMinutes: 8 * 60 + 30,
            endMinutes: 9 * 60 + 30
        )

        #expect(engine.conflicts(for: candidate, in: [existing]) == [existing])
    }

    @Test
    func q1AndQ2SessionsCanUseTheSameTime() {
        let engine = TimetableEngine(calendar: calendar)
        let existing = CourseSession(
            className: "3e1",
            siteID: UUID(),
            weekday: 2,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60,
            weekPattern: .q1
        )
        let candidate = CourseSession(
            className: "4e2",
            siteID: UUID(),
            weekday: 2,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60,
            weekPattern: .q2
        )

        #expect(engine.conflicts(for: candidate, in: [existing]).isEmpty)
    }

    @Test
    func consecutiveSessionsDoNotConflict() {
        let engine = TimetableEngine(calendar: calendar)
        let existing = CourseSession(
            className: "3e1",
            siteID: UUID(),
            weekday: 2,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60
        )
        let candidate = CourseSession(
            className: "4e2",
            siteID: UUID(),
            weekday: 2,
            startMinutes: 9 * 60,
            endMinutes: 10 * 60
        )

        #expect(engine.conflicts(for: candidate, in: [existing]).isEmpty)
    }

    @Test
    func legacySessionUsesClassNameAsRoomName() throws {
        let legacySession = CourseSession(
            className: "3e1",
            siteID: UUID(),
            weekday: 2,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60
        )
        let encoded = try JSONEncoder().encode(legacySession)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "roomName")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(CourseSession.self, from: legacyData)

        #expect(decoded.roomName == "3e1")
    }
}

import Foundation
import Testing
@testable import SonnerieProf

struct CloudTransferModelsTests {
    @Test
    func builtInSchoolPresetsMatchThePublishedSchedules() {
        let ind = BuiltInSitePresets.ind.makeSite()
        let nde = BuiltInSitePresets.nde.makeSite()

        #expect(ind.name == "IND")
        #expect(ind.schedules.map(\.weekday) == Array(2...7))
        #expect(ind.bellTimes(for: 2) == [
            "08:10", "09:05", "10:00", "10:15", "11:10", "12:05", "13:05",
            "13:10", "14:05", "15:00", "15:15", "16:10", "17:05", "18:00"
        ])
        #expect(ind.bellTimes(for: 7) == ind.bellTimes(for: 2))

        #expect(nde.name == "NDE")
        #expect(nde.schedules.map(\.weekday) == Array(2...6))
        #expect(nde.bellTimes(for: 2) == [
            "08:15", "08:20", "09:15", "10:10", "10:25", "11:20", "12:15",
            "13:45", "13:50", "14:45", "15:40", "15:55", "16:50", "17:45"
        ])
        #expect(nde.bellTimes(for: 7).isEmpty)
    }

    @Test
    func generatedShareCodesContainSixLowercaseLetters() {
        for _ in 0..<1_000 {
            let code = ShareCodeGenerator.generate()
            #expect(code.count == 6)
            #expect(code.allSatisfy { ("a"..."z").contains(String($0)) })
            #expect(ShareCodeGenerator.isValid(code))
        }

        #expect(!ShareCodeGenerator.isValid("abcde"))
        #expect(!ShareCodeGenerator.isValid("abcdefg"))
        #expect(!ShareCodeGenerator.isValid("ABCDEF"))
        #expect(!ShareCodeGenerator.isValid("abcd3f"))
    }

    @Test
    func sharedScheduleExcludesLocationAndCreatesANewLocalIdentity() throws {
        let original = BellSite(
            name: "Collège Exemple",
            latitude: 48.8566,
            longitude: 2.3522,
            detectionRadiusMeters: 500,
            schedules: [
                WeekdaySchedule(weekday: 2, bellTimes: ["08:00", "09:05"])
            ]
        )

        let encoded = try JSONEncoder().encode(SharedBellSchedule(site: original))
        let shared = try JSONDecoder().decode(SharedBellSchedule.self, from: encoded)
        let imported = shared.makeLocalSite()

        #expect(imported.name == original.name)
        #expect(imported.schedules == original.schedules)
        #expect(imported.id != original.id)
        #expect(imported.latitude == 0)
        #expect(imported.longitude == 0)
        #expect(imported.detectionRadiusMeters == 250)
    }

    @Test
    func timetableBackupRoundTripsAllRequiredRelationships() throws {
        let site = BellSite(name: "Lycée Exemple")
        let session = CourseSession(
            className: "5e3",
            roomName: "B12",
            siteID: site.id,
            weekday: 2,
            startMinutes: 8 * 60,
            endMinutes: 9 * 60
        )
        let backup = TimetableBackup(
            version: TimetableBackup.currentVersion,
            savedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            sessions: [session],
            referenceWeekStart: Date(timeIntervalSinceReferenceDate: 500),
            referenceWeek: .q2,
            q1Name: "A",
            q2Name: "B",
            sites: [site],
            selectedSiteID: site.id
        )

        let encoded = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(TimetableBackup.self, from: encoded)

        #expect(decoded.sessions == [session])
        #expect(decoded.sites == [site])
        #expect(decoded.sessions.first?.siteID == decoded.sites.first?.id)
        #expect(decoded.referenceWeek == .q2)
        #expect(decoded.q1Name == "A")
        #expect(decoded.q2Name == "B")
        #expect(decoded.selectedSiteID == site.id)
    }
}

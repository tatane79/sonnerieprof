import Foundation

struct BuiltInSitePreset: Identifiable, Sendable {
    let id: String
    let name: String
    let schedules: [WeekdaySchedule]

    func makeSite(id: UUID = UUID()) -> BellSite {
        BellSite(id: id, name: name, schedules: schedules)
    }
}

enum BuiltInSitePresets {
    static let ind = BuiltInSitePreset(
        id: "ind",
        name: "IND",
        schedules: repeatedSchedule(
            weekdays: 2...7,
            times: [
                "08:10", "09:05", "10:00", "10:15", "11:10", "12:05", "13:05",
                "13:10", "14:05", "15:00", "15:15", "16:10", "17:05", "18:00"
            ]
        )
    )

    static let nde = BuiltInSitePreset(
        id: "nde",
        name: "NDE",
        schedules: repeatedSchedule(
            weekdays: 2...6,
            times: [
                "08:15", "08:20", "09:15", "10:10", "10:25", "11:20", "12:15",
                "13:45", "13:50", "14:45", "15:40", "15:55", "16:50", "17:45"
            ]
        )
    )

    static let all = [ind, nde]

    private static func repeatedSchedule(
        weekdays: ClosedRange<Int>,
        times: [String]
    ) -> [WeekdaySchedule] {
        weekdays.map { weekday in
            WeekdaySchedule(weekday: weekday, bellTimes: times)
        }
    }
}

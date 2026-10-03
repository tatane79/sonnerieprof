import Foundation
import Observation
@preconcurrency import WatchConnectivity

@MainActor
@Observable
final class WatchScheduleModel: NSObject, WCSessionDelegate {
    private(set) var payload: WatchSchedulePayload?
    private(set) var synchronizationError = false

    private let storageKey = "watch.schedule.payload.v1"
    private let calendar = Calendar.autoupdatingCurrent

    override init() {
        super.init()
        loadStoredPayload()
        activateConnectivity()
    }

    func refresh() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            return
        }

        WCSession.default.sendMessage(
            ["requestSchedule": true],
            replyHandler: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.synchronizationError = true
            }
        }
    }

    func effectiveDate(for systemDate: Date) -> Date {
        guard let payload,
              payload.debugSimulatedTimeEnabled == true else {
            return systemDate
        }

        return systemDate.addingTimeInterval(
            payload.debugSimulatedTimeOffset ?? 0
        )
    }

    func status(at date: Date) -> WatchScheduleStatus {
        guard let payload else {
            return .waitingForSynchronization
        }

        if payload.sessions.isEmpty {
            guard let site = activeSite(in: payload),
                  let target = nextBell(
                    after: date,
                    at: site,
                    suspendedUntil: payload.scheduleSuspendedUntil
                  ) else {
                return .noUpcomingEvent(
                    siteName: activeSite(in: payload)?.name,
                    synchronizedAt: payload.synchronizedAt
                )
            }

            return .upcoming(
                title: site.name,
                target: target,
                isCourseEnd: false,
                synchronizedAt: payload.synchronizedAt
            )
        }

        let course = courseStatus(at: date, payload: payload)
        if let current = course.current {
            return .upcoming(
                title: current.session.className,
                target: current.endDate,
                isCourseEnd: true,
                synchronizedAt: payload.synchronizedAt
            )
        }

        if let next = course.next {
            return .upcoming(
                title: next.session.className,
                target: next.startDate,
                isCourseEnd: false,
                synchronizedAt: payload.synchronizedAt
            )
        }

        return .noUpcomingEvent(
            siteName: activeSite(in: payload)?.name,
            synchronizedAt: payload.synchronizedAt
        )
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard activationState == .activated else { return }

        if let data = session.receivedApplicationContext["schedule"] as? Data {
            Task { @MainActor [weak self] in
                self?.store(data)
            }
        }

        Task { @MainActor [weak self] in
            self?.refresh()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext["schedule"] as? Data else { return }

        Task { @MainActor [weak self] in
            self?.store(data)
        }
    }

    private func activateConnectivity() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func loadStoredPayload() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(
                WatchSchedulePayload.self,
                from: data
              ) else {
            return
        }

        payload = decoded
    }

    private func store(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(
            WatchSchedulePayload.self,
            from: data
        ) else {
            synchronizationError = true
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
        payload = decoded
        synchronizationError = false
    }

    private func activeSite(in payload: WatchSchedulePayload) -> WatchBellSite? {
        if let selectedSiteID = payload.selectedSiteID,
           let selected = payload.sites.first(where: { $0.id == selectedSiteID }) {
            return selected
        }
        return payload.sites.first
    }

    private func nextBell(
        after date: Date,
        at site: WatchBellSite,
        suspendedUntil: Date?
    ) -> Date? {
        let start = max(date, suspendedUntil ?? date)

        for dayOffset in 0...14 {
            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: start
            ) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            let times = site.schedules
                .first(where: { $0.weekday == weekday })?
                .bellTimes ?? []

            for time in times.sorted() {
                let parts = time.split(separator: ":")
                guard parts.count == 2,
                      let hour = Int(parts[0]),
                      let minute = Int(parts[1]),
                      let candidate = calendar.date(
                        bySettingHour: hour,
                        minute: minute,
                        second: 0,
                        of: day
                      ),
                      candidate > start else {
                    continue
                }
                return candidate
            }
        }

        return nil
    }

    private func courseStatus(
        at date: Date,
        payload: WatchSchedulePayload
    ) -> (
        current: WatchCourseOccurrence?,
        next: WatchCourseOccurrence?
    ) {
        var current: WatchCourseOccurrence?
        var next: WatchCourseOccurrence?
        let referenceStart = payload.referenceWeekStart
            ?? startOfWeek(containing: date)

        for dayOffset in 0...14 {
            guard let day = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: date
            ) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            let teachingWeek = week(
                on: day,
                referenceStart: referenceStart,
                referenceWeek: payload.referenceWeek
            )

            for session in payload.sessions where
                session.weekday == weekday
                    && session.weekPattern.includes(teachingWeek) {
                guard let occurrence = occurrence(for: session, on: day) else {
                    continue
                }

                if occurrence.startDate <= date && date < occurrence.endDate {
                    if current.map({ occurrence.startDate > $0.startDate }) ?? true {
                        current = occurrence
                    }
                } else if occurrence.startDate > date {
                    if next.map({ occurrence.startDate < $0.startDate }) ?? true {
                        next = occurrence
                    }
                }
            }

            if dayOffset > 0, next != nil {
                break
            }
        }

        return (current, next)
    }

    private func occurrence(
        for session: WatchCourseSession,
        on day: Date
    ) -> WatchCourseOccurrence? {
        guard let start = calendar.date(
            bySettingHour: session.startMinutes / 60,
            minute: session.startMinutes % 60,
            second: 0,
            of: day
        ),
        let end = calendar.date(
            bySettingHour: session.endMinutes / 60,
            minute: session.endMinutes % 60,
            second: 0,
            of: day
        ),
        end > start else {
            return nil
        }

        return WatchCourseOccurrence(
            session: session,
            startDate: start,
            endDate: end
        )
    }

    private func week(
        on date: Date,
        referenceStart: Date,
        referenceWeek: WatchTeachingWeek
    ) -> WatchTeachingWeek {
        let start = startOfWeek(containing: referenceStart)
        let target = startOfWeek(containing: date)
        let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return abs(days / 7) % 2 == 0 ? referenceWeek : referenceWeek.other
    }

    private func startOfWeek(containing date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        return calendar.date(
            byAdding: .day,
            value: -((weekday + 5) % 7),
            to: day
        ) ?? day
    }
}

enum WatchScheduleStatus {
    case waitingForSynchronization
    case noUpcomingEvent(siteName: String?, synchronizedAt: Date)
    case upcoming(
        title: String,
        target: Date,
        isCourseEnd: Bool,
        synchronizedAt: Date
    )
}

struct WatchSchedulePayload: Codable, Sendable {
    let sites: [WatchBellSite]
    let selectedSiteID: UUID?
    let scheduleSuspendedUntil: Date?
    let sessions: [WatchCourseSession]
    let referenceWeekStart: Date?
    let referenceWeek: WatchTeachingWeek
    let q1Name: String
    let q2Name: String
    let debugSimulatedTimeEnabled: Bool?
    let debugSimulatedTimeOffset: TimeInterval?
    let synchronizedAt: Date
}

struct WatchBellSite: Codable, Sendable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let detectionRadiusMeters: Double
    let schedules: [WatchWeekdaySchedule]
}

struct WatchWeekdaySchedule: Codable, Sendable {
    let weekday: Int
    let bellTimes: [String]
}

enum WatchTeachingWeek: String, Codable, Sendable {
    case q1
    case q2

    var other: WatchTeachingWeek {
        self == .q1 ? .q2 : .q1
    }
}

enum WatchCourseWeekPattern: String, Codable, Sendable {
    case everyWeek
    case q1
    case q2

    func includes(_ week: WatchTeachingWeek) -> Bool {
        self == .everyWeek || rawValue == week.rawValue
    }
}

struct WatchCourseSession: Codable, Sendable {
    let id: UUID
    let className: String
    let roomName: String
    let siteID: UUID
    let weekday: Int
    let startMinutes: Int
    let endMinutes: Int
    let weekPattern: WatchCourseWeekPattern
}

private struct WatchCourseOccurrence {
    let session: WatchCourseSession
    let startDate: Date
    let endDate: Date
}

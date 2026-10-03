import Foundation

/// Moteur pur de l'emploi du temps : alternance, occurrences, conflits et compte à rebours.
struct TimetableEngine {
    var calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func teachingWeek(
        on date: Date,
        referenceWeekStart: Date,
        referenceWeek: TeachingWeek
    ) -> TeachingWeek {
        let reference = startOfWeek(containing: referenceWeekStart)
        let target = startOfWeek(containing: date)
        let dayDistance = calendar.dateComponents([.day], from: reference, to: target).day ?? 0
        let weekDistance = dayDistance / 7
        return abs(weekDistance) % 2 == 0 ? referenceWeek : referenceWeek.other
    }

    func status(
        at date: Date,
        sessions: [CourseSession],
        referenceWeekStart: Date,
        referenceWeek: TeachingWeek
    ) -> CourseStatus {
        var current: CourseOccurrence?
        var next: CourseOccurrence?

        // Deux semaines suffisent pour traverser un cycle complet Q1/Q2.
        for dayOffset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            let week = teachingWeek(
                on: day,
                referenceWeekStart: referenceWeekStart,
                referenceWeek: referenceWeek
            )

            let daySessions = sessions
                .filter { $0.weekday == weekday && $0.weekPattern.includes(week) }
                .sorted { $0.startMinutes < $1.startMinutes }

            for session in daySessions {
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

        return CourseStatus(current: current, next: next)
    }

    func countdownTarget(
        at date: Date,
        sessions: [CourseSession],
        referenceWeekStart: Date,
        referenceWeek: TeachingWeek
    ) -> Date? {
        let courseStatus = status(
            at: date,
            sessions: sessions,
            referenceWeekStart: referenceWeekStart,
            referenceWeek: referenceWeek
        )
        return courseStatus.current?.endDate ?? courseStatus.next?.startDate
    }

    func boundaryDates(
        after date: Date,
        sessions: [CourseSession],
        referenceWeekStart: Date,
        referenceWeek: TeachingWeek,
        limit: Int = 40
    ) -> [Date] {
        guard limit > 0 else { return [] }

        var dates: Set<Date> = []

        for dayOffset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            let week = teachingWeek(
                on: day,
                referenceWeekStart: referenceWeekStart,
                referenceWeek: referenceWeek
            )

            for session in sessions where
                session.weekday == weekday && session.weekPattern.includes(week) {
                guard let course = occurrence(for: session, on: day) else {
                    continue
                }

                if course.startDate > date {
                    dates.insert(course.startDate)
                }
                if course.endDate > date {
                    dates.insert(course.endDate)
                }
            }
        }

        return Array(dates)
            .sorted()
            .prefix(limit)
            .map { $0 }
    }

    func conflicts(
        for candidate: CourseSession,
        in sessions: [CourseSession]
    ) -> [CourseSession] {
        sessions
            .filter { existing in
                existing.id != candidate.id
                    && existing.weekday == candidate.weekday
                    && weekPatternsOverlap(candidate.weekPattern, existing.weekPattern)
                    && candidate.startMinutes < existing.endMinutes
                    && existing.startMinutes < candidate.endMinutes
            }
            .sorted { first, second in
                if first.startMinutes != second.startMinutes {
                    return first.startMinutes < second.startMinutes
                }
                return first.className.localizedCaseInsensitiveCompare(second.className)
                    == .orderedAscending
            }
    }

    func startOfWeek(containing date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
    }

    func date(minutesSinceMidnight: Int, on day: Date = .now) -> Date {
        let hour = minutesSinceMidnight / 60
        let minute = minutesSinceMidnight % 60
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    func minutesSinceMidnight(for date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private func weekPatternsOverlap(
        _ first: CourseWeekPattern,
        _ second: CourseWeekPattern
    ) -> Bool {
        (first.includes(.q1) && second.includes(.q1))
            || (first.includes(.q2) && second.includes(.q2))
    }

    private func occurrence(for session: CourseSession, on day: Date) -> CourseOccurrence? {
        let startHour = session.startMinutes / 60
        let startMinute = session.startMinutes % 60
        let endHour = session.endMinutes / 60
        let endMinute = session.endMinutes % 60

        guard let startDate = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: day
        ),
        let endDate = calendar.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: day
        ),
        endDate > startDate else {
            return nil
        }

        return CourseOccurrence(session: session, startDate: startDate, endDate: endDate)
    }
}

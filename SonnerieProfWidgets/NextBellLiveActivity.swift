import ActivityKit
import SwiftUI
import WidgetKit

private struct BellActivityTiming {
    let state: BellActivityAttributes.ContentState

    func nextTarget(after date: Date) -> Date? {
        state.bellDates.first(where: { $0 > date })
    }

    func displayDate(for systemDate: Date) -> Date {
        systemDate.addingTimeInterval(state.simulatedTimeOffset ?? 0)
    }

    func isNextCourseOnLaterDay(_ targetDate: Date, than currentDate: Date) -> Bool {
        guard state.usesCourseSchedule == true else { return false }
        return !Calendar.autoupdatingCurrent.isDate(
            displayDate(for: currentDate),
            inSameDayAs: displayDate(for: targetDate)
        )
    }

    func courseDetails(at targetDate: Date) -> CourseActivityDetails? {
        state.courseDetails?.first {
            abs($0.startDate.timeIntervalSince(targetDate)) < 1
        }
    }

    var timelineDates: [Date] {
        let dayTransitions = state.bellDates.map(systemStartOfDisplayDay(containing:))
        return Array(Set([state.startDate] + state.bellDates + dayTransitions)).sorted()
    }

    func systemStartOfDisplayDay(containing systemDate: Date) -> Date {
        let offset = state.simulatedTimeOffset ?? 0
        let displayStartOfDay = Calendar.autoupdatingCurrent.startOfDay(
            for: displayDate(for: systemDate)
        )
        return displayStartOfDay.addingTimeInterval(-offset)
    }

    func calendarDayCount(to targetDate: Date, from currentDate: Date) -> Int {
        let calendar = Calendar.autoupdatingCurrent
        let currentDay = calendar.startOfDay(for: displayDate(for: currentDate))
        let targetDay = calendar.startOfDay(for: displayDate(for: targetDate))
        return max(1, calendar.dateComponents([.day], from: currentDay, to: targetDay).day ?? 1)
    }

    func shouldHide(targetDate: Date, at currentDate: Date) -> Bool {
        if isNextCourseOnLaterDay(targetDate, than: currentDate) {
            return false
        }
        guard AfterLastBellBridge.shouldHideUntilOneHourBefore else {
            return false
        }
        guard !Calendar.autoupdatingCurrent.isDate(
            displayDate(for: currentDate),
            inSameDayAs: displayDate(for: targetDate)
        ) else {
            return false
        }
        return currentDate < targetDate.addingTimeInterval(-60 * 60)
    }
}

private struct BellLockScreenView: View {
    let context: ActivityViewContext<BellActivityAttributes>

    var body: some View {
        let timing = BellActivityTiming(state: context.state)
        // La timeline ne sert qu'à basculer de cible aux bornes prévues.
        // Le Text temporel ci-dessous est actualisé directement par le système.
        TimelineView(.explicit(timing.timelineDates)) { timeline in
            let targetDate = timing.nextTarget(after: timeline.date)
            let isDistantCourse = targetDate.map {
                timing.isNextCourseOnLaterDay($0, than: timeline.date)
            } ?? false

            VStack(spacing: 6) {
                BellActivityHeader(
                    siteName: context.attributes.siteName,
                    currentDate: timeline.date,
                    targetDate: targetDate,
                    timing: timing,
                    courseDetails: targetDate.flatMap(timing.courseDetails(at:))
                )
                .font(isDistantCourse ? .title3 : .headline)
                .fontWeight(.semibold)
                .lineLimit(isDistantCourse ? 4 : 1)
                .minimumScaleFactor(isDistantCourse ? 0.85 : 0.7)
                .foregroundStyle(.secondary)

                if let targetDate,
                   !isDistantCourse,
                   !timing.shouldHide(targetDate: targetDate, at: timeline.date) {
                    BellMinuteCountdown(
                        targetDate: targetDate
                    )
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                } else if targetDate == nil {
                    Text(verbatim: "—")
                }
            }
        }
    }
}

private struct BellActivityHeader: View {
    let siteName: String
    let currentDate: Date
    let targetDate: Date?
    let timing: BellActivityTiming
    let courseDetails: CourseActivityDetails?

    var body: some View {
        if let targetDate,
           timing.isNextCourseOnLaterDay(targetDate, than: currentDate) {
            VStack(spacing: 3) {
                Text("Début du prochain cours")
                Text(
                    timing.displayDate(for: targetDate),
                    format: .dateTime.weekday(.wide).day().month(.wide).hour().minute()
                )
                if let courseDetails {
                    BellCourseLocationRow(
                        siteName: courseDetails.siteName ?? siteName,
                        roomName: courseDetails.roomName
                    )
                }
                BellDistantDurationText(
                    currentDate: currentDate,
                    targetDate: targetDate
                )
            }
            .multilineTextAlignment(.center)
        } else {
            Text(siteName)
        }
    }
}

private struct BellCourseLocationRow: View {
    let siteName: String
    let roomName: String

    var body: some View {
        HStack(spacing: 14) {
            Label(siteName, systemImage: "building.2")
            Label(roomName, systemImage: "door.left.hand.open")
        }
        .font(.subheadline.weight(.semibold))
    }
}

private struct BellDistantDurationText: View {
    let currentDate: Date
    let targetDate: Date

    var body: some View {
        let remainingSeconds = max(0, targetDate.timeIntervalSince(currentDate))
        let totalHours = max(1, Int(remainingSeconds / (60 * 60)))
        let days = totalHours / 24
        let hours = totalHours % 24

        if days == 1 {
            Text("1 jour \(hours, format: .number) h")
                .monospacedDigit()
        } else if days > 1 {
            Text("\(days, format: .number) jours \(hours, format: .number) h")
                .monospacedDigit()
        } else {
            Text("\(hours, format: .number) h")
                .monospacedDigit()
        }
    }
}

private struct BellMinuteCountdown: View {
    let targetDate: Date

    var body: some View {
        Text(
            .currentDate,
            format: .offset(
                to: BellCountdownClock.minuteDisplayTarget(targetDate),
                allowedFields: [.minute],
                maxFieldCount: 1,
                sign: .never
            )
        )
        .monospacedDigit()
    }
}

private struct BellDynamicIslandCountdown: View {
    let context: ActivityViewContext<BellActivityAttributes>

    var body: some View {
        let timing = BellActivityTiming(state: context.state)
        TimelineView(.explicit(timing.timelineDates)) { timeline in
            if let targetDate = timing.nextTarget(after: timeline.date),
               !timing.shouldHide(targetDate: targetDate, at: timeline.date) {
                if timing.isNextCourseOnLaterDay(targetDate, than: timeline.date) {
                    let dayCount = timing.calendarDayCount(
                        to: targetDate,
                        from: timeline.date
                    )
                    Text("\(dayCount, format: .number) j")
                        .monospacedDigit()
                } else {
                    let countdownStart = max(
                        context.state.startDate,
                        timing.systemStartOfDisplayDay(containing: targetDate)
                    )
                    Text(
                        .currentDate,
                        format: .timer(
                            countingDownIn: countdownStart..<targetDate,
                            showsHours: true,
                            maxFieldCount: 2,
                            maxPrecision: .seconds(1)
                        )
                    )
                    .monospacedDigit()
                    .frame(width: 34, alignment: .trailing)
                }
            } else {
                Text(verbatim: "—")
            }
        }
    }
}

/// Présentation de la Live Activity sur l'écran verrouillé et dans la Dynamic Island.
struct NextBellLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BellActivityAttributes.self) { context in
            // Écran verrouillé / Always-On : nom du site + minutes restantes.
            BellLockScreenView(context: context)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .environment(\.locale, appDisplayLocale())
            .activityBackgroundTint(.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)

            } compactTrailing: {
                BellDynamicIslandCountdown(context: context)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

            } minimal: {
                Image(systemName: "bell.fill")
            }
        }
    }
}

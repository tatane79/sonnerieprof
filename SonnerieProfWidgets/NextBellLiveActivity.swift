import ActivityKit
import SwiftUI
import WidgetKit

private struct BellActivityTarget {
    let date: Date
    let courseDetails: CourseActivityDetails?
}

private struct BellTimelineSchedule: TimelineSchedule {
    private let dates: [Date]

    init(state: BellActivityAttributes.ContentState) {
        let activityEnd = min(
            state.bellDates.last ?? state.startDate.addingTimeInterval(8 * 60 * 60),
            state.startDate.addingTimeInterval(8 * 60 * 60)
        )
        let courseBoundaries = (state.courseDetails ?? []).flatMap { course in
            [course.startDate, course.endDate].compactMap { $0 }
        }
        let boundaries = state.bellDates + courseBoundaries
        let boundaryRefreshes = boundaries.flatMap { boundary in
            [
                boundary,
                boundary.addingTimeInterval(0.3),
                boundary.addingTimeInterval(2)
            ]
        }

        var minuteRefreshes: [Date] = []
        var minute = Calendar.autoupdatingCurrent.date(
            bySetting: .second,
            value: 0,
            of: state.startDate
        )?.addingTimeInterval(60) ?? state.startDate.addingTimeInterval(60)

        while minute <= activityEnd {
            minuteRefreshes.append(minute)
            minute = minute.addingTimeInterval(60)
        }

        dates = Array(
            Set(boundaryRefreshes + minuteRefreshes)
        ).sorted()
    }

    func entries(from startDate: Date, mode: Mode) -> [Date] {
        dates.filter { $0 >= startDate }
    }
}

#if DEBUG
private func logBellTimelineUpdate(
    _ date: Date,
    cadenceDescription: String,
    presentation: String
) {
    print(
        "🔔 Live Activity \(presentation) refresh at \(date), cadence: \(cadenceDescription)"
    )
}
#endif

private struct BellActivityTiming {
    let state: BellActivityAttributes.ContentState

    func target(after date: Date) -> BellActivityTarget? {
        let boundaryTolerance: TimeInterval = 0.5
        guard let nextBoundary = state.bellDates
            .filter({ $0.timeIntervalSince(date) > boundaryTolerance })
            .min() else {
            return nil
        }

        return BellActivityTarget(
            date: nextBoundary,
            courseDetails: courseDetails(at: nextBoundary)
        )
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
        state.courseDetails?.first { course in
            abs(course.startDate.timeIntervalSince(targetDate)) < 1
                || course.endDate.map {
                    abs($0.timeIntervalSince(targetDate)) < 1
                } == true
        }
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
        // La timeline déclenche les rafraîchissements, mais sa date peut correspondre
        // à une entrée qu'iOS prépare en avance. La date réelle doit rester la référence
        // pour ne pas sélectionner prématurément la sonnerie suivante.
        TimelineView(BellTimelineSchedule(state: context.state)) { timeline in
#if DEBUG
            let _ = logBellTimelineUpdate(
                timeline.date,
                cadenceDescription: String(describing: timeline.cadence),
                presentation: "Lock Screen"
            )
#endif
            let currentDate = Date.now
            let target = timing.target(after: currentDate)
            let targetDate = target?.date
            let isDistantCourse = targetDate.map {
                timing.isNextCourseOnLaterDay($0, than: currentDate)
            } ?? false

            VStack(spacing: 6) {
                BellActivityHeader(
                    siteName: context.attributes.siteName,
                    currentDate: currentDate,
                    targetDate: targetDate,
                    timing: timing,
                    courseDetails: target?.courseDetails
                )
                .font(isDistantCourse ? .title3 : .headline)
                .fontWeight(.semibold)
                .lineLimit(isDistantCourse ? 4 : 1)
                .minimumScaleFactor(isDistantCourse ? 0.85 : 0.7)
                .foregroundStyle(.secondary)

                if let targetDate,
                   !timing.shouldHide(targetDate: targetDate, at: currentDate) {
                    Group {
                        if BellCountdownClock.showsDaysAndHours(
                            from: currentDate,
                            to: targetDate
                        ) {
                            BellDayHourCountdown(
                                currentDate: currentDate,
                                targetDate: targetDate
                            )
                        } else {
                            BellSystemCountdown(
                                startDate: context.state.startDate,
                                currentDate: currentDate,
                                targetDate: targetDate
                            )
                        }
                    }
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                } else if targetDate == nil {
                    Text(verbatim: "—")
                }
            }
        }
    }
}

private struct BellDayHourCountdown: View {
    let currentDate: Date
    let targetDate: Date

    var body: some View {
        let components = BellCountdownClock.dayHourComponents(
            from: currentDate,
            to: targetDate
        )

        Text(
            "\(components.days, format: .number) j \(components.hours, format: .number.precision(.integerLength(2))) h",
            comment: "Compte à rebours supérieur à 24 heures : nombre de jours, puis nombre d'heures sur deux chiffres."
        )
        .monospacedDigit()
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

private struct BellDynamicIslandCountdown: View {
    let context: ActivityViewContext<BellActivityAttributes>

    var body: some View {
        let timing = BellActivityTiming(state: context.state)
        let currentDate = Date.now

        if let targetDate = timing.target(after: currentDate)?.date,
           !timing.shouldHide(targetDate: targetDate, at: currentDate) {
            if timing.isNextCourseOnLaterDay(targetDate, than: currentDate) {
                let dayCount = timing.calendarDayCount(
                    to: targetDate,
                    from: currentDate
                )
                Text("\(dayCount, format: .number) j")
                    .monospacedDigit()
            } else {
                Text(
                    timerInterval: context.state.startDate...targetDate,
                    countsDown: true
                )
                .monospacedDigit()
            }
        } else {
            Text(verbatim: "—")
        }
    }
}

private struct BellSystemCountdown: View {
    let startDate: Date
    let currentDate: Date
    let targetDate: Date

    var body: some View {
        let intervalStart = min(startDate, currentDate)

        if BellCountdownClock.showsSeconds(from: currentDate, to: targetDate) {
            Text(
                .currentDate,
                format: .timer(
                    countingDownIn: intervalStart..<targetDate,
                    showsHours: true,
                    maxFieldCount: 2,
                    maxPrecision: .seconds(1)
                )
            )
            .monospacedDigit()
        } else {
            Text(
                .currentDate,
                // Le texte est rendu hors du processus de l'extension :
                // conserver un format système pour la Live Activity.
                format: .timer(
                    countingDownIn: intervalStart..<targetDate,
                    showsHours: true,
                    maxFieldCount: 2,
                    maxPrecision: .seconds(60)
                )
            )
            .monospacedDigit()
        }
    }
}

private struct BellDynamicIslandExpandedView: View {
    let context: ActivityViewContext<BellActivityAttributes>

    var body: some View {
        let timing = BellActivityTiming(state: context.state)
        let currentDate = Date.now

        VStack(spacing: 4) {
            Text(context.attributes.siteName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let targetDate = timing.target(after: currentDate)?.date {
                Group {
                    if BellCountdownClock.showsDaysAndHours(
                        from: currentDate,
                        to: targetDate
                    ) {
                        BellDayHourCountdown(
                            currentDate: currentDate,
                            targetDate: targetDate
                        )
                    } else {
                        BellSystemCountdown(
                            startDate: context.state.startDate,
                            currentDate: currentDate,
                            targetDate: targetDate
                        )
                    }
                }
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
            // Écran verrouillé / Always-On : même format que le plein écran.
            BellLockScreenView(context: context)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .environment(\.locale, appDisplayLocale())
            .activityBackgroundTint(.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    BellDynamicIslandExpandedView(context: context)
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
                    .minimumScaleFactor(0.5)
                    .frame(width: 44, alignment: .trailing)

            } minimal: {
                Image(systemName: "bell.fill")
            }
        }
    }
}

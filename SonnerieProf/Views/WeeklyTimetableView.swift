import SwiftUI

struct TimetableWeekSettings: View {
    let firstWeekName: String
    let secondWeekName: String
    let currentWeekSelection: Binding<TeachingWeek>
    let firstWeekNameBinding: Binding<String>
    let secondWeekNameBinding: Binding<String>
    @Binding var isCustomizingWeekNames: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Semaine actuelle"))
                .font(.headline)

            Picker(L("Semaine actuelle"), selection: currentWeekSelection) {
                Text(firstWeekName).tag(TeachingWeek.q1)
                Text(secondWeekName).tag(TeachingWeek.q2)
            }
            .pickerStyle(.segmented)

            DisclosureGroup(
                L("Personnaliser les noms des semaines"),
                isExpanded: $isCustomizingWeekNames
            ) {
                VStack(spacing: 10) {
                    TextField(
                        L("Nom de la première semaine"),
                        text: firstWeekNameBinding,
                        prompt: Text("Q1")
                    )
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)

                    TextField(
                        L("Nom de la deuxième semaine"),
                        text: secondWeekNameBinding,
                        prompt: Text("Q2")
                    )
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                }
                .padding(.top, 8)
            }

            Text(
                L("Choisissez le type de la semaine actuelle. L’application alternera ensuite automatiquement entre le premier et le second type de semaine.")
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TeachingWeekSelectionControl: View {
    let firstWeekName: String
    let secondWeekName: String
    @Binding var selection: TeachingWeek

    var body: some View {
        HStack(spacing: 6) {
            TeachingWeekSelectionButton(
                name: firstWeekName,
                color: .blue,
                isSelected: selection == .q1
            ) {
                selection = .q1
            }

            TeachingWeekSelectionButton(
                name: secondWeekName,
                color: .pink,
                isSelected: selection == .q2
            ) {
                selection = .q2
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }
}

private struct TeachingWeekSelectionButton: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Color.white : color)
                .background(
                    isSelected ? color : color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Lecture calendaire de l'emploi du temps, avec les deux semaines affichées en parallèle.
struct WeeklyTimetableCalendar: View {
    let sessions: [CourseSession]
    let siteNamesByID: [UUID: String]
    let firstWeekName: String
    let secondWeekName: String
    let currentWeek: TeachingWeek
    let onSelectSession: (CourseSession) -> Void

    private let pointsPerMinute: CGFloat = 1.05
    private let dayWidth: CGFloat = 176
    private let timeAxisWidth: CGFloat = 48

    var body: some View {
        let layout = WeeklyTimetableLayout(sessions: sessions)

        TimelineView(.everyMinute) { context in
            let calendar = Calendar.current
            let currentDate = DebugClockBridge.effectiveDate(for: context.date)
            let currentWeekday = calendar.component(.weekday, from: currentDate)
            let currentMinute = calendar.component(.hour, from: currentDate) * 60
                + calendar.component(.minute, from: currentDate)
            let initialWeekday = layout.sessionsByWeekday[currentWeekday] == nil
                ? layout.weekdays.first
                : currentWeekday

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        TimetableTimeAxis(
                            startHour: layout.startHour,
                            endHour: layout.endHour,
                            pointsPerMinute: pointsPerMinute,
                            width: timeAxisWidth
                        )

                        ForEach(layout.weekdays, id: \.self) { weekday in
                            TimetableDayColumn(
                                weekday: weekday,
                                sessions: layout.sessionsByWeekday[weekday] ?? [],
                                siteNamesByID: siteNamesByID,
                                firstWeekName: firstWeekName,
                                secondWeekName: secondWeekName,
                                currentWeek: currentWeek,
                                startHour: layout.startHour,
                                endHour: layout.endHour,
                                isToday: weekday == currentWeekday,
                                currentMinute: weekday == currentWeekday ? currentMinute : nil,
                                pointsPerMinute: pointsPerMinute,
                                width: dayWidth,
                                onSelectSession: onSelectSession
                            )
                            .id(weekday)
                        }
                    }
                }
                .scrollIndicators(.visible)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(L("Emploi du temps")))
                .task(id: initialWeekday) {
                    guard let initialWeekday else { return }
                    await Task.yield()
                    proxy.scrollTo(initialWeekday, anchor: .center)
                }
            }
        }
    }
}

private struct WeeklyTimetableLayout {
    let weekdays: [Int]
    let startHour: Int
    let endHour: Int
    let sessionsByWeekday: [Int: [CourseSession]]

    init(sessions: [CourseSession]) {
        let validSessions = sessions.filter { (2...7).contains($0.weekday) }
        let firstWeekday = validSessions.map(\.weekday).min() ?? 2
        let lastWeekday = validSessions.map(\.weekday).max() ?? firstWeekday
        let earliestMinute = validSessions.map(\.startMinutes).min() ?? 8 * 60
        let latestMinute = validSessions.map(\.endMinutes).max() ?? 17 * 60

        weekdays = Array(firstWeekday...lastWeekday)
        startHour = max(0, earliestMinute / 60)
        endHour = min(24, max(startHour + 1, (latestMinute + 59) / 60))
        sessionsByWeekday = Dictionary(grouping: validSessions, by: \.weekday)
    }
}

private struct TimetableTimeAxis: View {
    let startHour: Int
    let endHour: Int
    let pointsPerMinute: CGFloat
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: TimetableDayHeader.height)

            ZStack(alignment: .topTrailing) {
                Color.clear

                ForEach(startHour...endHour, id: \.self) { hour in
                    Text(hourLabel(hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .offset(y: CGFloat(hour - startHour) * 60 * pointsPerMinute - 7)
                }
            }
            .frame(
                width: width,
                height: CGFloat(endHour - startHour) * 60 * pointsPerMinute
            )
            .padding(.trailing, 6)
        }
        .frame(width: width)
    }

    private func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

private struct TimetableDayColumn: View {
    let weekday: Int
    let sessions: [CourseSession]
    let siteNamesByID: [UUID: String]
    let firstWeekName: String
    let secondWeekName: String
    let currentWeek: TeachingWeek
    let startHour: Int
    let endHour: Int
    let isToday: Bool
    let currentMinute: Int?
    let pointsPerMinute: CGFloat
    let width: CGFloat
    let onSelectSession: (CourseSession) -> Void

    var body: some View {
        VStack(spacing: 0) {
            TimetableDayHeader(
                weekday: weekday,
                firstWeekName: firstWeekName,
                secondWeekName: secondWeekName,
                currentWeek: currentWeek,
                isToday: isToday
            )

            ZStack(alignment: .top) {
                HStack(spacing: 1) {
                    TimetableWeekLane(
                        sessions: sessions.filter { $0.weekPattern == .q1 },
                        siteNamesByID: siteNamesByID,
                        color: .blue,
                        isActiveWeek: currentWeek == .q1,
                        currentMinute: currentMinute,
                        startHour: startHour,
                        endHour: endHour,
                        pointsPerMinute: pointsPerMinute,
                        onSelectSession: onSelectSession
                    )
                    TimetableWeekLane(
                        sessions: sessions.filter { $0.weekPattern == .q2 },
                        siteNamesByID: siteNamesByID,
                        color: .pink,
                        isActiveWeek: currentWeek == .q2,
                        currentMinute: currentMinute,
                        startHour: startHour,
                        endHour: endHour,
                        pointsPerMinute: pointsPerMinute,
                        onSelectSession: onSelectSession
                    )
                }

                TimetableSharedCoursesOverlay(
                    sessions: sessions.filter { $0.weekPattern == .everyWeek },
                    siteNamesByID: siteNamesByID,
                    startHour: startHour,
                    endHour: endHour,
                    pointsPerMinute: pointsPerMinute,
                    onSelectSession: onSelectSession
                )

                if let currentMinute,
                   (startHour * 60...endHour * 60).contains(currentMinute) {
                    let sharedCourseIsCurrent = sessions.contains {
                        $0.weekPattern == .everyWeek
                            && $0.startMinutes <= currentMinute
                            && currentMinute < $0.endMinutes
                    }

                    TimetableCurrentTimeIndicator()
                        .frame(
                            width: sharedCourseIsCurrent
                                ? width
                                : (width - 1) / 2
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: sharedCourseIsCurrent
                                ? .center
                                : (currentWeek == .q1 ? .leading : .trailing)
                        )
                        .offset(
                            y: CGFloat(currentMinute - startHour * 60) * pointsPerMinute
                        )
                }
            }
            .background(Color.secondary.opacity(0.18))
        }
        .frame(width: width)
        .overlay(alignment: .leading) { Divider() }
    }
}

private struct TimetableDayHeader: View {
    static let height: CGFloat = 62

    let weekday: Int
    let firstWeekName: String
    let secondWeekName: String
    let currentWeek: TeachingWeek
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(weekdayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            HStack(spacing: 4) {
                WeekBadge(
                    name: firstWeekName,
                    color: .blue,
                    isActive: currentWeek == .q1
                )
                WeekBadge(
                    name: secondWeekName,
                    color: .pink,
                    isActive: currentWeek == .q2
                )
            }
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(isToday ? Color.accentColor.opacity(0.10) : Color.clear)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var weekdayName: String {
        var calendar = Calendar.current
        calendar.locale = appDisplayLocale()
        let symbols = calendar.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1].localizedCapitalized
    }
}

private struct TimetableCurrentTimeIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 7, height: 7)

            Rectangle()
                .fill(.red)
                .frame(height: 2)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct WeekBadge: View {
    let name: String
    let color: Color
    let isActive: Bool

    var body: some View {
        Text(name)
            .font(.caption2.weight(isActive ? .bold : .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(isActive ? Color.white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .background(
                isActive ? color : color.opacity(0.12),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(color.opacity(isActive ? 1 : 0), lineWidth: 1.5)
            }
            .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct TimetableWeekLane: View {
    let sessions: [CourseSession]
    let siteNamesByID: [UUID: String]
    let color: Color
    let isActiveWeek: Bool
    let currentMinute: Int?
    let startHour: Int
    let endHour: Int
    let pointsPerMinute: CGFloat
    let onSelectSession: (CourseSession) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color(.secondarySystemBackground)

            ForEach(startHour...endHour, id: \.self) { hour in
                Divider()
                    .offset(y: CGFloat(hour - startHour) * 60 * pointsPerMinute)
            }

            ForEach(sessions) { session in
                TimetableCourseButton(
                    session: session,
                    siteName: siteNamesByID[session.siteID],
                    color: color,
                    isCurrentSession: isActiveWeek && currentMinute.map {
                        session.startMinutes <= $0 && $0 < session.endMinutes
                    } == true,
                    startHour: startHour,
                    pointsPerMinute: pointsPerMinute,
                    onSelectSession: onSelectSession
                )
            }
        }
        .frame(height: CGFloat(endHour - startHour) * 60 * pointsPerMinute)
        .opacity(isActiveWeek ? 1 : 0.55)
        .clipped()
    }
}

private struct TimetableSharedCoursesOverlay: View {
    let sessions: [CourseSession]
    let siteNamesByID: [UUID: String]
    let startHour: Int
    let endHour: Int
    let pointsPerMinute: CGFloat
    let onSelectSession: (CourseSession) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(sessions) { session in
                TimetableCourseButton(
                    session: session,
                    siteName: siteNamesByID[session.siteID],
                    color: .gray,
                    isCurrentSession: false,
                    startHour: startHour,
                    pointsPerMinute: pointsPerMinute,
                    onSelectSession: onSelectSession
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: CGFloat(endHour - startHour) * 60 * pointsPerMinute,
            alignment: .top
        )
        .clipped()
    }
}

private struct TimetableCourseButton: View {
    let session: CourseSession
    let siteName: String?
    let color: Color
    let isCurrentSession: Bool
    let startHour: Int
    let pointsPerMinute: CGFloat
    let onSelectSession: (CourseSession) -> Void

    var body: some View {
        Button {
            onSelectSession(session)
        } label: {
            TimetableCourseBlock(
                className: session.className,
                roomName: session.roomName,
                siteName: siteName,
                startMinutes: session.startMinutes,
                endMinutes: session.endMinutes,
                color: color,
                isCurrentSession: isCurrentSession
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .frame(height: blockHeight)
        .clipped()
        .offset(
            y: CGFloat(session.startMinutes - startHour * 60) * pointsPerMinute + 2
        )
    }

    private var blockHeight: CGFloat {
        max(
            1,
            CGFloat(session.endMinutes - session.startMinutes) * pointsPerMinute - 4
        )
    }
}

private struct TimetableCourseBlock: View {
    let className: String
    let roomName: String
    let siteName: String?
    let startMinutes: Int
    let endMinutes: Int
    let color: Color
    let isCurrentSession: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(className)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 2)

                if let siteName, !siteName.isEmpty {
                    Text(siteName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Text(roomName)
                .font(.caption2)
                .lineLimit(1)

            Text(timeRange)
                .font(.system(.caption2, design: .rounded).monospacedDigit())
                .lineLimit(1)

        }
        .foregroundStyle(.primary)
        .padding(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    color.opacity(isCurrentSession ? 1 : 0.45),
                    lineWidth: isCurrentSession ? 2.5 : 1
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                verbatim: [className, siteName, roomName, timeRange]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            )
        )
    }

    private var timeRange: String {
        "\(displayTime(startMinutes))–\(displayTime(endMinutes))"
    }

    private func displayTime(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

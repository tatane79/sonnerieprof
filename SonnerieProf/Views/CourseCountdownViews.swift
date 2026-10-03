import Combine
import SwiftUI
import UIKit

private enum CourseCountdownLocalizationSources {
    static func registerForExtraction() {
        _ = String(localized: "Prochaine sonnerie à %@")
        _ = String(localized: "Fin du cours à %@")
        _ = String(localized: "Début du prochain cours\n%@")
        _ = String(localized: "Début du prochain cours à %@")
    }
}

private struct DistantCourseCountdownText: View {
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

/// Carte principale : décompte vers la fin du cours ou le prochain cours.
/// Sans emploi du temps, elle revient automatiquement à la prochaine sonnerie.
struct CourseCountdownCard: View {
    let sessions: [CourseSession]
    let sites: [BellSite]
    let referenceWeekStart: Date
    let referenceWeek: TeachingWeek
    let fallbackSite: BellSite?
    let suspendedUntil: Date?
    let timeOffset: TimeInterval
    let onShowFullscreen: () -> Void

    private let engine = TimetableEngine()
    private let bellEngine = ScheduleEngine()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let displayDate = context.date.addingTimeInterval(timeOffset)
            let status = engine.status(
                at: displayDate,
                sessions: sessions,
                referenceWeekStart: referenceWeekStart,
                referenceWeek: referenceWeek
            )
            let fallbackBell = sessions.isEmpty
                ? fallbackSite.flatMap {
                    bellEngine.nextBell(
                        after: displayDate,
                        at: $0,
                        suspendedUntil: suspendedUntil
                    )
                }
                : nil

            if let target = status.current?.endDate ?? status.next?.startDate ?? fallbackBell {
                let systemTarget = target.addingTimeInterval(-timeOffset)
                let occurrence = status.current ?? status.next

                VStack(spacing: 16) {
                    if let occurrence {
                        Text(occurrence.session.className)
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)

                        HStack(spacing: 12) {
                            Label(
                                occurrence.session.roomName,
                                systemImage: "door.left.hand.open"
                            )

                            if let siteName = siteName(for: occurrence.session.siteID) {
                                Label(siteName, systemImage: "building.2")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    } else if let fallbackSite {
                        Text(fallbackSite.name)
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                    }

                    countdownText(
                        from: context.date,
                        to: systemTarget,
                        omitsSeconds: isOnLaterDay(target, than: displayDate)
                    )
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.45)
                    .accessibilityLabel("Temps restant")

                    Text(targetLabel(
                        status: status,
                        target: target,
                        displayDate: displayDate,
                        isFallbackBell: fallbackBell != nil
                    ))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .padding(.horizontal)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(alignment: .topTrailing) {
                    Button(action: onShowFullscreen) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.headline.weight(.semibold))
                            .padding(10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Afficher en plein écran")
                    .padding(6)
                }
            } else {
                ContentUnavailableView(
                    "Aucun cours programmé",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Ajoutez vos séances dans l’emploi du temps.")
                )
            }
        }
    }

    private func targetLabel(
        status: CourseStatus,
        target: Date,
        displayDate: Date,
        isFallbackBell: Bool
    ) -> String {
        let time = bellEngine.displayTime(for: target)
        if isFallbackBell {
            return L("Prochaine sonnerie à %@", time)
        }
        if status.current != nil {
            return L("Fin du cours à %@", time)
        }
        if isOnLaterDay(target, than: displayDate) {
            let dayAndTime = bellEngine.displayLongDayAndTime(for: target)
            return L("Début du prochain cours\n%@", dayAndTime)
        }
        return L("Début du prochain cours à %@", time)
    }

    @ViewBuilder
    private func countdownText(from startDate: Date, to targetDate: Date, omitsSeconds: Bool) -> some View {
        if omitsSeconds {
            DistantCourseCountdownText(
                currentDate: startDate,
                targetDate: targetDate
            )
        } else {
            Text(
                timerInterval: startDate...targetDate,
                pauseTime: targetDate,
                countsDown: true,
                showsHours: true
            )
        }
    }

    private func isOnLaterDay(_ target: Date, than displayDate: Date) -> Bool {
        !Calendar.autoupdatingCurrent.isDate(target, inSameDayAs: displayDate)
    }

    private func siteName(for id: UUID) -> String? {
        sites.first(where: { $0.id == id })?.name
    }
}

/// Variante plein écran du même compte à rebours, destinée à rester lisible de loin.
struct CourseFullscreenCountdownView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previousIdleTimerDisabled = false
    @State private var isManagingIdleTimer = false

    let sessions: [CourseSession]
    let sites: [BellSite]
    let referenceWeekStart: Date
    let referenceWeek: TeachingWeek
    let fallbackSite: BellSite?
    let suspendedUntil: Date?
    let timeOffset: TimeInterval
    let onTimerTick: (Date) -> Void

    private let engine = TimetableEngine()
    private let bellEngine = ScheduleEngine()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let displayDate = context.date.addingTimeInterval(timeOffset)
                let status = engine.status(
                    at: displayDate,
                    sessions: sessions,
                    referenceWeekStart: referenceWeekStart,
                    referenceWeek: referenceWeek
                )
                let fallbackBell = sessions.isEmpty
                    ? fallbackSite.flatMap {
                        bellEngine.nextBell(
                            after: displayDate,
                            at: $0,
                            suspendedUntil: suspendedUntil
                        )
                    }
                    : nil

                ZStack {
                    Color.black.ignoresSafeArea()

                    if let target = status.current?.endDate ?? status.next?.startDate ?? fallbackBell {
                        let systemTarget = target.addingTimeInterval(-timeOffset)
                        let occurrence = status.current ?? status.next

                        VStack(spacing: 24) {
                            if let occurrence {
                                Text(occurrence.session.className)
                                    .font(.system(size: min(geometry.size.width * 0.1, 48), weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                HStack(spacing: 16) {
                                    Label(occurrence.session.roomName, systemImage: "door.left.hand.open")

                                    if let siteName = sites.first(where: { $0.id == occurrence.session.siteID })?.name {
                                        Label(siteName, systemImage: "building.2")
                                    }
                                }
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))
                            } else if let fallbackSite {
                                Text(fallbackSite.name)
                                    .font(.system(size: min(geometry.size.width * 0.1, 48), weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            countdownText(
                                from: context.date,
                                to: systemTarget,
                                omitsSeconds: isOnLaterDay(target, than: displayDate)
                            )
                            .font(.system(size: min(geometry.size.width * 0.28, 160), weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                            .foregroundStyle(.white)

                            Text(targetLabel(
                                status: status,
                                target: target,
                                displayDate: displayDate,
                                isFallbackBell: fallbackBell != nil
                            ))
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(30)
                    } else {
                        ContentUnavailableView(
                            "Aucun cours programmé",
                            systemImage: "calendar.badge.exclamationmark"
                        )
                        .foregroundStyle(.white)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(.white)
            .padding()
            .accessibilityLabel("Fermer")
        }
        .persistentSystemOverlays(.hidden)
        .onReceive(
            Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        ) { date in
            onTimerTick(date)
        }
        .onAppear {
            guard !isManagingIdleTimer else { return }
            previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            isManagingIdleTimer = true
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            guard isManagingIdleTimer else { return }
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
            isManagingIdleTimer = false
        }
    }

    private func targetLabel(
        status: CourseStatus,
        target: Date,
        displayDate: Date,
        isFallbackBell: Bool
    ) -> String {
        let time = bellEngine.displayTime(for: target)
        if isFallbackBell {
            return L("Prochaine sonnerie à %@", time)
        }
        if status.current != nil {
            return L("Fin du cours à %@", time)
        }
        if isOnLaterDay(target, than: displayDate) {
            let dayAndTime = bellEngine.displayLongDayAndTime(for: target)
            return L("Début du prochain cours\n%@", dayAndTime)
        }
        return L("Début du prochain cours à %@", time)
    }

    @ViewBuilder
    private func countdownText(from startDate: Date, to targetDate: Date, omitsSeconds: Bool) -> some View {
        if omitsSeconds {
            DistantCourseCountdownText(
                currentDate: startDate,
                targetDate: targetDate
            )
        } else if targetDate.timeIntervalSince(startDate) >= 2 * 60 {
            let remainingMinutes = BellCountdownClock.remainingMinutes(
                from: startDate,
                to: targetDate
            )
            Text("\(remainingMinutes, format: .number) min")
                .monospacedDigit()
        } else {
            Text(
                timerInterval: startDate...targetDate,
                pauseTime: targetDate,
                countsDown: true,
                showsHours: true
            )
        }
    }

    private func isOnLaterDay(_ target: Date, than displayDate: Date) -> Bool {
        !Calendar.autoupdatingCurrent.isDate(target, inSameDayAs: displayDate)
    }
}

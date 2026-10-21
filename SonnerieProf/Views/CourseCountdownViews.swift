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
        let components = BellCountdownClock.components(from: currentDate, to: targetDate)

        if components.hasDays {
            Text("\(components.days, format: .number) j \(components.hours, format: .number)h\(components.minutes, format: .number.precision(.integerLength(2)))min")
                .monospacedDigit()
        } else if components.hasHours {
            Text("\(components.hours, format: .number)h\(components.minutes, format: .number.precision(.integerLength(2)))min")
                .monospacedDigit()
        } else {
            Text("\(components.minutes, format: .number) min")
                .monospacedDigit()
        }
    }
}

/// Carte principale : décompte vers la fin du cours ou le prochain cours.
/// Sans emploi du temps, elle revient automatiquement à la prochaine sonnerie.
struct CourseCountdownCard: View {
    @Binding var showsNextBell: Bool

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
            let nextBell = fallbackSite.flatMap {
                bellEngine.nextBell(
                    after: displayDate,
                    at: $0,
                    suspendedUntil: suspendedUntil
                )
            }
            let usesBellCountdown = sessions.isEmpty || showsNextBell
            let courseTarget = status.current?.endDate ?? status.next?.startDate
            let target = usesBellCountdown ? nextBell : courseTarget

            if let target {
                let systemTarget = target.addingTimeInterval(-timeOffset)
                let occurrence = usesBellCountdown ? nil : (status.current ?? status.next)

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
                        isFallbackBell: usesBellCountdown
                    ))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if !sessions.isEmpty, fallbackSite != nil {
                        Toggle(isOn: $showsNextBell) {
                            if showsNextBell {
                                Text("Prochaine sonnerie")
                            } else {
                                Text("Prochain cours")
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .toggleStyle(.switch)
                        .accessibilityHint("Change la destination du compte à rebours")
                    }
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousIdleTimerDisabled = false
    @State private var isManagingIdleTimer = false

    let showsNextBell: Bool
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
                let usesBellCountdown = sessions.isEmpty || showsNextBell
                let fallbackBell = usesBellCountdown
                    ? fallbackSite.flatMap {
                        bellEngine.nextBell(
                            after: displayDate,
                            at: $0,
                            suspendedUntil: suspendedUntil
                        )
                    }
                    : nil

                let courseTarget = status.current?.endDate ?? status.next?.startDate
                let target = usesBellCountdown ? fallbackBell : courseTarget

                ZStack {
                    Color.black.ignoresSafeArea()

                    if let target {
                        let systemTarget = target.addingTimeInterval(-timeOffset)
                        let occurrence = usesBellCountdown ? nil : (status.current ?? status.next)

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

                            Text(
                                .currentDate,
                                format: BellCountdownFormatStyle(
                                    targetDate: systemTarget,
                                    presentation: .full
                                )
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
                                isFallbackBell: usesBellCountdown
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, isManagingIdleTimer else { return }
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

    private func isOnLaterDay(_ target: Date, than displayDate: Date) -> Bool {
        !Calendar.autoupdatingCurrent.isDate(target, inSameDayAs: displayDate)
    }
}

import SwiftUI

struct ContentView: View {
    @State private var model = WatchScheduleModel()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let displayDate = model.effectiveDate(for: context.date)

            WatchStatusView(
                status: model.status(at: displayDate),
                displayDate: displayDate,
                hasSynchronizationError: model.synchronizationError,
                refreshAction: model.refresh
            )
        }
    }
}

private struct WatchStatusView: View {
    let status: WatchScheduleStatus
    let displayDate: Date
    let hasSynchronizationError: Bool
    let refreshAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            switch status {
            case .waitingForSynchronization:
                WaitingForSynchronizationView()

            case let .noUpcomingEvent(siteName, synchronizedAt):
                NoUpcomingEventView(
                    siteName: siteName,
                    synchronizedAt: synchronizedAt
                )

            case let .upcoming(
                title,
                target,
                isCourseEnd,
                synchronizedAt
            ):
                UpcomingEventView(
                    title: title,
                    target: target,
                    displayDate: displayDate,
                    isCourseEnd: isCourseEnd,
                    synchronizedAt: synchronizedAt
                )
            }

            if hasSynchronizationError {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Échec de la dernière synchronisation")
            }

            Button(action: refreshAction) {
                Label("Synchroniser", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Synchroniser avec l’iPhone")
        }
        .padding(.horizontal, 6)
    }
}

private struct WaitingForSynchronizationView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title2)
                .foregroundStyle(.tint)

            Text("Ouvrez Sonnerie Prof sur l’iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Les données seront ensuite disponibles sans l’iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct NoUpcomingEventView: View {
    let siteName: String?
    let synchronizedAt: Date

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "bell.slash")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Aucune sonnerie prévue")
                .font(.headline)
                .multilineTextAlignment(.center)

            if let siteName {
                Text(siteName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            SynchronizationDateView(date: synchronizedAt)
        }
    }
}

private struct UpcomingEventView: View {
    let title: String
    let target: Date
    let displayDate: Date
    let isCourseEnd: Bool
    let synchronizedAt: Date

    var body: some View {
        VStack(spacing: 4) {
            Text(isCourseEnd ? "Fin dans" : "Prochaine sonnerie")
                .font(.caption)
                .foregroundStyle(.secondary)

            WatchCountdownText(
                currentDate: displayDate,
                target: target
            )

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(target, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            SynchronizationDateView(date: synchronizedAt)
        }
    }
}

private struct WatchCountdownText: View {
    let currentDate: Date
    let target: Date

    var body: some View {
        let remainingSeconds = max(
            0,
            Int(ceil(target.timeIntervalSince(currentDate)))
        )

        if remainingSeconds < 60 {
            Text("\(remainingSeconds) s")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else {
            let remainingMinutes = Int(
                ceil(Double(remainingSeconds) / 60)
            )

            Text("\(remainingMinutes) min")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

private struct SynchronizationDateView: View {
    let date: Date

    var body: some View {
        HStack(spacing: 3) {
            Text("Synchronisé")
            Text(date, format: .dateTime.hour().minute())
        }
        .font(.system(.caption2, design: .rounded))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }
}

#Preview {
    ContentView()
}

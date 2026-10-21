import ActivityKit
import Foundation

/// Règle de décompte commune à l'app et à la Live Activity.
/// Une minute commencée reste affichée jusqu'à son expiration complète.
enum BellCountdownClock {
    static let secondsDisplayThreshold: TimeInterval = 3 * 60
    static let dayHourDisplayThreshold: TimeInterval = 24 * 60 * 60

    struct Components: Equatable {
        let days: Int
        let hours: Int
        let minutes: Int

        var hasDays: Bool { days > 0 }
        var hasHours: Bool { hours > 0 }
    }

    static func remainingMinutes(from currentDate: Date, to targetDate: Date) -> Int {
        let remainingSeconds = max(0, targetDate.timeIntervalSince(currentDate))
        return max(1, Int((remainingSeconds / 60).rounded(.up)))
    }

    static func components(from currentDate: Date, to targetDate: Date) -> Components {
        let totalMinutes = remainingMinutes(from: currentDate, to: targetDate)
        return Components(
            days: totalMinutes / (24 * 60),
            hours: (totalMinutes % (24 * 60)) / 60,
            minutes: totalMinutes % 60
        )
    }

    static func dayHourComponents(from currentDate: Date, to targetDate: Date) -> Components {
        let totalHours = max(0, Int(targetDate.timeIntervalSince(currentDate) / (60 * 60)))
        return Components(
            days: totalHours / 24,
            hours: totalHours % 24,
            minutes: 0
        )
    }

    static func showsSeconds(from currentDate: Date, to targetDate: Date) -> Bool {
        targetDate.timeIntervalSince(currentDate) < secondsDisplayThreshold
    }

    static func showsDaysAndHours(from currentDate: Date, to targetDate: Date) -> Bool {
        targetDate.timeIntervalSince(currentDate) > dayHourDisplayThreshold
    }

    /// `Date.OffsetFormatStyle` tronque les minutes. Ce décalage lui applique
    /// la même règle d'arrondi vers le haut que `remainingMinutes`.
    static func minuteDisplayTarget(_ targetDate: Date) -> Date {
        targetDate.addingTimeInterval(60 - 0.001)
    }
}

/// Format dynamique utilisé par SwiftUI et WidgetKit sans exécution périodique de l'extension.
struct BellCountdownFormatStyle: DiscreteFormatStyle, Codable, Hashable {
    enum Presentation: String, Codable, Hashable {
        case full
        case compact
    }

    let targetDate: Date
    let presentation: Presentation

    func format(_ value: Date) -> String {
        let remainingSeconds = max(0, Int(ceil(targetDate.timeIntervalSince(value))))

        if remainingSeconds < Int(BellCountdownClock.secondsDisplayThreshold) {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return "\(minutes):\(String(format: "%02d", seconds))"
        }

        let totalMinutes = max(1, Int(ceil(Double(remainingSeconds) / 60)))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        let paddedMinutes = String(format: "%02d", minutes)

        if days > 0 {
            return presentation == .full
                ? "\(days) j \(hours) h \(paddedMinutes) min"
                : "\(days) j \(hours)h\(paddedMinutes)"
        }
        if hours > 0 {
            return presentation == .full
                ? "\(hours) h \(paddedMinutes) min"
                : "\(hours)h\(paddedMinutes)"
        }
        return presentation == .full ? "\(minutes) min" : "\(minutes)min"
    }

    func discreteInput(after input: Date) -> Date? {
        let remainingSeconds = targetDate.timeIntervalSince(input)
        guard remainingSeconds > 0 else { return nil }

        if remainingSeconds <= BellCountdownClock.secondsDisplayThreshold {
            return min(targetDate, input.addingTimeInterval(1))
        }

        let displayedMinutes = Int(ceil(remainingSeconds / 60))
        let nextBoundary = targetDate.addingTimeInterval(
            -TimeInterval((displayedMinutes - 1) * 60)
        )
        return max(input.addingTimeInterval(0.001), nextBoundary)
    }

    func discreteInput(before input: Date) -> Date? {
        input.addingTimeInterval(
            targetDate.timeIntervalSince(input) <= BellCountdownClock.secondsDisplayThreshold
                ? -1
                : -60
        )
    }
}

struct CourseActivityDetails: Codable, Hashable {
    let startDate: Date
    let endDate: Date?
    let siteName: String?
    let roomName: String
    let className: String
}

/// Contrat de données partagé entre l'app et l'extension ActivityKit.
struct BellActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date

        /// Dates de sonnerie sur l'horloge système.
        /// Toutes les sonneries futures sont embarquées dans l'état afin que
        /// l'extension puisse choisir la prochaine à partir de l'heure courante.
        var bellDates: [Date]

        /// Décalage du mode développeur entre l'horloge simulée et l'horloge
        /// système. Nil en production.
        var simulatedTimeOffset: TimeInterval? = nil

        /// Indique que les dates représentent les débuts et fins de cours,
        /// plutôt que les sonneries générales d'un établissement.
        var usesCourseSchedule: Bool? = nil

        /// Informations nécessaires pour décrire les futurs débuts de cours
        /// sans que l'extension ait à relire l'emploi du temps de l'app.
        var courseDetails: [CourseActivityDetails]? = nil
    }

    var siteName: String
}

import ActivityKit
import Foundation

/// Règle de décompte commune à l'app et à la Live Activity.
/// Une minute commencée reste affichée jusqu'à son expiration complète.
enum BellCountdownClock {
    static func remainingMinutes(from currentDate: Date, to targetDate: Date) -> Int {
        let remainingSeconds = max(0, targetDate.timeIntervalSince(currentDate))
        return max(1, Int((remainingSeconds / 60).rounded(.up)))
    }

    /// `Date.OffsetFormatStyle` tronque les minutes. Ce décalage lui applique
    /// la même règle d'arrondi vers le haut que `remainingMinutes`.
    static func minuteDisplayTarget(_ targetDate: Date) -> Date {
        targetDate.addingTimeInterval(60 - 0.001)
    }
}

struct CourseActivityDetails: Codable, Hashable {
    let startDate: Date
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

import Foundation

/// Identifiant du conteneur partagé entre l'application et la Live Activity.
enum AppGroup {
    static let identifier = "group.fr.jonathanlafarge.sonnerieprof.shared"
}

/// Horloge de simulation disponible uniquement en Debug.
/// Elle permet de tester ensemble l'app et la Live Activity à une autre date sans modifier
/// l'horloge de l'iPhone. Une compilation Release utilise toujours l'heure réelle.
enum DebugClockBridge {
    static let enabledKey = "debug.simulatedTimeEnabled"
    static let offsetKey = "debug.simulatedTimeOffset"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static var isEnabled: Bool {
#if DEBUG
        defaults.bool(forKey: enabledKey)
#else
        false
#endif
    }

    static var offset: TimeInterval {
#if DEBUG
        isEnabled ? defaults.double(forKey: offsetKey) : 0
#else
        0
#endif
    }

    static func effectiveDate(for systemDate: Date) -> Date {
        systemDate.addingTimeInterval(offset)
    }

    static func systemDate(for effectiveDate: Date) -> Date {
        effectiveDate.addingTimeInterval(-offset)
    }
}

/// Partage la langue de test choisie en Debug avec toutes les extensions.
enum DebugLanguageBridge {
    static let languageKey = "debug.interfaceLanguage"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static var languageCode: String? {
#if DEBUG
        let value = defaults.string(forKey: languageKey) ?? "system"
        return value == "system" ? nil : value
#else
        return nil
#endif
    }
}

/// Expose à la Live Activity la préférence d'affichage après la dernière sonnerie du jour.
enum AfterLastBellBridge {
    static let preferenceKey = "display.afterLastBell"

    static let showNextBell = "showNextBell"
    static let hideUntilOneHourBefore = "hideUntilOneHourBefore"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static var shouldHideUntilOneHourBefore: Bool {
        defaults.string(forKey: preferenceKey)
            == hideUntilOneHourBefore
    }
}

/// Expose le choix 12 h / 24 h à toutes les cibles de l'application.
enum TimeFormatBridge {
    static let preferenceKey = "display.timeFormat"

    static let twentyFourHour = "24h"
    static let twelveHour = "12h"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    static var uses24HourTime: Bool {
        defaults.string(forKey: preferenceKey) != twelveHour
    }
}

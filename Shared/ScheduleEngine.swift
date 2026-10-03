import Foundation

/// Retourne le code de langue actuellement utilisé par l'interface.
func appDisplayLanguageCode() -> String {

#if DEBUG
    if let debugLanguage = DebugLanguageBridge.languageCode {
        return debugLanguage
    }
#endif

    let language =
        Bundle.main.preferredLocalizations.first
        ?? Locale.preferredLanguages.first
        ?? "fr"

    let value = language.lowercased()

    if value.hasPrefix("en") { return "en" }
    if value.hasPrefix("de") { return "de" }
    if value.hasPrefix("es") { return "es" }
    if value.hasPrefix("it") { return "it" }
    if value.hasPrefix("pt-br") { return "pt-BR" }
    if value.hasPrefix("pt") { return "pt-PT" }
    if value.hasPrefix("nl") { return "nl" }
    if value.hasPrefix("pl") { return "pl" }
    if value.hasPrefix("ro") { return "ro" }
    if value.hasPrefix("cs") { return "cs" }
    if value.hasPrefix("sv") { return "sv" }
    if value.hasPrefix("da") { return "da" }

    return "fr"
}


/// Retourne le bundle correspondant à la langue d'affichage sélectionnée.
private func appLocalizationBundle() -> Bundle {

    let languageCode = appDisplayLanguageCode()

    guard
        let path = Bundle.main.path(
            forResource: languageCode,
            ofType: "lproj"
        ),
        let bundle = Bundle(path: path)
    else {
        return .main
    }

    return bundle
}


/// Résout une chaîne localisée dans le bundle de langue choisi par l'utilisateur.
func L(_ key: String, _ arguments: CVarArg...) -> String {

    let format = appLocalizationBundle()
        .localizedString(
            forKey: key,
            value: nil,
            table: nil
        )

    guard !arguments.isEmpty else {
        return format
    }

    return String(
        format: format,
        locale: appDisplayLocale(),
        arguments: arguments
    )
}


/// Locale utilisée pour les dates, les jours et les valeurs formatées.
func appDisplayLocale() -> Locale {

    let baseIdentifier: String

    switch appDisplayLanguageCode() {

    case "en":
        baseIdentifier = "en_GB"

    case "de":
        baseIdentifier = "de_DE"

    case "es":
        baseIdentifier = "es_ES"

    case "it":
        baseIdentifier = "it_IT"

    case "pt-PT":
        baseIdentifier = "pt_PT"

    case "pt-BR":
        baseIdentifier = "pt_BR"

    case "nl":
        baseIdentifier = "nl_NL"

    case "pl":
        baseIdentifier = "pl_PL"

    case "ro":
        baseIdentifier = "ro_RO"

    case "cs":
        baseIdentifier = "cs_CZ"

    case "sv":
        baseIdentifier = "sv_SE"

    case "da":
        baseIdentifier = "da_DK"

    default:
        baseIdentifier = "fr_FR"
    }

    let hourCycle =
        TimeFormatBridge.uses24HourTime
        ? "h23"
        : "h12"

    return Locale(
        identifier:
            "\(baseIdentifier)@hours=\(hourCycle)"
    )
}

/// Résultat de la validation d'une liste d'horaires saisis sous forme de texte.
struct BellTimeValidation: Equatable {
    let normalizedTimes: [String]
    let invalidValues: [String]
    let duplicateCount: Int

    var isValid: Bool { invalidValues.isEmpty }
    var hasDuplicates: Bool { duplicateCount > 0 }
}

/// Moteur pur chargé de valider les horaires et de calculer les prochaines sonneries.
struct ScheduleEngine {
    var calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func nextBell(
        after date: Date,
        at site: BellSite,
        suspendedUntil: Date? = nil
    ) -> Date? {
        let effectiveStart: Date
        if let suspendedUntil, suspendedUntil > date {
            effectiveStart = suspendedUntil
        } else {
            effectiveStart = date
        }

        // Une fenêtre de deux semaines permet de traverser les week-ends et couvre
        // aussi les emplois du temps peu fréquents du samedi.
        for dayOffset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: effectiveStart) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: day)
            let times = normalizedTimes(site.bellTimes(for: weekday))

            for time in times {
                guard let components = parse(time),
                      let candidate = calendar.date(
                        bySettingHour: components.hour,
                        minute: components.minute,
                        second: 0,
                        of: day
                      ) else {
                    continue
                }

                if candidate > effectiveStart {
                    return candidate
                }
            }
        }

        return nil
    }

    func bellDates(
        from start: Date,
        at site: BellSite,
        limit: Int = 40,
        suspendedUntil: Date? = nil
    ) -> [Date] {
        guard limit > 0 else { return [] }

        var result: [Date] = []
        var cursor = start

        while result.count < limit,
              let next = nextBell(after: cursor, at: site, suspendedUntil: suspendedUntil) {
            result.append(next)
            cursor = next.addingTimeInterval(0.5)
        }

        return result
    }

    func validateBellTimes(_ values: [String]) -> BellTimeValidation {
        var invalid: [String] = []
        var parsedValues: [(text: String, minutes: Int)] = []

        for raw in values {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let parsed = parse(trimmed) else {
                invalid.append(trimmed)
                continue
            }

            let canonical = String(format: "%02d:%02d", parsed.hour, parsed.minute)
            parsedValues.append((canonical, parsed.hour * 60 + parsed.minute))
        }

        let uniqueMinutes = Set(parsedValues.map(\.minutes))
        let duplicateCount = parsedValues.count - uniqueMinutes.count

        let normalized = Dictionary(grouping: parsedValues, by: \.minutes)
            .compactMap { minute, values -> (Int, String)? in
                guard let first = values.first else { return nil }
                return (minute, first.text)
            }
            .sorted { $0.0 < $1.0 }
            .map(\.1)

        return BellTimeValidation(
            normalizedTimes: normalized,
            invalidValues: invalid,
            duplicateCount: duplicateCount
        )
    }

    func minutesSinceMidnight(from raw: String) -> Int? {
        guard let parsed = parse(raw) else { return nil }
        return parsed.hour * 60 + parsed.minute
    }

    func displayTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat =
            TimeFormatBridge.uses24HourTime
            ? "HH:mm"
            : "h:mm a"

        return formatter.string(from: date)
    }

    func isSameDay(_ firstDate: Date, _ secondDate: Date) -> Bool {
        calendar.isDate(firstDate, inSameDayAs: secondDate)
    }

    func displayDayAndTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        formatter.dateFormat =
            TimeFormatBridge.uses24HourTime
            ? "EEEE HH:mm"
            : "EEEE h:mm a"

        return formatter.string(from: date)
    }

    func displayLongDayAndTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(
            TimeFormatBridge.uses24HourTime
                ? "EEEE d MMMM HH:mm"
                : "EEEE d MMMM h:mm a"
        )
        return formatter.string(from: date)
    }

    func displayDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func fiveAM(onSameDayAs date: Date) -> Date? {
        calendar.date(bySettingHour: 5, minute: 0, second: 0, of: date)
    }

    private func normalizedTimes(_ values: [String]) -> [String] {
        validateBellTimes(values).normalizedTimes
    }

    private func parse(_ raw: String) -> (hour: Int, minute: Int)? {
        let parts = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")

        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return (hour, minute)
    }
}

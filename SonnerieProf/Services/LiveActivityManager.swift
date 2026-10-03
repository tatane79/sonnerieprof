import ActivityKit
import Foundation

/// Centralise le cycle de vie de l'unique Live Activity de Sonnerie Prof.
@MainActor
enum LiveActivityManager {
    /// Apple limite une Live Activity standard à huit heures actives.
    static let maximumSystemDuration: TimeInterval = 8 * 60 * 60
    /// ActivityKit limite l'ensemble des données statiques et dynamiques à 4 Ko.
    /// Huit débuts de cours suffisent largement pour la durée de vie maximale
    /// d'une activité tout en gardant une marge pour les noms saisis par l'utilisateur.
    private static let maximumCourseDetails = 8

    static var isActive: Bool {
        !Activity<BellActivityAttributes>.activities.isEmpty
    }

    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(
        for site: BellSite,
        bellDates: [Date],
        usesCourseSchedule: Bool,
        courseDetails: [CourseActivityDetails] = [],
        simulatedTimeOffset: TimeInterval = 0
    ) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.disabled
        }

        let futureDates = bellDates
            .filter { $0 > Date.now }
            .prefix(40)

        guard !futureDates.isEmpty else {
            throw LiveActivityError.noUpcomingBell
        }

        // Une seule Live Activity Sonnerie Prof à la fois.
        for activity in Activity<BellActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let dates = Array(futureDates)
        let relevantCourseDetails = limitedCourseDetails(
            courseDetails,
            matching: dates
        )
        let state = BellActivityAttributes.ContentState(
            startDate: .now,
            bellDates: dates,
            simulatedTimeOffset: simulatedTimeOffset == 0 ? nil : simulatedTimeOffset,
            usesCourseSchedule: usesCourseSchedule,
            courseDetails: relevantCourseDetails
        )

        // Retour à l'architecture locale qui avait été validée sur l'iPhone :
        // l'état transporte les sonneries futures et la vue sélectionne la
        // première date encore à venir à partir de l'heure courante.
        let content = ActivityContent(
            state: state,
            staleDate: dates.last
        )

        _ = try Activity<BellActivityAttributes>.request(
            attributes: BellActivityAttributes(siteName: site.name),
            content: content,
            pushType: nil
        )
    }

    static func refresh(
        for site: BellSite,
        bellDates: [Date],
        usesCourseSchedule: Bool,
        courseDetails: [CourseActivityDetails] = [],
        simulatedTimeOffset: TimeInterval = 0
    ) async throws {
        let futureDates = Array(
            bellDates
                .filter { $0 > Date.now }
                .prefix(40)
        )

        guard !futureDates.isEmpty else {
            await stopAll()
            return
        }

        let activities = Activity<BellActivityAttributes>.activities
        guard !activities.isEmpty else {
            try await start(
                for: site,
                bellDates: futureDates,
                usesCourseSchedule: usesCourseSchedule,
                courseDetails: courseDetails,
                simulatedTimeOffset: simulatedTimeOffset
            )
            return
        }

        // siteName appartient aux Attributes et est immuable : si l'utilisateur
        // change de site, on recrée la Live Activity.
        if activities.contains(where: { $0.attributes.siteName != site.name }) {
            try await start(
                for: site,
                bellDates: futureDates,
                usesCourseSchedule: usesCourseSchedule,
                courseDetails: courseDetails,
                simulatedTimeOffset: simulatedTimeOffset
            )
            return
        }

        let relevantCourseDetails = limitedCourseDetails(
            courseDetails,
            matching: futureDates
        )
        let state = BellActivityAttributes.ContentState(
            startDate: .now,
            bellDates: futureDates,
            simulatedTimeOffset: simulatedTimeOffset == 0 ? nil : simulatedTimeOffset,
            usesCourseSchedule: usesCourseSchedule,
            courseDetails: relevantCourseDetails
        )

        let content = ActivityContent(
            state: state,
            staleDate: futureDates.last
        )

        for activity in activities {
            await activity.update(content)
        }
    }

    /// Quand l'app est au premier plan, ContentView appelle cette méthode au
    /// passage d'une sonnerie. Elle conserve la signature de la version de
    /// référence actuelle tout en réutilisant la logique stable ci-dessus.
    static func refreshAtBellBoundaryIfNeeded(
        for site: BellSite,
        bellDates: [Date],
        usesCourseSchedule: Bool,
        courseDetails: [CourseActivityDetails] = [],
        simulatedTimeOffset: TimeInterval = 0
    ) async {
        guard isActive else { return }

        do {
            try await refresh(
                for: site,
                bellDates: bellDates,
                usesCourseSchedule: usesCourseSchedule,
                courseDetails: courseDetails,
                simulatedTimeOffset: simulatedTimeOffset
            )
        } catch {
#if DEBUG
            print("🔔 Live Activity foreground refresh failed: \(error)")
#endif
        }
    }

    static func stopAll() async {
        for activity in Activity<BellActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func limitedCourseDetails(
        _ details: [CourseActivityDetails],
        matching dates: [Date]
    ) -> [CourseActivityDetails] {
        details
            .filter { detail in
                dates.contains { abs($0.timeIntervalSince(detail.startDate)) < 1 }
            }
            .sorted { $0.startDate < $1.startDate }
            .prefix(maximumCourseDetails)
            .map { $0 }
    }
}

enum LiveActivityError: LocalizedError {
    case disabled
    case noUpcomingBell

    var errorDescription: String? {
        switch self {
        case .disabled:
            return L("live_activity.disabled")
        case .noUpcomingBell:
            return L("live_activity.no_upcoming")
        }
    }
}

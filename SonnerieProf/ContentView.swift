import ActivityKit
import AudioToolbox
import Combine
import SwiftUI

private enum ContentLocalizationSources {
    static func registerForExtraction() {
        _ = String(
            localized: "lock.long_delay",
            defaultValue: "Affichage activé. La prochaine sonnerie est éloignée ; iOS peut retirer la Live Activity avant celle-ci."
        )
    }
}

/// Écran racine : navigation, compte à rebours, réglages et synchronisation ActivityKit.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var store = SiteStore()
    @StateObject private var locationService = LocationService()
    @State private var timetableStore = TimetableStore()
    @State private var tipJarStore = TipJarStore()

    @State private var liveActivityMessage: String?
    @State private var isLockScreenEnabled = false
    @State private var isUpdatingLockScreen = false
    @State private var sitePendingDeletion: BellSite?
    @State private var lastVibratedBell: Date?
    @State private var lastObservedNextBellForActivity: Date?
    @State private var showOnboarding = false
    @State private var showFullscreenCountdown = false
    @State private var showTipPrompt = false
    @State private var showSuspensionChoices = false

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    @AppStorage("bellVibrationEnabled")
    private var bellVibrationEnabled = false

    @AppStorage("bellVibrationCount")
    private var bellVibrationCount = 1

    @AppStorage("lockScreenPreferred")
    private var lockScreenPreferred = false
    
    @AppStorage(
        TimeFormatBridge.preferenceKey,
        store: UserDefaults(suiteName: AppGroup.identifier)
    )
    private var timeFormatPreference = TimeFormatBridge.twentyFourHour
  
    @AppStorage(
        AfterLastBellBridge.preferenceKey,
        store: UserDefaults(suiteName: AppGroup.identifier)
    )
    private var afterLastBellPreference =
        AfterLastBellBridge.showNextBell
    
#if DEBUG
    @AppStorage(
        DebugClockBridge.enabledKey,
        store: UserDefaults(suiteName: AppGroup.identifier)
    ) private var debugSimulatedTimeEnabled = false

    @AppStorage(
        DebugClockBridge.offsetKey,
        store: UserDefaults(suiteName: AppGroup.identifier)
    ) private var debugSimulatedTimeOffset: Double = 0
    
    @AppStorage(
        DebugLanguageBridge.languageKey,
        store: UserDefaults(suiteName: AppGroup.identifier)
    ) private var debugLanguageCode = "system"
#endif

    @ScaledMetric(relativeTo: .largeTitle) private var countdownFontSize: CGFloat = 72
    @ScaledMetric(relativeTo: .title) private var siteFontSize: CGFloat = 32
    @ScaledMetric(relativeTo: .title) private var nextBellFontSize: CGFloat = 40
    @ScaledMetric(relativeTo: .headline) private var nextBellLabelFontSize: CGFloat = 24

    private let engine = ScheduleEngine()
    private let timetableEngine = TimetableEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    sitePicker
#if DEBUG
                    developerClockBanner
#endif
                    CourseCountdownCard(
                        sessions: timetableStore.sessions,
                        sites: store.sites,
                        referenceWeekStart: timetableStore.referenceWeekStart,
                        referenceWeek: timetableStore.referenceWeek,
                        fallbackSite: store.selectedSite,
                        suspendedUntil: store.activeScheduleSuspendedUntil,
                        timeOffset: activeTimeOffset
                    ) {
                        showFullscreenCountdown = true
                    }
                    actionCard
                    NavigationLink {
                        TimetableView(
                            store: timetableStore,
                            sites: store.sites
                        )
                    } label: {
                        CourseStatusCard(
                            sessions: timetableStore.sessions,
                            sites: store.sites,
                            referenceWeekStart: timetableStore.referenceWeekStart,
                            referenceWeek: timetableStore.referenceWeek
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Ouvre les réglages de l’emploi du temps.")
                }
                .padding()
            }
            .navigationTitle(L("Sonnerie Prof"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        presentTipPrompt()
                    } label: {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.blue)
                    }
                    .accessibilityLabel(
                        Text(TipL("tip.support_button", fallback: "Soutenir Sonnerie Prof"))
                    )

                    NavigationLink {
                        TimetableView(
                            store: timetableStore,
                            sites: store.sites
                        )
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(Text("Emploi du temps"))

                    NavigationLink {
                        aboutView
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel(Text(L("À propos")))

                    NavigationLink(L("Réglages")) {
                        settingsView
                    }
                }
            }
            .task {
                prepareOnboardingState()
                locationService.refreshLocationIfAuthorized()
                refreshLockScreenState()

                await tipJarStore.prepare()

                if !showOnboarding && tipJarStore.shouldPresentAutomaticPrompt {
                    try? await Task.sleep(for: .seconds(1.2))

                    if !showOnboarding {
                        presentTipPrompt(automatic: true)
                    }
                }
            }
            .onReceive(locationService.$location.compactMap { $0 }) { _ in
                autoSelectSiteIfPossible()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reconcileSuspensionState(at: effectiveDate(for: .now))
                    refreshLockScreenState()
                }
            }
            .onReceive(store.$sites.dropFirst()) { _ in
                guard isLockScreenEnabled else { return }
                refreshActiveLockScreenActivity()
            }
            .onReceive(store.$scheduleSuspendedUntil.dropFirst()) { _ in
                reconcileSuspensionState(at: effectiveDate(for: .now))
            }
            .onChange(of: timetableStore.sessions) { _, _ in
                guard isLockScreenEnabled else { return }
                refreshActiveLockScreenActivity()
            }
            .onChange(of: timetableStore.referenceWeek) { _, _ in
                guard isLockScreenEnabled else { return }
                refreshActiveLockScreenActivity()
            }
            .onChange(of: timetableStore.referenceWeekStart) { _, _ in
                guard isLockScreenEnabled else { return }
                refreshActiveLockScreenActivity()
            }
            .onReceive(
                Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
            ) { date in
                let appDate = effectiveDate(for: date)
                reconcileSuspensionState(at: appDate)
                checkForBell(at: appDate)
                refreshLiveActivityAtBellBoundaryIfNeeded(systemDate: date)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            NavigationStack {
                OnboardingView(
                    store: store,
                    locationService: locationService
                ) {
                    hasCompletedOnboarding = true
                    showOnboarding = false
                }
            }
        }
        .fullScreenCover(isPresented: $showFullscreenCountdown) {
            CourseFullscreenCountdownView(
                sessions: timetableStore.sessions,
                sites: store.sites,
                referenceWeekStart: timetableStore.referenceWeekStart,
                referenceWeek: timetableStore.referenceWeek,
                fallbackSite: store.selectedSite,
                suspendedUntil: store.activeScheduleSuspendedUntil,
                timeOffset: activeTimeOffset
            ) { systemDate in
                checkForBell(at: effectiveDate(for: systemDate))
            }
        }
        .sheet(isPresented: $showTipPrompt) {
            TipPromptView(store: tipJarStore)
        }
        .environment(
            \.locale,
            appDisplayLocale()
        )
    }

    // MARK: - Sélection du site

    private var sitePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.sites.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "building.2")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text(L("Aucun site configuré"))
                        .font(.headline)

                    Text(L("Ajoutez votre établissement et ses horaires de sonnerie."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    NavigationLink {
                        SiteEditorView(
                            site: BellSite(name: ""),
                            store: store,
                            locationService: locationService
                        )
                    } label: {
                        Label(L("Ajouter un site"), systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Text(L("Site actuel"))
                    .font(.headline)

                if store.sites.count <= 2 {
                    Picker(L("Site"), selection: siteSelectionBinding) {
                        ForEach(store.sites) { site in
                            Text(site.name)
                                .tag(site.id as UUID?)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    HStack {
                        Label(L("Site"), systemImage: "building.2")
                        Spacer()
                        Picker(L("Site"), selection: siteSelectionBinding) {
                            ForEach(store.sites) { site in
                                Text(site.name)
                                    .tag(site.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Button(L("Détecter automatiquement")) {
                        locationService.requestCurrentLocation()
                    }
                    .buttonStyle(.bordered)

                    if locationService.accuracyAuthorization == .reducedAccuracy {
                        Label(L("Position approximative"), systemImage: "location.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = locationService.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var siteSelectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedSiteID },
            set: { id in
                guard let id,
                      let site = store.sites.first(where: { $0.id == id }) else {
                    return
                }
                selectSite(site)
            }
        )
    }

    private func shouldHideCountdown(
        at currentDate: Date,
        nextBell: Date
    ) -> Bool {

        guard
            afterLastBellPreference
                == AfterLastBellBridge.hideUntilOneHourBefore
        else {
            return false
        }

        // Tant que la prochaine sonnerie est aujourd'hui,
        // le compte à rebours reste toujours visible.
        guard !engine.isSameDay(
            currentDate,
            nextBell
        ) else {
            return false
        }

        // Le cadre réapparaît exactement une heure
        // avant la prochaine sonnerie programmée.
        let revealDate =
            nextBell.addingTimeInterval(-60 * 60)

        return currentDate < revealDate
    }
    
    // MARK: - Compte à rebours

    private var countdownCard: some View {
        Group {
            if let site = store.selectedSite {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let currentDate = effectiveDate(for: context.date)

                    if let nextBell = engine.nextBell(
                        after: currentDate,
                        at: site,
                        suspendedUntil: store.activeScheduleSuspendedUntil
                    ) {
                        
                        if shouldHideCountdown(
                            at: currentDate,
                            nextBell: nextBell
                        ) {
                            
                            EmptyView()
                            
                        } else {
                            
                            VStack(spacing: 18) {
                                Text(site.name)
                                    .font(
                                        .system(
                                            size: siteFontSize,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .minimumScaleFactor(0.7)
                                    .accessibilityAddTraits(.isHeader)
                                
                                if let suspendedUntil = store.activeScheduleSuspendedUntil,
                                   suspendedUntil > currentDate {
                                    Label(
                                        L("schedule.suspended_until", engine.displayDate(for: suspendedUntil)),
                                        systemImage: "pause.circle.fill"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .multilineTextAlignment(.center)
                                }
                                
                                if engine.isSameDay(currentDate, nextBell) {
                                    let systemNextBell = systemDate(for: nextBell)
                                    
                                    Text(
                                        timerInterval: context.date...systemNextBell,
                                        pauseTime: systemNextBell,
                                        countsDown: true,
                                        showsHours: false
                                    )
                                    .font(
                                        .system(
                                            size: countdownFontSize,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.45)
                                    .accessibilityLabel(Text(L("Temps restant")))
                                    
                                    Text(L("next_bell_at", engine.displayTime(for: nextBell)))
                                        .font(
                                            .system(
                                                size: nextBellLabelFontSize,
                                                weight: .semibold,
                                                design: .rounded
                                            )
                                        )
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                } else {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                    
                                    VStack(spacing: 8) {
                                        Text(L("Prochaine sonnerie :"))
                                            .font(
                                                .system(
                                                    size: nextBellLabelFontSize,
                                                    weight: .semibold,
                                                    design: .rounded
                                                )
                                            )
                                            .foregroundStyle(.secondary)
                                        
                                        Text(engine.displayDayAndTime(for: nextBell))
                                            .font(
                                                .system(
                                                    size: nextBellFontSize,
                                                    weight: .bold,
                                                    design: .rounded
                                                )
                                            )
                                            .minimumScaleFactor(0.65)
                                    }
                                    .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .padding(.horizontal)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .overlay(alignment: .topTrailing) {
                                if engine.isSameDay(currentDate, nextBell) {
                                    Button {
                                        showFullscreenCountdown = true
                                    } label: {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.headline.weight(.semibold))
                                            .padding(10)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(Text(L("Afficher en plein écran")))
                                    .padding(6)
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            L("Aucune sonnerie configurée"),
                            systemImage: "bell.slash",
                            description: Text(L("Ajoutez les horaires de ce site dans Réglages."))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Écran verrouillé

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Écran verrouillé"))
                        .font(.headline)

                    Text(
                        L("lockscreen.description") // "Afficher le temps restant sur l’écran verrouillé et, si disponible, en mode Always-On."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(
                    L("Écran verrouillé"),
                    isOn: Binding(
                        get: { isLockScreenEnabled },
                        set: { setLockScreenEnabled($0) }
                    )
                )
                .labelsHidden()
                .disabled(
                    isUpdatingLockScreen ||
                    store.isScheduleSuspended ||
                    store.selectedSite == nil ||
                    !LiveActivityManager.areActivitiesEnabled
                )
            }

            if store.isScheduleSuspended,
               let resumeDate = store.scheduleSuspendedUntil {
                Label(
                    L(
                        "Indisponible pendant la suspension. L’affichage pourra être réactivé à la prochaine ouverture de l’app à partir du %@.",
                        engine.displayDate(for: resumeDate)
                    ),
                    systemImage: "pause.circle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !LiveActivityManager.areActivitiesEnabled {
                Label(
                    L("Les Live Activities sont désactivées dans les réglages iOS."),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            if isUpdatingLockScreen {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L("Mise à jour…"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let liveActivityMessage,
               !store.isScheduleSuspended {
                Text(liveActivityMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Réglages

    private var settingsView: some View {
        List {

            // 2. Planning
            Section {
                NavigationLink {
                    TimetableView(
                        store: timetableStore,
                        sites: store.sites
                    )
                } label: {
                    Label("Emploi du temps", systemImage: "calendar")
                }

                NavigationLink {
                    CloudTransferView(
                        siteStore: store,
                        timetableStore: timetableStore
                    )
                } label: {
                    Label(L("iCloud et partage"), systemImage: "icloud")
                }

                Picker(
                        L("Format de l’heure"),
                        selection: $timeFormatPreference
                    ) {
                        Text(L("24 h"))
                            .tag(TimeFormatBridge.twentyFourHour)

                        Text(L("12 h (AM/PM)"))
                            .tag(TimeFormatBridge.twelveHour)
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: timeFormatPreference) { _, _ in


                        if isLockScreenEnabled {
                            refreshActiveLockScreenActivity()
                        }
                    }
                
                Picker(
                    L("settings.after_last_bell"),
                    selection: $afterLastBellPreference
                ) {
                    Text(
                        L("settings.after_last_bell.show_next")
                    )
                    .tag(
                        AfterLastBellBridge.showNextBell
                    )

                    Text(
                        L("settings.after_last_bell.hide_until_one_hour")
                    )
                    .tag(
                        AfterLastBellBridge.hideUntilOneHourBefore
                    )
                }
                .pickerStyle(.navigationLink)
                .onChange(of: afterLastBellPreference) { _, _ in


                    if isLockScreenEnabled {
                        refreshActiveLockScreenActivity()
                    }
                }
                
                Toggle(
                    L("Suspendre temporairement"),
                    isOn: Binding(
                        get: {
                            store.hasScheduledSuspension
                        },
                        set: {
                            setScheduleSuspended($0)
                        }
                    )
                )
                .confirmationDialog(
                    L("Suspendre temporairement"),
                    isPresented: $showSuspensionChoices,
                    titleVisibility: .visible
                ) {
                    Button(L("Suspendre maintenant")) {
                        beginSuspension(at: effectiveDate(for: .now))
                    }

                    if let lastCourseEndToday {
                        Button(
                            L(
                                "Suspendre après le dernier cours à %@",
                                engine.displayTime(for: lastCourseEndToday)
                            )
                        ) {
                            beginSuspension(at: lastCourseEndToday)
                        }
                    }

                    Button(L("Annuler"), role: .cancel) {}
                } message: {
                    Text(
                        L(
                            "Des cours sont encore prévus aujourd’hui. Quand souhaitez-vous masquer l’écran verrouillé et la Dynamic Island ?"
                        )
                    )
                }

                if store.hasScheduledSuspension {
                    if store.isScheduleSuspensionPending,
                       let startsAt = store.scheduleSuspensionStartsAt {
                        Label(
                            L(
                                "Suspension prévue après le dernier cours à %@",
                                engine.displayTime(for: startsAt)
                            ),
                            systemImage: "clock.badge.checkmark"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    DatePicker(
                        L("Reprendre le"),
                        selection: Binding(
                            get: {
                                store.scheduleSuspendedUntil
                                    ?? defaultResumeDate
                            },
                            set: {
                                store.updateSuspensionEnd($0)
                            }
                        ),
                        in: defaultResumeDate...,
                        displayedComponents: .date
                    )
                }

            } header: {
                Text(L("Planning"))

            } footer: {
                Text(
                    L("Pendant une suspension (vacances, fermeture, congé), aucune sonnerie n'est proposée avant la date de reprise.")
                )
            }

            // 3. Sites
            Section {
                ForEach(store.sites) { site in

                    NavigationLink {
                        SiteEditorView(
                            site: site,
                            store: store,
                            locationService: locationService
                        )

                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(site.name)

                                if site.latitude == 0
                                    && site.longitude == 0 {

                                    Text(L("Position non configurée"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                        } icon: {
                            Image(
                                systemName: "building.columns.fill"
                            )
                        }
                    }
                    .swipeActions(
                        edge: .trailing,
                        allowsFullSwipe: false
                    ) {
                        Button(role: .destructive) {
                            sitePendingDeletion = site

                        } label: {
                            Label(
                                L("Supprimer"),
                                systemImage: "trash"
                            )
                        }
                    }
                }

                if store.canAddSite {

                    NavigationLink {
                        SiteEditorView(
                            site: BellSite(name: ""),
                            store: store,
                            locationService: locationService
                        )

                    } label: {
                        Label(
                            L("Ajouter un site"),
                            systemImage: "plus.circle.fill"
                        )
                    }

                } else {

                    Label(
                        L("Maximum de 4 sites atteint"),
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

            } header: {
                Text(L("Sites"))

            } footer: {
                Text(
                    L("Glisser à gauche pour supprimer un site.")
                )
            }

            // 4. Vibrations
            Section {
                Toggle(
                    L("Vibrer à la sonnerie"),
                    isOn: $bellVibrationEnabled
                )

                if bellVibrationEnabled {

                    Stepper(
                        value: $bellVibrationCount,
                        in: 1...10
                    ) {
                        HStack {
                            Text(L("Nombre de vibrations"))

                            Spacer()

                            Text(
                                verbatim: "\(bellVibrationCount)"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task {
                            await vibrate(
                                count: bellVibrationCount
                            )
                        }

                    } label: {
                        Label(
                            L("Tester"),
                            systemImage:
                                "iphone.radiowaves.left.and.right"
                        )
                    }
                }

            } header: {
                Text(L("Vibrations"))

            } footer: {
                Text(
                    L("Les vibrations sont déclenchées uniquement lorsque Sonnerie Prof est active au premier plan. Aucun son n'est joué.")
                )
            }

            developerSettingsSections
        }
        .navigationTitle(L("Réglages"))
        .alert(
            L("Supprimer ce site ?"),
            isPresented: Binding(
                get: {
                    sitePendingDeletion != nil
                },
                set: { isPresented in
                    if !isPresented {
                        sitePendingDeletion = nil
                    }
                }
            ),
            presenting: sitePendingDeletion
        ) { site in

            Button(
                L("Annuler"),
                role: .cancel
            ) {
                sitePendingDeletion = nil
            }

            Button(
                L("Supprimer"),
                role: .destructive
            ) {
                deleteSite(site)
            }

        } message: { site in

            Text(
                L(
                    "site.delete_message",
                    site.name
                )
            )
        }
    }

    @ViewBuilder
    private var developerSettingsSections: some View {
#if DEBUG
        Section {
            Picker(
                L("Langue de test"),
                selection: $debugLanguageCode
            ) {
                Text(L("language.system")).tag("system")
                Text(L("language.fr")).tag("fr")
                Text(L("language.en")).tag("en")
                Text(L("language.de")).tag("de")
                Text(L("language.es")).tag("es")
                Text(L("language.it")).tag("it")
                Text(L("language.pt_PT")).tag("pt-PT")
                Text(L("language.pt_BR")).tag("pt-BR")
                Text(L("language.nl")).tag("nl")
                Text(L("language.pl")).tag("pl")
                Text(L("language.ro")).tag("ro")
                Text(L("language.cs")).tag("cs")
                Text(L("language.sv")).tag("sv")
                Text(L("language.da")).tag("da")
            }
            .pickerStyle(.navigationLink)
            .onChange(of: debugLanguageCode) { _, _ in
                if isLockScreenEnabled {
                    refreshActiveLockScreenActivity()
                }
            }

            Toggle(
                L("Utiliser une heure simulée"),
                isOn: Binding(
                    get: { debugSimulatedTimeEnabled },
                    set: { setDebugSimulatedTimeEnabled($0) }
                )
            )

            if debugSimulatedTimeEnabled {
                DatePicker(
                    L("Date et heure simulées"),
                    selection: debugSimulatedDateBinding,
                    displayedComponents: [.date, .hourAndMinute]
                )

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        Text(L("Heure simulée"))
                        Spacer()
                        Text(debugDateTimeString(effectiveDate(for: context.date)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Button(L("5 min avant la prochaine sonnerie")) {
                    setDebugTime(minutesBeforeNextBell: 5)
                }
                .disabled(debugUpcomingBell == nil)

                Button(L("1 min avant la prochaine sonnerie")) {
                    setDebugTime(minutesBeforeNextBell: 1)
                }
                .disabled(debugUpcomingBell == nil)

                Button(L("Revenir à l’heure réelle")) {
                    setDebugSimulatedTimeEnabled(false)
                }
            }

            Button {
                presentTipPrompt()
            } label: {
                Label(
                    TipL(
                        "tip.debug_show",
                        fallback: "Un petit coup de pouce pour Sonnerie Prof ?"
                    ),
                    systemImage: "heart.circle"
                )
            }
        } header: {
            Label(L("Mode développeur"), systemImage: "hammer.fill")
        } footer: {
            Text(
                L("L’heure simulée avance à vitesse réelle. Elle est utilisée par l’app et la Live Activity. Ce réglage existe uniquement dans les builds Debug et n’apparaît pas dans la version App Store.")
            )
        }
#endif
    }

    // MARK: - Écran À propos

    private var aboutView: some View {
        List {
            Section {
                Text(
                    L("Sonnerie Prof est conçue pour aider les enseignants à garder un œil sur le temps restant avant la prochaine sonnerie, directement depuis l’app ou l’écran verrouillé")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    presentTipPrompt()
                } label: {
                    Label(
                        TipL(
                            "tip.support_button",
                            fallback: "Soutenir Sonnerie Prof"
                        ),
                        systemImage: "heart.circle.fill"
                    )
                }

                Text(
                    TipL(
                        "tip.support_about",
                        fallback: "Sonnerie Prof est gratuite et toutes ses fonctions sont disponibles sans paiement. Si vous le souhaitez, vous pouvez soutenir son développement avec un pourboire facultatif."
                    )
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(
                    TipL(
                        "tip.support_section",
                        fallback: "Soutenir l’application"
                    )
                )
            }
            
            // Confidentialité
            Section(L("Confidentialité")) {

                Label(
                    L("Aucun compte requis"),
                    systemImage:
                        "person.crop.circle.badge.checkmark"
                )

                Label(
                    L("Aucune publicité ni suivi"),
                    systemImage: "hand.raised"
                )

                Label(
                    L("Données enregistrées localement"),
                    systemImage: "iphone"
                )

                Text(
                    L("La localisation est facultative et n’est jamais transmise. Lorsque les mises à jour Always-On à distance sont activées, seules les heures de sonnerie nécessaires et un identifiant technique temporaire sont transmis au service de mise à jour.")
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            // Informations sur l'application
            Section(L("À propos")) {

                LabeledContent(
                    L("Auteur"),
                    value: "Jonathan Lafarge"
                )

                LabeledContent(
                    L("Version"),
                    value: appVersion
                )

                LabeledContent(
                    L("Compilation"),
                    value: buildDate
                )
            }
        }
        .navigationTitle(L("À propos"))
        .navigationBarTitleDisplayMode(.inline)
    }
    // MARK: - À propos

    private var appVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? L("common.not_available")

        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? ""

        return build.isEmpty ? version : "\(version) (\(build))"
    }

    private var buildDate: String {
        guard let executableURL = Bundle.main.executableURL,
              let values = try? executableURL.resourceValues(
                forKeys: [.contentModificationDateKey]
              ),
              let date = values.contentModificationDate else {
            return L("common.not_available")
        }

        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Soutien volontaire

    private func presentTipPrompt(automatic: Bool = false) {
        tipJarStore.prepareForPresentation()

        if automatic {
            tipJarStore.markAutomaticPromptPresented()
        }

        showTipPrompt = true
    }

    // MARK: - Onboarding

    private func prepareOnboardingState() {
        if !store.sites.isEmpty {
            hasCompletedOnboarding = true
            showOnboarding = false
        } else if !hasCompletedOnboarding {
            showOnboarding = true
        }
    }

    // MARK: - Planning suspendu

    private var defaultResumeDate: Date {
        let calendar = Calendar.autoupdatingCurrent
        let now = effectiveDate(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowStart = calendar.startOfDay(for: tomorrow)
        let searchDate = tomorrowStart.addingTimeInterval(-1)

        if !timetableStore.sessions.isEmpty {
            let status = timetableEngine.status(
                at: searchDate,
                sessions: timetableStore.sessions,
                referenceWeekStart: timetableStore.referenceWeekStart,
                referenceWeek: timetableStore.referenceWeek
            )
            if let nextCourse = status.next?.startDate {
                return calendar.startOfDay(for: nextCourse)
            }
        } else if let site = store.selectedSite,
                  let nextBell = engine.nextBell(after: searchDate, at: site) {
            return calendar.startOfDay(for: nextBell)
        }

        return tomorrowStart
    }

    private var lastCourseEndToday: Date? {
        let now = effectiveDate(for: .now)
        let calendar = Calendar.autoupdatingCurrent
        let weekday = calendar.component(.weekday, from: now)
        let teachingWeek = timetableEngine.teachingWeek(
            on: now,
            referenceWeekStart: timetableStore.referenceWeekStart,
            referenceWeek: timetableStore.referenceWeek
        )

        return timetableStore.sessions
            .filter {
                $0.weekday == weekday
                    && $0.weekPattern.includes(teachingWeek)
            }
            .map {
                timetableEngine.date(
                    minutesSinceMidnight: $0.endMinutes,
                    on: now
                )
            }
            .filter { $0 > now }
            .max()
    }

    private func setScheduleSuspended(_ suspended: Bool) {
        if suspended {
            if lastCourseEndToday != nil {
                showSuspensionChoices = true
            } else {
                beginSuspension(at: effectiveDate(for: .now))
            }
        } else {
            store.resumeSchedule()
            restorePreferredLockScreenIfNeeded()
        }
    }

    private func beginSuspension(at startDate: Date) {
        store.suspendSchedule(from: startDate, until: defaultResumeDate)
        reconcileSuspensionState(at: effectiveDate(for: .now))
    }

    private func reconcileSuspensionState(at date: Date) {
        store.clearExpiredSuspension(at: date)

        if store.isScheduleSuspended(at: date) {
            stopLockScreenForSuspension()
        } else if !store.hasScheduledSuspension {
            restorePreferredLockScreenIfNeeded()
        }
    }

    private func stopLockScreenForSuspension() {
        guard LiveActivityManager.isActive || isLockScreenEnabled else { return }

        isLockScreenEnabled = false
        isUpdatingLockScreen = true
        lastObservedNextBellForActivity = nil
        liveActivityMessage = L("Écran verrouillé suspendu temporairement.")

        Task {
            await LiveActivityManager.stopAll()
            await MainActor.run {
                isUpdatingLockScreen = false
            }
        }
    }

    private func restorePreferredLockScreenIfNeeded() {
        guard lockScreenPreferred,
              !store.isScheduleSuspended,
              !LiveActivityManager.isActive,
              !isUpdatingLockScreen,
              store.selectedSite != nil else {
            return
        }

        setLockScreenEnabled(true)
    }

    // MARK: - Détection automatique

    private func autoSelectSiteIfPossible() {
        guard let site = locationService.bestMatchingSite(in: store.sites) else {
            return
        }
        selectSite(site)
    }

    // MARK: - Live Activity / écran verrouillé

    private func setLockScreenEnabled(_ enabled: Bool) {
        guard !isUpdatingLockScreen else { return }
        isUpdatingLockScreen = true

        if enabled {
            guard let site = store.selectedSite else {
                lockScreenPreferred = false
                isLockScreenEnabled = false
                isUpdatingLockScreen = false
                liveActivityMessage = L("lock.add_site_first")
                return
            }

            guard !store.isScheduleSuspended else {
                isLockScreenEnabled = false
                isUpdatingLockScreen = false
                return
            }

            lockScreenPreferred = true
            let dates = activityBellDates(for: site)

            Task {
                do {
                    try await LiveActivityManager.start(
                        for: site,
                        bellDates: dates,
                        usesCourseSchedule: !timetableStore.sessions.isEmpty,
                        courseDetails: activityCourseDetails(),
                        simulatedTimeOffset: activeTimeOffset
                    )

                    await MainActor.run {
                        isLockScreenEnabled = true
                        isUpdatingLockScreen = false
                        lastObservedNextBellForActivity = currentSystemNextBell(for: site)
                        liveActivityMessage = activityStatusMessage(for: site)
                    }
                } catch {
                    await MainActor.run {
                        isLockScreenEnabled = false
                        isUpdatingLockScreen = false
                        liveActivityMessage = error.localizedDescription
                    }
                }
            }
        } else {
            lockScreenPreferred = false
            Task {
                await LiveActivityManager.stopAll()
                await MainActor.run {
                    isLockScreenEnabled = false
                    isUpdatingLockScreen = false
                    lastObservedNextBellForActivity = nil
                    liveActivityMessage = nil
                }
            }
        }
    }

    private func refreshLockScreenState() {
        if store.isScheduleSuspended {
            stopLockScreenForSuspension()
            return
        }

        isLockScreenEnabled = LiveActivityManager.isActive
        if isLockScreenEnabled, let site = store.selectedSite {
            lockScreenPreferred = true
            lastObservedNextBellForActivity = currentSystemNextBell(for: site)
            refreshActiveLockScreenActivity()
        } else {
            lastObservedNextBellForActivity = nil
            restorePreferredLockScreenIfNeeded()
        }
    }

    private func refreshActiveLockScreenActivity() {
        guard isLockScreenEnabled,
              let site = store.selectedSite else {
            return
        }

        let dates = activityBellDates(for: site)

        Task {
            do {
                try await LiveActivityManager.refresh(
                    for: site,
                    bellDates: dates,
                    usesCourseSchedule: !timetableStore.sessions.isEmpty,
                    courseDetails: activityCourseDetails(),
                    simulatedTimeOffset: activeTimeOffset
                )
                await MainActor.run {
                    liveActivityMessage = activityStatusMessage(for: site)
                }
            } catch {
                await MainActor.run {
                    liveActivityMessage = error.localizedDescription
                }
            }
        }
    }

    private func activityBellDates(for site: BellSite) -> [Date] {
        let appNow = effectiveDate(for: .now)
        let displayDates: [Date]
        if timetableStore.sessions.isEmpty {
            displayDates = engine.bellDates(
                from: appNow,
                at: site,
                limit: 40,
                suspendedUntil: store.activeScheduleSuspendedUntil
            )
        } else {
            displayDates = timetableEngine.boundaryDates(
                after: appNow,
                sessions: timetableStore.sessions,
                referenceWeekStart: timetableStore.referenceWeekStart,
                referenceWeek: timetableStore.referenceWeek,
                limit: 40
            )
        }

        // ActivityKit utilise toujours l'horloge système. En Debug, les dates
        // simulées sont reconverties en conservant la durée restante.
        return displayDates.map(systemDate(for:))
    }

    private func activityCourseDetails() -> [CourseActivityDetails] {
        let appNow = effectiveDate(for: .now)
        var details: [CourseActivityDetails] = []

        for dayOffset in 0...14 {
            guard let day = Calendar.autoupdatingCurrent.date(
                byAdding: .day,
                value: dayOffset,
                to: appNow
            ) else {
                continue
            }

            let weekday = Calendar.autoupdatingCurrent.component(.weekday, from: day)
            let teachingWeek = timetableEngine.teachingWeek(
                on: day,
                referenceWeekStart: timetableStore.referenceWeekStart,
                referenceWeek: timetableStore.referenceWeek
            )

            for session in timetableStore.sessions where
                session.weekday == weekday && session.weekPattern.includes(teachingWeek) {
                let displayStart = timetableEngine.date(
                    minutesSinceMidnight: session.startMinutes,
                    on: day
                )
                guard displayStart > appNow else { continue }

                details.append(
                    CourseActivityDetails(
                        startDate: systemDate(for: displayStart),
                        siteName: store.sites.first(where: { $0.id == session.siteID })?.name,
                        roomName: session.roomName,
                        className: session.className
                    )
                )
            }
        }

        return Array(details.sorted { $0.startDate < $1.startDate }.prefix(40))
    }

    private func displayCountdownTarget(at date: Date, site: BellSite) -> Date? {
        if timetableStore.sessions.isEmpty {
            return engine.nextBell(
                after: date,
                at: site,
                suspendedUntil: store.activeScheduleSuspendedUntil
            )
        }

        return timetableEngine.countdownTarget(
            at: date,
            sessions: timetableStore.sessions,
            referenceWeekStart: timetableStore.referenceWeekStart,
            referenceWeek: timetableStore.referenceWeek
        )
    }

    private func activityStatusMessage(for site: BellSite) -> String? {
        let appNow = effectiveDate(for: .now)
        guard let target = displayCountdownTarget(at: appNow, site: site) else {
            return L("lock.no_upcoming")
        }

        let limitDate = appNow.addingTimeInterval(LiveActivityManager.maximumSystemDuration)
        if target > limitDate {
            return L("lock.long_delay")
        }

        if engine.isSameDay(appNow, target) {
            return L("lock.active_until", engine.displayTime(for: target))
        }

        return L("lock.active_next", engine.displayDayAndTime(for: target))
    }

    /// Retourne la prochaine cible sur l'horloge système utilisée par ActivityKit.
    /// En Debug, la date simulée est reconvertie afin de rester comparable à la
    /// date réelle émise par le minuteur.
    private func currentSystemNextBell(for site: BellSite) -> Date? {
        let appNow = effectiveDate(for: .now)
        guard let displayTarget = displayCountdownTarget(at: appNow, site: site) else {
            return nil
        }
        return systemDate(for: displayTarget)
    }

    /// Au premier plan, actualise immédiatement la Live Activity lors d'un changement
    /// de cible. Lorsque l'iPhone est verrouillé, le système prend le relais.
    private func refreshLiveActivityAtBellBoundaryIfNeeded(systemDate: Date) {
        guard scenePhase == .active,
              isLockScreenEnabled,
              let site = store.selectedSite else {
            return
        }

        let appDate = effectiveDate(for: systemDate)
        let nextDisplayBell = displayCountdownTarget(at: appDate, site: site)
        let nextSystemBell = nextDisplayBell.map(systemDate(for:))

        if lastObservedNextBellForActivity == nil {
            lastObservedNextBellForActivity = nextSystemBell
            return
        }

        let changed: Bool
        switch (lastObservedNextBellForActivity, nextSystemBell) {
        case let (old?, new?):
            changed = abs(old.timeIntervalSince(new)) > 1
        case (nil, nil):
            changed = false
        default:
            changed = true
        }

        guard changed else { return }
        lastObservedNextBellForActivity = nextSystemBell

        let dates = activityBellDates(for: site)
        Task {
            await LiveActivityManager.refreshAtBellBoundaryIfNeeded(
                for: site,
                bellDates: dates,
                usesCourseSchedule: !timetableStore.sessions.isEmpty,
                courseDetails: activityCourseDetails(),
                simulatedTimeOffset: activeTimeOffset
            )
        }
    }

    // MARK: - Changement de site

    private func selectSite(_ site: BellSite) {
        store.select(site)

        guard isLockScreenEnabled else { return }
        restartLockScreen(for: site)
    }

    private func restartLockScreen(for site: BellSite) {
        let dates = activityBellDates(for: site)
        isUpdatingLockScreen = true

        Task {
            do {
                try await LiveActivityManager.start(
                    for: site,
                    bellDates: dates,
                    usesCourseSchedule: !timetableStore.sessions.isEmpty,
                    courseDetails: activityCourseDetails(),
                    simulatedTimeOffset: activeTimeOffset
                )

                await MainActor.run {
                    isLockScreenEnabled = true
                    isUpdatingLockScreen = false
                    lastObservedNextBellForActivity = currentSystemNextBell(for: site)
                    liveActivityMessage = activityStatusMessage(for: site)
                }
            } catch {
                await MainActor.run {
                    isLockScreenEnabled = false
                    isUpdatingLockScreen = false
                    liveActivityMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Horloge de l’app

    private var activeTimeOffset: TimeInterval {
#if DEBUG
        debugSimulatedTimeEnabled ? debugSimulatedTimeOffset : 0
#else
        0
#endif
    }

    private func effectiveDate(for systemDate: Date) -> Date {
        systemDate.addingTimeInterval(activeTimeOffset)
    }

    private func systemDate(for effectiveDate: Date) -> Date {
        effectiveDate.addingTimeInterval(-activeTimeOffset)
    }

#if DEBUG
    @ViewBuilder
    private var developerClockBanner: some View {
        if debugSimulatedTimeEnabled {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 10) {
                    Image(systemName: "hammer.fill")
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Mode test actif"))
                            .font(.subheadline.weight(.semibold))

                        Text(debugDateTimeString(effectiveDate(for: context.date)))
                            .font(.caption)
                            .monospacedDigit()
                    }

                    Spacer()
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var debugSimulatedDateBinding: Binding<Date> {
        Binding(
            get: { effectiveDate(for: .now) },
            set: { newDate in
                setDebugSimulatedDate(newDate)
            }
        )
    }

    private var debugUpcomingBell: Date? {
        guard let site = store.selectedSite else { return nil }
        return engine.nextBell(
            after: effectiveDate(for: .now),
            at: site,
            suspendedUntil: store.activeScheduleSuspendedUntil
        )
    }

    private func setDebugSimulatedTimeEnabled(_ enabled: Bool) {
        debugSimulatedTimeEnabled = enabled
        if !enabled {
            debugSimulatedTimeOffset = 0
        }
        refreshDebugTimeConsumers()
    }

    private func setDebugSimulatedDate(_ date: Date) {
        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let normalizedDate = calendar.date(from: components) ?? date

        debugSimulatedTimeOffset = normalizedDate.timeIntervalSince(Date.now)
        debugSimulatedTimeEnabled = true
        refreshDebugTimeConsumers()
    }

    private func setDebugTime(minutesBeforeNextBell minutes: Int) {
        guard let nextBell = debugUpcomingBell else { return }
        setDebugSimulatedDate(
            nextBell.addingTimeInterval(TimeInterval(-minutes * 60))
        )
    }

    private func refreshDebugTimeConsumers() {

        guard isLockScreenEnabled else { return }
        refreshActiveLockScreenActivity()
    }

    private func debugDateTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
#endif

    // MARK: - Vibrations

    private func checkForBell(at currentDate: Date) {
        guard bellVibrationEnabled,
              scenePhase == .active,
              let site = store.selectedSite else {
            return
        }

        if store.isScheduleSuspended(at: currentDate) {
            return
        }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate)
        let validation = engine.validateBellTimes(site.bellTimes(for: weekday))

        for time in validation.normalizedTimes {
            guard let minuteOfDay = engine.minutesSinceMidnight(from: time) else {
                continue
            }

            let hour = minuteOfDay / 60
            let minute = minuteOfDay % 60

            guard let bellDate = calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: currentDate
            ) else {
                continue
            }

            let elapsed = currentDate.timeIntervalSince(bellDate)
            guard elapsed >= 0, elapsed < 2 else { continue }

            if let lastVibratedBell,
               abs(lastVibratedBell.timeIntervalSince(bellDate)) < 1 {
                continue
            }

            lastVibratedBell = bellDate

            Task {
                await vibrate(count: bellVibrationCount)
            }

            break
        }
    }

    @MainActor
    private func vibrate(count: Int) async {
        let safeCount = max(1, min(count, 10))

        for index in 0..<safeCount {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

            if index < safeCount - 1 {
                try? await Task.sleep(for: .milliseconds(600))
            }
        }
    }

    // MARK: - Suppression d'un site

    private func deleteSite(_ site: BellSite) {
        let wasSelected = store.selectedSiteID == site.id
        store.delete(site)
        sitePendingDeletion = nil

        guard wasSelected else { return }

        if let replacementSite = store.selectedSite {
            if isLockScreenEnabled {
                restartLockScreen(for: replacementSite)
            }
            return
        }

        if isLockScreenEnabled {
            Task {
                await LiveActivityManager.stopAll()
                await MainActor.run {
                    isLockScreenEnabled = false
                    isUpdatingLockScreen = false
                    liveActivityMessage = nil
                }
            }
        }
    }
}

// MARK: - Compte à rebours plein écran

private struct FullscreenCountdownView: View {
    @Environment(\.dismiss) private var dismiss

    let site: BellSite
    let suspendedUntil: Date?
    let timeOffset: TimeInterval

    private let engine = ScheduleEngine()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let currentDate = context.date.addingTimeInterval(timeOffset)

                GeometryReader { geometry in
                    Group {
                        if let nextBell = engine.nextBell(
                            after: currentDate,
                            at: site,
                            suspendedUntil: suspendedUntil
                        ) {
                            if engine.isSameDay(currentDate, nextBell) {
                                VStack(spacing: 28) {
                                    Text(site.name)
                                        .font(
                                            .system(
                                                size: min(geometry.size.width * 0.10, 48),
                                                weight: .bold,
                                                design: .rounded
                                            )
                                        )
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                        .multilineTextAlignment(.center)

                                    let remainingSeconds = max(
                                        0,
                                        nextBell.timeIntervalSince(currentDate)
                                    )

                                    if remainingSeconds < 60 {

                                        Text(
                                            L(
                                                "seconds.short",
                                                max(1, Int(remainingSeconds.rounded(.up)))
                                            )
                                        )
                                        .font(
                                            .system(
                                                size: min(
                                                    geometry.size.width * 0.31,
                                                    170
                                                ),
                                                weight: .bold,
                                                design: .rounded
                                            )
                                        )
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.35)
                                        .lineLimit(1)
                                        .foregroundStyle(.white)

                                    } else {

                                        Text(
                                            L(
                                                "fullscreen.minutes_remaining",
                                                remainingMinutes(
                                                    from: currentDate,
                                                    to: nextBell
                                                )
                                            )
                                        )
                                        .font(
                                            .system(
                                                size: min(
                                                    geometry.size.width * 0.31,
                                                    170
                                                ),
                                                weight: .bold,
                                                design: .rounded
                                            )
                                        )
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.35)
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                    }

                                    Text(
                                        L(
                                            "next_bell_at",
                                            engine.displayTime(for: nextBell)
                                        )
                                    )
                                    .font(
                                        .system(
                                            size: min(geometry.size.width * 0.075, 36),
                                            weight: .semibold,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.white.opacity(0.75))
                                    .multilineTextAlignment(.center)
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .center
                                )
                                .padding(.horizontal, 30)
                            } else {
                                VStack(spacing: 24) {
                                    Text(site.name)
                                        .font(
                                            .system(
                                                size: min(geometry.size.width * 0.10, 48),
                                                weight: .bold,
                                                design: .rounded
                                            )
                                        )
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)

                                    Text(L("Prochaine sonnerie :"))
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.7))

                                    Text(engine.displayDayAndTime(for: nextBell))
                                        .font(
                                            .system(
                                                size: 64,
                                                weight: .bold,
                                                design: .rounded
                                            )
                                        )
                                        .minimumScaleFactor(0.5)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.white)
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .center
                                )
                                .padding(.horizontal, 32)
                            }
                        } else {
                            VStack(spacing: 20) {
                                Text(site.name)
                                    .font(.title.bold())
                                    .foregroundStyle(.white)

                                Text(L("Aucune sonnerie configurée"))
                                    .font(.title2.bold())
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .multilineTextAlignment(.center)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .center
                            )
                            .padding(32)
                        }
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L("Fermer le plein écran")))
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .statusBarHidden(true)
    }

    private func remainingMinutes(from currentDate: Date, to nextBell: Date) -> Int {
        BellCountdownClock.remainingMinutes(from: currentDate, to: nextBell)
    }
}

// MARK: - Premier lancement

private struct OnboardingView: View {
    @ObservedObject var store: SiteStore
    @ObservedObject var locationService: LocationService

    let completion: () -> Void

    @State private var siteName = ""
    @State private var rawMondayTimes = ""
    @State private var copyMondayToFriday = true
    @State private var copyMondayToSaturday = false
    @State private var useRequestedLocation = false
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0

    private let engine = ScheduleEngine()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)

                    Text(L("Bienvenue dans Sonnerie Prof"))
                        .font(.largeTitle.bold())

                    Text(
                        L("Configurez un premier établissement. Aucun compte n'est requis et vos données restent sur l'iPhone.")
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Nom de l'établissement"))
                        .font(.headline)

                    TextField(L("Ex. Collège Jean-Moulin"), text: $siteName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Localisation (facultatif)"))
                        .font(.headline)

                    Text(
                        L("Elle permet uniquement de sélectionner automatiquement le bon site lorsque vous utilisez plusieurs établissements.")
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button {
                        useRequestedLocation = true

                        if let location = locationService.location {
                            latitude = location.coordinate.latitude
                            longitude = location.coordinate.longitude
                        } else {
                            locationService.requestCurrentLocation()
                        }
                    } label: {
                        Label(
                            latitude == 0 && longitude == 0
                                ? L("Utiliser ma position")
                                : L("Position enregistrée"),
                            systemImage: latitude == 0 && longitude == 0
                                ? "location"
                                : "checkmark.circle.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L("Sonneries du lundi"))
                        .font(.headline)

                    Text(L("Un horaire par ligne, au format HH:mm."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $rawMondayTimes)
                        .frame(minHeight: 150)
                        .font(.system(.body, design: .monospaced))
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    HStack {
                        quickAddButton(minutes: 55)
                        quickAddButton(minutes: 15)
                    }

                    if !validation.invalidValues.isEmpty {
                        Text(L("onboarding.invalid_times", validation.invalidValues.joined(separator: ", ")))
                        .font(.footnote)
                        .foregroundStyle(.red)
                    }

                    if validation.hasDuplicates {
                        Text(L("Les doublons seront supprimés automatiquement."))
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Toggle(L("Même horaires du lundi au vendredi"), isOn: $copyMondayToFriday)
                    Toggle(L("Même horaires le samedi"), isOn: $copyMondayToSaturday)
                }

                Button {
                    createFirstSite()
                } label: {
                    Text(L("Créer mon site"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canCreateSite)

                Button(L("Configurer plus tard")) {
                    completion()
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onReceive(locationService.$location.compactMap { $0 }) { location in
            guard useRequestedLocation else { return }
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        }
        .interactiveDismissDisabled()
    }

    private var rawLines: [String] {
        rawMondayTimes
            .replacingOccurrences(of: ",", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var validation: BellTimeValidation {
        engine.validateBellTimes(rawLines)
    }

    private var canCreateSite: Bool {
        !siteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        validation.isValid &&
        !validation.normalizedTimes.isEmpty
    }

    @ViewBuilder
    private func quickAddButton(minutes: Int) -> some View {
        Button(L("quick_add_minutes", minutes)) {
            appendTime(adding: minutes)
        }
        .buttonStyle(.bordered)
        .disabled(lastValidTime == nil)
    }

    private var lastValidTime: Int? {
        guard let last = rawLines.last else { return nil }
        return engine.minutesSinceMidnight(from: last)
    }

    private func appendTime(adding minutesToAdd: Int) {
        guard let lastTime = lastValidTime else { return }

        let newTotalMinutes = (lastTime + minutesToAdd) % (24 * 60)
        let newTime = String(
            format: "%02d:%02d",
            newTotalMinutes / 60,
            newTotalMinutes % 60
        )

        let cleaned = rawMondayTimes.trimmingCharacters(in: .whitespacesAndNewlines)
        rawMondayTimes = cleaned.isEmpty ? newTime : cleaned + "\n" + newTime
    }

    private func createFirstSite() {
        let times = validation.normalizedTimes
        var schedules: [WeekdaySchedule] = [
            WeekdaySchedule(weekday: 2, bellTimes: times)
        ]

        if copyMondayToFriday {
            for weekday in 3...6 {
                schedules.append(WeekdaySchedule(weekday: weekday, bellTimes: times))
            }
        }

        if copyMondayToSaturday {
            schedules.append(WeekdaySchedule(weekday: 7, bellTimes: times))
        }

        let site = BellSite(
            name: siteName.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            detectionRadiusMeters: 250,
            schedules: schedules
        )

        store.update(site)
        store.select(site)
        completion()
    }
}

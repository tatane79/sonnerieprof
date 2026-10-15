import SwiftUI

// Ces déclarations donnent à Xcode la valeur source française des clés utilisées
// par `L`, afin que le catalogue puisse les extraire et les traduire.
private enum CourseEditorLocalizationSources {
    static func registerForExtraction() {
        _ = String(localized: "Cours")
        _ = String(localized: "Classe (ex. 5e3)")
        _ = String(localized: "Salle (ex. 5e3)")
        _ = String(localized: "Horaire")
        _ = String(localized: "Début")
        _ = String(localized: "Fin")
        _ = String(localized: "Aucun horaire de sonnerie n’est configuré pour ce site et ce jour. Saisissez les horaires manuellement.")
        _ = String(localized: "L’heure de fin doit être après l’heure de début.")
        _ = String(localized: "Cette séance chevauche un ou plusieurs cours existants.")
        _ = String(localized: "Modifiez le jour, les horaires ou le type de semaine avant d’enregistrer.")
        _ = String(localized: "Toutes les semaines")
        _ = String(localized: "Type de semaine")
        _ = String(localized: "Par défaut, cette séance apparaît toutes les semaines. Désactivez l’option uniquement si son horaire dépend du type de semaine.")
        _ = String(localized: "Enregistrer et suivant")
        _ = String(localized: "Conserve le site, le jour et le type de semaine, puis prépare le créneau suivant.")
        _ = String(localized: "Nouveau cours")
        _ = String(localized: "Modifier le cours")
        _ = String(localized: "Autre horaire…")
        _ = String(localized: "Horaire personnalisé")
    }
}

private enum TimetableLocalizationSources {
    static func registerForExtraction() {
        _ = String(localized: "Personnaliser les noms des semaines")
        _ = String(localized: "Prochain cours")
        _ = String(localized: "Choisissez le type de la semaine actuelle. L’application alternera ensuite automatiquement entre le premier et le second type de semaine.")
    }
}

/// Écran de consultation et de paramétrage de l'emploi du temps hebdomadaire.
struct TimetableView: View {
    @Bindable var store: TimetableStore
    let sites: [BellSite]

    @State private var isAddingSession = false
    @State private var pendingCurrentWeek: TeachingWeek?
    @State private var isCustomizingWeekNames = false

    var body: some View {
        List {
            Section {
                Picker(L("Semaine actuelle"), selection: currentWeekSelection) {
                    Text(store.weekName(for: .q1)).tag(TeachingWeek.q1)
                    Text(store.weekName(for: .q2)).tag(TeachingWeek.q2)
                }
                .pickerStyle(.segmented)

                DisclosureGroup(
                    L("Personnaliser les noms des semaines"),
                    isExpanded: $isCustomizingWeekNames
                ) {
                    TextField(
                        L("Nom de la première semaine"),
                        text: weekNameBinding(for: .q1),
                        prompt: Text("Q1")
                    )
                    .textInputAutocapitalization(.characters)

                    TextField(
                        L("Nom de la deuxième semaine"),
                        text: weekNameBinding(for: .q2),
                        prompt: Text("Q2")
                    )
                    .textInputAutocapitalization(.characters)
                }
            } footer: {
                Text(
                    L("Choisissez le type de la semaine actuelle. L’application alternera ensuite automatiquement entre le premier et le second type de semaine.")
                )
            }

            if store.sortedSessions.isEmpty {
                Button {
                    requestNewSession()
                } label: {
                    ContentUnavailableView(
                        L("Aucun cours"),
                        systemImage: "calendar.badge.plus",
                        description: Text(
                            L(
                                "Ajoutez votre première séance. Elle sera utilisée en %@ et en %@ par défaut.",
                                store.weekName(for: .q1),
                                store.weekName(for: .q2)
                            )
                        )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(sites.isEmpty)
                .accessibilityHint(L("Ouvre l’écran de création d’un cours."))
            } else {
                ForEach(2...7, id: \.self) { weekday in
                    let sessions = store.sortedSessions.filter { $0.weekday == weekday }
                    if !sessions.isEmpty {
                        Section(weekdayName(weekday)) {
                            ForEach(sessions) { session in
                                NavigationLink {
                                    CourseSessionEditorView(
                                        store: store,
                                        sites: sites,
                                        session: session
                                    )
                                } label: {
                                    CourseSessionRow(
                                        session: session,
                                        siteName: sites.first(where: { $0.id == session.siteID })?.name,
                                        q1Name: store.weekName(for: .q1),
                                        q2Name: store.weekName(for: .q2)
                                    )
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        store.delete(session)
                                    } label: {
                                        Label(L("Supprimer"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L("Emploi du temps"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    requestNewSession()
                } label: {
                    Label(L("Ajouter un cours"), systemImage: "plus")
                }
                .disabled(sites.isEmpty)
            }
        }
        .sheet(isPresented: $isAddingSession) {
            NavigationStack {
                CourseSessionEditorView(
                    store: store,
                    sites: sites,
                    session: nil
                )
            }
        }
        .alert(
            L("Confirmer la semaine actuelle"),
            isPresented: confirmationIsPresented,
            presenting: pendingCurrentWeek
        ) { week in
            Button(L("Confirmer")) {
                store.setCurrentWeek(week)
                pendingCurrentWeek = nil
            }
            Button(L("Annuler"), role: .cancel) {
                pendingCurrentWeek = nil
            }
        } message: { week in
            Text(
                L(
                    "Confirmez-vous que la semaine en cours est %@ ? L’alternance automatique repartira de ce choix.",
                    store.weekName(for: week)
                )
            )
        }
    }

    private func requestNewSession() {
        isAddingSession = true
    }

    private var currentWeekSelection: Binding<TeachingWeek> {
        Binding(
            get: { store.displayedCurrentWeek },
            set: { newWeek in
                guard newWeek != store.displayedCurrentWeek else { return }
                pendingCurrentWeek = newWeek
            }
        )
    }

    private var confirmationIsPresented: Binding<Bool> {
        Binding(
            get: { pendingCurrentWeek != nil },
            set: { isPresented in
                if !isPresented {
                    pendingCurrentWeek = nil
                }
            }
        )
    }

    private func weekNameBinding(for week: TeachingWeek) -> Binding<String> {
        Binding(
            get: { week == .q1 ? store.q1Name : store.q2Name },
            set: { store.setWeekName($0, for: week) }
        )
    }

    private func weekdayName(_ weekday: Int) -> String {
        var calendar = Calendar.current
        calendar.locale = appDisplayLocale()
        let symbols = calendar.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1].localizedCapitalized
    }
}

private struct CourseSessionRow: View {
    let session: CourseSession
    let siteName: String?
    let q1Name: String
    let q2Name: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeRange)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(session.className)
                    .font(.headline)

                Label(session.roomName, systemImage: "door.left.hand.open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let siteName {
                    Text(siteName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if session.weekPattern != .everyWeek {
                    Text(session.weekPattern == .q1 ? q1Name : q2Name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.14), in: Capsule())
                }
            }
        }
    }

    private var timeRange: String {
        "\(displayTime(session.startMinutes)) – \(displayTime(session.endMinutes))"
    }

    private func displayTime(_ minutes: Int) -> String {
        ScheduleEngine().displayTime(
            for: TimetableEngine().date(minutesSinceMidnight: minutes)
        )
    }
}

/// Formulaire d'une séance, avec suggestions issues des sonneries et contrôle des conflits.
struct CourseSessionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var store: TimetableStore
    let sites: [BellSite]
    let existingSessionID: UUID?

    @State private var draftSessionID: UUID
    @State private var className: String
    @State private var roomName: String
    @State private var roomNameWasCustomized: Bool
    @State private var siteID: UUID
    @State private var weekday: Int
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var startSelection: Int
    @State private var endSelection: Int
    @State private var appliesEveryWeek: Bool
    @State private var selectedWeek: TeachingWeek
    @State private var scrollToTopRequest = 0
    @FocusState private var isClassNameFocused: Bool

    private let engine = TimetableEngine()

    init(
        store: TimetableStore,
        sites: [BellSite],
        session: CourseSession?
    ) {
        self.store = store
        self.sites = sites
        self.existingSessionID = session?.id

        let initialSiteID = session?.siteID ?? sites.first?.id ?? UUID()
        let initialWeekday = session?.weekday ?? 2
        let initialBellMinutes = sites
            .first(where: { $0.id == initialSiteID })?
            .bellTimes(for: initialWeekday)
            .compactMap { ScheduleEngine().minutesSinceMidnight(from: $0) }
            .sorted() ?? []
        let defaultStart = initialBellMinutes.first ?? 8 * 60
        let defaultEnd = initialBellMinutes.first(where: { $0 > defaultStart }) ?? 9 * 60
        let initialStart = session?.startMinutes ?? defaultStart
        let initialEnd = session?.endMinutes ?? defaultEnd
        let pattern = session?.weekPattern ?? .everyWeek

        let initialClassName = session?.className ?? ""
        let initialRoomName = session?.roomName ?? initialClassName
        _draftSessionID = State(initialValue: session?.id ?? UUID())
        _className = State(initialValue: initialClassName)
        _roomName = State(initialValue: initialRoomName)
        _roomNameWasCustomized = State(initialValue: initialRoomName != initialClassName)
        _siteID = State(initialValue: initialSiteID)
        _weekday = State(initialValue: initialWeekday)
        _startTime = State(initialValue: engine.date(minutesSinceMidnight: initialStart))
        _endTime = State(initialValue: engine.date(minutesSinceMidnight: initialEnd))
        _startSelection = State(
            initialValue: initialBellMinutes.contains(initialStart) ? initialStart : -1
        )
        _endSelection = State(
            initialValue: initialBellMinutes.contains(initialEnd) ? initialEnd : -1
        )
        _appliesEveryWeek = State(initialValue: pattern == .everyWeek)
        _selectedWeek = State(initialValue: pattern == .q2 ? .q2 : .q1)
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section(L("Cours")) {
                TextField(L("Classe (ex. 5e3)"), text: $className)
                    .focused($isClassNameFocused)

                TextField(L("Salle (ex. 5e3)"), text: $roomName)

                Picker(L("Site"), selection: $siteID) {
                    ForEach(sites) { site in
                        Text(site.name).tag(site.id)
                    }
                }

                Picker(L("Jour"), selection: $weekday) {
                    ForEach(2...7, id: \.self) { value in
                        Text(weekdayName(value)).tag(value)
                    }
                }
            }
            .id("course-editor-top")

            Section(L("Horaire")) {
                BellTimePicker(
                    title: L("Début"),
                    suggestions: availableBellMinutes,
                    selection: $startSelection,
                    customTime: $startTime
                )

                BellTimePicker(
                    title: L("Fin"),
                    suggestions: availableBellMinutes,
                    selection: $endSelection,
                    customTime: $endTime
                )

                if availableBellMinutes.isEmpty {
                    Label(
                        L("Aucun horaire de sonnerie n’est configuré pour ce site et ce jour. Saisissez les horaires manuellement."),
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if !hasValidTimeRange {
                    Label(L("L’heure de fin doit être après l’heure de début."), systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if !conflictingSessions.isEmpty {
                Section {
                    Label(
                        L("Cette séance chevauche un ou plusieurs cours existants."),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.red)

                    ForEach(conflictingSessions) { session in
                        CourseConflictRow(
                            className: session.className,
                            roomName: session.roomName,
                            startMinutes: session.startMinutes,
                            endMinutes: session.endMinutes,
                            weekPattern: session.weekPattern,
                            q1Name: store.weekName(for: .q1),
                            q2Name: store.weekName(for: .q2)
                        )
                    }
                } header: {
                    Text(L("Conflit d’emploi du temps"))
                } footer: {
                    Text(L("Modifiez le jour, les horaires ou le type de semaine avant d’enregistrer."))
                }
            }

            Section {
                Toggle(L("Toutes les semaines"), isOn: $appliesEveryWeek)

                if !appliesEveryWeek {
                    Picker(L("Type de semaine"), selection: $selectedWeek) {
                        Text(store.weekName(for: .q1)).tag(TeachingWeek.q1)
                        Text(store.weekName(for: .q2)).tag(TeachingWeek.q2)
                    }
                    .pickerStyle(.segmented)
                }
            } footer: {
                Text(
                    L(
                        "Par défaut, cette séance apparaît toutes les semaines. Désactivez l’option uniquement si son horaire dépend du type de semaine."
                    )
                )
            }

            if existingSessionID == nil {
                Section {
                    Button {
                        saveAndContinue()
                    } label: {
                        Label(L("Enregistrer et suivant"), systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                } footer: {
                    Text(L("Conserve le site, le jour et le type de semaine, puis prépare le créneau suivant."))
                }
            }
        }
        .onChange(of: className) { _, newClassName in
            guard !roomNameWasCustomized else { return }
            roomName = newClassName
        }
        .onChange(of: roomName) { _, newRoomName in
            roomNameWasCustomized = newRoomName != className
        }
        .onChange(of: siteID) { _, _ in
            synchronizeTimeSelections()
        }
        .onChange(of: weekday) { _, _ in
            synchronizeTimeSelections()
        }
        .onChange(of: startSelection) { _, selection in
            guard selection >= 0 else { return }
            startTime = engine.date(minutesSinceMidnight: selection)
            selectNextBell(after: selection)
        }
        .onChange(of: endSelection) { _, selection in
            guard selection >= 0 else { return }
            endTime = engine.date(minutesSinceMidnight: selection)
        }
        .onChange(of: startTime) { _, newTime in
            guard startSelection == -1 else { return }
            selectNextBell(after: engine.minutesSinceMidnight(for: newTime))
        }
        .navigationTitle(existingSessionID == nil ? L("Nouveau cours") : L("Modifier le cours"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if existingSessionID == nil {
                    Button(L("Annuler")) {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(L("Enregistrer")) {
                    saveAndDismiss()
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: scrollToTopRequest) { _, _ in
            proxy.scrollTo("course-editor-top", anchor: .top)

            Task { @MainActor in
                await Task.yield()
                isClassNameFocused = true
            }
        }
        }
    }

    private var availableBellMinutes: [Int] {
        guard let site = sites.first(where: { $0.id == siteID }) else {
            return []
        }

        return Array(
            Set(
                site.bellTimes(for: weekday)
                    .compactMap { ScheduleEngine().minutesSinceMidnight(from: $0) }
            )
        )
        .sorted()
    }

    private func synchronizeTimeSelections() {
        let startMinutes = engine.minutesSinceMidnight(for: startTime)
        let endMinutes = engine.minutesSinceMidnight(for: endTime)
        startSelection = availableBellMinutes.contains(startMinutes) ? startMinutes : -1
        endSelection = availableBellMinutes.contains(endMinutes) ? endMinutes : -1
    }

    private func selectNextBell(after startMinutes: Int) {
        guard let nextBell = availableBellMinutes.first(where: { $0 > startMinutes }) else {
            return
        }

        endSelection = nextBell
        endTime = engine.date(minutesSinceMidnight: nextBell)
    }

    private var conflictingSessions: [CourseSession] {
        guard hasValidTimeRange else { return [] }
        return engine.conflicts(for: makeSession(), in: store.sessions)
    }

    private var canSave: Bool {
        !className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sites.contains(where: { $0.id == siteID })
            && hasValidTimeRange
            && conflictingSessions.isEmpty
    }

    private var hasValidTimeRange: Bool {
        engine.minutesSinceMidnight(for: endTime) > engine.minutesSinceMidnight(for: startTime)
    }

    private func saveAndDismiss() {
        store.save(makeSession())
        dismiss()
    }

    private func saveAndContinue() {
        let previousStart = engine.minutesSinceMidnight(for: startTime)
        let previousEnd = engine.minutesSinceMidnight(for: endTime)

        store.save(makeSession())
        draftSessionID = UUID()
        className = ""
        roomName = ""
        roomNameWasCustomized = false

        if let followingEnd = availableBellMinutes.first(where: { $0 > previousEnd }) {
            startTime = engine.date(minutesSinceMidnight: previousEnd)
            startSelection = availableBellMinutes.contains(previousEnd) ? previousEnd : -1
            endTime = engine.date(minutesSinceMidnight: followingEnd)
            endSelection = followingEnd
        } else {
            startTime = engine.date(minutesSinceMidnight: previousStart)
            endTime = engine.date(minutesSinceMidnight: previousEnd)
        }

        isClassNameFocused = false
        scrollToTopRequest += 1
    }

    private func makeSession() -> CourseSession {
        CourseSession(
            id: draftSessionID,
            className: className,
            roomName: roomName,
            siteID: siteID,
            weekday: weekday,
            startMinutes: engine.minutesSinceMidnight(for: startTime),
            endMinutes: engine.minutesSinceMidnight(for: endTime),
            weekPattern: appliesEveryWeek
                ? .everyWeek
                : (selectedWeek == .q1 ? .q1 : .q2)
        )
    }

    private func weekdayName(_ weekday: Int) -> String {
        var calendar = Calendar.current
        calendar.locale = appDisplayLocale()
        let symbols = calendar.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1].localizedCapitalized
    }
}


private struct CourseConflictRow: View {
    let className: String
    let roomName: String
    let startMinutes: Int
    let endMinutes: Int
    let weekPattern: CourseWeekPattern
    let q1Name: String
    let q2Name: String

    private let engine = TimetableEngine()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(className)
                    .font(.headline)

                Label(roomName, systemImage: "door.left.hand.open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(
                    "\(displayTime(startMinutes)) – \(displayTime(endMinutes))"
                )
                .font(.subheadline.monospacedDigit())

                Text(weekLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weekLabel: String {
        switch weekPattern {
        case .everyWeek:
            "\(q1Name) + \(q2Name)"
        case .q1:
            q1Name
        case .q2:
            q2Name
        }
    }

    private func displayTime(_ minutes: Int) -> String {
        ScheduleEngine().displayTime(
            for: engine.date(minutesSinceMidnight: minutes)
        )
    }
}

private struct BellTimePicker: View {
    let title: String
    let suggestions: [Int]
    @Binding var selection: Int
    @Binding var customTime: Date

    private let engine = TimetableEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: $selection) {
                ForEach(suggestions, id: \.self) { minutes in
                    Text(
                        engine.date(minutesSinceMidnight: minutes),
                        format: .dateTime.hour().minute()
                    )
                    .tag(minutes)
                }

                Divider()

                Text(L("Autre horaire…"))
                    .tag(-1)
            }
            .pickerStyle(.menu)

            if selection == -1 {
                DatePicker(
                    L("Horaire personnalisé"),
                    selection: $customTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
            }
        }
    }
}

/// Résumé du cours en cours et du prochain cours affiché sur l'écran principal.
struct CourseStatusCard: View {
    let sessions: [CourseSession]
    let sites: [BellSite]
    let referenceWeekStart: Date
    let referenceWeek: TeachingWeek

    private let engine = TimetableEngine()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let status = engine.status(
                at: context.date,
                sessions: sessions,
                referenceWeekStart: referenceWeekStart,
                referenceWeek: referenceWeek
            )

            VStack(alignment: .leading, spacing: 12) {
                Label(L("Cours"), systemImage: "person.crop.rectangle.stack")
                    .font(.headline)

                if let current = status.current {
                    statusLine(
                        title: L("Classe en cours"),
                        occurrence: current,
                        accent: true
                    )
                } else {
                    Text(L("Aucun cours en ce moment"))
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let next = status.next {
                    statusLine(
                        title: L("Prochain cours"),
                        occurrence: next,
                        accent: false
                    )
                } else {
                    Text(L("Aucun prochain cours programmé"))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func statusLine(
        title: String,
        occurrence: CourseOccurrence,
        accent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text(occurrence.session.className)
                    .font(.title3.weight(.semibold))

                Text("–")
                    .foregroundStyle(.secondary)

                Text(occurrence.startDate, format: .dateTime.hour().minute())
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()

                Spacer()

                if let siteName = sites.first(where: { $0.id == occurrence.session.siteID })?.name {
                    Text(siteName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(accent ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))

            Label(occurrence.session.roomName, systemImage: "door.left.hand.open")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

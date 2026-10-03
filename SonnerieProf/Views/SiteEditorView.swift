import CoreLocation
import SwiftUI

/// Formulaire de création ou de modification d'un établissement et de ses sonneries.
struct SiteEditorView: View {
    @ObservedObject var store: SiteStore
    @ObservedObject var locationService: LocationService

    @State private var draft: BellSite
    @State private var lastPersistedDraft: BellSite
    @State private var showCopyMondayConfirmation = false
    @State private var captureLocationWhenAvailable = false
    @State private var showsBuiltInPresets: Bool

    init(
        site: BellSite,
        store: SiteStore,
        locationService: LocationService
    ) {
        self.store = store
        self.locationService = locationService
        _draft = State(initialValue: site)
        _lastPersistedDraft = State(initialValue: site)
        _showsBuiltInPresets = State(
            initialValue: site.name.isEmpty && site.schedules.isEmpty
        )
    }

    var body: some View {
        Form {
            if showsBuiltInPresets {
                Section {
                    ForEach(BuiltInSitePresets.all) { preset in
                        Button {
                            apply(preset)
                        } label: {
                            Label {
                                Text(verbatim: preset.name)
                            } icon: {
                                Image(systemName: "building.columns.fill")
                            }
                        }
                    }
                }
            }

            Section {
                LabeledContent {
                    TextField(L("Ex. Collège Jean-Moulin"), text: $draft.name)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel(Text(L("Nom")))
                } label: {
                    Label(L("Nom"), systemImage: "building.columns.fill")
                }

                LabeledContent {
                    TextField(
                        L("Latitude"),
                        value: $draft.latitude,
                        format: .number.precision(.fractionLength(6)),
                        prompt: Text(verbatim: "48.856600")
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .accessibilityLabel(Text(L("Latitude")))
                } label: {
                    Text(L("Latitude"))
                }

                LabeledContent {
                    TextField(
                        L("Longitude"),
                        value: $draft.longitude,
                        format: .number.precision(.fractionLength(6)),
                        prompt: Text(verbatim: "2.352200")
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numbersAndPunctuation)
                    .accessibilityLabel(Text(L("Longitude")))
                } label: {
                    Text(L("Longitude"))
                }

                LabeledContent {
                    TextField(
                        L("Rayon (m)"),
                        value: $draft.detectionRadiusMeters,
                        format: .number,
                        prompt: Text(verbatim: "250")
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .accessibilityLabel(Text(L("Rayon (m)")))
                } label: {
                    Text(L("Rayon (m)"))
                }

                Button {
                    captureLocationWhenAvailable = true

                    if let location = locationService.location {
                        draft.latitude = location.coordinate.latitude
                        draft.longitude = location.coordinate.longitude
                        captureLocationWhenAvailable = false
                    } else {
                        locationService.requestCurrentLocation()
                    }
                } label: {
                    Label(L("Utiliser ma position actuelle"), systemImage: "scope")
                }

                if locationService.location == nil {
                    Text(
                        L("La localisation est facultative. Elle sert uniquement à sélectionner automatiquement le site le plus proche et n'est ni conservée séparément ni transmise.")
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text(L("Site"))
            } footer: {
                Text(L("Les modifications sont enregistrées automatiquement."))
            }

            Section {
                ForEach(2...7, id: \.self) { weekday in
                    NavigationLink {
                        DayScheduleEditorView(
                            site: $draft,
                            weekday: weekday,
                            onPersist: persistDraftIfPossible
                        )
                    } label: {
                        HStack {
                            Text(dayName(weekday))
                            Spacer()
                            Text(scheduleCountText(draft.bellTimes(for: weekday).count))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    showCopyMondayConfirmation = true
                } label: {
                    Label(
                        L("Appliquer le lundi à toute la semaine"),
                        systemImage: "doc.on.doc"
                    )
                }
                .disabled(draft.bellTimes(for: 2).isEmpty)
            } header: {
                Text(L("Sonneries"))
            } footer: {
                Text(
                    L("Saisissez les horaires jour par jour ou recopiez ceux du lundi sur le mardi, mercredi, jeudi, vendredi et samedi.")
                )
            }
        }
        .navigationTitle(draft.name.isEmpty ? L("Nouveau site") : draft.name)
        .alert(
            L("Appliquer les horaires du lundi ?"),
            isPresented: $showCopyMondayConfirmation
        ) {
            Button(L("Annuler"), role: .cancel) {}
            Button(L("Écraser les horaires"), role: .destructive) {
                copyMondayToWholeWeek()
            }
        } message: {
            Text(
                L("Les horaires du mardi au samedi seront remplacés par ceux définis pour le lundi.")
            )
        }
        .onReceive(locationService.$location.compactMap { $0 }) { location in
            guard captureLocationWhenAvailable else { return }
            draft.latitude = location.coordinate.latitude
            draft.longitude = location.coordinate.longitude
            captureLocationWhenAvailable = false
        }
        .task(id: draft) {
            // Temporise l'écriture pour éviter de persister à chaque frappe clavier.
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            persistDraftIfPossible()
        }
        .onDisappear {
            persistDraftIfPossible()
        }
    }

    private func persistDraftIfPossible() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var normalized = draft
        normalized.name = trimmedName

        guard normalized != lastPersistedDraft else { return }

        store.update(normalized)
        lastPersistedDraft = normalized
    }

    private func apply(_ preset: BuiltInSitePreset) {
        draft = preset.makeSite(id: draft.id)
        showsBuiltInPresets = false
        persistDraftIfPossible()
    }

    private func dayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        let symbols = formatter.weekdaySymbols ?? []

        guard symbols.indices.contains(weekday - 1) else {
            return L("day.fallback", weekday)
        }

        return symbols[weekday - 1].capitalized(with: appDisplayLocale())
    }

    private func scheduleCountText(_ count: Int) -> String {
        count == 1
            ? L("site.schedule_count.one", count)
            : L("site.schedule_count.many", count)
    }

    private func copyMondayToWholeWeek() {
        let mondayTimes = draft.bellTimes(for: 2)
        guard !mondayTimes.isEmpty else { return }

        for weekday in 2...7 {
            draft.setBellTimes(mondayTimes, for: weekday)
        }

        persistDraftIfPossible()
    }
}

// MARK: - Édition des horaires d'un jour

private struct DayScheduleEditorView: View {
    @Binding var site: BellSite
    let weekday: Int
    let onPersist: () -> Void

    @State private var rawTimes = ""

    private let engine = ScheduleEngine()

    var body: some View {
        Form {
            Section {
                TextEditor(text: $rawTimes)
                    .frame(minHeight: 200)
                    .font(.system(.body, design: .monospaced))
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack(spacing: 12) {
                    Button {
                        appendTime(adding: 55)
                    } label: {
                        Label(L("+55 min"), systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(lastValidTime == nil)

                    Button {
                        appendTime(adding: 15)
                    } label: {
                        Label(L("+15 min"), systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(lastValidTime == nil)
                }
            } header: {
                Text(L("Horaires HH:mm"))
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        L("Un horaire par ligne. Les boutons ajoutent automatiquement une ligne à partir du dernier horaire saisi.")
                    )

                    if !validation.invalidValues.isEmpty {
                        Text(L("editor.invalid_times", validation.invalidValues.joined(separator: ", ")))
                            .foregroundStyle(.red)
                    }

                    if validation.hasDuplicates {
                        Text(duplicateCountText(validation.duplicateCount))
                            .foregroundStyle(.orange)
                    }

                    if validation.isValid && !parsedTimes.isEmpty {
                        Text(
                            L("Les horaires seront triés automatiquement et normalisés au format HH:mm.")
                        )
                        .foregroundStyle(.secondary)
                    }

                    Text(L("Les modifications valides sont enregistrées automatiquement."))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(dayName)
        .onAppear {
            rawTimes = site.bellTimes(for: weekday).joined(separator: "\n")
        }
        .task(id: rawTimes) {
            // Une courte temporisation évite de sauvegarder un horaire intermédiaire
            // pendant que l'utilisateur est encore en train de le taper.
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            saveTimesIfValid(normalizeEditor: false)
        }
        .onDisappear {
            saveTimesIfValid(normalizeEditor: true)
        }
    }

    private var parsedTimes: [String] {
        rawTimes
            .replacingOccurrences(of: ",", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var validation: BellTimeValidation {
        engine.validateBellTimes(parsedTimes)
    }

    private var lastValidTime: Int? {
        guard let last = parsedTimes.last else { return nil }
        return engine.minutesSinceMidnight(from: last)
    }

    private func appendTime(adding minutesToAdd: Int) {
        guard let lastTime = lastValidTime else { return }

        let newTotalMinutes = (lastTime + minutesToAdd) % (24 * 60)
        let hours = newTotalMinutes / 60
        let minutes = newTotalMinutes % 60
        let newTime = String(format: "%02d:%02d", hours, minutes)

        let cleanedText = rawTimes.trimmingCharacters(in: .whitespacesAndNewlines)
        rawTimes = cleanedText.isEmpty ? newTime : cleanedText + "\n" + newTime
    }

    private func duplicateCountText(_ count: Int) -> String {
        count == 1
            ? L("editor.duplicate_count.one", count)
            : L("editor.duplicate_count.many", count)
    }

    private func saveTimesIfValid(normalizeEditor: Bool) {
        guard validation.isValid else { return }

        let normalizedTimes = validation.normalizedTimes
        let previousTimes = site.bellTimes(for: weekday)

        if normalizedTimes != previousTimes {
            site.setBellTimes(normalizedTimes, for: weekday)
            onPersist()
        }

        if normalizeEditor {
            let normalizedText = normalizedTimes.joined(separator: "\n")
            if rawTimes != normalizedText {
                rawTimes = normalizedText
            }
        }
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = appDisplayLocale()
        let symbols = formatter.weekdaySymbols ?? []

        return symbols.indices.contains(weekday - 1)
            ? symbols[weekday - 1].capitalized(with: appDisplayLocale())
            : L("Jour")
    }
}

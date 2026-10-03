import SwiftUI

private enum CloudTransferLocalizationSources {
    static func registerForExtraction() {
        _ = String(localized: "Aucun établissement")
        _ = String(localized: "Ajoutez d’abord un établissement et ses horaires.")
        _ = String(localized: "Établissement à partager")
        _ = String(localized: "Créer un code de partage")
        _ = String(localized: "Code de partage")
        _ = String(localized: "Horaires de sonnerie")
        _ = String(localized: "Importez ces horaires dans Sonnerie Prof avec ce code : %@")
        _ = String(localized: "Partager le code")
        _ = String(localized: "Partager les horaires d’un établissement")
        _ = String(localized: "Seuls le nom de l’établissement et les horaires de sonnerie sont publiés. La position et l’emploi du temps personnel ne sont jamais partagés.")
        _ = String(localized: "Importer les horaires")
        _ = String(localized: "Charger les horaires d’un collègue")
        _ = String(localized: "L’import crée un nouvel établissement local. Vous pourrez ensuite ajouter sa position sans modifier les horaires partagés.")
        _ = String(localized: "Sauvegarder maintenant")
        _ = String(localized: "Restaurer depuis iCloud")
        _ = String(localized: "Sauvegarde personnelle iCloud")
        _ = String(localized: "La sauvegarde privée contient l’emploi du temps, les noms de semaines et vos établissements afin de préserver les liens entre les cours et leurs sites.")
        _ = String(localized: "Communication avec iCloud…")
        _ = String(localized: "Connectez-vous à iCloud pour utiliser la sauvegarde et le partage.")
        _ = String(localized: "iCloud et partage")
        _ = String(localized: "Restaurer la sauvegarde ?")
        _ = String(localized: "Restaurer")
        _ = String(localized: "Les données locales seront remplacées par la sauvegarde iCloud.")
        _ = String(localized: "Le code de partage a été créé.")
        _ = String(localized: "Les horaires ont été importés.")
        _ = String(localized: "La sauvegarde iCloud est à jour.")
        _ = String(localized: "La sauvegarde iCloud a été restaurée.")
        _ = String(localized: "Le code de partage n’est pas valide.")
        _ = String(localized: "Les données iCloud reçues sont illisibles.")
        _ = String(localized: "Supprimez un établissement avant d’en importer un autre.")
    }
}

struct CloudTransferView: View {
    @ObservedObject var siteStore: SiteStore
    @Bindable var timetableStore: TimetableStore

    @State private var selectedSiteID: UUID?
    @State private var shareCode = ""
    @State private var importCode = ""
    @State private var isWorking = false
    @State private var isICloudAvailable = true
    @State private var pendingBackup: TimetableBackup?
    @State private var message: String?

    private let cloud = CloudDataService()

    var body: some View {
        Form {
            Section {
                if siteStore.sites.isEmpty {
                    ContentUnavailableView(
                        L("Aucun établissement"),
                        systemImage: "building.columns",
                        description: Text(L("Ajoutez d’abord un établissement et ses horaires."))
                    )
                } else {
                    Picker(L("Établissement à partager"), selection: $selectedSiteID) {
                        ForEach(siteStore.sites) { site in
                            Text(site.name).tag(Optional(site.id))
                        }
                    }

                    Button {
                        publishSelectedSite()
                    } label: {
                        Label(L("Créer un code de partage"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(isWorking || selectedSite == nil)

                    if !shareCode.isEmpty {
                        LabeledContent(L("Code de partage")) {
                            Text(shareCode)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }

                        ShareLink(
                            item: shareCode,
                            subject: Text(L("Horaires de sonnerie")),
                            message: Text(L("Importez ces horaires dans Sonnerie Prof avec ce code : %@", shareCode))
                        ) {
                            Label(L("Partager le code"), systemImage: "square.and.arrow.up")
                        }
                    }
                }
            } header: {
                Text(L("Partager les horaires d’un établissement"))
            } footer: {
                Text(L("Seuls le nom de l’établissement et les horaires de sonnerie sont publiés. La position et l’emploi du temps personnel ne sont jamais partagés."))
            }

            Section {
                TextField(L("Code de partage"), text: $importCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    importSharedSchedule()
                } label: {
                    Label(L("Importer les horaires"), systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking || importCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text(L("Charger les horaires d’un collègue"))
            } footer: {
                Text(L("L’import crée un nouvel établissement local. Vous pourrez ensuite ajouter sa position sans modifier les horaires partagés."))
            }

            Section {
                Button {
                    saveBackup()
                } label: {
                    Label(L("Sauvegarder maintenant"), systemImage: "icloud.and.arrow.up")
                }
                .disabled(isWorking || !isICloudAvailable)

                Button {
                    prepareRestore()
                } label: {
                    Label(L("Restaurer depuis iCloud"), systemImage: "icloud.and.arrow.down")
                }
                .disabled(isWorking || !isICloudAvailable)
            } header: {
                Text(L("Sauvegarde personnelle iCloud"))
            } footer: {
                Text(L("La sauvegarde privée contient l’emploi du temps, les noms de semaines et vos établissements afin de préserver les liens entre les cours et leurs sites."))
            }

            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text(L("Communication avec iCloud…"))
                    }
                }
            }

            if !isICloudAvailable {
                Section {
                    Label(
                        L("Connectez-vous à iCloud pour utiliser la sauvegarde et le partage."),
                        systemImage: "exclamationmark.icloud"
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(L("iCloud et partage"))
        .task {
            selectedSiteID = siteStore.selectedSiteID ?? siteStore.sites.first?.id
            do {
                isICloudAvailable = try await cloud.accountIsAvailable()
            } catch {
                isICloudAvailable = false
            }
        }
        .alert(
            L("Restaurer la sauvegarde ?"),
            isPresented: Binding(
                get: { pendingBackup != nil },
                set: { if !$0 { pendingBackup = nil } }
            )
        ) {
            Button(L("Annuler"), role: .cancel) {
                pendingBackup = nil
            }
            Button(L("Restaurer"), role: .destructive) {
                restorePendingBackup()
            }
        } message: {
            Text(L("Les données locales seront remplacées par la sauvegarde iCloud."))
        }
        .alert(
            L("iCloud"),
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button(L("OK")) {
                message = nil
            }
        } message: {
            Text(message ?? "")
        }
    }

    private var selectedSite: BellSite? {
        guard let selectedSiteID else { return nil }
        return siteStore.sites.first { $0.id == selectedSiteID }
    }

    private func publishSelectedSite() {
        guard let selectedSite else { return }
        performCloudOperation {
            shareCode = try await cloud.publish(selectedSite)
            message = L("Le code de partage a été créé.")
        }
    }

    private func importSharedSchedule() {
        performCloudOperation {
            guard siteStore.canAddSite else {
                throw CloudDataError.siteLimitReached
            }
            let sharedSchedule = try await cloud.sharedSchedule(for: importCode)
            let site = sharedSchedule.makeLocalSite()
            siteStore.update(site)
            siteStore.select(site)
            selectedSiteID = site.id
            importCode = ""
            message = L("Les horaires ont été importés.")
        }
    }

    private func saveBackup() {
        performCloudOperation {
            let backup = timetableStore.makeBackup(
                sites: siteStore.sites,
                selectedSiteID: siteStore.selectedSiteID
            )
            try await cloud.saveBackup(backup)
            message = L("La sauvegarde iCloud est à jour.")
        }
    }

    private func prepareRestore() {
        performCloudOperation {
            pendingBackup = try await cloud.fetchBackup()
        }
    }

    private func restorePendingBackup() {
        guard let backup = pendingBackup else { return }
        siteStore.restore(sites: backup.sites, selectedSiteID: backup.selectedSiteID)
        timetableStore.restore(backup)
        pendingBackup = nil
        message = L("La sauvegarde iCloud a été restaurée.")
    }

    private func performCloudOperation(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !isWorking else { return }
        isWorking = true
        Task { @MainActor in
            defer { isWorking = false }
            do {
                try await operation()
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

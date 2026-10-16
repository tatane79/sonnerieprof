import Observation
import StoreKit

// Ces déclarations donnent à Xcode la valeur source française des clés utilisées
// par `L`, afin que le catalogue puisse les extraire et les traduire.
private enum TipLocalizationSources {
    static func registerForExtraction() {
        _ = String(localized: "tip.navigation_title", defaultValue: "Soutenir Sonnerie Prof")
        _ = String(localized: "tip.title", defaultValue: "Un petit coup de pouce ?")
        _ = String(localized: "tip.body", defaultValue: "Toutes les fonctions de Sonnerie Prof sont gratuites. Si l’app vous aide au quotidien, vous pouvez soutenir son développement avec un pourboire facultatif.")
        _ = String(localized: "tip.no_unlock", defaultValue: "Le pourboire est entièrement facultatif et ne débloque aucune fonction.")
        _ = String(localized: "tip.products_unavailable", defaultValue: "Les pourboires sont momentanément indisponibles.")
        _ = String(localized: "tip.products_load_error", defaultValue: "Impossible de charger les propositions de pourboire.")
        _ = String(localized: "tip.purchase_pending", defaultValue: "Le paiement attend une autorisation.")
        _ = String(localized: "tip.purchase_error", defaultValue: "Le paiement n’a pas pu être effectué.")
        _ = String(localized: "tip.thank_you_title", defaultValue: "Merci beaucoup !")
        _ = String(localized: "tip.thank_you_message", defaultValue: "Merci de soutenir le développement de Sonnerie Prof.")
        _ = String(localized: "tip.product.small", defaultValue: "Petit merci")
        _ = String(localized: "tip.product.medium", defaultValue: "Un café")
        _ = String(localized: "tip.product.large", defaultValue: "Grand merci")
        _ = String(localized: "tip.voluntary", defaultValue: "Pourboire facultatif")
        _ = String(localized: "tip.debug_show", defaultValue: "Un petit coup de pouce pour Sonnerie Prof ?")
        _ = String(localized: "tip.support_button", defaultValue: "Soutenir Sonnerie Prof")
        _ = String(localized: "tip.support_about", defaultValue: "Sonnerie Prof est gratuite et toutes ses fonctions sont disponibles sans paiement. Si vous le souhaitez, vous pouvez soutenir son développement avec un pourboire facultatif.")
        _ = String(localized: "tip.support_section", defaultValue: "Soutenir l’application")
    }
}

/// Utilise le catalogue lorsqu'une traduction existe et garantit un texte français
/// lisible tant que les clés historiques du Tip Jar n'y ont pas été réimportées.
func TipL(_ key: String, fallback: String) -> String {
    let localized = L(key)
    return localized == key ? fallback : localized
}

/// Gère les pourboires volontaires et leur rappel hebdomadaire.
/// Aucun achat ne débloque de fonctionnalité.
@MainActor
@Observable
final class TipJarStore {
    static let smallTipID = "fr.jonathanlafarge.sonnerieprof.tip.small"
    static let mediumTipID = "fr.jonathanlafarge.sonnerieprof.tip.medium"
    static let largeTipID = "fr.jonathanlafarge.sonnerieprof.tip.large"

    static let productIDs = [
        smallTipID,
        mediumTipID,
        largeTipID
    ]

    private enum PromptPolicy {
        static let minimumAge: TimeInterval = 7 * 24 * 60 * 60
        static let reminderInterval: TimeInterval = 7 * 24 * 60 * 60
    }

    private enum DefaultsKey {
        static let firstLaunchDate = "tip.firstLaunchDate"
        static let lastPromptDate = "tip.lastPromptDate"
        static let hasTipped = "tip.hasTipped"
    }

    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var purchasingProductID: String?
    private(set) var message: String?
    private(set) var didJustTip = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: DefaultsKey.firstLaunchDate) == nil {
            defaults.set(Date.now, forKey: DefaultsKey.firstLaunchDate)
        }
    }

    func prepare() async {
        await loadProductsIfNeeded()
    }

    func loadProductsIfNeeded(force: Bool = false) async {
        guard force || products.isEmpty else { return }
        guard !isLoadingProducts else { return }

        isLoadingProducts = true
        message = nil
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await Product.products(for: Self.productIDs)
            products = loadedProducts.sorted { $0.price < $1.price }

            if products.isEmpty {
                message = TipL(
                    "tip.products_unavailable",
                    fallback: "Les pourboires sont momentanément indisponibles."
                )
            }
        } catch {
            message = TipL(
                "tip.products_load_error",
                fallback: "Impossible de charger les propositions de pourboire."
            )
        }
    }

    var shouldPresentAutomaticPrompt: Bool {
        guard !products.isEmpty else { return false }
        guard !defaults.bool(forKey: DefaultsKey.hasTipped) else { return false }
        guard let firstLaunchDate = defaults.object(
            forKey: DefaultsKey.firstLaunchDate
        ) as? Date else {
            return false
        }

        let now = Date.now
        guard now.timeIntervalSince(firstLaunchDate) >= PromptPolicy.minimumAge else {
            return false
        }

        guard let lastPromptDate = defaults.object(
            forKey: DefaultsKey.lastPromptDate
        ) as? Date else {
            return true
        }

        return now.timeIntervalSince(lastPromptDate) >= PromptPolicy.reminderInterval
    }

    func markAutomaticPromptPresented() {
        defaults.set(Date.now, forKey: DefaultsKey.lastPromptDate)
    }

    func prepareForPresentation() {
        didJustTip = false
        message = nil
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard purchasingProductID == nil else { return false }

        purchasingProductID = product.id
        message = nil
        defer { purchasingProductID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verificationResult):
                let transaction = try verified(verificationResult)
                await transaction.finish()
                defaults.set(true, forKey: DefaultsKey.hasTipped)
                didJustTip = true
                message = TipL(
                    "tip.thank_you_message",
                    fallback: "Merci de soutenir le développement de Sonnerie Prof."
                )
                return true
            case .pending:
                message = TipL(
                    "tip.purchase_pending",
                    fallback: "Le paiement attend une autorisation."
                )
            case .userCancelled:
                break
            @unknown default:
                message = TipL(
                    "tip.purchase_error",
                    fallback: "Le paiement n’a pas pu être effectué."
                )
            }
        } catch {
            message = TipL(
                "tip.purchase_error",
                fallback: "Le paiement n’a pas pu être effectué."
            )
        }

        return false
    }

    func title(for product: Product) -> String {
        switch product.id {
        case Self.smallTipID:
            return TipL("tip.product.small", fallback: "Petit merci")
        case Self.mediumTipID:
            return TipL("tip.product.medium", fallback: "Un café")
        case Self.largeTipID:
            return TipL("tip.product.large", fallback: "Grand merci")
        default:
            return product.displayName
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}

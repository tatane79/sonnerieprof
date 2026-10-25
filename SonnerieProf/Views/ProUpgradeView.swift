import StoreKit
import SwiftUI

private enum TipPromptLocalizationSources {
    static func registerForExtraction() {
        _ = String(localized: "Plus tard")
    }
}

/// Feuille de soutien volontaire. Aucun achat ne débloque de fonctionnalité.
struct TipPromptView: View {
    let store: TipJarStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 54, weight: .semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text(
                            store.didJustTip
                                ? TipL("tip.thank_you_title", fallback: "Merci beaucoup !")
                                : TipL("tip.title", fallback: "Un petit coup de pouce ?")
                        )
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(
                            store.didJustTip
                                ? TipL(
                                    "tip.thank_you_message",
                                    fallback: "Merci de soutenir le développement de Sonnerie Prof."
                                )
                                : TipL(
                                    "tip.body",
                                    fallback: "Toutes les fonctions de Sonnerie Prof sont gratuites. Si l’app vous aide au quotidien, vous pouvez soutenir son développement avec un pourboire facultatif."
                                )
                        )
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if store.didJustTip {
                        Button(L("Fermer")) {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        tipChoices

                        Text(
                            TipL(
                                "tip.no_unlock",
                                fallback: "Le pourboire est entièrement facultatif et ne débloque aucune fonction."
                            )
                        )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let message = store.message, !store.didJustTip {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .navigationTitle(
                TipL("tip.navigation_title", fallback: "Soutenir Sonnerie Prof")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !store.didJustTip {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L("Plus tard")) {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await store.loadProductsIfNeeded()
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var tipChoices: some View {
        if store.isLoadingProducts && store.products.isEmpty {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if store.products.isEmpty {
            VStack(spacing: 12) {
                Text(
                    TipL(
                        "tip.products_unavailable",
                        fallback: "Les pourboires sont momentanément indisponibles."
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(L("Réessayer")) {
                    Task {
                        await store.loadProductsIfNeeded(force: true)
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    Button {
                        Task {
                            _ = await store.purchase(product)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.title(for: product))
                                    .font(.headline)

                                Text(
                                    TipL(
                                        "tip.voluntary",
                                        fallback: "Pourboire facultatif"
                                    )
                                )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if store.purchasingProductID == product.id {
                                ProgressView()
                            } else {
                                Text(product.displayPrice)
                                    .font(.headline.monospacedDigit())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(store.purchasingProductID != nil)
                }
            }
        }
    }
}

# Sonnerie Prof — préparation à la commercialisation

Cette version intègre les principales améliorations nécessaires avant une bêta publique :

- premier lancement sans établissement imposé ;
- onboarding de création du premier site ;
- validation et normalisation des horaires ;
- jusqu’à 4 sites ;
- samedi pris en charge ;
- suspension temporaire du planning (vacances / fermeture) ;
- sélection de site adaptée à 3–4 établissements ;
- états vides et messages d’erreur plus explicites ;
- Dynamic Island volontairement limitée à la cloche ; Live Activity sécurisée par un timer système borné et préparée pour des mises à jour ActivityKit/APNs aux changements de sonnerie ;
- widget écran verrouillé planifié à l’avance avec WidgetKit ;
- tailles de texte principales rendues adaptatives ;
- privacy manifests ajoutés ;
- plan de tests TestFlight et checklist App Store ajoutés.

## Limitation iOS à conserver dans la communication produit

Une Live Activity standard ne peut rester active que pendant environ 8 heures. Après cette limite, iOS la retire de la Dynamic Island. Le widget d’écran verrouillé est donc la solution à privilégier pour un affichage fiable sur toute une journée ou entre deux jours de cours.

La Live Activity utilise à nouveau l’architecture locale précédemment validée sur iPhone : les futures sonneries sont embarquées dans son `ContentState` et l’extension choisit la première date encore à venir. Aucun backend ActivityKit/APNs n’est utilisé dans cette branche de référence.

## Ce qui reste externe au code

Avant publication, il restera à :

1. adhérer à l’Apple Developer Program avec le compte destiné à la distribution ;
2. créer la fiche App Store Connect ;
3. fournir une URL publique de politique de confidentialité et une URL de support ;
4. renseigner les informations bancaires, fiscales et contractuelles si l’app est payante ;
5. réaliser une bêta TestFlight sur plusieurs modèles d’iPhone ;
6. préparer les captures d’écran App Store et le texte marketing ;
7. vérifier le statut DSA / trader pour la distribution dans l’Union européenne.

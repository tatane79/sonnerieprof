# Checklist App Store — Sonnerie Prof

## Compte et contrats
- [ ] Apple Developer Program actif.
- [ ] App créée dans App Store Connect avec le bon Bundle ID.
- [ ] Paid Apps Agreement signé si l’app est payante.
- [ ] Coordonnées bancaires et fiscales complétées.
- [ ] Statut DSA / trader renseigné pour l’Union européenne.

## Métadonnées
- [ ] Nom et sous-titre App Store.
- [ ] Description courte et description complète.
- [ ] Mots-clés.
- [ ] URL de support publique.
- [ ] URL de politique de confidentialité publique.
- [ ] Classification d’âge.
- [ ] Catégorie principale / secondaire.
- [ ] Captures d’écran requises pour les tailles d’iPhone ciblées.
- [ ] Icône App Store 1024×1024 validée.

## Confidentialité
- [ ] Vérifier `PrivacyInfo.xcprivacy` de l’app.
- [ ] Vérifier `PrivacyInfo.xcprivacy` du widget.
- [ ] Si le backend ActivityKit est activé, déclarer dans App Privacy la transmission temporaire du token ActivityKit et des timestamps de sonnerie, utilisés uniquement pour la fonctionnalité écran verrouillé. Si le backend reste désactivé, confirmer qu’aucune donnée ne quitte l’appareil.
- [ ] Vérifier qu’aucun SDK tiers n’a été ajouté depuis la dernière revue.

## Qualité
- [ ] Exécuter tous les tests unitaires.
- [ ] Terminer le plan TestFlight.
- [ ] Vérifier VoiceOver et tailles de texte augmentées.
- [ ] Vérifier appareil sans Dynamic Island / sans Always-On.
- [ ] Tester permissions refusées.
- [ ] Tester une semaine avec samedi et une semaine sans samedi.
- [ ] Tester une période de suspension.

## Review Notes suggérées
Expliquer que la localisation est facultative et uniquement utilisée localement pour sélectionner le site configuré le plus proche. Préciser que les horaires sont saisis par l’utilisateur et qu’aucun compte n’est requis. Si le backend ActivityKit est activé, expliquer qu’un service technique reçoit temporairement uniquement le token ActivityKit et les timestamps nécessaires aux mises à jour de l’écran verrouillé ; la localisation et le nom de l’établissement ne sont pas transmis.

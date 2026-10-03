# Plan de développement — Sonnerie Prof

## Version 0.9 : bêta commerciale

### 1. Moteur d'horaires
- lundi à samedi ;
- planning par site ;
- prochaine sonnerie ;
- validation, normalisation, tri et doublons ;
- suspension temporaire du planning ;
- tests week-end et changement d'heure.

### 2. Configuration utilisateur
- onboarding au premier lancement ;
- aucun établissement imposé sur une installation neuve ;
- 1 à 4 sites ;
- localisation facultative ;
- saisie texte HH:mm ;
- raccourcis +55 min et +15 min ;
- copie du lundi vers mardi–samedi.

### 3. Interface principale
- sélection segmentée pour 1–2 sites ;
- menu pour 3–4 sites ;
- compte à rebours très lisible ;
- affichage du prochain jour après la dernière sonnerie ;
- tailles principales adaptatives ;
- états vides et permissions refusées.

### 4. Écran verrouillé
- Live Activity + Dynamic Island ;
- plusieurs sonneries futures préchargées ;
- minutes puis secondes dans la dernière minute lorsque le système le permet ;
- affichage compact : cloche à gauche, minutes ou jour à droite ;
- widget WidgetKit avec timeline prédictive ;
- bascule à 5 h vers le compte à rebours de la première sonnerie.

### 5. Fonctionnalités complémentaires
- vibrations configurables au premier plan ;
- suppression de site avec confirmation ;
- À propos : auteur, version et date de compilation ;
- informations de confidentialité intégrées.

### 6. Préparation App Store
- privacy manifests ;
- tests unitaires ;
- plan TestFlight ;
- modèle de politique de confidentialité ;
- checklist App Store ;
- audit documenté de la Live Activity.

## Après la 1.0
Fonctionnalités volontairement repoussées : calendrier scolaire automatique par zone, iCloud, import/export et partage de planning.

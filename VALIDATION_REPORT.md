# Rapport de validation de l'archive

## Vérifications effectuées dans l'environnement de génération

- Tous les fichiers Swift ont été passés dans le parseur Swift (`swiftc -frontend -parse`) : OK.
- `Models.swift`, `ScheduleEngine.swift`, `SiteRepository.swift` et `AppGroup.swift` ont été compilés sur Swift/Linux pour les parties compatibles Foundation : OK.
- Scénarios de régression exécutés : samedi, suspension, validation/normalisation, doublons et passage du changement d'heure : OK.
- `Info.plist` app/widget, les deux `PrivacyInfo.xcprivacy` et `project.pbxproj` ont été validés syntaxiquement avec `plutil` : OK.
- Un target `SonnerieProfTests` a été ajouté au projet Xcode et le fichier de tests a été étendu.

## Ce qui doit encore être validé sur macOS/Xcode

L'environnement de génération n'est pas macOS et ne contient pas les SDK iOS/Xcode. Il n'est donc pas possible ici d'exécuter `xcodebuild`, le simulateur iOS ou un test réel ActivityKit/WidgetKit.

À l'ouverture de l'archive dans Xcode :

1. sélectionner la Team de développement pour les trois targets si nécessaire ;
2. lancer **Product > Clean Build Folder** ;
3. lancer **Product > Build** ;
4. lancer **Product > Test** ;
5. tester sur un iPhone réel le widget, la Dynamic Island et la Live Activity ;
6. dérouler le fichier `TESTFLIGHT_TEST_PLAN.md` avant toute publication.

## Vérifications de localisation (13 langues)

- `Shared/Localizable.xcstrings` contient 149 entrées et chacune possède une traduction dans les 13 langues prises en charge : OK.
- Toutes les clés appelées via `L(...)` existent dans le catalogue : OK.
- Toutes les chaînes d’interface traduisibles de l’app, de l’onboarding, de l’éditeur de sites, du widget et des Live Activities passent explicitement par `L(...)` ; les seules chaînes laissées hors `L(...)` sont des valeurs techniques, numériques, noms propres ou SF Symbols : OK.
- Les paramètres de format (`%d`, `%@`, etc.) sont cohérents dans les 13 traductions : OK.
- Les 149 entrées du String Catalog sont marquées `manual` pour éviter les alertes `stale` de Xcode, car l’extraction automatique ne reconnaît pas le helper personnalisé `L(...)` : OK.
- Le portugais du Brésil (`pt-BR`) est déclaré dans le catalogue, les deux `Info.plist`, `knownRegions`, `InfoPlist.strings`, le sélecteur Debug et `appDisplayLocale()` : OK.
- Les valeurs purement techniques/non traduisibles (coordonnées d'exemple, tiret, valeur numérique dynamique et préfixe dynamique du widget) sont explicitement rendues en `verbatim` pour éviter de fausses alertes de clés manquantes : OK.
- Les 13 fichiers `InfoPlist.strings` existent et exposent le même jeu de clés : OK.
- Les noms de jours et dates suivent la langue de l’application : OK.
- Le projet Xcode déclare les 13 régions et embarque le catalogue dans l’app et le widget : OK.

À tester dans Xcode : **Edit Scheme → Run → Options → App Language**, puis vérifier au minimum français, anglais, allemand et polonais sur l’onboarding, l’éditeur de site, les réglages, le widget et la Live Activity.


## Vérifications autosave

- Aucun bouton `Enregistrer` / `confirmationAction` ne subsiste dans les éditeurs de site ou d’horaires : OK.
- `SiteEditorView` persiste les changements après une courte temporisation et à la fermeture : OK (validation syntaxique).
- `DayScheduleEditorView` persiste les horaires valides après temporisation et lors du retour : OK (validation syntaxique).
- Les champs du site utilisent désormais des libellés persistants dans des lignes compactes de formulaire iOS, avec libellé à gauche et valeur éditable à droite : OK.
- Les 149 chaînes du catalogue possèdent une traduction dans les 13 langues prises en charge : OK.

## Vérifications interface compacte / plein écran

- Les quatre champs principaux de `SiteEditorView` utilisent `LabeledContent` avec valeur éditable alignée à droite : OK (validation syntaxique).
- Le bouton de géolocalisation utilise le symbole SF Symbols `scope` : OK (à vérifier visuellement sur appareil réel).
- Le bouton d’agrandissement est affiché uniquement lorsqu’une prochaine sonnerie existe le jour même afin d’éviter un affichage plein écran de plusieurs milliers de minutes pendant le week-end : OK.
- Le mode plein écran est présenté via `fullScreenCover`, fond noir, texte blanc et fermeture explicite : OK (validation syntaxique).
- Le catalogue contient désormais 149 chaînes, traduites dans les 13 langues prises en charge : OK.


## Vérifications interface – pictogrammes et widget compact

- La liste des établissements dans Réglages utilise `building.columns.fill` à gauche du nom : OK (validation syntaxique).
- Le champ `Nom` de `SiteEditorView` utilise le même pictogramme d’école : OK (validation syntaxique).
- Le libellé du rayon est désormais `Rayon (m)` avec des traductions courtes dans les 13 langues : OK.
- Le bouton `Tester` des vibrations conserve le pictogramme `iphone.radiowaves.left.and.right` demandé précédemment : OK (validation syntaxique).
- Le widget circulaire, inline et rectangulaire utilisent désormais un timer SwiftUI borné (`timerInterval` + `pauseTime`) : le système fait vivre le compte à rebours et le compteur se fige à zéro si une transition de timeline est retardée, au lieu de repartir en positif. Les transitions de sonnerie et de réapparition H−1 sont préchargées dans la timeline : OK (validation syntaxique ; comportement final à confirmer sur iPhone).
- Le plein écran conserve les informations demandées précédemment : établissement, minutes restantes et heure de la prochaine sonnerie : OK (validation syntaxique).


## Audit Always-On / ActivityKit / WidgetKit

- suppression de la dépendance à `TimelineView(.periodic)` pour le compte à rebours de la Live Activity : OK ;
- timer ActivityKit borné à zéro afin d'empêcher un comptage positif après la sonnerie : OK ;
- planning court terme déplacé dans les attributs immuables de la Live Activity sous forme de timestamps Unix : OK ;
- mise à jour locale automatique à chaque changement de sonnerie lorsque l'app est au premier plan : OK ;
- `NSSupportsLiveActivitiesFrequentUpdates` ajouté à l'Info.plist : OK ;
- la capability Push Notifications n'est volontairement pas forcée dans les entitlements afin que le projet reste signable avec une Personal Team ; la procédure d'activation est documentée dans `ALWAYS_ON_BACKEND_SETUP.md` : OK ;
- limitation restante : la livraison APNs et le build ActivityKit doivent être validés sur un iPhone réel après déploiement du backend.

## Vérifications finales Always-On / backend

- tous les fichiers Swift reparsés après les dernières corrections : OK ;
- sous-ensemble Foundation (`AppGroup`, modèles, moteur d’horaires et repository) type-checké avec Swift 6.2.1 : OK ;
- `Localizable.xcstrings` : 149 clés utilisées via `L(...)`, 0 clé manquante, 0 clé inutilisée, 13 langues, 0 traduction manquante : OK ;
- `Info.plist`, entitlements, privacy manifests, `project.pbxproj` et les 13 `InfoPlist.strings` : syntaxe validée : OK ;
- Worker Cloudflare : syntaxe JavaScript validée avec Node 22 : OK ;
- schéma D1 exécuté dans SQLite en mémoire : OK ;
- texte de confidentialité dans l’application corrigé : la localisation n’est jamais transmise ; si le backend Always-On est activé, seuls les horaires nécessaires et des identifiants techniques temporaires sont transmis : OK.

Le backend APNs n’a pas pu être testé de bout en bout dans cet environnement car il nécessite un compte Apple Developer, une clé APNs, un Worker déployé et un iPhone réel. Cette validation sur appareil reste obligatoire avant publication.

## Minute-only countdown validation — 2026-09-20
- `NextBellWidget.swift` and `NextBellLiveActivity.swift` parse successfully after the minute-only change.
- Both use `SystemFormatStyle.Timer(countingDownIn:showsHours:maxFieldCount:maxPrecision:)` with `maxPrecision: .seconds(60)` and a bounded interval.
- No one-minute `TimelineProvider` refresh loop was added; predictable bell/reveal transitions remain timeline-driven while the visible countdown is system-managed.
- Dynamic Island remains bell-only.
- Final device validation is still required on an Always-On capable iPhone because refresh cadence and low-luminance rendering are controlled by iOS.

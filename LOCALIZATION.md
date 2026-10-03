# Localisation de Sonnerie Prof

## Langues livrées

- Français (`fr`) — langue de développement.
- Anglais (`en`).
- Allemand (`de`).
- Espagnol (`es`).
- Italien (`it`).
- Portugais — Portugal (`pt-PT`).
- Portugais — Brésil (`pt-BR`).
- Néerlandais (`nl`).
- Polonais (`pl`).
- Roumain (`ro`).
- Tchèque (`cs`).
- Suédois (`sv`).
- Danois (`da`).

Le nom commercial **Sonnerie Prof** est volontairement conservé dans toutes les langues.

## Architecture

- `Shared/Localizable.xcstrings` contient les chaînes d’interface de l’application, du widget et des Live Activities. Les entrées sont marquées `manual` afin que Xcode ne les signale pas comme obsolètes : le helper personnalisé `L(...)` n’est pas détecté par l’extraction automatique des String Catalogs.
- La fonction `L(...)` dans `Shared/ScheduleEngine.swift` est utilisée pour **toutes les chaînes d’interface traduisibles**, y compris les chaînes statiques, dynamiques et formatées. Cette règle garantit que le sélecteur de langue du mode développeur fonctionne immédiatement, sans dépendre uniquement de la localisation SwiftUI automatique.
- `appDisplayLocale()` aligne les noms de jours et les dates sur la langue de l’application.
- `SonnerieProf/<langue>.lproj/InfoPlist.strings` localise les messages de permission Core Location, y compris la demande temporaire de position précise (`SiteDetection`).

## Tester

En build Debug, le sélecteur **Réglages > Mode développeur > Langue de test** permet de changer immédiatement la langue de l’interface, y compris le portugais du Brésil.

Dans Xcode :
1. Edit Scheme…
2. Run → Options.
3. App Language → choisir la langue à tester.
4. Tester l’app principale, l’onboarding, les réglages, l’éditeur d’horaires, le widget et la Live Activity.

Sur iPhone, si iOS expose le réglage de langue par application, la langue peut être changée dans les réglages système de Sonnerie Prof.

## Vague européenne actuelle

Cette version couvre les principales langues européennes ciblées pour le premier lancement commercial, ainsi que le portugais du Brésil. Une seconde vague recommandée pourra ajouter le norvégien (bokmål), le finnois, le grec, le hongrois et, selon les téléchargements, le catalan.

## Ajouter une langue

1. Ajouter la langue au catalogue `Localizable.xcstrings`.
2. Ajouter la localisation correspondante de `InfoPlist.strings` pour les autorisations de localisation.
3. Ajouter le code de langue à `CFBundleLocalizations` dans les `Info.plist` app et widget.
4. Ajouter la langue à `knownRegions` et au groupe `InfoPlist.strings` du projet Xcode si Xcode ne le fait pas automatiquement.
5. Ajouter le mapping de locale à `appDisplayLocale()` pour les jours et dates.
6. Tester les textes longs dans les petites tailles d’iPhone, le Dynamic Type, le widget et la Dynamic Island.

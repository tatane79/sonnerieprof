# Audit de localisation — version de référence

- Chaînes utilisées via `L(...)` : **143**.
- Entrées du catalogue : **143**.
- Langues : **13** (`fr, en, de, es, it, pt-PT, pt-BR, nl, pl, ro, cs, sv, da`).
- Clés `L(...)` absentes du catalogue : **0**.
- Entrées du catalogue inutilisées : **0**.
- Traductions manquantes : **0**.
- Entrées marquées `manual` : **143 / 143**.
- Contrôles SwiftUI avec une chaîne traduisible littérale non passée par `L(...)` détectés par l’audit : **0**.
- Portugais du Brésil (`pt-BR`) : catalogue, `InfoPlist.strings`, `Info.plist`, projet Xcode, locale et sélecteur Debug : **présent**.

Les chaînes volontairement non passées par `L(...)` sont limitées aux valeurs techniques ou non linguistiques (noms SF Symbols, identifiants, clés UserDefaults/App Group, formats `HH:mm`, nombres/coordonnées d’exemple, nom propre de l’auteur et séparateurs décoratifs).

# Restauration du compteur Widget / Always-On

Cette version restaure volontairement le mécanisme de compteur de la version qui avait été validée sur l'iPhone avant les essais ActivityKit/APNs.

- Live Activity : les prochaines sonneries sont stockées dans `ContentState.bellDates`.
- Always-On : sélection de la prochaine date avec `TimelineView(.periodic)` et affichage avec `Text(.currentDate, format: .offset(... [.minute]))`.
- Widget : même format temporel `.offset` pour les minutes et timeline pré-calculée aux changements de sonnerie.
- Dynamic Island : cloche uniquement.
- Aucun backend APNs n'est utilisé dans cette version.

Le choix « masquer jusqu'à 1 h avant » est conservé.

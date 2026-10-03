# Audit Live Activity / Widget — restauration stable

Cette branche restaure le mécanisme qui avait été validé sur iPhone avant les essais de backend ActivityKit/APNs.

## Live Activity / Always-On

- `BellActivityAttributes.ContentState` contient les prochaines sonneries (`bellDates`) et le décalage éventuel du mode développeur.
- `BellCountdownView` utilise `TimelineView(.periodic(from: .now, by: 1))` pour sélectionner la première sonnerie future.
- Le nombre de minutes est rendu avec `Text(.currentDate, format: .offset(... allowedFields: [.minute]))`, comme dans la version précédemment validée.
- L’affichage écran verrouillé / Always-On montre uniquement les minutes restantes.
- La Dynamic Island affiche uniquement la cloche.
- L’option « masquer jusqu’à 1 h avant » est conservée.

## Widget

- WidgetKit reçoit des entrées à chaque changement de sonnerie et aux moments de réapparition nécessaires.
- Le compteur reprend le `Text(.currentDate, format: .offset(... [.minute]))` de la version validée.
- Le widget affiche uniquement les minutes restantes.

## Backend

Aucun backend ActivityKit/APNs n’est utilisé dans cette branche. Les fichiers backend expérimentaux ont été retirés de l’archive.

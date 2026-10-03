## Restauration compteur stable

- Restauration du mécanisme Widget / Always-On précédemment validé sur iPhone.
- Affichage limité aux minutes restantes.
- Dynamic Island : cloche uniquement.
- Retrait du backend ActivityKit expérimental de cette branche de référence.

# Changelog

## 0.9 — fiabilisation Always-On / widget

- audit complet de la séparation WidgetKit / ActivityKit ;
- Live Activity : remplacement du `TimelineView` périodique par un timer système borné qui ne repart jamais en positif après zéro ;
- Live Activity : planning court terme stocké dans les attributs immuables et contenu dynamique réduit à une révision ;
- rafraîchissement immédiat au changement de sonnerie lorsque l'app est au premier plan ;
- Dynamic Island conservée volontairement en mode « cloche uniquement » ;
- widget : timers bornés, transitions de sonnerie préchargées et prise en compte de l'option de masquage H−1 ;
- ajout de `NSSupportsLiveActivitiesFrequentUpdates` ;
- documentation d'activation APNs et mise à jour du modèle de confidentialité.

## 0.9 — localisation complète via L(...) + portugais du Brésil

- passage de toutes les chaînes d’interface traduisibles de l’app, de l’onboarding, des réglages, de l’éditeur de sites, du widget et des Live Activities par `L(...)` ;
- correction des chaînes qui restaient en français lors d’un changement de langue à chaud en mode développeur ;
- ajout du portugais du Brésil (`pt-BR`) au catalogue, aux réglages Debug, aux bundles et aux autorisations de localisation ;
- distinction portugais (Portugal) / portugais (Brésil) dans le sélecteur de langue ;
- audit des clés et des paramètres de format sur les 13 langues prises en charge.

## 0.9 UI polish – école, rayon court et widget compact

- pictogramme d’école (`building.columns.fill`) dans la liste des sites et à côté du champ Nom ;
- libellé compact « Rayon (m) » et traductions courtes dans les 12 langues ;
- widget circulaire : affichage compact « 25 min » sous la cloche ;
- audit des clés de localisation et des paramètres de format ;
- conservation des améliorations récentes du plein écran et du bouton de test des vibrations.


## 0.9 — Mode développeur (horloge simulée)

- Ajout d’un mode développeur disponible uniquement en build Debug.
- Choix libre d’une date et d’une heure simulées, avec progression à vitesse réelle.
- Raccourcis 5 min / 1 min avant la prochaine sonnerie.
- Bandeau orange « Mode test actif » sur l’écran principal.
- Prise en compte de l’heure simulée par le compteur principal, le plein écran, les vibrations, le widget et la Live Activity / Dynamic Island.
- Neutralisation automatique du mode test en Release / App Store.

## 0.9 — préparation commerciale

- Premier lancement avec onboarding ; plus aucun établissement imposé sur une installation neuve.
- Conservation des données des installations existantes.
- Validation complète des horaires : format, tri, normalisation et doublons.
- Samedi pris en charge.
- Jusqu’à 4 sites, ajout/suppression avec confirmation.
- Sélecteur de site adapté au nombre de sites.
- Suspension temporaire du planning.
- Localisation demandée uniquement après action utilisateur (hors permission déjà accordée).
- Live Activity enrichie avec plusieurs sonneries futures.
- Widget écran verrouillé avec transitions planifiées et bascule à 5 h.
- Gestion explicite des Live Activities désactivées.
- Améliorations Dynamic Type et accessibilité.
- Privacy manifests ajoutés.
- Tests unitaires enrichis.
- Documentation TestFlight / App Store / confidentialité ajoutée.

## 0.9 — Localisation FR / EN

- Interface entièrement localisable en français et en anglais.
- Ajout du catalogue `Shared/Localizable.xcstrings`, partagé par l’app et le widget.
- Localisation des messages dynamiques, erreurs, Live Activities et widgets.
- Jours et dates suivent maintenant la langue de l’application.
- Localisation des messages système de permission de localisation via `InfoPlist.strings`.
- Déclaration explicite des localisations `fr` et `en` dans les bundles app et widget.
- Le nom commercial `Sonnerie Prof` reste identique dans les deux langues.

## Localisation Europe

- Ajout de l’allemand, espagnol, italien, portugais (Portugal), néerlandais, polonais, roumain, tchèque, suédois et danois.
- Localisation des autorisations Core Location dans toutes ces langues.
- Dates et noms de jours adaptés à la langue choisie pour l’app dans iOS.

## 0.9 — Autosave et formulaires persistants

- Suppression des boutons « Enregistrer » dans l’édition d’un site et d’une journée.
- Sauvegarde automatique des modifications de site, avec courte temporisation pendant la saisie.
- Sauvegarde automatique des horaires valides pendant la saisie et lors du retour à l’écran précédent.
- Les nouveaux sites ne sont créés qu’après saisie d’un nom non vide.
- Les champs Nom, Latitude, Longitude et Rayon conservent désormais un libellé visible même lorsqu’ils contiennent une valeur.
- Ajout d’un message explicite indiquant que les modifications sont enregistrées automatiquement.
- Localisation des nouveaux messages dans les 12 langues européennes prises en charge.

## 0.9 — Interface compacte et compte à rebours plein écran

- Les champs Nom, Latitude, Longitude et Rayon utilisent désormais des lignes `LabeledContent` conformes au style des formulaires iOS : libellé persistant à gauche, valeur éditable à droite.
- Le bouton « Utiliser ma position actuelle » affiche un pictogramme cible.
- Ajout d’un bouton d’agrandissement dans le coin supérieur droit de la carte de compte à rebours lorsqu’une sonnerie est prévue le jour même.
- Nouveau mode plein écran : minutes restantes en très grand, blanc sur fond noir, avec bouton de fermeture en haut à droite.
- Le mode plein écran bascule sur la prochaine date/heure de sonnerie si la journée de cours est terminée.
- Ajout des traductions nécessaires dans les 12 langues prises en charge.

## 2026-09-20 — Minute-only Lock Screen presentation
- Lock Screen widget presentations now show only the remaining minutes; site name, bell icon and next-day text were removed from the widget surface.
- The Always-On / Lock Screen Live Activity now shows only the remaining minutes; site name and target bell time were removed.
- Both surfaces use SwiftUI SystemFormatStyle.Timer with 60-second precision, allowing the system to update the text at minute boundaries while extensions are suspended.
- Countdown ranges remain bounded and clamp at zero while awaiting the next WidgetKit entry or ActivityKit push.
- Dynamic Island remains bell-only.

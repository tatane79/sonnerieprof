# Sonnerie Prof

Application iOS SwiftUI affichant le temps restant avant la prochaine sonnerie d’un établissement scolaire.

## Version commerciale préparatoire

Cette archive inclut :

- onboarding sans établissement imposé sur une installation neuve ;
- jusqu’à 4 sites ;
- horaires du lundi au samedi ;
- saisie texte rapide, validation, tri et suppression des doublons ;
- boutons +55 min / +15 min ;
- copie du lundi vers le reste de la semaine ;
- détection géographique facultative ;
- suspension temporaire du planning ;
- vibrations au premier plan ;
- Live Activity / Dynamic Island ;
- widget écran verrouillé avec timeline prédictive ;
- privacy manifests ;
- tests unitaires enrichis et plan TestFlight ;
- documents de préparation App Store.

## Configuration Xcode

- Bundle ID app : `fr.jonathanlafarge.sonnerieprof`
- Bundle ID widget : `fr.jonathanlafarge.sonnerieprof.widgets`
- App Group : `group.fr.jonathanlafarge.sonnerieprof.shared`
- Déploiement minimum : iOS 18

Sélectionner votre Team dans **Signing & Capabilities** pour les deux targets avant de lancer l’app.

## Limite Live Activity

iOS limite une Live Activity standard à environ 8 heures actives. Cette branche restaure volontairement le mécanisme local de compteur qui avait été validé sur iPhone : les futures sonneries sont embarquées dans le `ContentState` et la vue sélectionne la première date encore à venir. Le widget reste entièrement piloté localement par sa timeline WidgetKit.

## Données existantes

Les installations déjà utilisées conservent les sites enregistrés sous les clés existantes. Une installation neuve démarre sans IND/NDE et propose l’onboarding.

## Langues

Cette version prend en charge **le français et l’anglais**. L’application suit la langue choisie par iOS ; lorsqu’iOS propose le réglage de langue par application, l’utilisateur peut choisir Français ou English dans les réglages système de Sonnerie Prof. Aucun sélecteur de langue interne n’est nécessaire.

Les textes d’interface sont centralisés dans `Shared/Localizable.xcstrings`. Les textes de confidentialité affichés par iOS pour la localisation sont traduits dans `SonnerieProf/fr.lproj/InfoPlist.strings` et `SonnerieProf/en.lproj/InfoPlist.strings`.

Pour tester dans Xcode, utiliser **Edit Scheme → Run → Options → App Language**, puis choisir French ou English.

## Autosave

Les écrans de configuration n’utilisent plus de bouton « Enregistrer ». Les modifications valides sont persistées automatiquement pendant la saisie et lors du retour à l’écran précédent. Les champs de configuration d’un site conservent un libellé visible (Nom, Latitude, Longitude, Rayon) même lorsqu’une valeur est renseignée.

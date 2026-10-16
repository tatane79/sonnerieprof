# Plan de test TestFlight — Sonnerie Prof

## Matériel minimal

Tester au moins :

- un iPhone avec Dynamic Island et Always-On ;
- un iPhone avec Dynamic Island sans Always-On ;
- un iPhone sans Dynamic Island ;
- une petite taille d’écran compatible iOS 18+ ;
- un appareil avec taille de texte d’accessibilité augmentée.

## Scénarios fonctionnels

### Premier lancement
- Aucun établissement n’est préchargé sur une installation neuve.
- L’onboarding peut créer un site.
- « Configurer plus tard » mène à un état vide exploitable.
- La localisation n’est demandée que sur action explicite de l’utilisateur.

### Sites
- Ajouter jusqu’à 4 sites.
- Le 5e site est impossible.
- Supprimer un site après confirmation.
- Supprimer le site actif sélectionne un autre site ou arrête l’affichage verrouillé s’il n’en reste aucun.
- 3 ou 4 sites utilisent une interface de sélection lisible.

### Horaires
- Saisie `8:10` normalisée en `08:10`.
- Tri automatique des horaires.
- Doublons supprimés.
- `25:00`, `9:75` et texte libre refusés.
- Boutons +55 min / +15 min.
- Copie du lundi vers mardi–samedi après confirmation.
- Samedi avec horaires et samedi vide.

### Planning suspendu
- Suspendre jusqu’à une date future.
- Aucune sonnerie avant la date de reprise.
- Widget et Live Activity recalculés.
- Reprendre immédiatement.

### Compte à rebours
- Même jour : compte à rebours correct.
- Après dernière sonnerie : comportement conforme au réglage choisi.
- Week-end vers lundi.
- Passage vendredi → samedi lorsque le samedi est configuré.
- Changement d’heure été/hiver.
- Formats 24 h et 12 h.

### Live Activity / écran verrouillé / Always-On — mode local
- Le compteur continue à descendre écran verrouillé.
- L’affichage de l’écran verrouillé reste identique au compte à rebours pleine page.
- Sous trois minutes, les secondes sont visibles et diminuent réellement.
- Au-delà de 24 h, afficher `J j HH h`, sans minutes ni secondes.
- La Dynamic Island reste aussi étroite que possible tout en étant lisible.
- La présentation développée de la Dynamic Island affiche `J j HH h` au-delà de 24 h.
- Dans toutes les présentations de la Dynamic Island, le temps continue à diminuer sans rester figé.
- À zéro, le compteur ne repart jamais en positif depuis une sonnerie passée.
- Lorsque l’app revient au premier plan, la Live Activity se recale sur la prochaine sonnerie.
- Tester l’option « Masquer jusqu’à 1 h avant ».

### Vibrations
- 1 à 10 vibrations au premier plan.
- Aucun son.
- Aucune vibration pendant une suspension du planning.
- Vérifier qu’aucune double séquence n’est déclenchée pour une même sonnerie.

### Permissions et erreurs
- Localisation refusée.
- Position approximative.
- Live Activities désactivées dans les réglages iOS.
- Aucun site / aucun horaire.
- CloudKit indisponible : l’app principale et la Live Activity locales doivent continuer à fonctionner.
- Vérifier que les sauvegardes privées et le partage facultatif signalent proprement une erreur réseau.

### Pourboires StoreKit
- Tester les trois produits consommables avec un compte Sandbox ou via TestFlight.
- Vérifier l’annulation, l’achat en attente et l’achat réussi.
- Après une transaction vérifiée, relancer l’app et avancer la date de test : aucune invitation automatique ne doit réapparaître.
- Le bouton manuel « Soutenir Sonnerie Prof » reste disponible dans l’écran À propos.

### CloudKit
- Vérifier une sauvegarde et une restauration dans la base privée de production.
- Vérifier la publication puis l’import d’un horaire partagé dans la base publique de production.
- Vérifier qu’aucune position ni aucun emploi du temps personnel n’est publié avec un code de partage.

### Contenu de l’archive
- Vérifier que `SonnerieProfWidgets.appex` est embarquée.
- Vérifier qu’aucune application Apple Watch n’est embarquée dans cette version.
- Vérifier la version commerciale `1.0` et le build `7` pour l’app et l’extension.

## Critère de sortie de bêta

Aucun crash ni blocage, aucune sonnerie incorrecte, aucun affichage de sonnerie passée et aucune durée qui repart en positif après zéro. Avant soumission, valider au moins une journée réelle avec la Live Activity locale sur un iPhone physique, les achats Sandbox et CloudKit Production.

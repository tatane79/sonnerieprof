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

### Widget écran verrouillé
- Le compteur continue de diminuer lorsque l’app est fermée/suspendue.
- À une sonnerie, le widget passe à la prochaine sonnerie grâce à sa timeline préchargée.
- Si iOS retarde exceptionnellement la transition de timeline, le timer reste bloqué à zéro et ne repart jamais en positif.
- Tester plusieurs sonneries successives sans ouvrir l’app.
- Tester l’option « Masquer jusqu’à 1 h avant » : masquage après la dernière sonnerie puis réapparition à H−1 de la première sonnerie suivante.
- Tester le passage vendredi → lundi sans ouvrir l’app.

### Live Activity / Always-On — mode local (backend non configuré)
- Le compteur continue à descendre écran verrouillé.
- À zéro, le timer reste à zéro : il ne doit jamais compter positivement depuis une sonnerie passée.
- Lorsque l’app revient au premier plan, la Live Activity se recale immédiatement sur la prochaine sonnerie.
- La Dynamic Island affiche uniquement la cloche dans toutes ses présentations.

### Live Activity / Always-On — mode commercial APNs

- Vérifier dans Xcode qu’un `ActivityKit push token` est reçu et enregistré par le backend.
- Verrouiller l’iPhone et ne plus rouvrir Sonnerie Prof.
- Tester une transition réelle, par exemple `10:00 → 10:55` : le timer atteint zéro puis la Live Activity doit basculer sur 10:55 après la mise à jour APNs.
- Enchaîner au moins trois sonneries successives téléphone verrouillé.
- Couper temporairement le réseau : le compteur doit rester bloqué à zéro, jamais repartir en positif ; restaurer le réseau puis vérifier le rattrapage.
- Tester un renouvellement de push token si observable.
- Tester la limite système d’environ 8 h d’une Live Activity ; le widget reste la solution de continuité au-delà de cette durée.
- Tester l’option « Masquer jusqu’à 1 h avant » et la mise à jour distante de réapparition.

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
- Backend indisponible : l’app principale et le widget doivent continuer à fonctionner ; la Live Activity ne doit jamais afficher un temps positif après zéro.

## Critère de sortie de bêta

Aucun crash ni blocage, aucune sonnerie incorrecte, aucun affichage de sonnerie passée et aucune durée qui repart en positif après zéro. Pour la version commerciale avec Always-On automatique entre les sonneries, au moins une journée réelle de test doit être validée avec les mises à jour ActivityKit/APNs activées.

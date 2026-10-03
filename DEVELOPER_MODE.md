# Mode développeur — horloge simulée

Le mode développeur est compilé uniquement dans les builds **Debug** (`#if DEBUG`). Il n’apparaît pas dans une archive Release/App Store.

## Utilisation

Dans **Réglages > Mode développeur** :

- choisir une **Langue de test** pour vérifier l’interface sans modifier la langue d’iOS ;
- activer **Utiliser une heure simulée** ;
- choisir une **date et heure simulées** ;
- ou utiliser les raccourcis **5 min avant la prochaine sonnerie** et **1 min avant la prochaine sonnerie** ;
- utiliser **Revenir à l’heure réelle** pour désactiver le test.

L’heure simulée continue d’avancer à vitesse réelle : si le test commence à 09:55, cinq minutes réelles plus tard l’application se comporte comme s’il était 10:00.

## Éléments concernés

Le mode test est appliqué au compteur principal, au mode plein écran, au déclenchement de vibration au premier plan, au widget et à la Live Activity / Dynamic Island. Les dates de la Live Activity sont remappées sur l’horloge système pour que le compte à rebours continue de fonctionner, tout en affichant les heures et jours simulés.

Un bandeau orange **Mode test actif** reste visible sur l’écran principal pour éviter de confondre l’heure simulée avec l’heure réelle.

Le sélecteur de langue inclut français, anglais, allemand, espagnol, italien, portugais (Portugal), portugais (Brésil), néerlandais, polonais, roumain, tchèque, suédois et danois.

## Production

La logique de lecture de l’horloge simulée est neutralisée hors `DEBUG`. Une version Release utilise toujours l’heure système réelle, même si une ancienne valeur de test subsiste dans le conteneur App Group.

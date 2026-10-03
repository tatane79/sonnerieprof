# Politique de confidentialité — modèle à publier sur une URL publique

**Application : Sonnerie Prof**  
**Éditeur : Jonathan Lafarge**  
**Dernière mise à jour : [DATE À RENSEIGNER]**

## Fonctionnement général

Sonnerie Prof ne crée aucun compte utilisateur. Les établissements, réglages et horaires sont enregistrés localement sur l'appareil et dans l'App Group partagé avec le widget.

## Localisation

L'accès à la localisation est facultatif. Lorsqu'il est autorisé, il sert uniquement à déterminer quel établissement configuré est le plus proche afin de sélectionner automatiquement le bon planning. La position n'est pas utilisée à des fins publicitaires ou de suivi et n'est pas transmise au serveur de mise à jour des Live Activities.

## Mise à jour de l'écran verrouillé / Live Activity

Si la fonction de mise à jour distante de la Live Activity est activée dans la version distribuée, Sonnerie Prof transmet temporairement à un service technique :

- un identifiant technique anonyme de Live Activity ;
- le token ActivityKit nécessaire à Apple Push Notification service (APNs) ;
- les heures techniques des prochaines sonneries sous forme de timestamps ;
- l'information indiquant si l'affichage doit être masqué après la dernière sonnerie ;
- une date d'expiration technique.

Le service ne reçoit ni le nom de l'utilisateur, ni sa position, ni le nom de l'établissement. Ces informations sont utilisées uniquement pour envoyer les mises à jour ActivityKit nécessaires à l'affichage sur l'écran verrouillé. Les enregistrements expirent automatiquement après la durée utile de la Live Activity et sont également supprimés lorsque l'utilisateur la désactive.

Si cette fonction distante n'est pas configurée, ces informations ne quittent pas l'appareil.

## Publicité et suivi

Sonnerie Prof n'intègre pas de publicité et n'effectue pas de suivi inter-applications ou inter-sites.

## Services Apple

L'application utilise des services système Apple tels que Core Location, WidgetKit, ActivityKit et Apple Push Notification service (APNs). Leur fonctionnement est soumis aux conditions et politiques de confidentialité d'Apple.

## Contact

Pour toute question relative à la confidentialité ou au support : **[ADRESSE E-MAIL DE SUPPORT À RENSEIGNER]**.

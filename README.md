# Inspection AQL (aql_inspect)

Application Flutter d'inspection finale AQL pour ateliers de confection.
Fonctionne sur **Android**, **Windows**, iOS et Web, hors ligne.

## Fonctions
- Plan d'échantillonnage **ISO 2859-1** (simple, contrôle normal) : lettre code, taille d'échantillon, Ac/Re, calculés automatiquement à partir de la taille du lot et du niveau d'inspection (I, II, III).
- AQL séparés pour défauts critiques (0 = zéro défaut), majeurs et mineurs.
- Liste de défauts confection courants + défauts personnalisés, compteurs +/−.
- Verdict instantané : lot accepté / refusé.
- **Rapport PDF** (partage / impression) prêt pour le donneur d'ordre.
- Historique des inspections stocké localement sur l'appareil.

## Télécharger
Chaque push sur `main` construit l'APK Android et le ZIP Windows via GitHub Actions
(release « latest » de ce dépôt).

## Développement
```bash
flutter pub get
flutter test
flutter run            # Android / Windows / Chrome
```

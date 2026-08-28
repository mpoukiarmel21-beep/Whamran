# Handoff OpenCode ⇄ Claude Code — Whamran

> Fichier de liaison dédié au projet **Whamran** (app iOS de fake-capture).
> L'autre `AGENT-HANDOFF.md` (au niveau `INSTA/`) concerne un projet différent
> (dylib insta-containerized / IGContainerMod), pas Whamran.
> Les entrées les plus récentes vont en haut du Journal.

## État actuel

- **Whamran** = application iOS (XcodeGen + SwiftUI) qui transforme une image/vidéo importée en une
  « vraie capture » : ré-encodage HEIC/MP4 + métadonnées EXIF/QuickTime réalistes (Make Apple,
  appareil simulé, iOS précis, GPS, date aléatoire passée, numéro de série), filtres quasi
  imperceptibles + recadrage léger. Livrée en IPA sideloadable via GitHub Release.
- Repo public `mpoukiarmel21-beep/Whamran` (branch `main`). CI : `.github/workflows/build-ipa.yml`
  (macOS runner, `xcodegen` + `xcodebuild` ad-hoc → IPA → upload artifact ; publication Release
  uniquement sur push de tag).
- Dernier build réussi : run `33216162559` (commit `ec087e3`). IPA (616 245 o) ré-uploadé
  manuellement dans la Release `v1.0.0` — **lien direct toujours** :
  `https://github.com/mpoukiarmel21-beep/Whamran/releases/download/v1.0.0/Whamran.ipa`

## En cours

- **(libre)** — Rework UX/design livré (voir Journal 2026-08-28). À valider par l'utilisateur.

## Prochaine étape

- Récupérer l'artefact `Whamran-ipa` du prochain build vert et l'uploader dans la Release `v1.0.0`
  (`gh release upload v1.0.0 Whamran.ipa --clobber`) — la CI ne publie qu'aux pushes de **tag**,
  pas à `main`.

## Blocages / risques

- La CI ne publie la Release que sur push de tag ; pour un push `main` il faut uploader l'artefact
  à la main.
- Pas de build/compilation Swift sous Windows : chaque erreur se découvre au prochain run Actions.
- `dist/` (IPA locales) est ignoré par `.gitignore`.

## Journal

- **2026-08-28 — ox-alpha (opencode)** : Rework important demandé et livré :
  - UX/design refait (écran sombre, cartes de sections, caméra virtuelle, spinner de progression).
  - Bouton **Partager supprimé** ; ajout d'un bouton **Nouvelle session** qui réinitialise tout
    sans fermer l'app.
  - **Fake localisation monde entier** : nouvelle ressource `WorldCities.json` (129 villes) +
    barre de recherche (ex : « Paris ») + carte du monde stylisée hors-ligne (`FakeMapView`) avec
    épingle sur la ville choisie ; la ville **agit réellement** sur le GPS/nom de lieu.
  - **Versions iOS détaillées et réalistes** (`IOSVersionTimeline` refait : catalogue explicite
    iOS 20→27 avec dates de sortie, patchs `.x.y` ; le sélecteur affiche la date de sortie).
  - **Caméra virtuelle** (`VirtualCamera`) : réglages EXIF réalistes (focale, ouverture, vitesse,
    ISO, luminosité, objectif) selon la génération de l'appareil — le fichier est lu comme une
    vraie photo de caméra, plus jamais « capture d'écran ».
  - Filtres **quasi invisibles** (variées, très faibles) + **recadrage subtil** (0-3%) + ré-encodage
    HEIC natif caméra ; vidéos : Make/Model/Software/Localisation cohérentes.
  - **Logo refait** : logomark tech (dégradé navy→violet, anneau d'objectif + 6 lames + W
    géométrique) généré par `D:\Temp\opencode\gen_icon.ps1`.
  - Build `33216162559` **vert** (commit `ec087e3`) ; IPA 616 245 o uploadé dans la Release
    `v1.0.0`. 3 erreurs de compile corrigées en cours de route (scope `makeDate`, clé EXIF
    invalide, identifiant encodeur QuickTime invalide).

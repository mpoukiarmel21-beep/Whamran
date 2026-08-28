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
- Dernier build réussi : run `33218103288` (commit `ff8cb27`). IPA (694 614 o) ré-uploadé
  manuellement dans la Release `v1.0.0` — **lien direct toujours** :
  `https://github.com/mpoukiarmel21-beep/Whamran/releases/download/v1.0.0/Whamran.ipa`

## En cours

- **(libre)** — Nouveau rework « DA + flux » livré et pushé (voir Journal tout en haut). Build
  `33218103288` vert, IPA uploaé dans la Release. À valider par l'utilisateur.

## Prochaine étape

- Si l'utilisateur valide, plus rien à faire côté build. Sinon, itérer sur la DA.

## Blocages / risques

- La CI ne publie la Release que sur push de tag ; pour un push `main` il faut uploader l'artefact
  à la main.
- Pas de build/compilation Swift sous Windows : chaque erreur se découvre au prochain run Actions.
- `dist/` (IPA locales) est ignoré par `.gitignore`.

## Journal

- **2026-08-28 — ox-alpha (opencode)** : Second rework « DA + flux » **terminé et livré** :
  - **DA claire et lisible** : abandon du thème sombre/violet jugé « dégueulasse » ; thème clair
    (fond blanc/bleu très pâle), textes foncés bien visibles (« Fichiers générés » en accent),
    police système arrondie (`.rounded`), cartes blanches aux coins arrondis.
  - **Boutons unifiés** (même DA partout) : `WhamranButtonStyle` (primaire = dégradé indigo→cyan,
    secondaire = contour). Générer / Enregistrer / Nouvelle session cohérents.
  - **Flux modifié** : sélection d'une image/vidéo → **navigation directe vers l'interface
    d'options** avec l'**aperçu de la photo choisie** en haut ; plus besoin d'appuyer sur
    « Options ».
  - **Carte du monde supprimée** (`FakeMapView.swift` supprimé) — inutile ; on garde la **barre de
    recherche de villes** et la version iOS (avec option « Auto »).
  - **Stepper +/- bien visible** : boutons circulaires colorés « − » / « + » avec le compteur au
    centre.
  - **Logo changé encore** : marque pro type objectif (anneau + 7 lames d'ouverture + rond central),
    sur dégradé indigo→cyan, **sans le « W »** ; régénéré pour toutes les tailles.
  - **Caméra virtuelle vérifiée** : `VirtualCamera` construit **à chaque itération** dans les deux
    moteurs → réglages EXIF uniques par fichier généré (rien à corriger).
  - **Builds** : premier essai échoué (erreur de type sur le fond du bouton stepper : ternaire
    `Color` vs `LinearGradient`) → corrigé (`AnyShapeStyle`) ⇒ run `33218103288` **vert** (57 s).
    IPA 694 614 o uploadé dans la Release `v1.0.0`.

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

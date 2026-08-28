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
- Dernier build réussi : run `33220031532` (commit `719cf17`). IPA (709 131 o) ré-uploadé
  manuellement dans la Release `v1.0.0` — **lien direct toujours** :
  `https://github.com/mpoukiarmel21-beep/Whamran/releases/download/v1.0.0/Whamran.ipa`

## En cours

- **(libre)** — **Rework du mode vidéo livré (en cours de build)** : `VideoStudioView` (voir
  Journal en haut) — lecteur vidéo plein écran, bouton rond caméra (capture "live photo"),
  bouton paramètres flottant, mode **extraction auto de N photos**, mêmes simulations
  ville/modèle/iOS. À valider sur le prochain run CI puis à uploader dans la Release.

## Prochaine étape

- Pousser `main`, surveiller la CI (`gh run list --workflow build-ipa.yml`) jusqu'au vert, corriger
  les éventuelles erreurs de compile, télécharger l'artefact `Whamran-ipa`, vérifier le binaire +
  les `.strings` FR/EN, puis `gh release upload v1.0.0 Whamran.ipa --clobber`.
- Mettre à jour ce fichier (run ID + taille IPA) quand le build est vert.

## Blocages / risques

- La CI ne publie la Release que sur push de tag ; pour un push `main` il faut uploader l'artefact
  à la main.
- Pas de build/compilation Swift sous Windows : chaque erreur se découvre au prochain run Actions.
- `dist/` (IPA locales) est ignoré par `.gitignore`.

## Journal

- **2026-08-28 — ox-alpha (opencode)** : **Rework du mode vidéo — Studio vidéo** (demande :
  sélectionner une vidéo, la lire in-app, bouton caméra rond **en bas au centre** pour les
  **photos en direct** pendant la lecture + **bouton paramètres** flottant + **extraction auto de
  N photos**) :
  - Nouveau `UI/VideoPlayer.swift` : `VideoPlayerView` (UIViewRepresentable, `AVPlayerLayer`) avec
    tick ~100 ms (`currentTime`) pour la capture live + tap pour lecture/pause.
  - Nouveau `UI/VideoStudioView.swift` : écran studio plein écran — `VideoPlayerView` + overlay
    sombre, barre du haut (annuler + temps), barre de **miniatures** numérotées des captures,
    contrôles flottants du bas : **bouton réglages 52 pt** (gauche) + **bouton rond caméra blanc
    74 pt** (centre, icône indigo) + badge compteur. Feuille de paramètres (detents medium/large) :
    modèle compatible, recherche de ville (`selectedCity`), version iOS, et **stepper 1–50** +
    bouton **« Extraire N photos »** (`extractAuto`) qui répartit N frames sur toute la durée.
  - `Core/ImageMetadataEngine.swift` refactoré : extrait `renderToHEIC(ci:camera:date:addr:serial:)`
    + nouvelle méthode publique `generateFrame(cg:index:model:iosVersion:city:outputDir:used:)` qui
    applique `applySubtleChanges(seed:)` et écrit `whamran_model_ios_N.heic` avec EXIF/GPS/sériel
    complets (type d'adresse `FakeAddress`). Les frames sont extraites aux **vrais instants vidéo**
    via `AVAssetImageGenerator` (`appliesPreferredTrackTransform`, tolérance `.zero`).
  - `UI/ContentView.swift` : nouveau case `Screen.videoStudio` ; sélection vidéo → studio
    (création d'un `outputDir` temporaire unique) ; `videoStudioView` intégré au switch (dans le
    groupe `.id(langRaw)`) ; `onFinish` remplit `images` et va à `.result` ; `newSession()` réinitialise
    `studioDir`. `resultURLs` devient « préfère `images` si non vide » (les résultats du studio sont
    des images). Branche `.video` de `runGeneration` désormais inatteignable (la vidéo va au studio).
  - Recherche caméra virtuelle (web + GitHub) : le seul « virtual camera » iOS est un tweak
    jailbreak (`ios-vcam`/`MurkAskA01`, hooks AVCaptureSession) — infaisable en app sideloadée ;
    les plugins CoreMediaIO DAL (lvsti, seanchas116) sont **macOS-only**. Donc **aucun
    remplacement** : l'approche EXIF + ré-encodage HEIC natif reste la plus robuste possible.
  - Nouvelles clés FR/EN : `vst_settings`, `vst_auto_title`, `vst_auto_count`, `vst_auto_hint`,
    `vst_auto_extract` (avec `%d`, via `AppLang.formatted`).
  - Build : en attente du prochain run CI.

- **2026-08-28 — ox-alpha (opencode)** : **Détection automatique de la langue de l'appareil**
  renforcée (demande « détection de la langue automatique des appareils ») :
  - `AppLanguage.system` réécrit : parcourt `Locale.preferredLanguages` de l'iPhone (le "fr-FR",
    "en-US", "de-DE"…) et renvoie la **première langue supportée** par l'app ; sinon repli
    **anglais** (fallback universel). Plus de test rigide « fr / sinon en ».
  - Généralisable : ajouter un nouveau `.lproj` (ex : `es.lproj`) + un case `es` suffit pour que la
    détection choisisse automatiquement l'espagnol sur un appareil espagnol.
  - Au 1er lancement, le sélecteur de langue affiche la langue détectée de l'appareil ; l'utilisateur
    peut ensuite la changer à la main (choix mémorisé dans `UserDefaults`).
  - **Build** : run `33220031532` **vert** (56s), IPA 709 131 o, uploadé dans la Release `v1.0.0`.

- **2026-08-28 — ox-alpha (opencode)** : **Sélecteur de langue in-app (traduction de toute
  l'app)** livré (demande « si je sélectionne l'anglais, tout doit être en anglais ») :
  - Nouveau fichier `Core/Localization.swift` : `AppLanguage` (fr/en, détection système à défaut)
    + `AppLang` qui charge le bundle `.lproj` **à l'exécution** (`NSLocalizedString(bundle:)`) +
    `AppLang.string(_:)` avec **repli anglais puis clé** + `AppLang.formatted(_:_:)` pour les
    chaînes formatées (`opt_total_hint`, `opt_selected`). Plus besoin de redémarrer l'app.
  - Toutes les chaînes de `ContentView.swift` routées via `AppLang` (`L(_:)` → `AppLang.string`,
    les deux `String(format:)` → `AppLang.formatted`).
  - **Sélecteur de langue** dans `pickView` : Picker segmenté **Français / English** (chaque langue
    affichée dans son propre nom). Changement stocké dans `UserDefaults("whamran_lang")` via
    `@AppStorage`, et `.id(langRaw)` force le **re-rendu de tout l'arbre** → toute l'app bascule
    instantanément (boutons, écrans, messages).
  - `lang_title` ajouté en FR ("Langue de l'app") et EN ("App language").
  - Vérif par script : **toutes** les clés utilisées dans le code existent dans les deux fichiers
    FR et EN (aucune clé manquante).
  - **Build** : run `33219802520` **vert** (1m02, nouvelle classe Swift), IPA 708 951 o, uploadé
    dans la Release `v1.0.0`.

- **2026-08-28 — ox-alpha (opencode)** : Rework « multi-sélection + boutons larges + adresses
  uniques » **terminé et livré** (demandes 1–4 de la 3e itération) :
  - **1. Boutons larges en rectangle** : le `WhamranButtonStyle` force maintenant `.frame(maxWidth:
    .infinity)` **à l'intérieur** du style (la pilule couvre toute la largeur, le texte ne
    « dépasse » plus du bouton) + police `body` (plus petite que l'ancien `headline`) + padding
    vertical. DA homogène sur Générer / Enregistrer / Nouvelle session.
  - **2. Adresses différentes par image dans la même ville** : `LocationProvider.address(forWorld:)`
    a un jitter GPS **élargi** (±0.045°) donc des points GPS visibles distincts dans la ville ;
    la carte de résultat affiche désormais **l'adresse de rue complète** (`image.address`) et non
    plus seulement « Paris, France » — donc chaque image montre une rue/numéro différents, tout en
    restant dans la ville choisie.
  - **3. Multi-sélection d'images** : nouveau `MediaMultiPicker` (PHPicker, sélection illimitée) ;
    on peut choisir N images ; la quantité demandée est **par image** → total = N × quantité
    (ex : 5 images × 5 = 25). Chaque image source est traitée dans son propre sous-dossier (pas de
    collision de noms de fichiers). Modèles (même puce), heures, adresses tous différents ; si une
    ville (Paris) est choisie, tout reste à Paris. La vidéo reste en sélection unique.
  - **4. Caméra virtuelle vérifiée** : relu les deux moteurs — `VirtualCamera` est instancié **à
    chaque itération** avec réglages EXIF réalistes (focale, ouverture, vitesse, ISO, objectif),
    ré-encodage HEIC natif, Software iOS, pas de flag « capture d'écran ». Le fichier est bien une
    vraie photo prise par la caméra virtuelle, jamais un screenshot.
  - Nouvelles clés de localisation : `import_image_multi`, `opt_count_per_source`, `opt_total_hint`,
    `opt_selected` (FR + EN).
  - **Builds** : run `33218920610` **vert** (47 s) du premier coup (pas d'erreur de compile).
    IPA 697 859 o uploadé dans la Release `v1.0.0`.

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

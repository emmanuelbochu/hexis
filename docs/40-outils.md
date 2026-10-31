# Outils : mode d'emploi

Toutes les commandes se lancent depuis `~/Developer/Hexis`.

## Je veux… → je fais…
| Je veux… | Je fais… |
|---|---|
| Installer l'app sur l'iPhone | Xcode, schéma Hexis, iPhone branché ou en Wi-Fi, **⌘R en Release** (Product → Scheme → Edit Scheme → Run → Release) |
| Ne plus y penser chaque semaine | Rien : le build automatique réinstalle l'app (voir « Build automatique ») |
| Mettre la doc à jour | éditer `docs/*.md` puis `python3 Tools/doc.py` ; ouvrir `docs/index.html` dans le navigateur |
| Vérifier que rien n'est cassé | `zsh Tools/check.sh` |
| Chasser les bugs en profondeur | `zsh Tools/check.sh deep`, ou `/chasse` dans Claude Code, ou `/loop /chasse` |
| Savoir si l'iPhone a des problèmes | lire `Tools/.data/report.md` |
| Comprendre un crash ou un gel | `python3 Tools/crashlog.py` |
| Changer le programme | éditer `Hexis/Resources/Program.json` puis ⌘R (rechargé au lancement) |
| Mettre la clé Gemini | copier `Hexis/Secrets.example.plist` en `Hexis/Secrets.plist` et remplir `GeminiAPIKey` |
| Restaurer une sauvegarde | automatique : si la base est vide au lancement, l'app remet la dernière copie (`AutoBackup.restoreIfEmpty`). Les copies sont dans Fichiers → Hexis (20 gardées) |
| Refaire les images d'exos | `python3 Tools/exo_generate.py` puis `python3 Tools/exo_import.py Tools/generated` |
| Refaire les sons | `python3 Tools/sounds.py` |

## Compiler et lancer l'app
- **Quoi** : Xcode, ⌘R sur l'iPhone 15 Pro Max, toujours en **Release** (Debug seulement pour déboguer).
- **Pourquoi chaque semaine** : le compte Apple gratuit signe pour 7 jours. L'app prévient 36 h avant l'expiration (`ProfileExpiry`).
- **Ne jamais** : changer le Bundle ID `com.example.Hexis`, désinstaller l'app (les données sont dedans).

## Build automatique
| | |
|---|---|
| Quoi | recompile **HEAD** en Release (jamais le travail en cours) et installe en Wi-Fi sur l'iPhone appairé : « Hexis », puis « Hexis Elle » à côté (pour la tester ; un échec d'Elle ne bloque jamais la tienne) |
| Quand | **nouveau commit** : réinstallé le jour même au même « bon moment » (voir ci-dessous), une fois HEAD immobile depuis 20 min et au plus une fois toutes les 6 h ; sinon dès 3 jours après la dernière installation, au « bon moment » (iPhone répond et verrouillé, Mac inactif ≥ 2 min avec secteur ou ≥ 40 %, heure habituelle apprise) ; dès 5 jours au premier moment où l'iPhone répond ; nouvel essai après 30 min si échec |
| Automatique | oui, `launchd` contrôle toutes les 10 min |
| Installer / réinstaller | `zsh Tools/install_weekly_build.sh` |
| Forcer maintenant | `python3 Tools/weekly_build.py --force` |
| Compiler à la demande | `compil hexis` : Hexis + Hexis Elle sur ton iPhone ; `compil hexis2` : en plus Hexis Elle (seule, vérifiée sur l'app compilée) sur le sien ; `compil status` : ce qui est installé, jours restants, qui répond. Compile le travail en cours en Release, les deux apps en parallèle, une ligne par étape avec sa durée, des conseils en clair (déverrouiller, mode développeur, faire confiance, compte Apple, place, Wi-Fi) ; prend le même verrou que le job (jamais en même temps, il attend son tour) ; remet à zéro les horloges de 7 jours ; n'ouvre jamais l'app. Ton iPhone est épinglé dans `Tools/.data/my-device` (jamais deviné deux fois : ton app ne peut pas atterrir sur le sien) |
| Alerte | notification Mac seulement à partir de 5,5 jours sans installation (au plus toutes les 12 h) |
| Log | `~/Library/Logs/HexisBuild.log` |
| Prérequis | compte Apple connecté dans Xcode |
| Fichiers | `Tools/weekly_build.py`, `Tools/install_weekly_build.sh` |

**Son iPhone (Hexis Elle)** : une fois `zsh Tools/her_phone.sh pair` (liste les appareils ; noter le sien dans `Tools/.data/her-device`). Ensuite le même job `launchd` s'en occupe seul, avec sa propre horloge (`her_*` dans `~/Library/Application Support/HexisBuild`). Elle n'est près du Mac que pendant sa visite (vendredi 18 h au dimanche 18 h) et ne s'y entraîne pas : installation dès que son iPhone répond, verrouillé ou non, à l'arrivée dès 3 jours puis une 2e fois avant son départ dès une demi-journée (elle repart avec 7 jours pleins) ; hors visite seulement verrouillé, et dès 5 jours à tout moment ; le build de HEAD est réutilisé si HEAD n'a pas bougé. Un `compil hexis2` hors visite laisse un drapeau (`her_check`) : la visite suivante la réinstalle quoi qu'il arrive, pour vérifier que ça marche vraiment sur son iPhone. Notification Mac seulement pendant la visite, dès 4 jours sans pouvoir l'installer. Ton iPhone est toujours choisi en excluant le sien. À la main : `zsh Tools/her_phone.sh` (installe maintenant puis contrôle ses données).

Le même passage quotidien lance `data_check.sh` (et `data_check.sh elle` si son iPhone répond) et écrit `Tools/.data/report.md`.

## Le contrôle unique : `check.sh`
| | |
|---|---|
| Commande | `zsh Tools/check.sh` (rapide, 1 vie simulée par scénario) · `zsh Tools/check.sh deep` (8 vies + vraies données de l'iPhone) |
| Contenu | audit statique · doc à jour · tests de logique + simulateur de vie · compilation iOS |
| Quand | avant chaque commit, **automatique** par le hook Git ; `deep` pour chasser |
| Coût | rapide : quelques minutes ; deep : plus long |
| Hook | `Tools/hooks/pre-commit` (installé par `git config core.hooksPath Tools/hooks`) refuse un commit rouge ; urgence : `git commit --no-verify` |
| Fichier | `Tools/check.sh` |

## Les outils de contrôle
| Outil | Quoi | Quand | Commande | Auto ? |
|---|---|---|---|---|
| Audit statique | force unwrap, `print`, couleurs en dur, `NavigationStack`/toolbar dans le pager, `.task` sur un `Group` qui peut être vide (ne tourne jamais), fetch sans filtre, types orphelins, modèle absent de la sauvegarde, **code mort** (bloque le commit) | dans `check.sh` | `python3 Tools/audit.py` | oui |
| Secrets | clé Google (`AIza…`), clé `sk-`, en-tête de clé privée, mot de passe en clair dans les fichiers suivis par Git ; `Secrets.plist` suivi = erreur. Bloque le commit | dans `check.sh` via l'audit | `python3 Tools/secrets_scan.py` | oui |
| Code mort | fonctions/statiques/types jamais utilisés, images d'exos sans exo, clés `UserDefaults` jamais lues, champs de `Program.json` jamais lus (avertissement), fichiers > 150 lignes (avertissement), `TODO`/`FIXME`. Liste blanche : `Tools/deadcode_allow.txt` (nom + raison ; un nom de fichier y silence l'avertissement de taille). Les anciens schémas ne sont jamais signalés | dans `check.sh` via l'audit | `python3 Tools/deadcode.py` | oui |
| Tests de logique | tests unitaires de `Services/` ; **tests de performance** (`PerformanceTests` : 2 ans d'historique synthétique, un budget de temps par calcul lourd : bilan de semaine, apport, analyse, plateaux, ajusteur, courses) | dans `check.sh` | `zsh Tools/logic_tests.sh` | oui |
| Simulateur de vie (alimentation) | 12 à 16 semaines de repas, courses et stock avec le vrai plan | dans `check.sh` | `zsh Tools/logic_tests.sh --filter NutritionLifeTests` | oui |
| Simulateur de vie | athlète virtuel qui vit des mois avec le vrai `WorkoutViewModel` (ses vies à lui dans la passe « Hexis », les siennes dans la passe « Hexis Elle ») | dans `check.sh` | `zsh Tools/logic_tests.sh` | oui |
| Passe « Hexis Elle » | toute la suite recompilée avec `ELLE` (dossier `.build-elle`) : son programme, ses règles (Cheer, relances, salles, effort), ses vies (`#if ELLE` dans `LifeTests`), ses données réelles ; sans l'alimentation | dans `check.sh` | `HEXIS_EDITION=elle zsh Tools/logic_tests.sh --skip Nutrition` | oui |
| Démarrage d'une conversation | prochaine action, à faire, 8 commits, verdict du rapport, branche de chasse à relire, en un appel | début de chaque conv | `zsh Tools/brief.sh` | non |
| Ce que l'utilisateur verra | sur la dernière sauvegarde de l'iPhone (`Tools/.data/latest.json`), à l'heure de la sauvegarde : Accueil (séance, semaine à 3), chaque séance préremplie, Aujourd'hui, courses ; `check.sh` affiche le diff depuis le dernier vert (`seen-last.txt`). Pareil pour elle (`her-latest.json`, `her-seen-last.txt`), sans l'alimentation | dans `check.sh` | `zsh Tools/check.sh` | oui |
| Données réelles | contrôle la dernière sauvegarde de l'iPhone, affiche la prochaine séance de chaque modèle, compare ce que l'Accueil a montré (`HomeShown`, sauvegardé) à la logique | après un usage réel | `zsh Tools/data_check.sh` (le tien, jamais le sien) · `zsh Tools/data_check.sh elle` (le sien, contrôlé comme son app) ; lecture seule, fichiers dans `Tools/.data/`, hors Git | oui, chaque jour |
| Documentation | régénère `docs/index.html` depuis `docs/*.md` et les faits du code (fichiers, schéma, modèles, services, tests, programme) ; `--check` échoue si la page est périmée | à chaque changement de `docs/*.md` ou de code | `python3 Tools/doc.py` (écrire) · `python3 Tools/doc.py --check` | check dans `check.sh` |
| Usage réel | ce que l'utilisateur utilise vraiment, sur 30 et 90 jours : séances, « Fatigué », « Gêne », repas « Mangé », tickets, corrections, cases de courses, + ouvertures des écrans secondaires (`UsageCounter`, sauvegardé avec les préférences). Ne décide rien : une fonction à 0 pendant 60 jours d'usage réel va dans `ROADMAP.md` « Idées à évaluer » | après quelques semaines d'usage | `python3 Tools/usage.py` (lit `Tools/.data/latest.json`) | section « Usage » du rapport |
| Anomalies dans l'app | journal des anomalies non fatales (échec de sauvegarde, sauvegarde illisible, erreur Gemini, `Program.json` refusé, valeur NaN rattrapée, lancement > 2 s), borné à 200, sans écran ; **MetricKit** écrit les 5 derniers rapports de crash/gel/lancement d'Apple dans `Documents/diagnostics/` de l'iPhone | en permanence | lus par le rapport quotidien (`Anomalies`, `Crashs et gels`, `Performance`) | oui |
| Rapport quotidien | première ligne `RAS` ou `À CORRIGER (n)`, puis 8 sections fixes : Données · Crashs et gels · Anomalies · Performance · Usage · Installation (âge de la dernière installation auto, signalé au-delà de 5 jours au lieu d'attendre la notification à 5,5) · Code · Chasse (un crash plus ancien que le dernier commit est montré mais pas signalé), + « Hexis Elle » quand son iPhone a été lu (ses problèmes comptent, préfixés « Elle : ») | lu en premier à chaque conversation | `Tools/.data/report.md`, construit par `Tools/report.py` (appelé par `weekly_build.py`) | oui, chaque jour |
| Crash | dernier rapport de crash de l'iPhone (`0x8BADF00D` = thread principal bloqué > 10 s) | crash ou gel | `python3 Tools/crashlog.py [elle] [n]` | non |
| `/chasse` | une zone par passe : cas concrets, test qui échoue, correctif, journal | à la demande | `/chasse` ou `/loop /chasse` dans Claude Code | non |

## Chasse automatique
| | |
|---|---|
| Quoi | Claude lance `/chasse` seul, dans un worktree `../Hexis-chasse` sur la branche `chasse/<date>` : jamais `main`, jamais de push |
| Quand | lancée par `weekly_build.py` après le rapport, seulement si : rapport `À CORRIGER`, ou ≥ 4 nouvelles séances réelles, ou ≥ 10 commits depuis la dernière chasse ; au plus tous les 3 jours ; Mac inactif et sur secteur ; dernière série de l'iPhone > 3 h |
| Coût | payant (Claude, ≤ 60 tours) : c'est pourquoi les conditions sont strictes |
| Résultat | section `Chasse` de `report.md` (`Tools/.data/chasse.md`) ; la branche est supprimée si rien n'est trouvé |
| Ensuite | une conversation relit le diff de la branche et fait `git merge --ff-only chasse/<date>` si c'est bon |
| Forcer | `zsh Tools/auto_chasse.sh` |
| Log | `~/Library/Logs/HexisChasse.log` |

## Publier une version publique
| | |
|---|---|
| Quoi | un instantané propre du projet **sans historique** et sans données perso : le dépôt réel reste privé (son historique contient adresses et GPS des salles) |
| Commande | `zsh Tools/publish.sh <dossier neuf ou vide hors du projet>` |
| Étapes | `git archive HEAD` · règles de `Tools/publish_redact.txt` appliquées à chaque fichier texte · motifs `forbid:` toujours présents ⇒ échec · scan de secrets · `doc.py` · le dossier n'est créé que si tout passe |
| Règles | `Tools/publish_redact.txt` (privé, ignoré par Git car il liste les données perso) ; modèle : `Tools/publish_redact.example.txt` |
| Ensuite | pousser le dossier soi-même (le script ne pousse jamais) ; `docs/index.html` s'ouvre sur GitHub Pages |
| Vitrine | `README.md` (anglais), ses chiffres sont générés par `doc.py` |

## Outils de ressources
| Outil | Quoi | Commande |
|---|---|---|
| Illustrations dessinées | 1 image par exo (mannequin, machine, muscle) ; `--elle` : son programme, silhouette de femme (queue de cheval, brassière, cycliste) et son accent, écrit `elle-exo-<slug>` dans `HexisElle/Assets.xcassets`. L'audit exige une image pour chaque exo des deux programmes | `python3 Tools/exo_images.py [--elle] [--sheet out.png] [noms]` (kit : `exo_draw.py`) |
| Photos Gemini | image 3D par exo, facturation Gemini requise (~0,13 $ l'image) | `python3 Tools/exo_generate.py ["Nom exo"]` → `Tools/generated/` |
| Import d'images | recadre en carré 512 px et écrit l'asset `exo-<slug>` | `python3 Tools/exo_import.py <dossier>` |
| Historique Hevy (Elle) | convertit l'export Hevy en `HexisElle/HevyHistory.json` (table « même exo / autre exo » et conversions dans le script, ré-exécutable) ; l'app le charge seule au lancement (`HistorySeed`) | `python3 Tools/hevy_import.py [workout_data.csv]` |
| Sons | synthétise les `.caf` de `Hexis/Resources/Sounds` (numpy + macOS `afconvert`, synthèse modale + réverbe par convolution, graine fixe) | `python3 Tools/sounds.py` |

## En cas de crash
1. `python3 Tools/crashlog.py` (iPhone branché au Mac pour que les rapports se synchronisent).
2. Ne pas deviner : écrire d'abord le test qui reproduit, puis le correctif.
3. Si la base ne s'ouvre pas : l'app affiche un écran de secours ; les copies sont dans Fichiers → Hexis et une base vide est restaurée seule au lancement suivant.

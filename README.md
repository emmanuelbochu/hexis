# Hexis

Application iOS personnelle de musculation et d'alimentation, en SwiftUI et SwiftData. Tout tourne sur le téléphone :
pas de compte, pas de serveur, pas de suivi. Projet personnel, tous droits réservés.

## À lire d'abord : comment ce projet a été fait

**Je n'ai pas écrit le code de ce projet.** Hexis a été construit presque entièrement par une IA (Claude Code) que j'ai
dirigée par le chat, pendant de nombreuses heures. Je n'ai pas lu la plupart du code Swift ligne par ligne, et je ne
saurais pas le réécrire seul aujourd'hui.

**Ce que j'ai fait :**
- **Décidé de ce que l'app devait être** : l'idée du produit (l'app décide et explique, sans demander de confirmation, un seul bouton évident par écran), les fonctionnalités, et les outils qui valaient la peine d'exister.
- **Défini les règles d'entraînement** (progression, allègement, phases de réhabilitation) avec l'IA.
- **Utilisé l'app, repéré les problèmes et les ai signalés** (surtout des problèmes d'affichage ou de logique), puis demandé à l'IA de les corriger.
- **Demandé l'ingénierie autour** (tests, simulateur de vie, contrôles automatiques, documentation) : plusieurs de ces outils existent parce que je les ai imaginés et demandés.

**Ce que l'IA a fait :** tout le code Swift, les tests, les outils et la documentation.

Je le publie comme **démonstration de ma façon de diriger une IA sur un gros projet**, pas comme preuve de compétences en Swift.
Le code que j'ai écrit moi-même se trouve dans mes autres dépôts.

*Les données personnelles sont retirées de cette copie publique. Pour cette raison, `HexisElle/HevyHistory.json` ne contient
aucune séance ici, et les tests qui en dépendent ne passent pas dans cette copie.*

## Principe

L'app décide, dit ce qu'elle a décidé, et ne demande jamais de confirmation. Un seul bouton évident par écran.

## Ce qu'elle fait
- **Entraînement** : un programme tient dans un seul fichier JSON. L'app choisit la prochaine séance, fixe les charges, les séries et les temps de repos d'après l'historique (double progression, paliers, allègement automatique toutes les 6 semaines, phases de réhabilitation du mollet), prépare l'échauffement, chronomètre les repos (Live Activity comprise) et clôt seule les séances oubliées.
- **Alimentation** : un plan de repas hebdomadaire, un appui pour enregistrer un repas, une liste de courses calculée à partir du plan moins le stock, des tickets de caisse lus par Gemini pour mettre à jour stock et prix, et un plan qui suit la balance.
- **Analyse** : bilan hebdomadaire, records, volume par muscle face aux objectifs, tendances repérées dans tes propres données (toujours avec la taille de l'échantillon, jamais une cause inventée).

## Chiffres (générés depuis le code)
<!-- facts -->
- 262 fichiers Swift, 15 067 lignes, schéma SwiftData V16
- 239 tests de logique, 6 scénarios de vie simulés
- 113 règles documentées, chacune avec son seuil
<!-- /facts -->

## Organisation
| Dossier | Rôle |
|---|---|
| `Hexis/Models` | Modèles SwiftData, schéma versionné et plan de migration |
| `Hexis/Services` | Logique pure : progression, allègement, ajustements, statistiques, courses, sauvegarde |
| `Hexis/Features` | Écrans (un seul `NavigationStack` autour d'un pager de 6 pages) |
| `HexisWidgets` | Live Activity du minuteur de repos |
| `Tools` | Contrôles, simulateurs, automatisation du build et de l'installation |

## Comment elle reste correcte
- `zsh Tools/check.sh` est l'unique contrôle : audit statique (`!`, code mort, secrets), tests de logique, **simulateur de vie** (un athlète virtuel vit des mois avec le vrai modèle de vue, la vraie base et le vrai programme), budgets de performance, documentation à jour, compilation iOS. Un hook Git refuse tout commit rouge.
- Chaque nuit, le Mac lit la sauvegarde de l'app sur le téléphone et écrit un court rapport (données, plantages, anomalies, performance, usage, code mort). Une chasse aux bugs par Claude se lance seule quand elle en vaut la peine, sur sa propre branche.
- Une nouvelle règle de calcul demande un test ; un bug trouvé demande d'abord un test qui échoue.

## Documentation
La documentation complète (fonctions, règles avec leurs seuils, architecture, outils, décisions, glossaire) tient en une page générée : [`docs/index.html`](docs/index.html), construite depuis `docs/*.md` par `python3 Tools/doc.py`.

## Compiler
Ouvrir `Hexis.xcodeproj` dans Xcode, copier `Hexis/Secrets.example.plist` vers `Hexis/Secrets.plist` et y mettre une clé Gemini (seule la lecture des tickets en a besoin), choisir sa propre équipe et son propre identifiant de bundle, puis lancer sur un appareil.

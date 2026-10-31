# Architecture

## Dossiers
| Dossier | Contenu |
|---|---|
| `Hexis/App` | `HexisApp`, `RootView` (NavigationStack + pager), `RootTabBar`, `ModeSwitcher` |
| `Hexis/Theme` | `Theme.swift` : tout le style (couleurs `Color(light:dark:)`, espacements) |
| `Hexis/Models` | `@Model` ; `Schema/` : V1…V16 + `HexisMigrationPlan` |
| `Hexis/Features` | écrans : Home, Workout, Program, History (Analyse, Bilan, Temps), Settings (rappel de sauvegarde), Gyms, Nutrition. `Workout/` et `Nutrition/` ne se connaissent pas |
| `Hexis/Services` | logique pure : progression, déload, ajustements, stats, Gemini, sauvegarde… |
| `Hexis/Components` | vues partagées |
| `Hexis/Resources` | `Program.json` (programme, consignes, réhab, cibles, priorités) |
| `HexisWidgets/`, `HexisShared/` | extension Live Activity (Dynamic Island, repos) ; attributs partagés app/extension, sans App Group |
| `Tools/` | scripts et tests, voir [Outils](40-outils.md) |
| `docs/` | cette documentation (`*.md` source, `index.html` généré) |

Vues sans logique métier ; logique en fonctions pures dans `Services/`. `@Observable`, `@Query`, `#Preview` par vue, un type principal par fichier, pas de `!`/`print`, vues < ~150 lignes. Tout ce qui lit l'heure prend un `now:` (le simulateur voyage dans le temps).

## Flux d'une séance
| # | Étape | Fichier |
|---|---|---|
| 1 | L'accueil propose la séance suivante (variante 3 séances si la semaine est courte) | `WeekRotation`, `TemplatePicker` |
| 2 | Les charges, séries, repos sont décidés d'après l'historique | `SessionAdjuster` (+`Load`), `Progression`, `Rehab`, `TrainingCycle` |
| 3 | La séance est construite (échauffements, supersets) | `SessionPlan`, `WarmupCalculator` |
| 4 | La séance vit, saisie libre dans n'importe quel ordre | `WorkoutViewModel` (présenté par `RootView`) |
| 5 | Elle se ferme (toutes les séries cochées, ou oubliée) | `SessionCloser` |
| 6 | Copie de sauvegarde, lecture IA des plateaux | `AutoBackup`, `ProgressDiagnosis` |

## Navigation (contraintes dures)
- **Un seul `NavigationStack`**, dans `RootView`, autour du pager de 6 écrans. Pas de `NavigationStack` ni de `.toolbar` par écran racine (crash UIKit au swipe) : boutons d'action en `PageActionRow` dans un `VStack`.
- Pas de `safeAreaInset` autour du pager ni dans ses pages (boucle de mise en page, gel).
- `RootTabBar` flotte en `overlay` ; marge basse par `.contentMargins`. Les écrans poussés recouvrent le pager.
- La séance en cours est présentée par `RootView` (`ActiveWorkoutView`), jamais depuis une page du pager.
- Confirmations en `.alert` ; pas de swipe action ; seul geste global : glissé sur `ModeSwitcher`.

## Données
- SwiftData local, schéma actuel **V16** (V1 base, V2 SessionNote, V3 CarryNote, V4 ExerciseFeeling, V5 FoodEntry, V6 nutrition, V7 ExerciseLoad + DeloadWeek, V8 PurchaseLog, V9 AIInsight, V10 ReceiptAlias, V11 ExtraPurchase, V12 ExerciseTweak, V13 ShoppingNote, V14 ProductMemory, V15 OffPlanProduct, V16 FlatStock).
- Tout changement de `@Model` = nouvelle `VersionedSchema` + étape du `SchemaMigrationPlan`. **Jamais modifier une propriété d'un `@Model` livré** (crash au lancement) : nouveau modèle lié par UUID. Les anciens schémas ne se suppriment jamais.
- Tout nouveau modèle : `BackupDocument` + `BackupService`.
- `Program` → `WorkoutTemplate` → `TemplateBlock` (>1 exo = superset) → `TemplateExercise`. `WorkoutSession` + `SetLog` ; notes (`SessionNote`, `CarryNote`, `ExerciseFeeling`, `ExerciseGymNote`) ; `ExerciseTweak` (changement durable par salle, effacé à chaque nouveau programme). Nutrition : `FoodEntry`, `Ingredient`, `PlanMeal`, `PlanMealLog`, `ShoppingCheck`, `BatchStep`, `PurchaseLog`, `ExtraPurchase`, `ReceiptAlias`.
- Programme : `ProgramSync` recharge `Program.json` au lancement quand il change. Mêmes séances (noms) ⇒ mise à jour sur place ; autres séances ⇒ nouveau programme actif (anciens gardés pour les noms de l'historique). Seul un changement d'exos d'une séance déjà là (ou sa disparition) relance le cycle et efface les `ExerciseTweak` ; ajouter des séances ne relance rien (empreinte par séance `programSessionsHash`, sauvegardée).
- **Sauvegarde** : `BackupDocument` (JSON versionné, clés inconnues ignorées) + `BackupService`. Copie auto en fin de séance, au lancement si > 20 h, avant toute suppression ou restauration ; 20 gardées dans Documents ; rappel hebdo de les sortir du téléphone. Base vide ⇒ la dernière copie est remise seule (`AutoBackup.restoreIfEmpty`).
- Un `save()` raté affiche un bandeau (`SaveMonitor`).
- Secrets : `Hexis/Secrets.plist` (ignoré par Git, modèle `Secrets.example.plist`), clé `GeminiAPIKey`.

## Au lancement (`RootView.task`)
`ProgramSync`, `NutritionDefaults.seed`, `StockReconciler`, `AutoBackup.saveIfStale`, rappel d'expiration du profil, clôture des séances oubliées, rappel de sauvegarde hebdo. Au retour au premier plan : clôture des séances oubliées.

## Hexis Elle (seconde app, même code)
Cible `HexisElle` (scheme du même nom) : mêmes sources que `Hexis` (dossiers `Hexis/` et `HexisShared/`), drapeau de compilation `ELLE`, bundle `com.example.Hexis.Elle`, nom « Hexis Elle », icône `AppIconElle` (`HexisElle/Assets.xcassets`). `Edition.hasNutrition` (faux en `ELLE`) retire l'Alimentation et le `ModeSwitcher` de `RootView`. Son programme est `HexisElle/Program.json` (le `Program.json` de `Hexis/` et `Secrets.plist` sont exclus de sa cible). Aucun profil : chaque iPhone a sa propre base, donc rien ne se croise. Salles, Santé, accent et relances : voir `10-fonctions.md` (section Hexis Elle) ; entitlements propres (`HexisElle/HexisElle.entitlements`, sans HealthKit). Live Activity de repos propre à elle : cible `HexisElleWidgets` (bundle `…Hexis.Elle.Widgets`, mêmes sources que `HexisWidgets`, accent rose gold, drapeau `ELLE`). Installer sur son iPhone : `zsh Tools/her_phone.sh pair` une fois, ensuite le job `launchd` (`weekly_build.py`) la réinstalle seul ; à la main `zsh Tools/her_phone.sh`. Tests : passe `ELLE` de `check.sh` (voir `40-outils.md`).

Séance pour elle : effort en « reps encore possibles » (`SimpleEffortSheet`, 0/1/2/3+ = RPE 10/9/8/7 derrière), jamais de rattrapage de semaine (`WeekPlan` seulement à partir de 3 séances), 2 premières semaines à 3 reps en réserve (`rampWeeks`/`rampRIR` de son `Program.json`). Les sons de l'app ne jouent qu'au premier plan (`SoundService`) : en arrière-plan, la notification de fin de repos sonne seule.

## Compte Apple gratuit
| Contrainte | Conséquence |
|---|---|
| Profil valable 7 jours | refaire ⌘R chaque semaine, ou build auto (voir [Outils](40-outils.md)) ; l'app prévient 36 h avant (`ProfileExpiry`) |
| Pas de CloudKit/push/App Groups/Watch/widgets | tout est local ; Live Activity de repos sans App Group |
| Bundle ID `com.example.Hexis` | jamais le changer ; app jamais désinstallée (les données sont dedans) |
| Projet hors iCloud | `~/Developer/Hexis`, jamais Documents/Desktop |
| Pas de dépendance externe | sans demander à l'utilisateur d'abord |

## Schéma : une séance
<svg viewBox="0 0 760 130" role="img" aria-label="Flux d'une séance" width="760">
<defs><marker id="a1" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z"/></marker></defs>
<g class="box"><rect x="4" y="40" width="100" height="50" rx="8"/><rect x="124" y="40" width="100" height="50" rx="8"/><rect x="244" y="40" width="100" height="50" rx="8"/><rect x="364" y="40" width="100" height="50" rx="8"/><rect x="484" y="40" width="100" height="50" rx="8"/><rect x="604" y="40" width="150" height="50" rx="8"/></g>
<g class="arrow"><path d="M104 65H122" marker-end="url(#a1)"/><path d="M224 65H242" marker-end="url(#a1)"/><path d="M344 65H362" marker-end="url(#a1)"/><path d="M464 65H482" marker-end="url(#a1)"/><path d="M584 65H602" marker-end="url(#a1)"/></g>
<g text-anchor="middle"><text x="54" y="62">Accueil</text><text x="54" y="80">TemplatePicker</text><text x="174" y="62">Décision</text><text x="174" y="80">SessionAdjuster</text><text x="294" y="62">Construction</text><text x="294" y="80">SessionPlan</text><text x="414" y="62">Séance</text><text x="414" y="80">WorkoutViewModel</text><text x="534" y="62">Clôture</text><text x="534" y="80">SessionCloser</text><text x="679" y="62">Copie + lecture IA</text><text x="679" y="80">AutoBackup</text></g>
</svg>

## Services (généré depuis le code)
<!-- auto:services -->

## Modèles SwiftData (générés depuis le code)
<!-- auto:modeles -->

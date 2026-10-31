# Qualité : comment Hexis reste sans bug

| Outil | Quand | Ce qu'il fait |
|---|---|---|
| `zsh Tools/check.sh` | avant chaque commit (hook Git `Tools/hooks/pre-commit`, automatique) | audit statique + doc à jour + tests de logique et simulateur de vie (1 vie/scénario) **des deux apps** (passe « Hexis », puis passe « Hexis Elle » compilée avec `ELLE`) + compilation iOS des deux cibles ; refuse le commit si rouge |
| cache de `check.sh` | automatique (`Tools/.data/check-cache`) | chaque étape coûteuse (logique Hexis, logique Elle, compilation iOS) est sautée si ses fichiers sont identiques au dernier vert (logique : même jour, car le simulateur lit l'horloge) : le hook juste après un `check.sh` vert, ou un changement de docs / de tests seuls, coûte quelques secondes. `deep` ne lit ni n'écrit le cache logique |
| `zsh Tools/check.sh deep` | chasse aux bugs (`/chasse`) | idem avec 8 vies/scénario + vraies données de chaque iPhone |
| `zsh Tools/data_check.sh` | après un usage réel, ou en chasse | récupère la dernière sauvegarde auto de l'iPhone (lecture seule, dans `Tools/.data/`, hors Git), contrôle l'historique réel et affiche la prochaine séance de chaque modèle telle que l'app la préremplira |
| automatique (`weekly_build.py`, launchd) | une fois par jour quand l'iPhone répond et le Mac est inactif | lance `data_check.sh` sur HEAD et écrit `Tools/.data/report.md` (RAS ou À CORRIGER) ; chaque nouvelle conversation Claude le lit en premier |
| `/chasse` (skill) | à la demande ou `/loop /chasse` | une zone par passe : cas concrets de la vie, test qui échoue, correctif, journal ci-dessous |
| `python3 Tools/crashlog.py [elle]` | crash ou gel | dernier rapport de l'iPhone (le sien avec `elle`) |

**Simulateur de vie** (`Tools/LogicTests/Tests/LogicTests/Life/`) : un athlète virtuel (force réelle cachée qui progresse,
stagne ou baisse) vit des mois avec la **vraie** app : vrai `Program.json`, vraie base SwiftData (schéma courant), vrai
`WorkoutViewModel`, vraies règles (cycle, déload, plateaux, réhab, clôture des séances oubliées). Habitudes réglables
(`Habits` : séances sautées, vacances, RPE oublié, faute de frappe, « Fatigué », « Gêne », séance abandonnée ouverte,
2 salles, ordre changé, plateau). `LifeChecks` vérifie à chaque séance : bornes (reps, RIR, repos, séries), poids
fini/positif, pas de 0 kg après une séance chargée, pas de saut de charge > 25 %, échauffement ≤ travail, textes sans
« dur »/NaN/doublon ; et la base entière : rien d'orphelin, de doublé, de resté ouvert, ajustements bornés, déloads espacés.
Mesures suivies : part de charges trop lourdes, charge proposée ÷ charge idéale (doit rester ≈ 0,8–1,1).
Mac : son, notifications, Live Activity, GPS et sauvegardes fichiers sont remplacés par des bouchons (`Tools/LogicTests/Stubs`).

**Simulateur alimentation** (`Life/NutritionLifeTests.swift`) : 12 à 16 semaines de repas avec le vrai plan, la vraie validation (`MealLogger`), le vrai rapprochement du stock (`StockReconciler`) et la vraie liste de courses ; habitudes : repas sautés, semaine libre, courses oubliées, double tap. Contrôle : stock jamais négatif ni infini, courses = besoins − stock puis vides après achat, repas validé deux fois compté une fois, plan sans dérive.

**Tests de performance** (`PerformanceTests`) : 2 ans d'historique synthétique (4 séances/semaine, 3 repas/jour) et un budget de temps par calcul lourd (≈ 2× le temps mesuré pendant `check.sh`). Un calcul en O(n²) échoue ici avant de geler l'iPhone.

Règle : un bug trouvé = d'abord un test (ou un contrôle de vie) qui échoue, puis le correctif.

## Schéma : le pipeline qualité
<svg viewBox="0 0 760 130" role="img" aria-label="Pipeline qualité" width="760">
<defs><marker id="a2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0L10 5L0 10z"/></marker></defs>
<g class="box"><rect x="4" y="40" width="130" height="50" rx="8"/><rect x="164" y="40" width="130" height="50" rx="8"/><rect x="324" y="40" width="130" height="50" rx="8"/><rect x="484" y="40" width="130" height="50" rx="8"/><rect x="644" y="40" width="112" height="50" rx="8"/></g>
<g class="arrow"><path d="M134 65H162" marker-end="url(#a2)"/><path d="M294 65H322" marker-end="url(#a2)"/><path d="M454 65H482" marker-end="url(#a2)"/><path d="M614 65H642" marker-end="url(#a2)"/></g>
<g text-anchor="middle"><text x="69" y="62">Commit</text><text x="69" y="80">hook check.sh</text><text x="229" y="62">Build + install</text><text x="229" y="80">chaque nuit</text><text x="389" y="62">Données iPhone</text><text x="389" y="80">data_check.sh</text><text x="549" y="62">report.md</text><text x="549" y="80">RAS / À CORRIGER</text><text x="700" y="62">Conversation</text><text x="700" y="80">suivante</text></g>
</svg>

## Journal de chasse (zone la plus ancienne = prochaine)
| Zone | Dernière chasse | Résultat |
|---|---|---|
| Séance : charges proposées | 2026-10-31 | faute de frappe ×10 reprise comme objectif → corrigé ; exo fait seulement en semaine de déload → 0 kg ensuite → corrigé. 31/10 (`check.sh deep`, chute de charge « sans raison » une fois sur 2 passes, seeds 3/7/8) : plateau « −1 kg » empilé sur une charge déjà baissée par des reps sous la fourchette (18 kg à 9/9/7 reps → 14 kg, −22 %) → corrigé (`Progression.shifted`) ; chutes de 47,5 → 37,5 et 42,5 → 32,5 = règle voulue (reps ≥ 2 sous le bas de la fourchette) → `LifeChecks` la connaît. Le « flake » du roadmap n'en était pas un : l'ordre des événements change d'un lancement à l'autre, seul `deep` (8 vies) l'attrape |
| Données réelles (sauvegarde iPhone) | 2026-10-29 | saines (69 séances) ; séries anciennes numérotées par exo (normal) |
| Hexis Elle (programme, cycle, IA, outils) | 2026-10-30 | simulateur de vie jamais lancé sur son programme → passe `ELLE` ajoutée : 6 déloads en 26 sem. au lieu de ~4 (plateau d'avant le déload rejugé 3 sem. après, dans les 2 apps) → corrigé (`AutoDeload.plateauSets`, plateau seul ≤ 2 sem. avant l'échéance) ; `ProgramCatalog.spec` figé au 1er fichier lu (tests) → rechargé quand le fichier change ; 2 appels Gemini simultanés au lancement (relances) → verrou + réutilisation ; mot « dur » dans la jauge et une phrase de secours → règle d'audit ; « RIR/RPE » affichés chez elle → `EffortScale.target/average`. Piste : sa vraie sauvegarde (`data_check.sh elle`) dès que son iPhone est appairé |
| Cycle, déload, plateaux | 2026-10-29 | déload en retard repoussée jusqu'à 4 semaines par une semaine de vacances → corrigé (plafond +1 semaine) ; vérifiés : passage d'année, semaine manquée/2 manquées, reprise après 3 semaines, semaine lancée, déjà planifiée. repli « Fatigué ×2 → déload » de `StagnationDetector` inatteignable (séances fatiguées filtrées par tous les appelants, la fatigue relève de `DeloadAdvisor`) → supprimé. Piste : plateaux par salle |
| Réhab | jamais | |
| Clôture / reprise d'une séance | 2026-10-29 | « Terminer » sans aucune série laissait une séance vide (comptée dans l'historique, la semaine, le cycle) → supprimée à la fin (test unitaire = filet). Piste : `reopen()` après clôture auto hors salle referme la séance au prochain retour d'app tant qu'aucune série n'est cochée |
| Salles et position | jamais | |
| Alimentation : plan, apport, courses | 2026-10-29 (« En plus ») | article reporté coché samedi disparaissait aussitôt (impossible de décocher) → corrigé ; repli sans IA : « 1,5 L de lait » coupé à la virgule et « de » gardé, doublons tapés insérés deux fois → corrigés (tests unitaires = filet). Piste : plan/apport/`PlanAutoAdjust` pas encore chassés. Avant : simulateur alimentation ajouté le 2026-10-29 (stock jamais négatif, courses = besoins − stock, double tap) ; boucle poids de `PlanAutoAdjust` non simulée (Santé) |
| Historique, Analyse, Bilan (perf) | jamais | |
| Écran Dépenses, médaille de record, stock par unité | 2026-10-31 | « 100 g de protéines » classait pâtes, flocons, pain et riz (8–13 g/100 g) comme sources de protéines les moins chères → seuil sur la part de calories venant des protéines (≥ 25 %), test `starchesAreNotProteinSources`. Médaille et `QuantityFormatter.stock` relus : RAS. Piste : `SpendingStats` calculé dans `body` sur tout l'historique des tickets (petit aujourd'hui) |
| Sauvegarde / restauration / migration | 2026-10-31 | les 30 `@Model` sont exportés, vidés et restaurés ; 145 champs vérifiés un par un : aucun oublié. Filet ajouté : règle d'audit « chaque propriété stockée d'un `@Model` figure dans la sauvegarde ». Piste : test aller-retour (export → restauration → export identique) sur une vie simulée |
| Programme (`Program.json`, `ProgramSync`) | 2026-10-29 | ajout de Full A / Upper A · 3 j relançait le cycle et effaçait les ajustements → corrigé (empreinte par séance) ; écart Accueil ↔ logique non reproduit → `HomeShown` + contrôle RealData |
| Navigation, pager, textes de l'UI | 2026-10-29 | `.task` sur `Group` vide : cartes poids, Corps et encouragement jamais chargées → corrigé + règle d'audit ; « En plus » effacé avant les courses → corrigé |
| Performance (budgets, MetricKit, lancement) | jamais | tests de perf ajoutés le 2026-10-29 |
| Sécurité (secrets, HTTPS, données perso) | jamais | |

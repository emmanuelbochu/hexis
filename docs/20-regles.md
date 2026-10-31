# Règles de calcul

Le code est la source de vérité : ce fichier donne les seuils et le « pourquoi ». Un tableau par moteur (règle · seuil · fichier). Colonne « test » : suite de `Tools/LogicTests` ; `vie` = vérifié par le [simulateur de vie](50-qualite.md) ; `—` = pas encore de test dédié.

## Cycle et déload — `TrainingCycle`, `DeloadAdvisor`, `AutoDeload`
| Règle | Seuil | Fichier | Test |
|---|---|---|---|
| Cycle | 6 semaines (réglable : `trainingWeeks` de `Program.json`, 5 par défaut ; le sien : 6, donc cycle de 7) : S1 RIR +1 (reprise ; `rampWeeks`/`rampRIR` : les siennes, 2 semaines à 3 reps en réserve), dernière semaine = déload (`deloadRIR` : 3 reps en réserve chez elle) | `TrainingCycle`, `SessionAdjuster` | CycleTests, ElleRulesTests |
| Semaine de déload | mêmes charges, moitié des séries (arrondi au-dessus), durées intactes | `TrainingCycle` | CycleTests |
| Relance du cycle | un déload, une semaine vide, un nouveau programme (`programStartedAt`) ; une séance déjà là dont les exos changent, jamais l'ajout de séances | `TrainingCycle`, `ProgramSync` | CycleTests, ProgramSyncTests |
| Semaine manquée | une est tolérée, deux de suite relancent | `TrainingCycle` | CycleTests |
| Déload dû | après `trainingWeeks` semaines d'entraînement (5 chez lui, 6 chez elle) | `DeloadAdvisor` | CycleTests, ElleRulesTests |
| Déload avancé | ≥ 2 plateaux jugés sur les séances **depuis le dernier déload** (un plateau qu'il n'a pas débloqué reste l'affaire de l'exo), au plus 2 semaines avant l'échéance (lui dès 3 sem., elle dès 4) ; RPE moyen 14 j ≥ 9 ou « Fatigué » sur 3 séances en 14 j : dès 3 semaines | `DeloadAdvisor`, `AutoDeload.plateauSets` | CycleTests, ElleRulesTests, LifeTests (Elle) |
| Placé aux vacances | semaine de vacances proche (≥ 4 jours), au plus 1 semaine après l'échéance | `AutoDeload` | CycleTests |
| Jamais | sur une semaine déjà commencée ; planifié deux fois | `AutoDeload` | CycleTests |

## Progression — `Progression`
| Règle | Seuil | Test |
|---|---|---|
| Double progression | haut de fourchette sur toutes les séries ⇒ ≈ +2,5 % arrondi au pas de la machine (min. 1 pas) ; reps visées = même e1RM (Epley) au nouveau poids | vie |
| Effort trop haut | RPE moyen > cible + 1 ⇒ charge gardée | vie |
| Effort très bas | RPE moyen ≤ cible − 2 ⇒ double augmentation | vie |
| Dans la fourchette | +1 rep si l'effort laissait de la marge | vie |
| Fourchette changée | à plus de 2 reps ⇒ poids recalculé par e1RM (borné à +20 %) | vie |
| Objectif | dernière séance de **cet exo dans cette salle** ; déloads, jours « Fatigué » et séance en cours ignorés | vie, ProgramContentTests (`aTiredDayIsNotTheNextGoal`) |
| Historique Hevy (Elle) | `HexisElle/HevyHistory.json` (fait par `Tools/hevy_import.py` depuis l'export Hevy) chargé **une fois** au lancement (`HistorySeed`) dans sa salle, séances A/B reconnues ; seuls les exos **identiques** à son programme (même machine, même mouvement) sont enregistrés sous le nom du programme, dans l'unité de l'app : poulies/haltères tels quels, **hip thrust (« barre » n'est que l'étiquette Hevy), Smith et presse ÷ 2** (Hevy : disques au total, l'app demande un côté) ; les autres (rowing poulie ≠ rowing machine à disques…) restent de l'historique sous leur nom, sans calibrer rien ; ces séances ont des UUID v5 (`HistorySeed.isImported`) et une heure unique : **elles servent aux poids seulement** (ni plateau, ni repos, ni ordre, ni temps de séance dès 2 séances à elle) ; les non-calibrés sont déduits par la médiane de Poids de départ | HistorySeedTests |
| Poids proposés (machine) | poids possibles d'une machine = ceux vraiment tapés dessus (`WeightGrid`) : machine régulière (écarts = multiples du cran) → grille complète ; irrégulière (39, 45, 50, 54 ; haltères 15, 16, 17,5) → **jamais de poids inventé entre deux poids réels**, puis le cran du programme au-delà ; deux poids très éloignés (série lourde isolée) ne sont pas un cran de la machine. Haltères d'Elle : cran 2 kg | WeightGridTests |
| Durée de séance (Accueil) | moyenne des 5 dernières séances de la séance ; semaines de déload écartées (moitié des séries) ; l'historique importé ne sert qu'avant 2 séances réelles | ImportedHistoryLearningTests |
| Mise à jour | ligne discrète en bas de l'Accueil : « Mise à jour il y a 3 h » (accent, 36 h) puis « Version du 31 oct. à 14:20 » (date de l'exécutable) | BuildInfoTests |
| Renommer un exo | `renamedFrom` = son nom actuel : même exo, même historique, le cycle ne repart pas (seul un autre exo le relance) | ProgramSyncTests |
| Messages « Ce que je remarque » (jour, moment, repos) | au moins 4 séances par groupe et un écart d’au moins 5 % ; en dessous, rien | InsightSampleTests |
| Comparaison « vs sem. préc. » (Bilan) | seulement une fois la semaine finie (lundi 00:00 suivant, dimanche compris) ; jamais sans données la semaine d'avant | ScreenSanityTests |
| Poids proposé en baisse (début de cycle, fourchette changée) | arrondi au pas le plus proche (pas vers le bas) ; recalé sur un poids réel de la machine : celui en dessous, sauf si celui du dessus dépasse de moins de 3 % ; aucun exo d'Elle proposé à plus de −10 % de son dernier poids | RampDropTests, HistorySeedTests |
| Palier : charge −5 % | calculée sur la série la plus lourde **sans faute de frappe** (35 / 35 / 350 → 35) ; `LifeChecks` signale toute chute de charge de plus de 15 % sans déload, reprise ni raison | TypoTests, simulateur de vie |
| Pots à acheter | arrondi au-dessus, sauf un dépassement < 2 % d’un pot (3,85 kg = 4 pots de 960 g) | PackToleranceTests |
| Poids de départ | exo jamais fait dans cette salle : `start` du programme (poids saisi, ex. hip thrust 55 = poids de la machine chez elle), mis à l'échelle par la médiane de (meilleur poids fait / `start`) sur les autres exos de la séance qui ont un historique, bornée ×0,5–×2,5, arrondi **vers le bas** au cran ; reps = bas de la fourchette ; sans `start` (le tien) : 0 comme avant. Les échauffements s'appuient dessus dès la 1re série | StartWeightTests |
| Poids réels | chaque proposition (et échauffement) tombe sur un poids qui existe sur **cette machine dans cette salle** : grille apprise des poids saisis (fautes ×10 exclues), pas = plus petit écart vu, crans entre et au-delà remplis ; en hausse le 1er poids ≥ cible, en baisse le 1er ≤, sinon le plus proche ; un écart > 2 × le pas du programme n'est pas cru (moins de 2 poids vus : rien ne change) | WeightGridTests, vie |
| Faute de frappe | > 1,45 × la médiane des 20 séries précédentes ⇒ ignorée des records/plateaux ; > 3× les autres de la séance ⇒ jamais reprise comme objectif | TypoTests |
| Série sans poids | l'exo n'est pas remis à 0 (la dernière avec poids sert d'objectif) ; exo fait seulement en déload garde ses charges | TypoTests, vie |

## Plateau et baisse — `StagnationDetector`, `SessionAdjuster`, `ExerciseTweak`
| Règle | Seuil | Test |
|---|---|---|
| Plateau | ≥ 3 séances sans meilleur e1RM (tolérance 1 %), historique ≥ 4 séances, exo vu < 42 j, par salle ; déloads et « Fatigué » exclus | vie |
| Échelle (une marche à la fois, 3 séances laissées) | effort ≤ 7,5 ⇒ +1 pas · muscle prioritaire bien récupéré ⇒ +1 série durable (jamais au-delà du max `volume` ; 2e exo de superset seulement s'il fait moins de séries que le 1er) · sinon charge ≈ −5 % | vie |
| Toujours bloqué | ≥ 6 séances ⇒ fourchette décalée 12 semaines (+2 si haut ≤ 8, +4 sinon, −4 si haut ≥ 15 ; bas ≥ 4, haut ≤ 30), puis retour au programme | vie |
| « Gêne » | rien n'est poussé, alimente la réhab | vie |
| Baisse | 2 séances à −7 % du meilleur récent **à effort au moins égal** (sans RPE saisi : jamais une baisse), ou « Fatigué » 2 fois sur 3 ⇒ la série ajoutée part, sinon −1 série (si ≥ 3 séries) | vie |
| Garde-fou volume | 11 séries max par muscle et par séance avant d'en ajouter | ProgramFileTests |
| Reprise après absence | 8 jours ⇒ charges −5 % ; 15 jours ⇒ −10 % | vie |

## Repos — `SessionAdjuster.restTarget`, `RestTimer`
| Règle | Seuil | Test |
|---|---|---|
| Repos appris (exo seul) | repos réellement pris (médiane des 3 dernières séances, écarts > 2× le prévu ignorés) ± 15 s selon les reps perdues (≥ 25 % ⇒ +15, ≤ 10 % ⇒ −15) | RestTests |
| Bornes | 60–90 s ; 90–150 s si ≤ 8 reps | RestTests |
| Superset | repos seulement après le dernier exo du bloc | WarmupTests |
| Unilatéral | 15 s entre les côtés | — |

## Échauffements — `WarmupCalculator`
| Règle | Seuil | Test |
|---|---|---|
| Rampe complète | 40 % × 8–10, 70 % × 4, 85–90 % × 1–2 : 1er exo de la séance seulement | WarmupTests |
| Sinon | 1 seule série à 60 % sur le 1er exo lourd seul (≤ 10 reps) de l'autre région (haut/bas) ; aucun autre exo ne s'échauffe | WarmupTests |
| Repos | 30/45/60 s | WarmupTests |
| Jamais | réhab, durées, poids du corps ; suit le poids de travail, sauté s'il est à 0 | WarmupTests |
| Écrites par le programme | `warmups` d'un exo de `Program.json` (`[[%, reps], …]`) : exactement celles-là ; dès qu'un programme en écrit, les autres exos n'en ont aucune ; aucun des deux programmes n'en écrit : le sien, comme le tien, a les échauffements automatiques | WarmupTests, ElleProgramTests |

## Réhab mollet — `Rehab`
| Règle | Seuil | Test |
|---|---|---|
| Début | comptée depuis la 1re série de réhab (tout exo du groupe « Réhab », même retiré du fichier : modifier le programme ne remet pas à zéro) | vie |
| Phases | 4 semaines chacune ; semaine propre avec ≥ 2 séances de réhab ⇒ +1 (une seule ⇒ rien) | vie |
| Recul | semaine avec « Gêne » sur un exo de réhab ou de mollets ⇒ −1 ; « Gêne » à la dernière séance ⇒ charge gardée | vie |
| Fin | après 12 semaines ⇒ blocs retirés des séances | vie |
| Charges `weekly` | montée 1 pas par semaine au plus | vie |

## Séance et planning — `TemplatePicker`, `WeekRotation`, `WeekPlan`, `SessionPlan`, `SessionCloser`
| Règle | Seuil | Test |
|---|---|---|
| Prochaine séance | la suivante dans l'ordre du programme, sans jours fixes ; une séance ratée revient | vie |
| Semaine à 3 séances | séances habituelles restantes > (jours restants + 1) / 2 ⇒ variante `shortWeek` pour le reste de la semaine ; une séance faite couvre celles qu'elle remplace ; une séance « 3 séances » faite garde la semaine courte ; volumes hebdo et cible de régularité comptés sur la semaine habituelle (4) | WeekRotationTests |
| Semaine courte sans variante | plus de séances que de jours ⇒ les plus en retard d'abord, le reste décalé et dit | — |
| Superset | tours = plus petit nombre de séries du bloc, le surplus se fait seul | vie |
| Fin automatique | dès que toutes les séries sont cochées ; « Reprendre » rouvre | vie |
| Séance oubliée | close à l'heure de la dernière série après 20 min hors de la salle (rayon + 100 m) ou 4 h sans série ; aucune série ⇒ supprimée | vie |
| Terminer sans série | aucune série cochée ⇒ la séance est supprimée (pas de séance vide) | TrainingTests |
| Salle | GPS (rayon 150 m) ; sinon CityB le samedi et en vacances, CityA sinon (`GymRule`) ; historique séparé par salle | — |
| Repos d'une séance finie | une séance terminée, abandonnée ou fermée seule arrête son repos (notification « Repos terminé », Live Activity) ; le minuteur d'un écran de séance disparu ne sonne plus ; à l'ouverture sans séance en cours, tout repos restant est annulé | RestTimerTests |
| Durée affichée | jamais estimée : moyenne réelle des 5 dernières séances du modèle (dès 2), sinon rien | `DurationStats` |

## Analyse — `Insights`, `BodyInsights`, `SpeedInsights`, `PositionInsights`, `TimeInsights`, `DurationStats`, `VolumeCheck`, `Regularity`
Toujours avec la taille d'échantillon, jamais de cause affirmée.
| Règle | Seuil |
|---|---|
| Pente de poids | 28 jours, moindres carrés, ≥ 4 pesées étalées sur ≥ 14 jours |
| Croisements (jour, créneau, repos, kcal, pas) | ≥ 2 groupes de ≥ 2 séances, écart ≥ 3 % ; pas : ≥ 6 séances avec pas |
| Rapidité | séances de 15 min à 3 h, ≥ 4 séances du modèle, ≥ 3 par créneau ; avertit si > 10 % plus lent que le meilleur |
| Temps de séance | ≥ 3 séances avec heures réelles ; pauses > 8 min |
| Durée apprise | moyenne des 5 dernières à 5 min près (≥ 2 séances) ; < 10 min ou > 3 h oubliées |
| Volume | séries directes par muscle contre `volume` ; hors cible seulement (rien en déload) |
| Régularité | séances contre le nombre de séances du programme |
| Affichage | au plus 4 lignes, le reste sous « Voir les autres » |

## Hexis Elle : rythme — `HabitStreak`
- Une semaine est tenue quand les séances atteignent l'objectif (2). Une semaine ratée devient un **joker** si aucun joker n'a servi dans les 3 semaines d'avant, sinon elle casse la série. Le joker n'ajoute rien à la série. La première semaine (commencée en cours) ne compte ni comme ratée ni comme joker ; la semaine en cours ne casse rien avant sa fin. Test : `HabitStreakTests`.

## Notifications — `NotificationHub`, `NotificationPolicy`, `PerfNotices`
- **Un seul chef d'orchestre** : `NotificationHub.refresh` (ouverture, retour dans l'app, fin de séance) demande à l'édition ce qu'elle veut dire, `NotificationPolicy` garde le peu qui vaut le coup, et le téléphone est aligné dessus (ce qui n'est plus voulu part, ce qui change est remplacé, les anciens identifiants sont nettoyés). Les minuteurs (repos, batch) et la liste du vendredi restent fonctionnels, hors plafond.
- **Plafonds** : 3 par semaine, 1 par jour, 20 h d'écart minimum, seulement de 9 h à 20 h 59 ; en cas de concurrence, le plus utile gagne (bilan > semaine ouverte > absence). Les faits ne bougent que quand l'app s'ouvre (séance, repas), donc un texte planifié n'est jamais périmé.
- **Chez toi** (`PerfNotices`) : des chiffres, pas d'encouragement. Le dimanche 18 h 30, seulement s'il y a eu une séance : « 3/4 séances · 2 records (Squat 120 kg) », le volume seulement sur une semaine complète et si l'écart est ≥ 8 %, et « Semaine allégée demain » quand elle est due ; plus l'absence (J+5…) et la semaine ouverte du jeudi en chiffres. Texte local, aucun appel IA.
- **Chez elle** : voir ci-dessous. Leviers psychologiques (intention précise, geste minuscule, libre choix, nouveau départ), jamais de culpabilité ; si le créneau tombe sur son jour d'entraînement habituel (≥ 3 séances, ≥ 2 le même jour), le fait est donné à l'IA.
- **Batch** : « Annuler le batch cooking » arrête tous les minuteurs et efface leurs notifications ; au lancement, toute notification de batch sans minuteur vivant est supprimée.

## Hexis Elle : relances — `NudgePlan`, `NudgeService`
- Seulement quand c'est utile : absence à J+5, 8, 12, 17, 23, 30, 37, 44 après la dernière séance (jamais de séance : J+2, 5, 9, 14…), mais rien sur une semaine dont l'objectif est atteint ni le lendemain d'une séance ; semaine ouverte : un rappel le jeudi. Une relance par jour au plus, 8 d'avance au plus, à l'heure habituelle de ses séances moins 2 h (9 h–19 h, 17 h sans historique).
- Mots : toujours l'IA (drôle, complice, un registre différent par message, jamais un mot sur le corps/poids), jamais de texte en conserve : une ligne trop proche d'une déjà envoyée est abandonnée. Un créneau déjà planifié (même moment, mêmes faits) garde sa phrase : seuls les nouveaux vont à l'IA (une requête, 15 phrases récentes montrées pour ne pas répéter) ; IA injoignable : les phrases encore justes restent, les périmées partent, on réessaie à l'ouverture suivante. (NudgeTests)

## IA Gemini — `GeminiClient`, `ProgressDiagnosis`
| Règle | Seuil |
|---|---|
| Modèle | un seul (`GeminiClient.model`), sortie JSON, clé dans `Secrets.plist` |
| Lecture d'un exo | auto en fin de séance pour un plateau ou une baisse de 5 % ; 3 exos max ; ni réhab ni cardio ; cache par exo/salle/nombre de séances ; **explique, ne change rien** |
| Surcharge | réponse 429/500/502/503/504 ⇒ jusqu'à 2 nouveaux essais (après 2 s puis 6 s) ; un délai dépassé n'est pas rejoué ; le scan de ticket retombe ensuite sur le texte lu par l'iPhone |
| Encouragement (`Cheer`) | 1 ligne ≤ 14 mots/140 caractères, jamais la même : cache par fait (`AIInsight` `cheer`), refus si ≥ 70 % de mots communs avec une ancienne ; 2 essais max (registre différent), aucun si l'IA est injoignable ; puis `CheerPool` (phrases à la main, une fois chacune), puis rien. Température 1, 80 tokens max, 8 s, pas de nouvel essai en cas de surcharge |
| Quand | fin de séance : toujours (n° 10/25/50…, record, semaine tenue, reprise ≥ 7 j, volume ≥ +5 %, sinon séance x/y) ; Accueil : 1/jour au plus (reprise ≥ 6 j, série ≥ 2 sem. en danger dès jeudi, palier de force +5 %) |
| Tes 12 dernières semaines (`Journey`) | masqué avant 4 semaines et 8 séances ; seules les séries des 84 derniers jours comptent ; force = moyenne sur ≥ 2 exos, chacun depuis son dernier changement de réglage (rapport d'e1RM entre 2 séances hors 0,75–1,4) avec ≥ 4 séances (meilleur e1RM des k premières vs k dernières, k = min(3, n/2)) ; poids = ≥ 2 pesées à chaque bout des 28 derniers jours, ≥ 14 j d'écart ; séances de la semaine / objectif |

## Alimentation
| Moteur | Règle | Seuil | Fichier | Test |
|---|---|---|---|---|
| Repas du moment | jour + heure ; créneaux passés non validés supposés mangés | Petit-déj < 10 h, Déjeuner, Collation, Dîner, Après dîner | `NextMealPicker` | NextMealPickerTests |
| Apport du jour | saisies + repas prévus des créneaux passés sans saisie ; jours suivis = ≥ 3 créneaux saisis ; moyenne ≥ 5 jours | | `DailyIntake` | DailyIntakeTests |
| Phase | prise de masse +0,10 à +0,20 kg/sem. ; protéines 1,6–2,2 g/kg | | `NutritionGoals` | PhaseCheckTests |
| Verdict de balance | pente Santé 28 j (≥ 4 pesées sur 14 j) ; maintenance = apport − pente × 7 700 / 7 ; ±400 kcal max | | `PhaseCheck` | PhaseCheckTests |
| Plan qui suit la balance | samedi/dimanche ; ≥ 6 pesées depuis le dernier changement, ≥ 5 jours saisis ; riz/pâtes/avoine (glucides ≥ 45 g/100 g, ≥ 300 kcal) × facteur ; ±150 kcal/j par étape, tous les 14 j au plus, ±400 au total, plancher 70 % | | `PlanAutoAdjust`, `BatchScaling` | PlanAutoAdjustTests |
| Cycle de courses | lundi → dimanche, bascule le **vendredi 18 h** (liste + notification), batch le dimanche | | `PlanCycle` | ShoppingHabitsTests |
| Liste de courses | besoins des repas pas encore mangés − stock ; case décochée quand le stock couvre ; repas des jours passés exclus | | `ShoppingList` | ShoppingHabitsTests |
| Paquets | plus petite quantité achetée dont les autres sont des multiples (« 3 × 500 g ») | | `UsualPack` | ShoppingHabitsTests |
| Marge week-end | +20 % poulet, pâtes, riz, sauce (repas sam/dim, jamais les steaks) | | `GuestMargin` | ShoppingHabitsTests |
| Semaine de vacances | cycle à ≥ 4 jours de vacances : la liste est affichée quand même (indicative, « suivi en pause »), sans notification du vendredi ; le stock et le plan ne bougent pas | | `FreePeriod.isHolidayCycle`, `ShoppingView` | FreePeriodTests |
| À emmener à l'appart | repas du dimanche « Après dîner » au vendredi « Collation » ; sans les aliments dont le 1er mot nomme une étape du batch (« Steak haché » ↔ « Steaks ») ni l'huile (reste à l'appart) ; pain en bouts (un par repas) ; tout le dimanche ; rien avant une semaine de vacances | | `CarryList` | CarryListTests |
| Pain | acheté en miches entières (paquet 750 g, 2,60 € réglés une fois), la liste dit seulement « N miche(s) » ; hors budget Supermarket | | `ShoppingLine.buyText` | NutritionTests |
| « D'habitude aussi » | lignes hors plan achetées ≥ 3 jours différents, rappelées à leur rythme | | `UsualExtras` | ShoppingHabitsTests |
| Semaines libres | repas prévu d'un jour passé sans saisie ⇒ supposé mangé et retiré du stock ; frais plafonnés à ≈ 1,5 semaine ; période libre (vacances school, ou ≥ 3 jours avec ≤ 1 créneau saisi) : stock figé, plan figé pendant et 7 jours après | | `StockReconciler`, `FreePeriod` | StockReconcilerTests, FreePeriodTests |
| Ticket | photo → Gemini ; repli sur le texte lu par l'iPhone ; lignes suspectes décochées (prix au kilo hors 0,4×–2,5×) | | `ReceiptGuard`, `ReceiptParser` | — |
| Ticket relu | ≥ 60 % de lignes au même prix et quantité dans un scan des 30 derniers jours | | `ReceiptGuard.earlierScan` | — |
| Correction mémorisée | une ligne déplacée vers un autre aliment, ou envoyée « Pas dans le plan », est mémorisée (`ReceiptAlias`, cible spéciale `ReceiptResolver.offPlan`) ; elle s'applique avant la réponse de l'IA et est donnée en exemple | | `ReceiptAlias`, `ReceiptResolver` | ReceiptResolverTests |
| Détail de quantité | l'IA renvoie aussi le nombre d'unités de la ligne (`n`) : la revue montre « 3 × 650 g » ; deux lignes du même aliment additionnent leurs nombres, un nombre inconnu montre le total ; retaper le nombre de paquets garde la taille d'un paquet | | `ReceiptMatch.quantityText` | ReceiptQuantityTests |
| Quantité non imprimée | l'IA reçoit le paquet habituel de chaque aliment (`pN`, réglé dans le Placard) et calcule quantité × N ; la quantité d'une ligne se retape dans la revue | | `ReceiptResolver.prompt` | ReceiptResolverTests |
| Total du ticket | l'IA renvoie le total payé (`T`) ; l'écart avec les lignes (≥ 0,50 €) devient une ligne hors plan « Autres lignes du ticket » (ou « Remises du ticket », négative) : les dépenses = le total payé, TVA et remises comprises | | `ReceiptResolver.resolve` | ReceiptTotalTests, ProductMemoryTests |
| Acheté = fait | un aliment qu'un ticket scanné depuis le vendredi 18 h précédant le cycle (jusqu'à sa fin) a apporté n'est plus proposé (même si le plan en veut plus) ; il passe dans « Déjà à la maison », non cochable | | `ShoppingList.cycleLines` | BoughtShoppingTests |
| Historique des tickets | écran « Voir les tickets » (carte Dépensé) : tickets reconstitués des lignes ajoutées à moins de 10 min d'écart, ligne retapée (quantité, prix) ou supprimée ; le stock suit la différence | | `ReceiptHistory` | ReceiptHistoryTests |
| Mémoire des produits | chaque ticket validé apprend ligne imprimée → aliment, poids et prix (TTC) d'une unité (`ProductMemory`) ; donnés à l'IA, et un poids deviné à plus de 15 % de n × poids connu est corrigé ; le paquet d'un aliment se recale sur grammes ÷ nombre | | `ProductMemoryBook` | ProductMemoryTests |
| Paquet réglé à la main | changer le poids d'un pot dans le Placard le verrouille (ligne `ProductMemory` à libellé vide) : les tickets ne le changent plus | | `ProductMemoryBook.lockPack` | ProductMemoryTests |
| Ticket validé | les articles cochés en magasin mais absents du ticket sont payés aussi : ils rejoignent le stock (donc « Déjà à la maison ») ; les « En plus » cochés sont supprimés ; les cases sont remises à zéro | | `ShoppingList.settleChecked` | SettleShoppingTests |
| Déjà à la maison (manuel) | appui long sur un article → « Déjà à la maison » : le stock passe à ce qui couvre le besoin | | `ShoppingList.coveredStock` | SettleShoppingTests |
| Ticket supprimé | « Supprimer le ticket » : le stock des lignes revient comme avant, les lignes et dépenses disparaissent | | `ReceiptHistory.remove` | ReceiptHistoryTests |
| Boîtes de thon | le thon se compte en boîtes (113 g égouttées) et s'achète par 3 (paquet 339 g, une ligne = « 1 × 3 boîtes ») ; l'IA compte toujours unités × poids égoutté, jamais le poids brut imprimé | | `ReceiptResolver.prompt`, `NutritionDefaults.fixTunaPack` | FlatStockTests |
| Appart : aliments gardés là-bas | huile, flocons d'avoine, thon (`FlatStockBook.staples`) : portés la 1re fois puis seulement ce qui manque à l'appart pour la semaine (boîtes entières) ; manger à l'appart (lun.–ven.) vide sa part avant tout, manger à la maison non ; le dimanche 21 h la liste est comptée comme emportée (aucune case) ; la part de l'appart ne dépasse jamais le stock total ; les courses restent calculées sur le stock total | | `FlatStockBook`, `CarryList.lines(flat:)` | FlatStockTests, CarryListTests |
| Record en séance | médaille dorée à côté de l'exo et de la série qui bat un record : poids supérieur à tout l'historique de l'exo, ou plus de reps qu'avec ce poids ou plus lourd ; jamais la 1re fois ; seule la série qui atteint un nouveau meilleur la reçoit ; haptique + son discret (les 2 apps ; le repos plus court n'est pas un record) | | `LiveRecord` | LiveRecordTests |
| Statistiques de dépenses | écran « Dépenses » (carte Dépensé) : total de la semaine et écart à la semaine type, 8 semaines en barres, semaine type et par jour (semaines passées avec ticket), répartition par catégorie sur 28 jours, 3 sources de protéines les moins chères (prix du Placard ÷ protéines, ≥ 8 g/100 g), jusqu'à 3 aliments dont le prix au kilo a bougé de ≥ 10 % (≥ 3 achats, 180 jours) ; que des tickets réels | | `SpendingStats` | SpendingStatsTests |
| Quantité du stock | `QuantityFormatter.stock` : boîtes/pièces pour ce qui se compte en pièces ; « n × poids » quand le stock vaut un nombre entier de paquets (à 8 % près) ; sinon le poids | | `QuantityFormatter.stock` | StockTextTests |
| Équivalent | sardines ↔ maquereau (`FoodSubstitutes`) : la liste dit « Sardines à l'huile ou maquereau », l'IA du ticket compte un maquereau comme des sardines | | `FoodSubstitutes` | SubstituteTests |
| Minuteurs du batch | un par étape, plusieurs à la fois ; date de fin gardée (survivent à la fermeture de l'app), une notification chacun, Dynamic Island = le plus proche ; son à la fin même en mode silencieux quand l'app est ouverte | | `BatchTimers` | BatchTimersTests |
| Ligne retapée | revue et historique : nombre d'unités, poids d'une unité (ou pièces par boîte pour les œufs), prix ; ce que l'IA avait lu reste affiché barré à côté de ce qui est compté | | `ReceiptMatch.set`, `ReceiptReviewLine.isChanged` | ReceiptEditTests |
| Ligne hors plan expliquée | l'utilisateur dit ce que c'est avec ses mots ; l'IA donne un nom et une catégorie ; mémorisé par ligne imprimée (`OffPlanProduct`, V15) et appliqué aux prochains tickets | | `ExtraTidy`, `OffPlanBook` | ReceiptEditTests |
| Prix inhabituel | seulement face à ≥ 2 achats réellement payés du même aliment (jamais face à un prix saisi ou deviné) | | `ReceiptGuard.warning` | ReceiptEditTests |
| Relances d'Elle | une ligne avec « savoure », « fierté », « ton effort », « pour toi », « bravo » est refusée (aucun effort à saluer quand elle n'est pas venue) ; ton SMS d'amie | | `NudgeService.banned` | NudgeTests |
| Prix de référence | prix réel au kilo des achats des 120 derniers jours (8 max, pondérés) | | `Spending` | — |
| Dépenses | semaine (plan / hors plan) contre la moyenne des 4 semaines d'avant | | `Spending` | — |

## Données
- Relations par UUID. Historique séparé par salle : toute « dernière perf » filtre sur `gymID`.
- Exos rapprochés **par nom** (insensible à la casse) entre `Program.json` et l'historique : garder les noms pour garder l'historique.
- `Program.json` porte : `cue`, `unit` (`s`/`min`), `weekly`, `loadFactor`, `priorities`, `volume`, `rehab` (phases × emplacement nommé par le bloc, ici `mollet` : mêmes exos en début de Lower A/B et avant le vélo d'Upper B), `target` (muscles précis de la fiche), `points` (« Pourquoi : », « Réglage : », « Mouvement : », variante « À CityB : »), `renamedFrom` (renomme l'exo stocké : historique et charges gardés), `shortWeek` + `replaces` (variante 3 séances). Lu par `ProgramCatalog` et `ProgramSync`.
- Sens du poids (`ExerciseLoad`, `LoadProfile.guess`) : par côté + barre, stack, par haltère, total ; « machine », Smith et « disques » = par côté sans barre, abduction/oiseau = stack, marteau = haltères, nuque/ab wheel/vélo = total ; sert au volume réel, jamais aux records/e1RM.
- Schémas et sauvegarde : voir [Architecture](30-architecture.md).

- Décalage de charge du plateau (−X kg) : jamais empilé sur une charge déjà baissée par des reps sous la fourchette (`Progression.shifted`).
- « 100 g de protéines » (Dépenses) : seulement les aliments dont les protéines font ≥ 25 % des calories (pas les féculents).

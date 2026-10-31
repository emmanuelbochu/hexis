---
name: chasse
description: Chasse aux bugs de Hexis — lance les contrôles profonds (simulateur de vie, vraies données de l'iPhone), choisit la zone la moins récemment chassée, cherche des cas concrets de la vie réelle qui cassent la logique ou l'usage, écrit le test qui échoue, corrige, commite. À lancer quand l'utilisateur dit « chasse », « cherche des bugs », « vérifie l'app », ou en boucle (/loop /chasse).
---

# Chasse aux bugs

But : zéro bug, logique cohérente, aucune friction d'usage. Une passe = une zone, à fond. Ne rien demander à l'utilisateur.

1. **État** : `zsh Tools/check.sh deep` (audit, tests des deux apps — passe « Hexis » puis passe « Hexis Elle » compilée avec
   `ELLE` —, 8 vies simulées par scénario, vraies données de chaque iPhone, build des deux cibles).
   Tout échec passe avant le reste : cause racine, test qui le reproduit, correctif.
2. **Zone** : `git log --since=<date de la dernière chasse du journal> --stat --oneline | head -60` : la zone dont les
   fichiers ont le plus changé depuis sa dernière chasse passe en premier (les bugs viennent du code récent) ; sinon la zone
   du journal à la date la plus ancienne. Relire aussi le diff « ce que l'utilisateur verra » de `check.sh` : chaque ligne
   changée doit s'expliquer par un commit voulu.
3. **Cas concrets** : écrire mentalement 8-10 situations réelles de cette zone, surtout les bords :
   machine prise, ordre changé, série cochée par erreur puis décochée, série sans poids ou sans RPE, faute de frappe,
   séance oubliée ouverte, minuit ou changement d'heure pendant la séance, deux salles, vacances, maladie, reprise après 3 semaines,
   déload pendant la réhab, programme modifié en cours de cycle, appli tuée puis rouverte, base vide, sauvegarde restaurée,
   repas sauté, semaine de 2 séances… **Hexis Elle** est une zone à part entière (son programme A/B, cycle de 6 semaines,
   rampe à RIR 3, effort « reps en plus », rythme + joker, relances IA, une salle par GPS, pas d'alimentation ni de Santé) :
   cas « elle » dans `LifeTests` (`#if ELLE`), `ElleProgramTests`, `HEXIS_EDITION=elle zsh Tools/logic_tests.sh`. Pour chacune : chemin du code (grep + lecture partielle),
   comportement attendu selon `docs/20-regles.md` et `CLAUDE.md` (UX : un bouton évident, l'app dit ce qu'elle fait, jamais « dur »).
4. **Prouver puis corriger** : logique pure ou séance → un test qui échoue d'abord (`Tools/LogicTests` : test unitaire, ou
   nouvelle habitude `Habits`/scénario `LifeTests`/contrôle `LifeChecks` pour un comportement de vie). Vue → raisonnement
   statique sur le code + correctif minimal. Perf : fetch sans borne, calcul dans `body`, travail sur le main thread.
   Un doute sur la règle métier elle-même → la noter dans `ROADMAP.md` (Questions ouvertes), ne pas trancher seul.
5. **Auto-amélioration** : pour chaque bug, ajouter le filet qui l'aurait trouvé seul (règle d'audit pour un piège de code,
   `LifeChecks` pour un comportement de vie, contrôle `RealDataTests` pour un écart sur les vraies données), noté au journal.
6. **Commit** : `zsh Tools/check.sh` vert, un `fix:` par bug (le hook Git refuse un commit cassé), ligne ajoutée au journal
   de `docs/50-qualite.md` (date, zone, trouvé/corrigé, piste suivante), `docs/20-regles.md` si une règle change.
7. **Fin** : 2-3 lignes (bugs corrigés, quoi tester sur l'iPhone). Zone sans bug : le dire et noter ce qui a été vérifié.
8. **Lancée seule** (`claude -p`, par `Tools/auto_chasse.sh`, dans un worktree sur la branche `chasse/<date>`) : ne rien demander,
   ne jamais pousser ni toucher à `main`, rester sur la branche ; la conversation suivante relit le diff et fusionne.
   Zones « Performance » (tests de perf, `Tools/.data/diagnostics`, section Performance du rapport) et « Sécurité »
   (`docs/50-qualite.md`, journal) : mêmes règles, test d'abord.

# Décisions et pièges

## Ne pas construire (et pourquoi)
| Idée | Pourquoi non |
|---|---|
| Édition du programme ou du plan dans l'app, « ajouter une série/exo » en séance, import/collage/exemple, jours fixes | Le plan est suivi tel quel. On change de programme en éditant `Program.json`, rechargé au lancement. Une série non faite reste décochée. |
| Ressenti facile/bien/dur | Le RPE dit déjà l'effort. Jamais le mot « dur » ; seuls « Fatigué » et « Gêne ». |
| Geste global (double tap, drag) | Conflit avec les boutons ; le pager natif règle le swipe. Exception voulue : glissé sur la rangée du haut (Muscu/Alimentation). |
| Calculateur de disques | On saisit le poids par côté directement (`ExerciseLoad` gère le sens). |
| Saisie ou scan d'aliments | Un plan à suivre, un tap valide. Seul scan prévu : le ticket de courses. (Minuteur dans les étapes du batch : fait.) |
| Données de test | L'historique réel vient de Hevy (import retiré, l'historique vit dans la base et les sauvegardes). |
| Un `NavigationStack` ou `.toolbar` par écran racine | Crash UIKit au swipe. |
| Textes de coach IA, rappels de plateau dans la carte d'exo, carte « durée moyenne » | Rien d'affiché qui ne change une décision. |
| Export manuel | L'envoi hors téléphone passe par le rappel hebdo. |
| Fonction « au cas où » | Moins d'écrans = moins de bugs et de code à recompiler chaque semaine. |

## Pièges connus
| Piège | Règle |
|---|---|
| `Date.now` ou valeur changeante dans un `@Query`/`#Predicate` construit dans un `init` de vue | Boucle et gel. Chargement unique par `ModelContext` dans `.task`. |
| Calcul sur tout l'historique dans `body` | Interdit. Calculer une fois, hors `body`. |
| Recherche dans un tableau | Utiliser `Set`/`Dictionary`. |
| Fonction qui lit l'heure | Prend un `now:` (le simulateur voyage dans le temps). |
| `safeAreaInset` autour du pager | Boucle de mise en page qui a gelé l'app. |
| `.confirmationDialog` dans le pager | Popover mal placé : utiliser `.alert`. |
| Modifier une propriété d'un `@Model` livré | Crash au lancement : nouveau modèle lié par UUID + nouvelle `VersionedSchema`. |
| Secrets (`Secrets.plist`) | Jamais dans Git, jamais affichés ni commités. |
| Second exo seul d'un superset | Le mettre en premier dans `Program.json`. |

## Sécurité et données personnelles
| Sujet | État |
|---|---|
| Clé Gemini | seulement dans `Secrets.plist` (ignoré par Git), envoyée en en-tête HTTPS à Google, jamais journalisée ; le scan de secrets bloque tout commit qui en contiendrait une |
| Réseau | HTTPS seulement, aucune exception ATS ; sauvegardes JSON seulement dans le conteneur de l'app (visibles dans Fichiers) |
| Données perso dans le code | adresses et GPS des 2 salles (`GymDefaults`), règle de salle et calendrier de cours (`GymRule`, `SchoolHolidays`), plan alimentaire et prix (`NutritionDefaults`), Team ID Apple (`project.pbxproj`) : acceptables en privé |
| Dépôt public | jamais l'historique : un instantané propre par `Tools/publish.sh` (données remplacées par des exemples) |

## Questions ouvertes
Voir `ROADMAP.md`.

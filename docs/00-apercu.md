# Hexis en 2 minutes

App iOS **perso** de musculation + alimentation. SwiftUI + SwiftData, 100 % local, un seul utilisateur ; une seconde app « Hexis Elle » sort du même code (voir `30-architecture.md`). UI en français ; code, commentaires et commits en anglais.

## Principes
| Principe | Ce que ça veut dire |
|---|---|
| Automatisée | L'app décide (charges, séries, repos, déload, courses) et **dit ce qu'elle fait**. Rien à valider. |
| Un bouton évident | Chaque écran a une seule action principale. |
| Lecture / utilisation pure | Aucune config, aucun import, aucune édition dans l'app. Le programme se change dans `Resources/Program.json`. |
| Peu de texte | On affiche peu, on calcule beaucoup en arrière-plan. Rien d'affiché qui ne soit comparé à une cible ou ne change une décision. |
| Local seulement | Compte Apple gratuit : pas de CloudKit, push, App Groups, Watch ni widgets d'accueil (seule exception : la Live Activity de repos). |

## Les 6 écrans
| Mode | Écrans |
|---|---|
| Muscu | Accueil · Programme · Historique |
| Alimentation | Aujourd'hui · Plan · Courses |

Un glissé horizontal sur la rangée du haut bascule Muscu/Alimentation. La barre du bas flotte sur le pager. Voir [Fonctions](10-fonctions.md).

## Où est quoi
| Je cherche… | Fichier |
|---|---|
| Ce que fait chaque écran | [Fonctions](10-fonctions.md) |
| Les seuils et règles de calcul | [Règles](20-regles.md) |
| Dossiers, flux d'une séance, données | [Architecture](30-architecture.md) |
| Comment compiler, installer, contrôler | [Outils](40-outils.md) |
| Tests, simulateur de vie, journal de chasse | [Qualité](50-qualite.md) |
| Ce qu'on ne construit pas, pièges connus | [Décisions](60-decisions.md) |
| Un mot que je ne connais pas (RPE, e1RM…) | [Glossaire](90-glossaire.md) |

## Chiffres clés (générés depuis le code)
<!-- auto:chiffres -->

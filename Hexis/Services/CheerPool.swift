import Foundation

/// Lines written by hand, used when the AI is out of reach (offline, no key, busy). Each is used once, like the others.
enum CheerPool {
    private static let lines: [CheerFact.Moment: [String]] = [
        .milestone: [
            "{n} séances : ce n'est plus de la motivation, c'est une habitude.",
            "Séance n°{n}. Le genre de chiffre qu'on ne fait qu'en revenant.",
            "{n} séances au compteur. Voilà d'où vient la progression.",
        ],
        .record: [
            "{name} à {weight} kg, ça n'était jamais arrivé.",
            "Record sur {name} : {weight} kg. Le travail paye.",
            "Avant, c'était {previous} kg sur {name}. Plus maintenant.",
            "{weight} kg au {name}, nouvelle référence.",
        ],
        .weekDone: [
            "Objectif de la semaine rempli : {target}/{target}. Le reste est du bonus.",
            "{target} séances sur {target}. Semaine bouclée.",
            "Semaine tenue. Les résultats se construisent comme ça.",
        ],
        .comeback: [
            "Revenir est la partie la plus difficile. C'est fait.",
            "{days} jours d'écart, et tu es de retour. Ça compte plus que tout.",
            "Reprise réussie : le plus difficile est derrière toi.",
        ],
        .volumeUp: [
            "+{pct} % de volume sur la dernière fois : ça monte.",
            "Plus de travail qu'à la dernière séance, de {pct} %. Continue.",
            "{pct} % de volume en plus : le corps reçoit le message.",
        ],
        .regular: [
            "Une séance de plus dans la poche : {done}/{target} cette semaine.",
            "Séance faite. La régularité fait le travail.",
            "{done} sur {target} cette semaine. On avance.",
            "Encore une de validée. Ça s'additionne.",
        ],
        .streakAtRisk: [
            "{streak} semaines d'affilée : une séance de plus et elle continue.",
            "Ta série de {streak} semaines se joue cette semaine.",
            "{done}/{target} cette semaine. La série de {streak} semaines t'attend.",
        ],
        .progress: [
            "Force en hausse de {pct} % en {weeks} semaines. Ça se voit sur la barre.",
            "+{pct} % de force depuis {weeks} semaines : l'app sert, tu progresses.",
            "{weeks} semaines, +{pct} % de force. Beau chemin.",
        ],
    ]

    /// The first hand-written line of the moment not used yet, with the figures filled in; nil when all were used.
    static func line(for fact: CheerFact, used: [String]) -> String? {
        for template in lines[fact.moment] ?? [] {
            var text = template
            for (name, value) in fact.values { text = text.replacingOccurrences(of: "{\(name)}", with: value) }
            guard !text.contains("{"), !Cheer.isTooClose(text, used: used) else { continue }
            return text
        }
        return nil
    }
}

import Foundation

/// Backup of the UserDefaults preferences that shape decisions (cycle start, program hash, goals, look).
extension BackupDocument {
    /// What lives in UserDefaults and shapes the decisions (cycle start, program hashes, goals, look): without it a restored
    /// phone would restart the training cycle and re-run the one-time rules.
    struct PreferencesDTO: Codable {
        var programStartedAt: Date?
        var programFileHash: String?
        var programStructureHash: String?
        /// Exercises digest per session name: only a lived session that changes restarts the cycle.
        var programSessionsHash: [String: String]?
        /// What Home last proposed (`HomeShown`), compared with the logic on the real data.
        var homeShown: HomeShown.Record?
        var stockReconciledOn: Date?
        var planKcalDelta: Int?
        var planAdjustedOn: Date?
        var planAdjustNote: String?
        var planStarchScale: Double?
        var appearance: String?
        /// Uses of the secondary screens (`UsageCounter`), by feature name.
        var usage: [String: UsageCounter.Entry]?
        /// Non-fatal anomalies (`Diagnostics`), newest last.
        var diagnostics: [Diagnostics.Entry]?
    }
}

nonisolated enum BackupPreferences {
    // Literal keys (the owners are main-actor types; this runs off the main thread too).
    private static let startKey = "programStartedAt"
    private static let planDeltaKey = "planKcalDelta"
    private static let planDateKey = "planAdjustedOn"
    private static let planNoteKey = "planAdjustNote"
    private static let planScaleKey = "planStarchScale"
    private static let appearanceKey = "appearance"
    private static let programHashKey = "programFileHash"
    private static let structureHashKey = "programStructureHash"
    private static let reconciledKey = "stockReconciledOn"
    private static let sessionsHashKey = "programSessionsHash"

    static func read(_ defaults: UserDefaults = .standard) -> BackupDocument.PreferencesDTO {
        .init(
            programStartedAt: defaults.object(forKey: startKey) as? Date,
            programFileHash: defaults.string(forKey: programHashKey),
            programStructureHash: defaults.string(forKey: structureHashKey),
            programSessionsHash: defaults.dictionary(forKey: sessionsHashKey) as? [String: String],
            homeShown: HomeShown.last(defaults: defaults),
            stockReconciledOn: defaults.object(forKey: reconciledKey) as? Date,
            planKcalDelta: defaults.object(forKey: planDeltaKey) as? Int,
            planAdjustedOn: defaults.object(forKey: planDateKey) as? Date,
            planAdjustNote: defaults.string(forKey: planNoteKey),
            planStarchScale: defaults.object(forKey: planScaleKey) as? Double,
            appearance: defaults.string(forKey: appearanceKey),
            usage: Dictionary(uniqueKeysWithValues: UsageCounter.entries(defaults: defaults).map { ($0.key.rawValue, $0.value) }),
            diagnostics: Diagnostics.entries(defaults: defaults)
        )
    }

    static func apply(_ prefs: BackupDocument.PreferencesDTO, to defaults: UserDefaults = .standard) {
        func set(_ value: Any?, _ key: String) { if let value { defaults.set(value, forKey: key) } }
        set(prefs.programStartedAt, startKey)
        set(prefs.programFileHash, programHashKey)
        set(prefs.programStructureHash, structureHashKey)
        set(prefs.programSessionsHash, sessionsHashKey)
        if let shown = prefs.homeShown { HomeShown.save(shown, defaults: defaults) }
        set(prefs.stockReconciledOn, reconciledKey)
        set(prefs.planKcalDelta, planDeltaKey)
        set(prefs.planAdjustedOn, planDateKey)
        set(prefs.planAdjustNote, planNoteKey)
        set(prefs.planStarchScale, planScaleKey)
        set(prefs.appearance, appearanceKey)
        if let usage = prefs.usage { UsageCounter.merge(usage, defaults: defaults) }
        if let diagnostics = prefs.diagnostics { Diagnostics.merge(diagnostics, defaults: defaults) }
    }
}

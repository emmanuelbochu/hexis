import Foundation
import SwiftData

/// Legacy (V1): no screen edits these any more, the app uses constants. Kept for the migration and old backups.
@Model
final class AppSettings {
    var useKilograms: Bool
    var unilateralRestSeconds: Int
    /// Warmup set weights as fractions of the work weight.
    var warmupPercents: [Double]

    init(useKilograms: Bool = true, unilateralRestSeconds: Int = 15, warmupPercents: [Double] = WarmupCalculator.defaultPercents) {
        self.useKilograms = useKilograms
        self.unilateralRestSeconds = unilateralRestSeconds
        self.warmupPercents = warmupPercents
    }
}

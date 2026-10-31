import Foundation
import HealthKit

/// Read-only access to Apple Health (Withings weight and steps arrive there through the Withings app).
enum HealthService {
    struct Day: Equatable {
        let date: Date
        let value: Double
    }

    private static let store = HKHealthStore()
    private static let weightType = HKQuantityType(.bodyMass)
    private static let stepsType = HKQuantityType(.stepCount)

    static var isAvailable: Bool { Edition.usesHealth && HKHealthStore.isHealthDataAvailable() }

    /// Shows the system sheet once; later calls return immediately.
    static func authorize() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [], read: [weightType, stepsType])
    }

    /// Body weight samples in kg, oldest first.
    static func weights(since start: Date) async -> [Day] {
        guard isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: weightType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { Day(date: $0.startDate, value: $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
    }

    /// Total steps per calendar day, oldest first.
    static func dailySteps(since start: Date) async -> [Day] {
        guard isAvailable else { return [] }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: start)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: stepsType, predicate: HKQuery.predicateForSamples(withStart: anchor, end: nil)),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return [] }
        return collection.statistics().compactMap { stat in
            stat.sumQuantity().map { Day(date: stat.startDate, value: $0.doubleValue(for: .count())) }
        }
    }
}

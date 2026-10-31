import Foundation

/// Decides which planned meal to show now, from the day and the hour: the one of the current slot, else the next one still
/// to come. Meals of slots already gone and never validated are assumed eaten (`DailyIntake`), nothing is asked about them.
enum NextMealPicker {
    static func pick(meals: [PlanMeal], doneIDs: Set<UUID>, weekday: Int, hour: Int) -> PlanMeal? {
        let pending = meals
            .filter { $0.weekday == weekday && !doneIDs.contains($0.id) }
            .sorted { $0.slot.order < $1.slot.order }
        let now = MealSlot.current(hour: hour).order
        return pending.first { $0.slot.order == now } ?? pending.first { $0.slot.order > now }
    }
}

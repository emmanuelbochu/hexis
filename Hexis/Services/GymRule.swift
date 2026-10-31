import Foundation

/// Default gym when the GPS does not decide: CityB on Saturdays and during zone B school holidays, CityA otherwise.
enum GymRule {
    static func usesCityB(on date: Date, holidays: [SchoolHoliday] = SchoolHoliday.current, calendar: Calendar = .current) -> Bool {
        if calendar.component(.weekday, from: date) == 7 { return true }
        let day = calendar.startOfDay(for: date)
        return holidays.contains { day >= $0.start && day <= $0.end }
    }
}

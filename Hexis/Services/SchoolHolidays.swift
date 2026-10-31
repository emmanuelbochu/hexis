import Foundation

/// French school holidays, zone B (académie d'Academy: CityA and CityB).
/// Dates of the 2026-2027 calendar; extend the list when the next calendar is published.
struct SchoolHoliday: Equatable {
    var name: String
    var start: Date
    var end: Date

    /// Days of the week starting at `monday` that fall in the holiday.
    func overlapDays(weekStarting monday: Date) -> Int {
        let calendar = Calendar.current
        return (0..<7).filter { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return false }
            return day >= start && day <= end
        }.count
    }

    static let zoneB: [SchoolHoliday] = [
        make("vacances de la Toussaint", 2026, 10, 17, 2026, 11, 2),
        make("vacances de Noël", 2026, 12, 19, 2027, 1, 4),
        make("vacances d'hiver", 2027, 2, 20, 2027, 3, 8),
        make("vacances de printemps", 2027, 4, 17, 2027, 5, 3),
        make("vacances d'été", 2027, 7, 3, 2027, 8, 31),
    ]

    /// Holidays of the user's school (the real days off); while empty, the school calendar above is used.
    /// One week off per break (the second one), two at Christmas; no spring break (internship from the end of March).
    static let iut: [SchoolHoliday] = [
        make("vacances de la Toussaint", 2026, 10, 26, 2026, 11, 1),
        make("vacances de Noël", 2026, 12, 19, 2027, 1, 3),
        make("vacances d'hiver", 2027, 3, 1, 2027, 3, 7),
    ]

    /// What the app plans around (default gym, deload week): the school calendar when known, else the school one.
    static var current: [SchoolHoliday] { iut.isEmpty ? zoneB : iut }

    private static func make(_ name: String, _ y1: Int, _ m1: Int, _ d1: Int, _ y2: Int, _ m2: Int, _ d2: Int) -> SchoolHoliday {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: y1, month: m1, day: d1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: y2, month: m2, day: d2)) ?? .distantPast
        return SchoolHoliday(name: name, start: start, end: end)
    }
}

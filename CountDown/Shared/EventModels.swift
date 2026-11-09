import Foundation

/// A calendar date, deliberately independent of a time zone or time of day.
struct CalendarDay: Codable, Hashable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 2000, month: components.month ?? 1, day: components.day ?? 1)
    }

    func date(in calendar: Calendar = .current) -> Date {
        // Noon avoids midnight ambiguity at DST transitions.
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? calendar.startOfDay(for: .now)
    }
}

enum EventPalette: String, Codable, CaseIterable, Identifiable {
    case coral, ocean, violet, forest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coral: "Коралл"
        case .ocean: "Океан"
        case .violet: "Лаванда"
        case .forest: "Лес"
        }
    }
}

struct CountEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var date: CalendarDay
    var palette: EventPalette
    var symbol: String

    init(id: UUID = UUID(), title: String, date: CalendarDay, palette: EventPalette = .coral, symbol: String = "sparkles") {
        self.id = id
        self.title = title
        self.date = date
        self.palette = palette
        self.symbol = symbol
    }
}

enum DayCount {
    /// Positive = days until; negative = days since; zero = today.
    /// Counting calendar days, not 24-hour intervals, handles DST changes.
    static func signedDays(to target: CalendarDay, from now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let destination = calendar.startOfDay(for: target.date(in: calendar))
        return calendar.dateComponents([.day], from: today, to: destination).day ?? 0
    }

    static func status(_ days: Int) -> String {
        if days > 0 { return "ДО СОБЫТИЯ" }
        if days < 0 { return "ПРОШЛО" }
        return "СЕГОДНЯ"
    }

    static func dayWord(_ number: Int) -> String {
        let n = abs(number)
        if n % 10 == 1 && n % 100 != 11 { return "день" }
        if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return "дня" }
        return "дней"
    }
}

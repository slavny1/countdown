import Foundation

/// Wall-clock date components, not a UTC instant. Existing stored day-only events
/// decode with nil time and keep the same calendar date across time zones.
struct CalendarDay: Codable, Hashable {
    var year: Int
    var month: Int
    var day: Int
    var hour: Int?
    var minute: Int?

    init(year: Int, month: Int, day: Int, hour: Int? = nil, minute: Int? = nil) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    init(date: Date, includesTime: Bool = false, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        self.init(year: components.year ?? 2000,
                  month: components.month ?? 1,
                  day: components.day ?? 1,
                  hour: includesTime ? (components.hour ?? 0) : nil,
                  minute: includesTime ? (components.minute ?? 0) : nil)
    }

    var includesTime: Bool { hour != nil }

    func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour ?? 0, minute: minute ?? 0))
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

enum CountUnit: String, Codable, CaseIterable, Identifiable {
    case automatic, days, hours, minutes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Автоматически"
        case .days: "Дни"
        case .hours: "Часы"
        case .minutes: "Минуты"
        }
    }
}

enum PhotoMask: String, Codable, CaseIterable, Identifiable {
    case black, navy, plum, brown
    var id: String { rawValue }
    var title: String {
        switch self {
        case .black: "Чёрный"
        case .navy: "Синий"
        case .plum: "Сливовый"
        case .brown: "Тёплый"
        }
    }
}

struct CountEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var date: CalendarDay
    var palette: EventPalette
    var symbol: String
    var note: String
    var unit: CountUnit
    var showsMilestones: Bool
    var photoFilename: String?
    var mask: PhotoMask
    var maskOpacity: Double

    init(id: UUID = UUID(), title: String, date: CalendarDay,
         palette: EventPalette = .coral, symbol: String = "sparkles",
         note: String = "", unit: CountUnit = .automatic,
         showsMilestones: Bool = true, photoFilename: String? = nil,
         mask: PhotoMask = .black, maskOpacity: Double = 0.55) {
        self.id = id
        self.title = title
        self.date = date
        self.palette = palette
        self.symbol = symbol
        self.note = note
        self.unit = unit
        self.showsMilestones = showsMilestones
        self.photoFilename = photoFilename
        self.mask = mask
        self.maskOpacity = min(max(maskOpacity, 0), 0.9)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, palette, symbol, note, unit
        case showsMilestones, photoFilename, mask, maskOpacity
    }

    // Older events only contain id, title, date, palette, and symbol.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(CalendarDay.self, forKey: .date)
        palette = try c.decode(EventPalette.self, forKey: .palette)
        symbol = try c.decode(String.self, forKey: .symbol)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        unit = try c.decodeIfPresent(CountUnit.self, forKey: .unit) ?? .automatic
        showsMilestones = try c.decodeIfPresent(Bool.self, forKey: .showsMilestones) ?? true
        photoFilename = try c.decodeIfPresent(String.self, forKey: .photoFilename)
        mask = try c.decodeIfPresent(PhotoMask.self, forKey: .mask) ?? .black
        maskOpacity = min(max(try c.decodeIfPresent(Double.self, forKey: .maskOpacity) ?? 0.55, 0), 0.9)
    }
}

struct CountReading {
    var number: Int
    var unit: CountUnit
    var isFuture: Bool

    var direction: String { isFuture ? "Осталось" : "Прошло" }

    var unitLabel: String {
        let n = abs(number)
        switch unit {
        case .days, .automatic:
            if n % 10 == 1 && n % 100 != 11 { return "день" }
            if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return "дня" }
            return "дней"
        case .hours:
            if n % 10 == 1 && n % 100 != 11 { return "час" }
            if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return "часа" }
            return "часов"
        case .minutes:
            if n % 10 == 1 && n % 100 != 11 { return "минута" }
            if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return "минуты" }
            return "минут"
        }
    }
}

enum DayCount {
    /// Calendar-day difference is unaffected by 23/25-hour DST days.
    static func signedDays(to target: CalendarDay, from now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: target.date(in: calendar))).day ?? 0
    }

    static func reading(for event: CountEvent, now: Date = .now, calendar: Calendar = .current) -> CountReading {
        let delta = event.date.date(in: calendar).timeIntervalSince(now)
        let future = delta >= 0
        let seconds = abs(delta)
        let chosen: CountUnit
        if event.unit == .automatic {
            chosen = !future || seconds >= 86_400 ? .days
                : (seconds >= 3_600 ? .hours : .minutes)
        } else {
            chosen = event.unit
        }
        let number: Int
        switch chosen {
        case .days, .automatic:
            number = abs(signedDays(to: event.date, from: now, calendar: calendar))
        case .hours:
            number = Int(future ? ceil(seconds / 3_600) : floor(seconds / 3_600))
        case .minutes:
            number = Int(future ? ceil(seconds / 60) : floor(seconds / 60))
        }
        return CountReading(number: number, unit: chosen, isFuture: future)
    }

    static func status(_ days: Int) -> String {
        days >= 0 ? "Осталось" : "Прошло"
    }

    static func dayWord(_ number: Int) -> String {
        CountReading(number: number, unit: .days, isFuture: true).unitLabel
    }
}

/// Milestone dates use calendar arithmetic for months and years, not fixed day counts.
struct Milestone: Identifiable {
    let title: String
    let date: Date
    var id: String { title + String(date.timeIntervalSinceReferenceDate) }
}

enum EventMilestones {
    private struct Offset {
        let title: String
        let component: Calendar.Component
        let amount: Int
    }

    private static let offsets: [Offset] = [
        .init(title: "1 день", component: .day, amount: 1),
        .init(title: "7 дней", component: .day, amount: 7),
        .init(title: "10 дней", component: .day, amount: 10),
        .init(title: "30 дней", component: .day, amount: 30),
        .init(title: "50 дней", component: .day, amount: 50),
        .init(title: "100 дней", component: .day, amount: 100),
        .init(title: "200 дней", component: .day, amount: 200),
        .init(title: "1 месяц", component: .month, amount: 1),
        .init(title: "Полгода", component: .month, amount: 6),
        .init(title: "1 год", component: .year, amount: 1),
        .init(title: "2 года", component: .year, amount: 2),
        .init(title: "5 лет", component: .year, amount: 5),
        .init(title: "10 лет", component: .year, amount: 10)
    ]

    static func next(for event: CountEvent, now: Date = .now, calendar: Calendar = .current) -> Milestone? {
        guard event.showsMilestones else { return nil }
        let target = event.date.date(in: calendar)
        let upcoming = target > now
        return offsets.compactMap { offset -> Milestone? in
            guard let result = calendar.date(byAdding: offset.component,
                                             value: upcoming ? -offset.amount : offset.amount,
                                             to: target),
                  result >= now,
                  (!upcoming || result <= target) else { return nil }
            return Milestone(title: offset.title, date: result)
        }.sorted { $0.date < $1.date }.first
    }
}

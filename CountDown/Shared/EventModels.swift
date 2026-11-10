import Foundation

/// Wall-clock date components, not a UTC instant. Existing stored day-only events
/// decode with nil time and keep the same calendar date across time zones.
struct CalendarDay: Codable, Hashable {
    var year: Int
    var month: Int
    var day: Int
    var hour: Int?
    var minute: Int?
    var second: Int?

    init(year: Int, month: Int, day: Int, hour: Int? = nil, minute: Int? = nil, second: Int? = nil) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    init(date: Date, includesTime: Bool = false, includesSeconds: Bool = false, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        self.init(year: components.year ?? 2000,
                  month: components.month ?? 1,
                  day: components.day ?? 1,
                  hour: includesTime ? (components.hour ?? 0) : nil,
                  minute: includesTime ? (components.minute ?? 0) : nil,
                  second: includesSeconds ? (components.second ?? 0) : nil)
    }

    var includesTime: Bool { hour != nil }

    var displayLabel: String {
        let value = date()
        let dateText = value.formatted(.dateTime.day().month(.wide).year())
        return includesTime
            ? dateText + " · " + value.formatted(.dateTime.hour().minute())
            : dateText
    }

    func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour ?? 0, minute: minute ?? 0, second: second ?? 0))
        ?? calendar.startOfDay(for: .now)
    }
}

enum EventPalette: String, Codable, CaseIterable, Identifiable {
    case coral, ocean, violet, forest, sand
    var id: String { rawValue }
    var title: String {
        switch self {
        case .coral: "Коралл"
        case .ocean: "Океан"
        case .violet: "Лаванда"
        case .forest: "Лес"
        case .sand: "Песок"
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

/// Time components requested for the card. Automatic preserves the classic
/// days → hours → minutes behavior until the user chooses explicit units.
struct TimeUnitSelection: Codable, Hashable {
    var automatic: Bool = true
    var days: Bool = true
    var hours: Bool = false
    var minutes: Bool = false

    init(automatic: Bool = true, days: Bool = true,
         hours: Bool = false, minutes: Bool = false) {
        self.automatic = automatic
        self.days = days
        self.hours = hours
        self.minutes = minutes
    }

    var selected: [CountUnit] {
        let units: [CountUnit] = [.days, .hours, .minutes]
        return units.filter {
            switch $0 {
            case .days: days
            case .hours: hours
            case .minutes: minutes
            case .automatic: false
            }
        }
    }

    mutating func select(_ unit: CountUnit, enabled: Bool) {
        automatic = false
        switch unit {
        case .days: days = enabled
        case .hours: hours = enabled
        case .minutes: minutes = enabled
        case .automatic: automatic = enabled
        }
        if selected.isEmpty { days = true }
    }

    static func fromLegacy(_ unit: CountUnit) -> Self {
        switch unit {
        case .automatic: Self()
        case .days: Self(automatic: false, days: true)
        case .hours: Self(automatic: false, days: false, hours: true)
        case .minutes: Self(automatic: false, days: false, minutes: true)
        }
    }
}

enum EventPhase: String, Equatable {
    case waiting, now, elapsed
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
    var legacyHex: String {
        switch self {
        case .black: "000000"
        case .navy: "142957"
        case .plum: "541F4A"
        case .brown: "47291A"
        }
    }
}

/// Same curated color choices for card text and photo overlays.
enum CardColorPalette {
    static let swatches = ["FFFFFF", "F0E3D1", "1B2029", "F6CF59",
                           "C8E9FF", "E8C4F0", "B9EDC6", "FFB8A7"]
}

/// Appearance is saved per event and shared with the home screen widget.
/// Defaults intentionally match the original visual style of existing events.
enum CardTypeface: String, Codable, CaseIterable, Identifiable {
    case editorial, modern, soft, mono
    var id: String { rawValue }
    var title: String {
        switch self {
        case .editorial: "Классика"
        case .modern: "Чёткий"
        case .soft: "Мягкий"
        case .mono: "Цифровой"
        }
    }
}

enum CardThickness: String, Codable, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold, heavy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: "Тонкий"
        case .regular: "Обычный"
        case .medium: "Средний"
        case .semibold: "Плотный"
        case .bold: "Жирный"
        case .heavy: "Очень жирный"
        }
    }
}

enum CardAlignment: String, Codable, CaseIterable, Identifiable {
    case leading, center
    var id: String { rawValue }
    var title: String { self == .leading ? "Слева" : "По центру" }
}

enum CardUnitPlacement: String, Codable, CaseIterable, Identifiable {
    case beside, below
    var id: String { rawValue }
    var title: String { self == .beside ? "Рядом" : "Снизу" }
}

struct CardStyle: Codable, Hashable {
    var typeface: CardTypeface = .editorial
    var thickness: CardThickness = .bold
    var scale: Double = 1.0
    /// Six-digit RGB, no opacity. Stored as a string for WidgetKit JSON sharing.
    var textColorHex: String = "FFFFFF"
    var alignment: CardAlignment = .leading
    var unitPlacement: CardUnitPlacement = .beside
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
    var maskColorHex: String
    var photoZoom: Double
    var photoFocusX: Double
    var photoFocusY: Double
    var backgroundColorHex: String?
    var isPinned: Bool
    var style: CardStyle
    var countsUp: Bool
    var displayUnits: TimeUnitSelection

    init(id: UUID = UUID(), title: String, date: CalendarDay,
         palette: EventPalette = .coral, symbol: String = "sparkles",
         note: String = "", unit: CountUnit = .automatic,
         showsMilestones: Bool = true, photoFilename: String? = nil,
         mask: PhotoMask = .black, maskOpacity: Double = 0.55,
         maskColorHex: String? = nil, photoZoom: Double = 1,
         photoFocusX: Double = 0.5, photoFocusY: Double = 0.5,
         backgroundColorHex: String? = nil, isPinned: Bool = false,
         style: CardStyle = CardStyle(), countsUp: Bool = false,
         displayUnits: TimeUnitSelection? = nil) {
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
        self.maskColorHex = maskColorHex ?? mask.legacyHex
        self.photoZoom = min(max(photoZoom, 1), 2.5)
        self.photoFocusX = min(max(photoFocusX, 0), 1)
        self.photoFocusY = min(max(photoFocusY, 0), 1)
        self.backgroundColorHex = backgroundColorHex
        self.isPinned = isPinned
        self.style = style
        self.countsUp = countsUp
        self.displayUnits = displayUnits ?? .fromLegacy(unit)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, palette, symbol, note, unit
        case showsMilestones, photoFilename, mask, maskOpacity, maskColorHex
        case photoZoom, photoFocusX, photoFocusY, backgroundColorHex, isPinned, style, countsUp, displayUnits
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
        maskColorHex = try c.decodeIfPresent(String.self, forKey: .maskColorHex) ?? mask.legacyHex
        photoZoom = min(max(try c.decodeIfPresent(Double.self, forKey: .photoZoom) ?? 1, 1), 2.5)
        photoFocusX = min(max(try c.decodeIfPresent(Double.self, forKey: .photoFocusX) ?? 0.5, 0), 1)
        photoFocusY = min(max(try c.decodeIfPresent(Double.self, forKey: .photoFocusY) ?? 0.5, 0), 1)
        backgroundColorHex = try c.decodeIfPresent(String.self, forKey: .backgroundColorHex)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        style = try c.decodeIfPresent(CardStyle.self, forKey: .style) ?? CardStyle()
        countsUp = try c.decodeIfPresent(Bool.self, forKey: .countsUp) ?? false
        displayUnits = try c.decodeIfPresent(TimeUnitSelection.self, forKey: .displayUnits) ?? .fromLegacy(unit)
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
        let future = !event.countsUp && delta >= 0
        let seconds = event.countsUp ? max(0, -delta) : abs(delta)
        let chosen: CountUnit
        if event.unit == .automatic {
            if event.countsUp {
                chosen = seconds >= 86_400 ? .days : (seconds >= 3_600 ? .hours : .minutes)
            } else {
                chosen = !future || seconds >= 86_400 ? .days
                    : (seconds >= 3_600 ? .hours : .minutes)
            }
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

    static func phase(for event: CountEvent, now: Date = .now,
                      calendar: Calendar = .current) -> EventPhase {
        if event.countsUp { return .elapsed }
        let target = event.date.date(in: calendar)
        if calendar.isDate(now, inSameDayAs: target), now >= target {
            return .now
        }
        return now < target ? .waiting : .elapsed
    }

    static func readings(for event: CountEvent, now: Date = .now,
                         calendar: Calendar = .current,
                         selection override: TimeUnitSelection? = nil) -> [CountReading] {
        if phase(for: event, now: now, calendar: calendar) == .now { return [] }
        let selected = override ?? event.displayUnits
        if event.countsUp && now < event.date.date(in: calendar) {
            return (selected.automatic ? [.minutes] : selected.selected).map {
                CountReading(number: 0, unit: $0, isFuture: false)
            }
        }
        if selected.automatic {
            var automaticEvent = event
            automaticEvent.unit = .automatic
            return [reading(for: automaticEvent, now: now, calendar: calendar)]
        }
        let target = event.date.date(in: calendar)
        let isFuture = !event.countsUp && target > now
        let from = isFuture ? now : min(now, target)
        let to = isFuture ? target : max(now, target)
        let seconds = max(0, to.timeIntervalSince(from))
        let totalMinutes = Int(isFuture ? ceil(seconds / 60) : floor(seconds / 60))
        let totalHours = Int(isFuture ? ceil(seconds / 3600) : floor(seconds / 3600))
        let calendarDays = abs(signedDays(to: event.date, from: now, calendar: calendar))
        let split = calendar.dateComponents([.day, .hour, .minute], from: from, to: to)
        let splitDays = max(0, split.day ?? 0)
        let splitHours = max(0, split.hour ?? 0)
        let splitMinutes = max(0, split.minute ?? 0)
        let units = selected.selected.isEmpty ? [.days] : selected.selected

        // When showing several units, each smaller component is the remainder
        // of the larger one. Single-unit counters show the full total.
        return units.map { unit in
            let number: Int
            switch unit {
            case .days, .automatic:
                number = units.count == 1 ? calendarDays : splitDays
            case .hours:
                if selected.days {
                    number = splitHours
                } else {
                    number = units.count == 1 ? totalHours : totalMinutes / 60
                }
            case .minutes:
                if selected.days {
                    number = splitHours * (selected.hours ? 0 : 60) + splitMinutes
                } else if selected.hours {
                    number = totalMinutes % 60
                } else {
                    number = totalMinutes
                }
            }
            return CountReading(number: number, unit: unit, isFuture: isFuture)
        }
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

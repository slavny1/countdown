import Foundation

enum EventRepository {
    static let appGroup = "group.com.slavny1.countdown"
    static let key = "countdown.events.v1"
    private static let seededKey = "countdown.sample-seeded.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> [CountEvent] {
        if let data = defaults.data(forKey: key),
           let events = try? JSONDecoder().decode([CountEvent].self, from: data) {
            // Never overwrite existing events, even an intentionally empty list.
            defaults.set(true, forKey: seededKey)
            return events
        }
        guard !defaults.bool(forKey: seededKey) else { return [] }
        let sample = CountEvent(title: "30 апреля 2026",
                                date: CalendarDay(year: 2026, month: 4, day: 30),
                                palette: .ocean, symbol: "calendar")
        defaults.set(true, forKey: seededKey)
        _ = save([sample])
        return [sample]
    }

    @discardableResult
    static func save(_ events: [CountEvent]) -> Bool {
        guard let data = try? JSONEncoder().encode(events) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}

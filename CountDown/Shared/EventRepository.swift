import Foundation

/// Shared storage is readable by both the app and its WidgetKit extension.
enum EventRepository {
    static let appGroup = "group.com.slavny1.countdown"
    private static let key = "countdown.events.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func load() -> [CountEvent] {
        guard let data = defaults.data(forKey: key),
              let events = try? JSONDecoder().decode([CountEvent].self, from: data) else {
            return []
        }
        return events
    }

    @discardableResult
    static func save(_ events: [CountEvent]) -> Bool {
        guard let data = try? JSONEncoder().encode(events) else { return false }
        defaults.set(data, forKey: key)
        return true
    }
}

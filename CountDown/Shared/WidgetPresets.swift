import Foundation

enum WidgetPresetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: "Малый"
        case .medium: "Средний"
        case .large: "Большой"
        }
    }
}

struct WidgetPreset: Codable, Identifiable, Hashable {
    var id: UUID
    var eventID: UUID
    var title: String
    var size: WidgetPresetSize
    var style: CardStyle
    var units: TimeUnitSelection
    var palette: EventPalette
    var backgroundColorHex: String?
    var maskColorHex: String
    var maskOpacity: Double
    var photoFilename: String?
    var useEventPhoto: Bool

    init(id: UUID = UUID(), event: CountEvent, size: WidgetPresetSize = .small) {
        self.id = id
        self.eventID = event.id
        self.title = "\(size.title) · \(event.title)"
        self.size = size
        self.style = event.style
        self.units = size == .small
            ? .fromLegacy(event.displayUnits.selected.first ?? .days)
            : event.displayUnits
        self.palette = event.palette
        self.backgroundColorHex = event.backgroundColorHex
        self.maskColorHex = event.maskColorHex
        self.maskOpacity = event.maskOpacity
        self.photoFilename = nil
        self.useEventPhoto = true
    }

    func applying(to event: CountEvent) -> CountEvent {
        var copy = event
        copy.style = style
        copy.displayUnits = units
        copy.palette = palette
        copy.backgroundColorHex = backgroundColorHex
        copy.maskColorHex = maskColorHex
        copy.maskOpacity = maskOpacity
        copy.photoFilename = photoFilename ?? (useEventPhoto ? event.photoFilename : nil)
        return copy
    }
}

enum WidgetPresetRepository {
    static let key = "countdown.widget-presets.v1"

    static func load() -> [WidgetPreset] {
        let preferences = UserDefaults(suiteName: EventRepository.appGroup) ?? .standard
        guard let data = preferences.data(forKey: key),
              let presets = try? JSONDecoder().decode([WidgetPreset].self, from: data) else { return [] }
        return presets
    }

    @discardableResult
    static func save(_ presets: [WidgetPreset]) -> Bool {
        let preferences = UserDefaults(suiteName: EventRepository.appGroup) ?? .standard
        guard let data = try? JSONEncoder().encode(presets) else { return false }
        preferences.set(data, forKey: key)
        return true
    }
}

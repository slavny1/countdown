import AppIntents
import SwiftUI
import UIKit
import WidgetKit

private enum SharedData {
    static let appGroup = "group.com.slavny1.countdown"
    static let eventKey = "countdown.events.v1"
    static let presetKey = "countdown.widget-presets.v1"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func events() -> [WidgetEvent] {
        guard let data = defaults?.data(forKey: eventKey) else { return [] }
        return (try? JSONDecoder().decode([WidgetEvent].self, from: data)) ?? []
    }

    static func presets() -> [WidgetPresetData] {
        guard let data = defaults?.data(forKey: presetKey) else { return [] }
        return (try? JSONDecoder().decode([WidgetPresetData].self, from: data)) ?? []
    }

    static func photo(named name: String?) -> UIImage? {
        guard let name, let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let url = container.appendingPathComponent("EventPhotos", isDirectory: true)
            .appendingPathComponent(name)
        return UIImage(contentsOfFile: url.path)
    }
}

private struct WidgetDay: Decodable {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int?
    let minute: Int?
    let second: Int?

    func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour ?? 0, minute: minute ?? 0,
                                           second: second ?? 0)) ?? calendar.startOfDay(for: .now)
    }

    var label: String {
        let value = date()
        let day = value.formatted(.dateTime.day().month(.wide).year())
        return hour == nil ? day : day + " · " + value.formatted(.dateTime.hour().minute())
    }
}

private struct WidgetCardStyle: Decodable {
    let typeface: String
    let thickness: String
    let scale: Double
    let textColorHex: String
    let alignment: String
    let unitPlacement: String

    var color: Color { Color(rgbHex: textColorHex) }

    var design: Font.Design {
        switch typeface {
        case "modern": .default
        case "soft": .rounded
        case "mono": .monospaced
        default: .serif
        }
    }

    var weight: Font.Weight {
        switch thickness {
        case "light": .light
        case "regular": .regular
        case "medium": .medium
        case "semibold": .semibold
        case "heavy": .heavy
        default: .bold
        }
    }

    var scaleValue: CGFloat { CGFloat(min(max(scale, 0.7), 1.6)) }

    static let standard = WidgetCardStyle(
        typeface: "editorial", thickness: "bold", scale: 1,
        textColorHex: "FFFFFF", alignment: "leading", unitPlacement: "beside"
    )
}

private extension Color {
    init(rgbHex: String) {
        let value = UInt64(rgbHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")),
                           radix: 16) ?? 0xFFFFFF
        self.init(.sRGB,
                  red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255,
                  opacity: 1)
    }
}

private struct WidgetUnits: Decodable {
    let automatic: Bool
    let days: Bool
    let hours: Bool
    let minutes: Bool

    var selected: [String] {
        var chosen: [String] = []
        if days { chosen.append("days") }
        if hours { chosen.append("hours") }
        if minutes { chosen.append("minutes") }
        return chosen.isEmpty ? ["days"] : chosen
    }

    static func legacy(_ unit: String?) -> WidgetUnits {
        let u = unit ?? "automatic"
        return WidgetUnits(automatic: u == "automatic",
                           days: u == "days" || u == "automatic",
                           hours: u == "hours", minutes: u == "minutes")
    }
}

private struct WidgetEvent: Decodable {
    let id: UUID
    let title: String
    let date: WidgetDay
    let palette: String
    let symbol: String
    let note: String?
    let unit: String?
    let displayUnits: WidgetUnits?
    let photoFilename: String?
    let maskColorHex: String?
    let mask: String?
    let maskOpacity: Double?
    let photoZoom: Double?
    let photoFocusX: Double?
    let photoFocusY: Double?
    let backgroundColorHex: String?
    let countsUp: Bool?
    let style: WidgetCardStyle?

    var maskColor: Color {
        if let maskColorHex { return Color(rgbHex: maskColorHex) }
        switch mask {
        case "navy": return Color(rgbHex: "142957")
        case "plum": return Color(rgbHex: "541F4A")
        case "brown": return Color(rgbHex: "47291A")
        default: return .black
        }
    }

    static func colors(_ palette: String) -> [Color] {
        switch palette {
        case "ocean": [Color(red: 0.18, green: 0.54, blue: 0.72),
                       Color(red: 0.11, green: 0.27, blue: 0.52)]
        case "violet": [Color(red: 0.65, green: 0.48, blue: 0.86),
                        Color(red: 0.35, green: 0.25, blue: 0.57)]
        case "forest": [Color(red: 0.30, green: 0.62, blue: 0.50),
                        Color(red: 0.11, green: 0.37, blue: 0.39)]
        case "sand": [Color(red: 0.91, green: 0.74, blue: 0.52),
                      Color(red: 0.64, green: 0.46, blue: 0.33)]
        default: [Color(red: 0.94, green: 0.45, blue: 0.36),
                  Color(red: 0.64, green: 0.23, blue: 0.43)]
        }
    }

    func isNow(at now: Date, calendar: Calendar = .current) -> Bool {
        guard countsUp != true else { return false }
        let target = date.date(in: calendar)
        return now >= target && calendar.isDate(now, inSameDayAs: target)
    }

    func readings(at now: Date, selectedUnits: WidgetUnits? = nil,
                  calendar: Calendar = .current) -> [WidgetReading] {
        if isNow(at: now, calendar: calendar) { return [] }
        let units = selectedUnits ?? displayUnits ?? .legacy(unit)
        let target = date.date(in: calendar)
        let isFuture = countsUp != true && now < target
        let elapsed = countsUp == true ? max(0, now.timeIntervalSince(target))
                                        : abs(target.timeIntervalSince(now))

        if units.automatic {
            let mode = !isFuture || elapsed >= 86400 ? "days"
                       : elapsed >= 3600 ? "hours" : "minutes"
            return [reading(for: mode, at: now, calendar: calendar)]
        }

        let keys = units.selected
        let from = min(now, target)
        let to = max(now, target)
        let components = calendar.dateComponents([.day, .hour, .minute], from: from, to: to)
        let calendarDays = abs(calendar.dateComponents([.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: target)).day ?? 0)
        let minutes = Int(isFuture ? ceil(elapsed / 60) : floor(elapsed / 60))
        let hours = Int(isFuture ? ceil(elapsed / 3600) : floor(elapsed / 3600))

        return keys.map { key in
            let number: Int
            switch key {
            case "days":
                number = keys.count == 1 ? calendarDays : (components.day ?? 0)
            case "hours":
                number = units.days ? (components.hour ?? 0)
                    : (keys.count == 1 ? hours : minutes / 60)
            default:
                number = units.days
                    ? (components.minute ?? 0) + (units.hours ? 0 : (components.hour ?? 0) * 60)
                    : (units.hours ? minutes % 60 : minutes)
            }
            return WidgetReading(number: max(0, number), unit: key, isFuture: isFuture)
        }
    }

    private func reading(for unit: String, at now: Date, calendar: Calendar) -> WidgetReading {
        let target = date.date(in: calendar)
        let isFuture = countsUp != true && now < target
        let elapsed = countsUp == true ? max(0, now.timeIntervalSince(target))
                                        : abs(target.timeIntervalSince(now))
        let result: Int
        switch unit {
        case "hours": result = Int(isFuture ? ceil(elapsed / 3600) : floor(elapsed / 3600))
        case "minutes": result = Int(isFuture ? ceil(elapsed / 60) : floor(elapsed / 60))
        default:
            result = abs(calendar.dateComponents([.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: target)).day ?? 0)
        }
        return WidgetReading(number: result, unit: unit, isFuture: isFuture)
    }
}

private struct WidgetPresetData: Decodable {
    let id: UUID
    let eventID: UUID
    let title: String
    let size: String
    let style: WidgetCardStyle
    let units: WidgetUnits
    let palette: String
    let backgroundColorHex: String?
    let maskColorHex: String
    let maskOpacity: Double
    let photoFilename: String?
    let useEventPhoto: Bool
}

private struct WidgetReading {
    let number: Int
    let unit: String
    let isFuture: Bool
    var direction: String { isFuture ? "ОСТАЛОСЬ" : "ПРОШЛО" }
    var label: String {
        let n = abs(number)
        func ending(_ one: String, _ few: String, _ many: String) -> String {
            if n % 10 == 1 && n % 100 != 11 { return one }
            if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return few }
            return many
        }
        switch unit {
        case "hours": return ending("час", "часа", "часов")
        case "minutes": return ending("минута", "минуты", "минут")
        default: return ending("день", "дня", "дней")
        }
    }
}

struct WidgetEventOption: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Событие"
    static var defaultQuery = WidgetEventQuery()
    let id: String
    let title: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
    }
}

struct WidgetEventQuery: EntityQuery {
    func entities(for identifiers: [WidgetEventOption.ID]) async throws -> [WidgetEventOption] {
        SharedData.events().filter { identifiers.contains($0.id.uuidString) }
            .map { WidgetEventOption(id: $0.id.uuidString, title: $0.title) }
    }
    func suggestedEntities() async throws -> [WidgetEventOption] {
        SharedData.events().map { WidgetEventOption(id: $0.id.uuidString, title: $0.title) }
    }
    func defaultResult() async -> WidgetEventOption? {
        SharedData.events().first.map { WidgetEventOption(id: $0.id.uuidString, title: $0.title) }
    }
}

struct WidgetPresetOption: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Оформление"
    static var defaultQuery = WidgetPresetQuery()
    let id: String
    let title: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
    }
}

struct WidgetPresetQuery: EntityQuery {
    func entities(for identifiers: [WidgetPresetOption.ID]) async throws -> [WidgetPresetOption] {
        SharedData.presets().filter { identifiers.contains($0.id.uuidString) }
            .map { WidgetPresetOption(id: $0.id.uuidString, title: $0.title) }
    }
    func suggestedEntities() async throws -> [WidgetPresetOption] {
        SharedData.presets().map { WidgetPresetOption(id: $0.id.uuidString, title: $0.title) }
    }
    func defaultResult() async -> WidgetPresetOption? {
        SharedData.presets().first.map { WidgetPresetOption(id: $0.id.uuidString, title: $0.title) }
    }
}

struct SelectCountEventIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Дни"
    static var description = IntentDescription("Выберите событие или своё оформление")
    @Parameter(title: "Оформление")
    var preset: WidgetPresetOption?
    @Parameter(title: "Событие")
    var event: WidgetEventOption?
    init() {}
}

private struct CountEntry: TimelineEntry {
    let date: Date
    let event: WidgetEvent?
    let preset: WidgetPresetData?
    let readings: [WidgetReading]
    let isNow: Bool
}

private struct CountProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountEntry {
        CountEntry(date: .now, event: nil, preset: nil,
                   readings: [WidgetReading(number: 42, unit: "days", isFuture: true)],
                   isNow: false)
    }
    func snapshot(for configuration: SelectCountEventIntent, in context: Context) async -> CountEntry {
        entry(at: .now, configuration: configuration)
    }
    func timeline(for configuration: SelectCountEventIntent, in context: Context) async -> Timeline<CountEntry> {
        let now = Date()
        let current = entry(at: now, configuration: configuration)
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1,
            to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        var next = midnight.addingTimeInterval(10)

        if let event = current.event {
            let remaining = event.date.date(in: calendar).timeIntervalSince(now)
            if remaining > 0 && event.countsUp != true {
                for threshold in [86400.0, 3600.0] where remaining > threshold {
                    next = min(next, now.addingTimeInterval(remaining - threshold + 1))
                }
                next = min(next, now.addingTimeInterval(remaining + 2))
            }
            if let first = current.readings.first {
                if first.unit == "minutes" { next = min(next, now.addingTimeInterval(60)) }
                else if first.unit == "hours" { next = min(next, now.addingTimeInterval(300)) }
            }
        }
        return Timeline(entries: [current], policy: .after(max(now.addingTimeInterval(30), next)))
    }

    private func entry(at now: Date, configuration: SelectCountEventIntent) -> CountEntry {
        let events = SharedData.events()
        let presets = SharedData.presets()
        let preset = presets.first { $0.id.uuidString == configuration.preset?.id }
        let chosen: WidgetEvent?
        if let preset {
            chosen = events.first { $0.id == preset.eventID }
        } else if let eventID = configuration.event?.id {
            chosen = events.first { $0.id.uuidString == eventID }
        } else {
            chosen = events.filter { $0.date.date() >= now }
                .sorted { $0.date.date() < $1.date.date() }.first
                ?? events.sorted { $0.date.date() > $1.date.date() }.first
        }
        return CountEntry(date: now, event: chosen, preset: preset,
                          readings: chosen?.readings(at: now, selectedUnits: preset?.units)
                              ?? [WidgetReading(number: 0, unit: "days", isFuture: true)],
                          isNow: chosen?.isNow(at: now) ?? false)
    }
}

private struct WidgetBackground: View {
    let entry: CountEntry

    var body: some View {
        GeometryReader { proxy in
            let preset = entry.preset
            let event = entry.event
            let filename = preset?.photoFilename ??
                ((preset?.useEventPhoto ?? true) ? event?.photoFilename : nil)
            if let image = SharedData.photo(named: filename) {
                let scale = max(proxy.size.width / max(image.size.width, 1),
                                proxy.size.height / max(image.size.height, 1))
                    * CGFloat(min(max(event?.photoZoom ?? 1, 1), 2.5))
                let width = image.size.width * scale
                let height = image.size.height * scale
                let offsetX = (width - proxy.size.width) * CGFloat(0.5 - (event?.photoFocusX ?? 0.5))
                let offsetY = (height - proxy.size.height) * CGFloat(0.5 - (event?.photoFocusY ?? 0.5))
                Image(uiImage: image)
                    .resizable()
                    .frame(width: width, height: height)
                    .position(x: proxy.size.width / 2 + offsetX,
                              y: proxy.size.height / 2 + offsetY)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(Color(rgbHex: preset?.maskColorHex ??
                                   event?.maskColorHex ?? "000000")
                        .opacity(min(max(preset?.maskOpacity ?? event?.maskOpacity ?? 0.55, 0), 0.9)))
            } else if let hex = preset?.backgroundColorHex ?? event?.backgroundColorHex {
                Color(rgbHex: hex)
            } else {
                LinearGradient(colors: WidgetEvent.colors(preset?.palette ?? event?.palette ?? "coral"),
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

private struct CountWidgetFace: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountEntry

    private var style: WidgetCardStyle { entry.preset?.style ?? entry.event?.style ?? .standard }
    private var title: String { entry.event?.title ?? "Создай событие" }
    private var values: [WidgetReading] {
        family == .systemSmall ? Array(entry.readings.prefix(1)) : entry.readings
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.isNow ? "\(title) · СЕЙЧАС"
                     : "\(title) · \(entry.readings.first?.number ?? 0) \(entry.readings.first?.label ?? "дней")")
                    .lineLimit(1)
            case .accessoryCircular:
                VStack(spacing: 0) {
                    if entry.isNow {
                        Image(systemName: "sparkles")
                        Text("СЕЙЧАС").font(.system(size: 9, weight: .heavy))
                    } else {
                        Text(entry.readings.first?.number ?? 0, format: .number)
                            .font(.system(size: 30, weight: style.weight, design: style.design))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        Text(entry.readings.first?.label ?? "дней")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                    if entry.isNow {
                        Text("СЕЙЧАС").font(.system(size: 23, weight: .bold))
                    } else {
                        Text(entry.readings.first?.number ?? 0, format: .number)
                            .font(.system(size: 33, weight: style.weight, design: style.design))
                    }
                    Text(entry.readings.first?.label ?? "дней").font(.caption)
                }
            case .systemLarge:
                VStack(alignment: .leading, spacing: 15) {
                    header
                    Spacer(minLength: 0)
                    readingsRow(fontSize: 60)
                    Text(title)
                        .font(.system(size: 24 * style.scaleValue,
                                      weight: style.weight, design: style.design))
                        .lineLimit(2)
                        .minimumScaleFactor(0.4)
                    Text(entry.event?.date.label ?? "")
                        .font(.caption)
                        .opacity(0.85)
                    Rectangle().fill(style.color.opacity(0.35)).frame(height: 1)
                    Text(entry.event?.note?.isEmpty == false ? entry.event?.note ?? "" :
                         "Заметка к событию")
                        .font(.system(size: 13))
                        .lineLimit(5)
                }
                .foregroundStyle(style.color)
                .padding(4)
            case .systemMedium:
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        header
                        Text(title)
                            .font(.system(size: 20 * style.scaleValue,
                                          weight: style.weight, design: style.design))
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                        Text(entry.event?.date.label ?? "")
                            .font(.caption2)
                            .lineLimit(2)
                            .opacity(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    readingsRow(fontSize: values.count > 1 ? 34 : 74)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .foregroundStyle(style.color)
                .padding(2)
            default:
                VStack(alignment: .leading, spacing: 5) {
                    header
                    Spacer(minLength: 0)
                    readingsRow(fontSize: 77)
                    Text(title)
                        .font(.system(size: 16 * style.scaleValue,
                                      weight: style.weight, design: style.design))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                .foregroundStyle(style.color)
                .padding(2)
            }
        }
        .containerBackground(for: .widget) { WidgetBackground(entry: entry) }
        .widgetURL(entry.preset.flatMap { URL(string: "dni://widget/\($0.id.uuidString)") })
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        Text(entry.isNow ? "ЭТОТ ДЕНЬ НАСТАЛ" :
             entry.event?.countsUp == true || entry.readings.first?.isFuture == false
                ? "ПРОШЛО" : "ОСТАЛОСЬ")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1)
    }

    @ViewBuilder
    private func readingsRow(fontSize: CGFloat) -> some View {
        if entry.isNow {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .symbolEffect(.bounce)
                Text("СЕЙЧАС")
                    .font(.system(size: min(fontSize * style.scaleValue * 0.72, 54),
                                  weight: style.weight, design: style.design))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                ForEach(values.indices, id: \.self) { i in
                    let reading = values[i]
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reading.number, format: .number)
                            .font(.system(size: fontSize * style.scaleValue,
                                          weight: style.weight, design: style.design))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                        Text(reading.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct CountDownWidget: Widget {
    let kind = "CountDownWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectCountEventIntent.self,
                               provider: CountProvider()) { entry in
            CountWidgetFace(entry: entry)
        }
        .configurationDisplayName("Дни")
        .description("Выберите событие или сохранённое оформление")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct CountDownWidgets: WidgetBundle {
    var body: some Widget {
        CountDownWidget()
    }
}

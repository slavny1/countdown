import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// Widget-only decoder. The application owns the data model; both read the same
// backward-compatible JSON in the shared App Group.
private enum SharedEvents {
    static let group = "group.com.slavny1.countdown"
    static let key = "countdown.events.v1"

    static func all() -> [WidgetEvent] {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
              let events = try? JSONDecoder().decode([WidgetEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func photo(named name: String?) -> UIImage? {
        guard let name,
              let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: group
              ) else { return nil }
        let url = directory.appendingPathComponent("EventPhotos", isDirectory: true)
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
                                           hour: hour ?? 0, minute: minute ?? 0, second: second ?? 0))
        ?? calendar.startOfDay(for: .now)
    }
}

private struct WidgetCardStyle: Decodable {
    let typeface: String
    let thickness: String
    let scale: Double
    let textColorHex: String
    let alignment: String
    let unitPlacement: String

    var color: Color {
        let value = UInt64(textColorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFFFFFF
        return Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255,
                     green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255, opacity: 1)
    }

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

    var placementBelow: Bool { unitPlacement == "below" }
    var centered: Bool { alignment == "center" }

    static let standard = WidgetCardStyle(
        typeface: "editorial", thickness: "bold", scale: 1,
        textColorHex: "FFFFFF", alignment: "leading", unitPlacement: "beside"
    )
}

private struct WidgetEvent: Decodable {
    let id: UUID
    let title: String
    let date: WidgetDay
    let palette: String
    let backgroundColorHex: String?
    let symbol: String
    let unit: String?
    let photoFilename: String?
    let mask: String?
    let maskOpacity: Double?
    let maskColorHex: String?
    let photoZoom: Double?
    let photoFocusX: Double?
    let photoFocusY: Double?
    let countsUp: Bool?
    let style: WidgetCardStyle?

    func calendarDays(from now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date.date(in: calendar))).day ?? 0
    }

    func reading(now: Date, calendar: Calendar = .current) -> WidgetReading {
        let remaining = date.date(in: calendar).timeIntervalSince(now)
        let countUp = countsUp ?? false
        let isFuture = !countUp && remaining >= 0
        let seconds = countUp ? max(0, -remaining) : abs(remaining)
        let selected: String
        if (unit ?? "automatic") == "automatic" {
            if countUp {
                selected = seconds >= 86_400 ? "days" : seconds >= 3_600 ? "hours" : "minutes"
            } else {
                selected = !isFuture || seconds >= 86_400 ? "days"
                         : seconds >= 3_600 ? "hours" : "minutes"
            }
        } else {
            selected = unit ?? "days"
        }
        let number: Int
        switch selected {
        case "hours":
            number = Int(isFuture ? ceil(seconds / 3600) : floor(seconds / 3600))
        case "minutes":
            number = Int(isFuture ? ceil(seconds / 60) : floor(seconds / 60))
        default:
            number = abs(calendarDays(from: now, calendar: calendar))
        }
        return WidgetReading(number: number, unit: selected, isFuture: isFuture)
    }

    var colors: [Color] {
        switch palette {
        case "ocean": [Color(red: 0.18, green: 0.54, blue: 0.72), Color(red: 0.11, green: 0.27, blue: 0.52)]
        case "violet": [Color(red: 0.65, green: 0.48, blue: 0.86), Color(red: 0.35, green: 0.25, blue: 0.57)]
        case "forest": [Color(red: 0.30, green: 0.62, blue: 0.50), Color(red: 0.11, green: 0.37, blue: 0.39)]
        case "sand": [Color(red: 0.91, green: 0.74, blue: 0.52), Color(red: 0.64, green: 0.46, blue: 0.33)]
        default: [Color(red: 0.94, green: 0.45, blue: 0.36), Color(red: 0.64, green: 0.23, blue: 0.43)]
        }
    }

    var backgroundColor: Color? {
        guard let backgroundColorHex,
              let rgb = UInt64(backgroundColorHex, radix: 16) else { return nil }
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255, opacity: 1)
    }

    var dateLabel: String {
        let value = date.date()
        let result = value.formatted(.dateTime.day().month(.wide).year())
        return date.hour == nil ? result : result + " · " + value.formatted(.dateTime.hour().minute())
    }

    var maskColor: Color {
        if let maskColorHex, let rgb = UInt64(maskColorHex, radix: 16) {
            return Color(.sRGB,
                         red: Double((rgb >> 16) & 0xff) / 255,
                         green: Double((rgb >> 8) & 0xff) / 255,
                         blue: Double(rgb & 0xff) / 255,
                         opacity: 1)
        }
        switch mask {
        case "navy": return Color(red: 0.08, green: 0.16, blue: 0.34)
        case "plum": return Color(red: 0.33, green: 0.12, blue: 0.29)
        case "brown": return Color(red: 0.28, green: 0.16, blue: 0.10)
        default: return .black
        }
    }
}

private struct WidgetReading {
    let number: Int
    let unit: String
    let isFuture: Bool

    var direction: String { isFuture ? "Осталось" : "Прошло" }

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

// Each widget can pick a different event using Edit Widget → Событие.
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
        SharedEvents.all()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { WidgetEventOption(id: $0.id.uuidString, title: $0.title) }
    }

    func suggestedEntities() async throws -> [WidgetEventOption] {
        SharedEvents.all()
            .map { WidgetEventOption(id: $0.id.uuidString, title: $0.title) }
    }

    func defaultResult() async -> WidgetEventOption? {
        guard let first = SharedEvents.all().first else { return nil }
        return WidgetEventOption(id: first.id.uuidString, title: first.title)
    }
}

struct SelectCountEventIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Выбрать событие"
    static var description = IntentDescription("Какое событие показывать на этом виджете")

    @Parameter(title: "Событие", description: "Оставьте пустым для ближайшего события")
    var event: WidgetEventOption?

    init() {}
}

private struct CountEntry: TimelineEntry {
    let date: Date
    let event: WidgetEvent?
    let reading: WidgetReading
}

private struct CountProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountEntry {
        CountEntry(date: .now, event: nil,
                   reading: WidgetReading(number: 42, unit: "days", isFuture: true))
    }

    func snapshot(for configuration: SelectCountEventIntent, in context: Context) async -> CountEntry {
        makeEntry(at: .now, configuration: configuration)
    }

    func timeline(for configuration: SelectCountEventIntent, in context: Context) async -> Timeline<CountEntry> {
        let now = Date()
        let entry = makeEntry(at: now, configuration: configuration)
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        var next = midnight.addingTimeInterval(10)

        if let event = entry.event {
            let seconds = event.date.date(in: calendar).timeIntervalSince(now)
            if seconds > 0 {
                if (event.unit ?? "automatic") == "automatic" {
                    for threshold in [86_400.0, 3_600.0] {
                        if seconds > threshold {
                            let transition = now.addingTimeInterval(seconds - threshold + 1)
                            next = min(next, transition)
                        }
                    }
                }
                if entry.reading.unit == "minutes" {
                    next = min(next, now.addingTimeInterval(60))
                } else if entry.reading.unit == "hours" {
                    next = min(next, now.addingTimeInterval(300))
                }
                next = min(next, event.date.date(in: calendar).addingTimeInterval(2))
            }
        }
        if let event = entry.event, event.countsUp == true {
            // Refresh elapsed counters too, not just countdowns.
            if entry.reading.unit == "minutes" {
                next = min(next, now.addingTimeInterval(60))
            } else if entry.reading.unit == "hours" {
                next = min(next, now.addingTimeInterval(300))
            }
            let elapsed = now.timeIntervalSince(event.date.date())
            for threshold in [3_600.0, 86_400.0] where elapsed < threshold {
                next = min(next, now.addingTimeInterval(threshold - elapsed + 1))
            }
        }
        return Timeline(entries: [entry], policy: .after(max(now.addingTimeInterval(30), next)))
    }

    private func makeEntry(at now: Date, configuration: SelectCountEventIntent) -> CountEntry {
        let events = SharedEvents.all()
        let selected: WidgetEvent?
        if let id = configuration.event?.id, let chosen = events.first(where: { $0.id.uuidString == id }) {
            selected = chosen
        } else {
            let future = events.filter { $0.date.date() >= now }
                .sorted { $0.date.date() < $1.date.date() }
            let past = events.filter { $0.date.date() < now }
                .sorted { $0.date.date() > $1.date.date() }
            selected = (future + past).first
        }
        return CountEntry(date: now, event: selected,
                          reading: selected?.reading(now: now)
                            ?? WidgetReading(number: 0, unit: "days", isFuture: true))
    }
}

private struct WidgetBackground: View {
    let event: WidgetEvent?

    var body: some View {
        GeometryReader { proxy in
            if let event,
               let image = SharedEvents.photo(named: event.photoFilename) {
                let scale = max(proxy.size.width / max(image.size.width, 1),
                                proxy.size.height / max(image.size.height, 1))
                    * CGFloat(min(max(event.photoZoom ?? 1, 1), 2.5))
                let width = image.size.width * scale
                let height = image.size.height * scale
                let x = (width - proxy.size.width) * CGFloat(0.5 - (event.photoFocusX ?? 0.5))
                let y = (height - proxy.size.height) * CGFloat(0.5 - (event.photoFocusY ?? 0.5))
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: width, height: height)
                    .position(x: proxy.size.width / 2 + x, y: proxy.size.height / 2 + y)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(event.maskColor.opacity(min(max(event.maskOpacity ?? 0.55, 0), 0.9)))
            } else if let color = event?.backgroundColor {
                color
            } else {
                LinearGradient(colors: event?.colors ?? [.indigo, .purple],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

private struct CountWidgetFace: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: CountEntry

    private var style: WidgetCardStyle { entry.event?.style ?? .standard }

    private var numberSize: CGFloat {
        (family == .systemMedium ? 112 : 91) * CGFloat(min(max(style.scale, 0.7), 1.6))
    }

    private var numberText: some View {
        Text(entry.reading.number, format: .number)
            .font(.system(size: numberSize, weight: style.weight, design: style.design))
            .tracking(-3)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .monospacedDigit()
    }

    private var unitText: some View {
        Text(entry.reading.label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("\(entry.event?.title ?? "Дни") · \(entry.reading.number) \(entry.reading.label)")
                    .lineLimit(1)
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(entry.reading.number, format: .number)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Text(entry.reading.unit == "days" ? "ДНЕЙ" : entry.reading.unit == "hours" ? "ЧАСОВ" : "МИН")
                        .font(.system(size: 9, weight: .bold))
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.event?.title ?? "Добавь событие")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(entry.reading.number, format: .number)
                            .font(.system(size: 34, weight: .bold, design: .serif))
                        Text(entry.reading.label)
                            .font(.caption.weight(.medium))
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    Text(entry.reading.direction.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                }
            case .systemMedium:
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.reading.direction.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                        Text(entry.event?.title ?? "Создай событие")
                            .font(.system(size: 21, weight: style.weight, design: style.design))
                            .lineLimit(2)
                        if let dateLabel = entry.event?.dateLabel {
                            Text(dateLabel)
                                .font(.caption.weight(.medium))
                                .opacity(0.85)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(entry.reading.number, format: .number)
                            .font(.system(size: 76 * CGFloat(min(max(style.scale, 0.7), 1.6)),
                                          weight: style.weight, design: style.design))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                        Text(entry.reading.label)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .foregroundStyle(style.color)
                .padding(2)
            default:
                VStack(alignment: style.centered ? .center : .leading, spacing: 5) {
                    Text(entry.reading.direction.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1)
                    Spacer(minLength: 0)
                    Text(entry.reading.number, format: .number)
                        .font(.system(size: 74 * CGFloat(min(max(style.scale, 0.7), 1.6)),
                                      weight: style.weight, design: style.design))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                    Text(entry.reading.label)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(entry.event?.title ?? "Создай событие")
                        .font(.system(size: 15, weight: style.weight, design: style.design))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: style.centered ? .center : .leading)
                .foregroundStyle(style.color)
                .padding(2)
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackground(event: entry.event)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.event?.title ?? "Дни"). \(entry.reading.direction): \(entry.reading.number) \(entry.reading.label)")
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
        .description("Выберите событие для каждого виджета")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct CountDownWidgets: WidgetBundle {
    var body: some Widget {
        CountDownWidget()
    }
}

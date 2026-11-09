import SwiftUI
import WidgetKit

private struct Day: Decodable {
    let year: Int
    let month: Int
    let day: Int
    func value(_ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }
}
private struct Event: Decodable {
    let id: UUID
    let title: String
    let date: Day
    let palette: String
    let symbol: String
    func days(_ now: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date.value(calendar))).day ?? 0
    }
}
private struct Entry: TimelineEntry {
    let date: Date
    let event: Event?
    let days: Int
}
private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, event: nil, days: 12) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(makeEntry(.now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        completion(Timeline(entries: [makeEntry(now)], policy: .after(midnight.addingTimeInterval(5))))
    }
    private func makeEntry(_ now: Date) -> Entry {
        let data = UserDefaults(suiteName: "group.com.slavny1.countdown")?.data(forKey: "countdown.events.v1")
        let events = data.flatMap { try? JSONDecoder().decode([Event].self, from: $0) } ?? []
        let calendar = Calendar.current
        let upcoming = events.filter { $0.days(now, calendar) >= 0 }.sorted { $0.days(now, calendar) < $1.days(now, calendar) }
        let previous = events.filter { $0.days(now, calendar) < 0 }.sorted { $0.days(now, calendar) > $1.days(now, calendar) }
        let event = (upcoming + previous).first
        return Entry(date: now, event: event, days: event?.days(now, calendar) ?? 0)
    }
}
private struct WidgetFace: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family
    private var word: String {
        let n = abs(entry.days)
        if n % 10 == 1 && n % 100 != 11 { return "день" }
        if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return "дня" }
        return "дней"
    }
    private var background: [Color] {
        switch entry.event?.palette {
        case "ocean": [.cyan, .blue]
        case "violet": [.purple, .indigo]
        case "forest": [.green, .teal]
        default: [.orange, .pink]
        }
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("\(entry.event?.title ?? "Событие"): \(abs(entry.days)) \(word)")
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text(abs(entry.days), format: .number).font(.system(.title, design: .rounded, weight: .black)).minimumScaleFactor(0.5)
                    Text("ДНЕЙ").font(.system(size: 9, weight: .bold))
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.event?.title ?? "Добавь событие").font(.caption.weight(.medium)).lineLimit(1)
                    Text("\(abs(entry.days)) \(word)").font(.title2.weight(.black))
                    Text(entry.days > 0 ? "ДО СОБЫТИЯ" : entry.days < 0 ? "ПРОШЛО" : "СЕГОДНЯ").font(.system(size: 9, weight: .bold))
                }
            default:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: entry.event?.symbol ?? "calendar")
                        Spacer()
                        Text(entry.days > 0 ? "ДО СОБЫТИЯ" : entry.days < 0 ? "ПРОШЛО" : "СЕГОДНЯ")
                            .font(.system(size: 9, weight: .heavy))
                    }
                    Spacer(minLength: 0)
                    Text(abs(entry.days), format: .number)
                        .font(.system(size: family == .systemMedium ? 72 : 56, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text(word).font(.caption.weight(.bold))
                    Text(entry.event?.title ?? "Считай моменты").font(.headline.weight(.bold)).lineLimit(2)
                }
                .foregroundStyle(.white).padding(6)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: background, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
struct CountDownWidget: Widget {
    let kind = "CountDownWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in WidgetFace(entry: entry) }
            .configurationDisplayName("Счётчик дат")
            .description("Дни до ближайшего события или с последнего события")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
@main
struct CountDownWidgets: WidgetBundle {
    var body: some Widget { CountDownWidget() }
}

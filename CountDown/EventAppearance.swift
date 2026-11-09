import SwiftUI
import UIKit

extension EventPalette {
    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .coral: colors = [Color(red: 0.94, green: 0.45, blue: 0.36), Color(red: 0.64, green: 0.23, blue: 0.43)]
        case .ocean: colors = [Color(red: 0.18, green: 0.54, blue: 0.72), Color(red: 0.11, green: 0.27, blue: 0.52)]
        case .violet: colors = [Color(red: 0.65, green: 0.48, blue: 0.86), Color(red: 0.35, green: 0.25, blue: 0.57)]
        case .forest: colors = [Color(red: 0.30, green: 0.62, blue: 0.50), Color(red: 0.11, green: 0.37, blue: 0.39)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension PhotoMask {
    var color: Color {
        switch self {
        case .black: .black
        case .navy: Color(red: 0.08, green: 0.16, blue: 0.34)
        case .plum: Color(red: 0.33, green: 0.12, blue: 0.29)
        case .brown: Color(red: 0.28, green: 0.16, blue: 0.10)
        }
    }
}

struct EventBackground: View {
    let event: CountEvent

    var body: some View {
        GeometryReader { proxy in
            if let image = EventPhotoStore.image(named: event.photoFilename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(event.mask.color.opacity(event.maskOpacity))
            } else {
                event.palette.gradient
            }
        }
    }
}

struct EventNumber: View {
    let reading: CountReading
    let large: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(reading.number, format: .number)
                .font(.system(size: large ? (reading.isFuture ? 72 : 86) : 62,
                              weight: .bold, design: .serif))
                .tracking(-3)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .accessibilityHidden(true)
            Text(reading.unitLabel)
                .font(.system(size: large ? 17 : 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reading.number) \(reading.unitLabel)")
    }
}

struct EventCard: View {
    let event: CountEvent
    let now: Date

    private var reading: CountReading { DayCount.reading(for: event, now: now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                Image(systemName: event.symbol)
                    .font(.subheadline.weight(.bold))
                Text(reading.direction.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                Spacer()
                if event.showsMilestones {
                    Image(systemName: "circle.hexagongrid")
                        .font(.subheadline)
                        .accessibilityLabel("Круглые даты включены")
                }
            }
            Spacer(minLength: 2)
            EventNumber(reading: reading, large: false)
            HStack(alignment: .firstTextBaseline) {
                Text(event.title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .lineLimit(1)
                Spacer()
                Text(event.date.date().formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption.weight(.medium))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 176)
        .background { EventBackground(event: event) }
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title). \(reading.direction), \(reading.number) \(reading.unitLabel).")
        .accessibilityHint("Нажмите, чтобы открыть заметку. Смахните влево для редактирования.")
    }
}

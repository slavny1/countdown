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
        case .sand: colors = [Color(red: 0.91, green: 0.74, blue: 0.52), Color(red: 0.64, green: 0.46, blue: 0.33)]
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

extension CardThickness {
    var fontWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}

extension CardTypeface {
    var fontDesign: Font.Design {
        switch self {
        case .editorial: .serif
        case .modern: .default
        case .soft: .rounded
        case .mono: .monospaced
        }
    }
}

extension CardStyle {
    var textColor: Color { Color(rgbHex: textColorHex) }

    var swiftUIAlignment: Alignment {
        alignment == .center ? .center : .leading
    }

    var horizontalAlignment: HorizontalAlignment {
        alignment == .center ? .center : .leading
    }
}

extension Color {
    init(rgbHex: String) {
        let raw = rgbHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(raw, radix: 16) ?? 0xFFFFFF
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255,
                  opacity: 1)
    }

    var rgbHex: String {
        let color = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "FFFFFF" }
        return String(format: "%02X%02X%02X",
                      Int((red * 255).rounded()), Int((green * 255).rounded()),
                      Int((blue * 255).rounded()))
    }
}

struct EventBackground: View {
    let event: CountEvent
    var previewImage: UIImage? = nil

    var body: some View {
        GeometryReader { proxy in
            if let image = previewImage ?? EventPhotoStore.image(named: event.photoFilename) {
                let scale = max(proxy.size.width / max(image.size.width, 1),
                                proxy.size.height / max(image.size.height, 1))
                    * CGFloat(min(max(event.photoZoom, 1), 2.5))
                let fullWidth = image.size.width * scale
                let fullHeight = image.size.height * scale
                let offsetX = (fullWidth - proxy.size.width) * CGFloat(0.5 - event.photoFocusX)
                let offsetY = (fullHeight - proxy.size.height) * CGFloat(0.5 - event.photoFocusY)
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fullWidth, height: fullHeight)
                    .position(x: proxy.size.width / 2 + offsetX,
                              y: proxy.size.height / 2 + offsetY)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(Color(rgbHex: event.maskColorHex).opacity(event.maskOpacity))
            } else if let hex = event.backgroundColorHex {
                Color(rgbHex: hex)
            } else {
                event.palette.gradient
            }
        }
    }
}

struct EventNumber: View {
    let reading: CountReading
    let large: Bool
    var style: CardStyle = CardStyle()

    private var size: CGFloat {
        (large ? 84 : 65) * CGFloat(min(max(style.scale, 0.7), 1.6))
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(reading.number, format: .number)
                .font(.system(size: size, weight: style.thickness.fontWeight,
                              design: style.typeface.fontDesign))
                .monospacedDigit()
                .tracking(-2)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .contentTransition(.numericText())
            Text(reading.unitLabel)
                .font(.system(size: large ? 18 : 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(style.textColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reading.number) \(reading.unitLabel)")
    }
}

struct EventTimeDisplay: View {
    let event: CountEvent
    let now: Date
    let large: Bool

    private var phase: EventPhase { DayCount.phase(for: event, now: now) }
    private var readings: [CountReading] { DayCount.readings(for: event, now: now) }
    private var scale: CGFloat { CGFloat(min(max(event.style.scale, 0.7), 1.6)) }

    var body: some View {
        Group {
            if phase == .now {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: large ? 28 : 22))
                        .symbolEffect(.bounce, value: phase)
                    Text("СЕЙЧАС")
                        .font(.system(size: (large ? 64 : 48) * scale,
                                      weight: event.style.thickness.fontWeight,
                                      design: event.style.typeface.fontDesign))
                        .tracking(-1.7)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .shadow(color: event.style.textColor.opacity(0.3), radius: 15)
            } else if readings.count == 1, let reading = readings.first {
                EventNumber(reading: reading, large: large, style: event.style)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: large ? 20 : 9) {
                    ForEach(readings.indices, id: \.self) { index in
                        let reading = readings[index]
                        VStack(alignment: .leading, spacing: 1) {
                            Text(reading.number, format: .number)
                                .font(.system(size: (large ? 49 : 40) * scale,
                                              weight: event.style.thickness.fontWeight,
                                              design: event.style.typeface.fontDesign))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.45)
                            Text(reading.unitLabel)
                                .font(.system(size: large ? 14 : 12, weight: .semibold,
                                              design: .rounded))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .foregroundStyle(event.style.textColor)
        .accessibilityElement(children: .combine)
    }
}

struct EventCard: View {
    let event: CountEvent
    let now: Date
    var previewImage: UIImage? = nil

    private var phase: EventPhase { DayCount.phase(for: event, now: now) }
    private var isNow: Bool { phase == .now }
    private var scale: CGFloat { CGFloat(min(max(event.style.scale, 0.7), 1.6)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: isNow ? "sparkles" : event.symbol)
                    .font(.subheadline.weight(.bold))
                Text(isNow ? "ЭТОТ ДЕНЬ НАСТАЛ" :
                     event.countsUp || event.date.date() < now ? "ПРОШЛО" : "ОСТАЛОСЬ")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                Spacer(minLength: 0)
                if event.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.subheadline)
                        .accessibilityLabel("Закреплено")
                }
            }
            Spacer(minLength: 6)
            EventTimeDisplay(event: event, now: now, large: false)
                .frame(maxWidth: .infinity, alignment: event.style.swiftUIAlignment)
            HStack(alignment: .bottom, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 20 * scale, weight: event.style.thickness.fontWeight,
                                  design: event.style.typeface.fontDesign))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .layoutPriority(1)
                Spacer(minLength: 2)
                Text(event.date.displayLabel)
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(event.style.textColor)
        .padding(19)
        .frame(maxWidth: .infinity, minHeight: 178 + max(0, scale - 1) * 74 + (isNow ? 20 : 0),
               alignment: .leading)
        .background { EventBackground(event: event, previewImage: previewImage) }
        .overlay {
            if isNow {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(event.style.textColor.opacity(0.55), lineWidth: 1.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .animation(.spring(response: 0.7, dampingFraction: 0.7), value: isNow)
        .animation(.easeInOut(duration: 0.25), value: event.style.scale)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Нажмите для заметки; удерживайте для перемещения")
    }
}

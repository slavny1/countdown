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

    private var numberSize: CGFloat {
        (large ? (reading.isFuture ? 72 : 86) : 62) * CGFloat(min(max(style.scale, 0.7), 1.6))
    }

    var body: some View {
        Group {
            if style.unitPlacement == .beside {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    numberText
                    unitText
                }
            } else {
                VStack(alignment: style.horizontalAlignment, spacing: -4) {
                    numberText
                    unitText
                }
            }
        }
        .foregroundStyle(style.textColor)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reading.number) \(reading.unitLabel)")
    }

    private var numberText: some View {
        Text(reading.number, format: .number)
            .font(.system(size: numberSize, weight: style.thickness.fontWeight, design: style.typeface.fontDesign))
            .tracking(-2)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.35)
            .contentTransition(.numericText())
    }

    private var unitText: some View {
        Text(reading.unitLabel)
            .font(.system(size: large ? 17 : 14, weight: .semibold, design: .rounded))
            .lineLimit(1)
    }
}

struct EventCard: View {
    let event: CountEvent
    let now: Date
    var previewImage: UIImage? = nil

    private var reading: CountReading { DayCount.reading(for: event, now: now) }

    var body: some View {
        VStack(alignment: event.style.horizontalAlignment, spacing: 7) {
            HStack(alignment: .center) {
                Image(systemName: event.symbol)
                    .font(.subheadline.weight(.bold))
                Text(reading.direction.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                Spacer()
                if event.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.subheadline)
                        .accessibilityLabel("Закреплённое событие")
                }
            }
            Spacer(minLength: 2)
            EventNumber(reading: reading, large: false, style: event.style)
                .frame(maxWidth: .infinity, alignment: event.style.swiftUIAlignment)
            HStack(alignment: .firstTextBaseline) {
                Text(event.title)
                    .font(.system(size: 20 * CGFloat(min(max(event.style.scale, 0.7), 1.6)),
                                  weight: event.style.thickness.fontWeight,
                                  design: event.style.typeface.fontDesign))
                    .lineLimit(1)
                Spacer()
                Text(event.date.displayLabel)
                    .font(.caption.weight(.medium))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(event.style.textColor)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 176)
        .background { EventBackground(event: event, previewImage: previewImage) }
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title). \(reading.direction), \(reading.number) \(reading.unitLabel).")
        .accessibilityHint("Нажмите, чтобы открыть заметку. Смахните влево для редактирования.")
    }
}

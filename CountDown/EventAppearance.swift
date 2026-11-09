import SwiftUI

extension EventPalette {
    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .coral:
            colors = [Color(red: 0.98, green: 0.37, blue: 0.38), Color(red: 0.65, green: 0.20, blue: 0.44)]
        case .ocean:
            colors = [Color(red: 0.16, green: 0.63, blue: 0.83), Color(red: 0.12, green: 0.35, blue: 0.74)]
        case .violet:
            colors = [Color(red: 0.59, green: 0.44, blue: 0.91), Color(red: 0.35, green: 0.27, blue: 0.64)]
        case .forest:
            colors = [Color(red: 0.20, green: 0.68, blue: 0.51), Color(red: 0.10, green: 0.40, blue: 0.43)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct EventCard: View {
    let event: CountEvent

    var body: some View {
        let distance = DayCount.signedDays(to: event.date)

        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Image(systemName: event.symbol)
                    .font(.title2.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                Text(DayCount.status(distance))
                    .font(.caption2.weight(.heavy))
                    .tracking(1.8)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(abs(distance), format: .number)
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(DayCount.dayWord(distance))
                    .font(.title2.weight(.bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.title2.weight(.heavy))
                    .lineLimit(2)
                Text(event.date.date().formatted(.dateTime.day().month(.wide).year()))
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(event.palette.gradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(abs(distance)) \(DayCount.dayWord(distance)), \(DayCount.status(distance).lowercased())")
    }
}

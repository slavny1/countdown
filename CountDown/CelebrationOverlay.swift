import SwiftUI

/// A lightweight, original fireworks animation rendered only for a milestone
/// that has reached its scheduled day. No timer or persistent background work.
struct CelebrationOverlay: View {
    let event: CountEvent
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.animation) { clock in
            ZStack {
                Color.black.opacity(0.78)
                    .ignoresSafeArea()

                Canvas { context, size in
                    let seconds = clock.date.timeIntervalSinceReferenceDate
                    for burst in 0..<5 {
                        let phase = (seconds * 0.37 + Double(burst) * 0.21)
                            .truncatingRemainder(dividingBy: 1)
                        let center = CGPoint(
                            x: size.width * (0.20 + Double(burst % 3) * 0.30),
                            y: size.height * (0.17 + Double(burst / 3) * 0.18)
                        )
                        for particle in 0..<22 {
                            let angle = Double(particle) * (Double.pi * 2 / 22)
                            let radius = 9 + phase * 118
                            let x = center.x + cos(angle) * radius
                            let y = center.y + sin(angle) * radius
                            let diameter = 2.5 + 3.5 * (1 - phase)
                            let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                            let color = Color(hue: (Double(burst) * 0.17 +
                                                     Double(particle % 5) * 0.04)
                                                .truncatingRemainder(dividingBy: 1),
                                              saturation: 0.72, brightness: 1)
                                .opacity((1 - phase) * 0.92)
                            context.fill(Path(ellipseIn: rect), with: .color(color))
                        }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                VStack(spacing: 24) {
                    VStack(spacing: 7) {
                        Image(systemName: "party.popper.fill")
                            .font(.system(size: 42))
                            .symbolEffect(.bounce)
                        Text("Этот день настал!")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                        Text(event.title)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .foregroundStyle(.white)

                    EventCard(event: event, now: clock.date)
                        .frame(maxWidth: 440)
                        .shadow(color: .white.opacity(0.14), radius: 30)
                        .scaleEffect(1.03)

                    Text("Коснись экрана, чтобы продолжить")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 26)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
        }
        .transition(.opacity)
    }
}

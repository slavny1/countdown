import SwiftUI

/// Celebration stays at normal card size; no duplicate title or extra icon.
/// The rest of the interface is dimmed until the user dismisses it.
struct CelebrationOverlay: View {
    let event: CountEvent
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.animation) { clock in
            GeometryReader { proxy in
                ZStack {
                    Color.black.opacity(0.76)
                        .ignoresSafeArea()

                    Canvas { context, size in
                        let seconds = clock.date.timeIntervalSinceReferenceDate
                        for burst in 0..<4 {
                            let phase = (seconds * 0.40 + Double(burst) * 0.24)
                                .truncatingRemainder(dividingBy: 1)
                            let center = CGPoint(
                                x: size.width * (0.15 + Double(burst % 3) * 0.32),
                                y: size.height * (0.16 + Double(burst / 3) * 0.20))
                            for particle in 0..<20 {
                                let angle = Double(particle) * (Double.pi * 2 / 20)
                                let radius = 10 + phase * 95
                                let position = CGRect(
                                    x: center.x + cos(angle) * radius,
                                    y: center.y + sin(angle) * radius,
                                    width: 4, height: 4)
                                let color = Color(
                                    hue: (Double(burst) * 0.18 + Double(particle % 5) * 0.045)
                                        .truncatingRemainder(dividingBy: 1),
                                    saturation: 0.67, brightness: 1)
                                    .opacity(0.9 * (1 - phase))
                                context.fill(Path(ellipseIn: position), with: .color(color))
                            }
                        }
                    }
                    .allowsHitTesting(false)

                    VStack(spacing: 0) {
                        Text("Этот день настал")
                            .font(.system(size: 18, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .padding(.bottom, 18)

                        EventCard(event: event, now: clock.date)
                            .frame(width: min(max(260, proxy.size.width - 36), 410))
                            .shadow(color: .white.opacity(0.12), radius: 22)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
            }
        }
        .transition(.opacity)
    }
}

import SwiftUI
import UIKit

struct EventDetail: View {
    let event: CountEvent
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: EventStore
    @State private var showingSettings = false

    private var currentEvent: CountEvent {
        store.events.first(where: { $0.id == event.id }) ?? event
    }

    private func restart() {
        var updated = currentEvent
        updated.date = CalendarDay(date: .now, includesTime: true, includesSeconds: true)
        updated.countsUp = true
        store.update(updated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let liveEvent = currentEvent
            let reading = DayCount.reading(for: liveEvent, now: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: liveEvent.style.horizontalAlignment, spacing: 12) {
                        HStack {
                            Image(systemName: liveEvent.symbol)
                            Text(reading.direction.uppercased())
                                .font(.caption2.weight(.heavy))
                                .tracking(1.5)
                            Spacer()
                        }
                        EventNumber(reading: reading, large: true, style: liveEvent.style)
                            .frame(maxWidth: .infinity, alignment: liveEvent.style.swiftUIAlignment)
                        Text(liveEvent.title)
                            .font(.system(size: 32 * CGFloat(min(max(liveEvent.style.scale, 0.7), 1.6)),
                                          weight: liveEvent.style.thickness.fontWeight,
                                          design: liveEvent.style.typeface.fontDesign))
                        Text(liveEvent.date.displayLabel)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(liveEvent.style.textColor)
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: 310, alignment: .leading)
                    .background { EventBackground(event: liveEvent) }
                    .clipShape(RoundedRectangle(cornerRadius: 30))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Заметка")
                            .font(.title2.bold())
                        if liveEvent.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Пока нет заметки. Её можно добавить через свайп влево → Изменить.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(liveEvent.note)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Виджеты")
                                .font(.title2.bold())
                            Spacer()
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title3)
                                    .frame(width: 38, height: 38)
                                    .background(.thinMaterial, in: Circle())
                            }
                            .accessibilityLabel("Настроить виджеты")
                        }
                        HStack {
                            WidgetCardPreview(event: liveEvent,
                                              image: EventPhotoStore.image(named: liveEvent.photoFilename),
                                              wide: false)
                                .frame(width: 172, height: 172)
                            Spacer()
                        }
                        WidgetCardPreview(event: liveEvent,
                                          image: EventPhotoStore.image(named: liveEvent.photoFilename),
                                          wide: true)
                            .frame(height: 172)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let milestone = EventMilestones.next(for: liveEvent, now: context.date) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Круглая дата", systemImage: "sparkles")
                                .font(.headline)
                            Text(milestone.title)
                                .font(.system(size: 28, weight: .bold, design: .serif))
                            Text(milestone.date.formatted(.dateTime.day().month(.wide).year()))
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                if liveEvent.countsUp {
                    Button {
                        restart()
                    } label: {
                        Label("Обнулить счётчик", systemImage: "arrow.counterclockwise")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
                }
                .padding(20)
            }
        }
        .navigationTitle("Событие")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Настроить", systemImage: "slider.horizontal.3") {
                    showingSettings = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") { dismiss() }
            }
        }
        .sheet(isPresented: $showingSettings) {
            EventEditor(event: currentEvent).environmentObject(store)
        }
    }
}

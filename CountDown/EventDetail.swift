import SwiftUI

struct EventDetail: View {
    let event: CountEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let reading = DayCount.reading(for: event, now: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: event.symbol)
                            Text(reading.direction.uppercased())
                                .font(.caption2.weight(.heavy))
                                .tracking(1.5)
                            Spacer()
                        }
                        EventNumber(reading: reading, large: true)
                        Text(event.title)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                        Text(event.date.date().formatted(.dateTime.day().month(.wide).year()))
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(28)
                    .frame(maxWidth: .infinity, minHeight: 310, alignment: .leading)
                    .background { EventBackground(event: event) }
                    .clipShape(RoundedRectangle(cornerRadius: 30))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Заметка")
                            .font(.title2.bold())
                        if event.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Пока нет заметки. Её можно добавить через свайп влево → Изменить.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(event.note)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let milestone = EventMilestones.next(for: event, now: context.date) {
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
                .padding(20)
            }
        }
        .navigationTitle("Событие")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") { dismiss() }
            }
        }
    }
}

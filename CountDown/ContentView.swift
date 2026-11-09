import SwiftUI
import UIKit

private enum EditorRoute: Identifiable {
    case create
    case edit(CountEvent)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let event): event.id.uuidString
        }
    }
    var event: CountEvent? {
        if case .edit(let event) = self { return event }
        return nil
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editor: EditorRoute?
    @State private var selectedEvent: CountEvent?

    private var sortedEvents: [CountEvent] {
        store.events.sorted { $0.date.date() < $1.date.date() }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Дни")
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .tracking(-2.5)
                            .accessibilityAddTraits(.isHeader)
                        Text("Даты, которые имеют значение")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editor = .create
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .frame(width: 46, height: 46)
                            .background(.primary.opacity(0.08), in: Circle())
                    }
                    .accessibilityLabel("Добавить событие")
                    .accessibilityIdentifier("addEvent")
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                if store.events.isEmpty {
                    ContentUnavailableView {
                        Label("Нет событий", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Добавь дату, которую ждёшь или хочешь сохранить.")
                    } actions: {
                        Button("Создать") { editor = .create }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        List {
                            ForEach(sortedEvents) { event in
                                Button {
                                    selectedEvent = event
                                } label: {
                                    EventCard(event: event, now: context.date)
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        editor = .edit(event)
                                    } label: {
                                        Label("Изменить", systemImage: "pencil")
                                    }
                                    .tint(.indigo)
                                    Button(role: .destructive) {
                                        store.remove(event)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .animation(reduceMotion ? nil : .smooth, value: store.events)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editor) { route in
                EventEditor(event: route.event)
                    .environmentObject(store)
            }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    EventDetail(event: store.events.first(where: { $0.id == event.id }) ?? event)
                }
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(EventStore())
}

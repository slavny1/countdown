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
    @State private var expandedNotes: Set<UUID> = []

    private var sortedEvents: [CountEvent] {
        store.events.enumerated().sorted { left, right in
            if left.element.isPinned != right.element.isPinned { return left.element.isPinned }
            return left.offset < right.offset
        }.map(\.element)
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
                                VStack(spacing: 0) {
                                    Button {
                                        if event.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            selectedEvent = event
                                        } else {
                                            if expandedNotes.contains(event.id) {
                                                expandedNotes.remove(event.id)
                                            } else {
                                                expandedNotes.insert(event.id)
                                            }
                                        }
                                    } label: {
                                        EventCard(event: event, now: context.date)
                                    }
                                    .buttonStyle(.plain)
                                    if expandedNotes.contains(event.id) && !event.note.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ScrollView(.vertical) {
                                                Text(event.note)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .font(.body)
                                                    .textSelection(.enabled)
                                            }
                                            .frame(maxHeight: 160)
                                            Button {
                                                selectedEvent = event
                                            } label: {
                                                Label("Открыть событие", systemImage: "arrow.up.right")
                                                    .font(.caption.weight(.semibold))
                                            }
                                        }
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                                    in: UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
                                        .padding(.horizontal, 5)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        store.togglePin(event)
                                    } label: {
                                        Label(event.isPinned ? "Открепить" : "Закрепить",
                                              systemImage: event.isPinned ? "pin.slash" : "pin")
                                    }
                                    .tint(.orange)
                                    Button { editor = .edit(event) } label: {
                                        Label("Изменить", systemImage: "pencil")
                                    }
                                    .tint(.indigo)
                                    Button(role: .destructive) {
                                        store.remove(event)
                                        expandedNotes.remove(event.id)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                                .draggable(event.id.uuidString)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                                    store.move(id, before: event.id)
                                    return true
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

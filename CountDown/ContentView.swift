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
    @State private var editor: EditorRoute?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sortedEvents: [CountEvent] {
        store.events.sorted { $0.date.date() < $1.date.date() }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("КАЖДЫЙ ДЕНЬ ИМЕЕТ ЗНАЧЕНИЕ")
                            .font(.caption2.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        Text("Считай моменты.")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .tracking(-1)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Spacer(minLength: 10)
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        editor = .create
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.bold))
                            .frame(width: 52, height: 52)
                            .background(.primary.opacity(0.09), in: Circle())
                    }
                    .accessibilityLabel("Добавить событие")
                    .accessibilityIdentifier("addEvent")
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 14)

                if store.events.isEmpty {
                    ContentUnavailableView {
                        Label("Пока нет событий", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Сохрани дату, которую ждёшь или хочешь помнить.")
                    } actions: {
                        Button("Создать событие") { editor = .create }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sortedEvents) { event in
                            Button {
                                editor = .edit(event)
                            } label: {
                                EventCard(event: event)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { store.remove(event) } label: {
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
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editor) { route in
                EventEditor(event: route.event)
                    .environmentObject(store)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EventStore())
}

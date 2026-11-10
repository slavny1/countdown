import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Dragging is tracked by ID rather than asynchronously reading the item provider:
/// dropEntered can reorder immediately with a spring, while the drag preview stays visible.
private struct CardReorderDelegate: DropDelegate {
    let target: CountEvent
    @Binding var draggedID: UUID?
    let store: EventStore

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedID, draggedID != target.id,
              let source = store.events.first(where: { $0.id == draggedID }) else { return false }
        return source.isPinned == target.isPinned
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != target.id else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
            store.move(draggedID, before: target.id)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

private enum EditorRoute: Identifiable {
    case create, edit(CountEvent)
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
    @State private var draggedID: UUID?
    @State private var openedPreset: WidgetPreset?
    @AppStorage("days.celebrations.dismissed") private var dismissedCelebrations = ""

    private func celebrationKey(for event: CountEvent) -> String {
        "\(event.id.uuidString)-\(event.date.year)-\(event.date.month)-\(event.date.day)"
    }

    private func canCelebrate(_ event: CountEvent, at date: Date) -> Bool {
        DayCount.phase(for: event, now: date) == .now &&
        !dismissedCelebrations.split(separator: "|").contains(Substring(celebrationKey(for: event)))
    }

    private func dismissCelebration(_ event: CountEvent) {
        let key = celebrationKey(for: event)
        withAnimation(.easeOut(duration: 0.45)) {
            dismissedCelebrations = dismissedCelebrations + "|" + key
        }
    }

    private var sortedEvents: [CountEvent] {
        store.events.enumerated()
            .sorted {
                $0.element.isPinned == $1.element.isPinned
                    ? $0.offset < $1.offset
                    : $0.element.isPinned
            }
            .map(\.element)
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
                    List {
                        ForEach(sortedEvents) { event in
                            VStack(spacing: -19) {
                                Button {
                                    guard !event.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                        selectedEvent = event
                                        return
                                    }
                                    withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.88)) {
                                        if !expandedNotes.insert(event.id).inserted {
                                            expandedNotes.remove(event.id)
                                        }
                                    }
                                } label: {
                                    TimelineView(.periodic(from: .now, by: 15)) { clock in
                                        EventCard(event: event, now: clock.date)
                                    }
                                }
                                .buttonStyle(.plain)
                                .zIndex(1)

                                if expandedNotes.contains(event.id) && !event.note.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        ScrollView(.vertical) {
                                            Text(event.note)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .font(.body)
                                                .textSelection(.enabled)
                                        }
                                        .frame(maxHeight: 155)
                                        Button {
                                            selectedEvent = event
                                        } label: {
                                            Label("Открыть событие", systemImage: "arrow.up.right")
                                                .font(.caption.weight(.semibold))
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 32)
                                    .padding(.bottom, 15)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    withAnimation(.spring(response: 0.48, dampingFraction: 0.87)) {
                                        store.togglePin(event)
                                    }
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
                                    withAnimation {
                                        store.remove(event)
                                        expandedNotes.remove(event.id)
                                    }
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                            .onDrag {
                                draggedID = event.id
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                return NSItemProvider(object: event.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.plainText],
                                    delegate: CardReorderDelegate(target: event,
                                                                  draggedID: $draggedID,
                                                                  store: store))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .animation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.87),
                               value: sortedEvents.map(\.id))
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editor) { route in
                EventEditor(event: route.event).environmentObject(store)
            }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    EventDetail(event: store.events.first(where: { $0.id == event.id }) ?? event)
                }
            }
            .sheet(item: $openedPreset) { preset in
                if let event = store.events.first(where: { $0.id == preset.eventID }) {
                    WidgetPresetEditor(event: event, existing: preset)
                        .environmentObject(store)
                }
            }
            .overlay {
                TimelineView(.periodic(from: .now, by: 1)) { clock in
                    if let event = sortedEvents.first(where: { canCelebrate($0, at: clock.date) }) {
                        CelebrationOverlay(event: event) {
                            dismissCelebration(event)
                        }
                    }
                }
            }
            .onOpenURL { url in
                guard url.scheme == "dni", url.host == "widget",
                      let id = UUID(uuidString: url.lastPathComponent),
                      let preset = store.widgetPresets.first(where: { $0.id == id }) else { return }
                openedPreset = preset
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(EventStore())
}

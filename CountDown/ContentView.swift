import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Live reordering keeps the dragged cell at its insertion point. The system
/// drag preview uses only EventCard rather than a List row/background snapshot.
private struct CardReorderDelegate: DropDelegate {
    let target: CountEvent
    @Binding var draggedID: UUID?
    @Binding var dropTargetID: UUID?
    let store: EventStore

    private var canMove: Bool {
        guard let draggedID,
              let item = store.events.first(where: { $0.id == draggedID }) else { return false }
        return item.isPinned == target.isPinned
    }

    func validateDrop(info: DropInfo) -> Bool {
        canMove
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != target.id, canMove else { return }
        withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.82)) {
            dropTargetID = target.id
            store.move(draggedID, before: target.id, persist: false)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: canMove ? .move : .forbidden)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard canMove else {
            draggedID = nil
            dropTargetID = nil
            return false
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            draggedID = nil
            dropTargetID = nil
        }
        store.finishReordering()
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
    @State private var dropTargetID: UUID?
    @State private var openedPreset: WidgetPreset?
    @State private var openedWidgetEvent: CountEvent?
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
                            VStack(spacing: 0) {
                                Button {
                                    guard !event.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                        selectedEvent = event
                                        return
                                    }
                                    withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
                                        if expandedNotes.contains(event.id) {
                                            expandedNotes.remove(event.id)
                                        } else {
                                            expandedNotes.insert(event.id)
                                        }
                                    }
                                } label: {
                                    TimelineView(.periodic(from: .now, by: 15)) { clock in
                                        EventCard(event: event, now: clock.date)
                                    }
                                }
                                .buttonStyle(.plain)

                                if expandedNotes.contains(event.id) && !event.note.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ScrollView(.vertical) {
                                            Text(event.note)
                                                .font(.body)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .textSelection(.enabled)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxHeight: 185)
                                        .scrollIndicators(.visible)

                                        Button {
                                            selectedEvent = event
                                        } label: {
                                            Label("Открыть событие", systemImage: "arrow.up.right")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.top, 17)
                                    .padding(.bottom, 18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 25))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(210))
                                        withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                                            store.togglePin(event)
                                        }
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
                            .overlay(alignment: .top) {
                                if dropTargetID == event.id && draggedID != nil {
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .frame(height: 5)
                                        .padding(.horizontal, 10)
                                        .offset(y: -9)
                                        .shadow(color: Color.accentColor.opacity(0.3), radius: 5)
                                        .allowsHitTesting(false)
                                }
                            }
                            .opacity(draggedID == event.id ? 0.12 : 1)
                            .overlay {
                                if draggedID == event.id {
                                    RoundedRectangle(cornerRadius: 25)
                                        .strokeBorder(Color.accentColor.opacity(0.65),
                                                      style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                                        .allowsHitTesting(false)
                                }
                            }
                            .onDrag {
                                draggedID = event.id
                                dropTargetID = nil
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                return NSItemProvider(object: event.id.uuidString as NSString)
                            } preview: {
                                EventCard(event: event, now: .now)
                                    .frame(width: 325)
                                    .clipShape(RoundedRectangle(cornerRadius: 25,
                                                                style: .continuous))
                                    .contentShape(.dragPreview,
                                                  RoundedRectangle(cornerRadius: 25))
                            }
                            .onDrop(of: [UTType.plainText],
                                    delegate: CardReorderDelegate(target: event,
                                                                  draggedID: $draggedID,
                                                                  dropTargetID: $dropTargetID,
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
            .sheet(item: $openedWidgetEvent) { event in
                WidgetGallery(eventID: event.id)
                    .environmentObject(store)
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
                guard url.scheme == "dni",
                      let id = UUID(uuidString: url.lastPathComponent) else { return }
                if url.host == "widget",
                   let preset = store.widgetPresets.first(where: { $0.id == id }) {
                    openedPreset = preset
                } else if url.host == "event",
                          let event = store.events.first(where: { $0.id == id }) {
                    openedWidgetEvent = event
                }
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(EventStore())
}

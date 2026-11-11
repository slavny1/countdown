import SwiftUI
import UIKit

private struct CardFramePreference: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect],
                       nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
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

private struct LiftedCard {
    let event: CountEvent
    let frame: CGRect
    var translation: CGSize = .zero
    let framesAtLift: [UUID: CGRect]
    let initialIndex: Int
}

struct ContentView: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var editor: EditorRoute?
    @State private var selectedEventID: UUID?
    @State private var expandedNoteID: UUID?
    @State private var lifted: LiftedCard?
    @State private var insertionIndex: Int?
    @State private var frames: [UUID: CGRect] = [:]
    @State private var swipedID: UUID?
    @State private var openedPreset: WidgetPreset?
    @State private var openedWidgetEvent: CountEvent?
    @AppStorage("days.celebrations.dismissed") private var dismissedCelebrations = ""

    private var sortedEvents: [CountEvent] {
        store.events.enumerated().sorted { left, right in
            if left.element.isPinned != right.element.isPinned {
                return left.element.isPinned
            }
            return left.offset < right.offset
        }.map(\.element)
    }

    private func group(for event: CountEvent) -> [CountEvent] {
        sortedEvents.filter { $0.isPinned == event.isPinned }
    }

    private func celebrationKey(for event: CountEvent) -> String {
        "\(event.id.uuidString)-\(event.date.year)-\(event.date.month)-\(event.date.day)"
    }

    private func canCelebrate(_ event: CountEvent, at now: Date) -> Bool {
        DayCount.phase(for: event, now: now) == .now &&
        !dismissedCelebrations.split(separator: "|")
            .contains(Substring(celebrationKey(for: event)))
    }

    private func dismissCelebration(_ event: CountEvent) {
        withAnimation(.easeOut(duration: 0.45)) {
            dismissedCelebrations += "|" + celebrationKey(for: event)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

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
                    cardList
                }
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedEventID) { id in
                if let event = store.events.first(where: { $0.id == id }) {
                    EventDetail(event: event)
                        .environmentObject(store)
                        .toolbar(.visible, for: .navigationBar)
                }
            }
            .sheet(item: $editor) { route in
                EventEditor(event: route.event)
                    .environmentObject(store)
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

    private var header: some View {
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
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 13) {
                ForEach(sortedEvents) { event in
                    VStack(spacing: 0) {
                        if isInsertionBefore(event) {
                            insertionMarker
                        }

                        cardRow(event)

                        if isInsertionAfter(event) {
                            insertionMarker
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .animation(reduceMotion ? nil : .spring(response: 0.43, dampingFraction: 0.89),
                       value: insertionIndex)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.9),
                       value: sortedEvents.map(\.id))
            .animation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.88),
                       value: expandedNoteID)
        }
        .scrollDisabled(lifted != nil)
        .coordinateSpace(name: "eventList")
        .onPreferenceChange(CardFramePreference.self) { frames = $0 }
        .overlay(alignment: .topLeading) {
            if let lifted {
                EventCard(event: lifted.event, now: .now)
                    .frame(width: lifted.frame.width)
                    .scaleEffect(reduceMotion ? 1 : 1.025)
                    .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
                    .position(x: lifted.frame.midX + lifted.translation.width,
                              y: lifted.frame.midY + lifted.translation.height)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .accessibilityIdentifier("eventList")
    }

    private var insertionMarker: some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(height: 5)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 5)
            .accessibilityLabel("Место вставки карточки")
    }

    private func isInsertionBefore(_ event: CountEvent) -> Bool {
        guard let lifted, let insertionIndex else { return false }
        let groupMembers = group(for: lifted.event).filter { $0.id != lifted.event.id }
        return groupMembers.indices.contains(insertionIndex) &&
            groupMembers[insertionIndex].id == event.id
    }

    private func isInsertionAfter(_ event: CountEvent) -> Bool {
        guard let lifted, let insertionIndex else { return false }
        let groupMembers = group(for: lifted.event).filter { $0.id != lifted.event.id }
        return !groupMembers.isEmpty && insertionIndex == groupMembers.count &&
            groupMembers.last?.id == event.id
    }

    private func cardRow(_ event: CountEvent) -> some View {
        let isOpen = expandedNoteID == event.id
        let isLifted = lifted?.event.id == event.id

        return ZStack(alignment: .trailing) {
            if lifted == nil || swipedID == event.id {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    actionButton("Закрепить", icon: event.isPinned ? "pin.slash" : "pin",
                                 color: .orange) {
                        swipedID = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(180))
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                                store.togglePin(event)
                            }
                        }
                    }
                    actionButton("Изменить", icon: "pencil", color: .indigo) {
                        swipedID = nil
                        editor = .edit(event)
                    }
                    actionButton("Удалить", icon: "trash", color: .red) {
                        swipedID = nil
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                            store.remove(event)
                            if expandedNoteID == event.id { expandedNoteID = nil }
                        }
                    }
                }
                .padding(.trailing, 5)
            }

            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 15)) { clock in
                    EventCard(event: event, now: clock.date)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: CardFramePreference.self,
                                    value: [event.id: geometry.frame(in: .named("eventList"))]
                                )
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 25))
                        // Recognize the long press before the ScrollView's pan and
                        // the card's short tap. This must be attached to the card,
                        // not the surrounding swipe-action container.
                        .highPriorityGesture(liftGesture(for: event))
                        .onTapGesture {
                            guard lifted == nil else { return }
                            if swipedID != nil {
                                withAnimation(.easeOut(duration: 0.2)) { swipedID = nil }
                            } else {
                                // A short tap never lifts a card or navigates full-screen.
                                // It reveals its compact details panel; the link below
                                // is the deliberate action for opening the event page.
                                withAnimation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.9)) {
                                    expandedNoteID = expandedNoteID == event.id ? nil : event.id
                                }
                            }
                        }
                }

                if isOpen {
                    VStack(alignment: .leading, spacing: 12) {
                        if !event.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ScrollView(.vertical) {
                                Text(event.note)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 180)
                            .scrollIndicators(.visible)
                        }

                        Button {
                            selectedEventID = event.id
                        } label: {
                            Label("Открыть событие", systemImage: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 19)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .transition(.opacity)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .opacity(isLifted ? 0.08 : (lifted == nil ? 1 : 0.83))
            .overlay {
                if lifted != nil && !isLifted {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.black.opacity(0.14))
                        .allowsHitTesting(false)
                }
            }
            .offset(x: swipedID == event.id && lifted == nil ? -228 : 0)
            .simultaneousGesture(swipeGesture(for: event))
        }
        .accessibilityElement(children: .contain)
    }

    private func actionButton(_ label: String, icon: String, color: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.body.weight(.semibold))
                Text(label).font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(width: 67, height: 65)
            .background(color, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }

    private func swipeGesture(for event: CountEvent) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard lifted == nil,
                      abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                withAnimation(.easeOut(duration: 0.23)) {
                    if value.translation.width < -48 {
                        swipedID = event.id
                    } else if value.translation.width > 48 {
                        swipedID = nil
                    }
                }
            }
    }

    private func liftGesture(for event: CountEvent) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4, maximumDistance: 20)
            .sequenced(before: DragGesture(minimumDistance: 0,
                                           coordinateSpace: .named("eventList")))
            .onChanged { phase in
                switch phase {
                case .first(true):
                    beginLift(for: event)
                case .second(true, let motion):
                    // On some iOS versions the sequenced gesture does not
                    // emit .first(true) when the pan recognizer is already
                    // tracking the touch. The second phase must also lift.
                    if let motion {
                        updateLift(for: event, translation: motion.translation)
                    } else {
                        beginLift(for: event)
                    }
                default:
                    break
                }
            }
            .onEnded { phase in
                switch phase {
                case .first, .second:
                    endLift()
                }
            }
    }

    private func beginLift(for event: CountEvent) {
        guard lifted == nil, let frame = frames[event.id] else { return }
        let initial = group(for: event).firstIndex(where: { $0.id == event.id }) ?? 0
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.78)) {
            lifted = LiftedCard(event: event, frame: frame, framesAtLift: frames,
                                initialIndex: initial)
            insertionIndex = initial
            swipedID = nil
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func updateLift(for event: CountEvent, translation: CGSize) {
        if lifted == nil { beginLift(for: event) }
        guard var state = lifted, state.event.id == event.id else { return }
        state.translation = translation
        lifted = state

        let fingerY = state.frame.midY + translation.height
        let candidates = group(for: state.event).filter { $0.id != state.event.id }
        let insertion = candidates.firstIndex {
            fingerY < (state.framesAtLift[$0.id]?.midY ?? .greatestFiniteMagnitude)
        } ?? candidates.count

        if insertionIndex != insertion {
            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85)) {
                insertionIndex = insertion
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func endLift() {
        guard let state = lifted else { return }
        let target = insertionIndex ?? state.initialIndex
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
            store.reorder(state.event.id, toGroupIndex: target)
            insertionIndex = nil
            lifted = nil
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    ContentView().environmentObject(EventStore())
}

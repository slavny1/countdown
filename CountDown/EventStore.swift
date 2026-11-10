import SwiftUI
import WidgetKit

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [CountEvent] = EventRepository.load()

    func add(_ event: CountEvent) {
        events.append(event)
        persist()
    }

    func update(_ event: CountEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
        persist()
    }

    func togglePin(_ event: CountEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].isPinned.toggle()
        persist()
    }

    func move(_ draggedID: UUID, before targetID: UUID) {
        guard draggedID != targetID,
              let from = events.firstIndex(where: { $0.id == draggedID }),
              let destination = events.firstIndex(where: { $0.id == targetID }) else { return }
        var reordered = events
        var moved = reordered.remove(at: from)
        let target = reordered.first(where: { $0.id == targetID })!
        moved.isPinned = target.isPinned
        if let to = reordered.firstIndex(where: { $0.id == targetID }) {
            reordered.insert(moved, at: to)
        }
        events = reordered
        persist()
    }

    func remove(_ event: CountEvent) {
        events.removeAll { $0.id == event.id }
        EventPhotoStore.remove(named: event.photoFilename)
        persist()
    }

    private func persist() {
        _ = EventRepository.save(events)
        WidgetCenter.shared.reloadTimelines(ofKind: "CountDownWidget")
    }
}

import Foundation
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

    func remove(_ event: CountEvent) {
        events.removeAll { $0.id == event.id }
        persist()
    }

    private func persist() {
        _ = EventRepository.save(events)
        WidgetCenter.shared.reloadTimelines(ofKind: "CountDownWidget")
    }
}

import SwiftUI
import WidgetKit

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [CountEvent] = EventRepository.load()
    @Published private(set) var widgetPresets: [WidgetPreset] = WidgetPresetRepository.load()

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
              let source = events.firstIndex(where: { $0.id == draggedID }),
              let target = events.firstIndex(where: { $0.id == targetID }),
              events[source].isPinned == events[target].isPinned else { return }
        let moved = events.remove(at: source)
        guard let destination = events.firstIndex(where: { $0.id == targetID }) else { return }
        events.insert(moved, at: destination)
        persist()
    }

    func addPreset(_ preset: WidgetPreset) {
        widgetPresets.append(preset)
        persistPresets()
    }

    func updatePreset(_ preset: WidgetPreset) {
        guard let index = widgetPresets.firstIndex(where: { $0.id == preset.id }) else { return }
        widgetPresets[index] = preset
        persistPresets()
    }

    func removePreset(_ preset: WidgetPreset) {
        widgetPresets.removeAll { $0.id == preset.id }
        EventPhotoStore.remove(named: preset.photoFilename)
        persistPresets()
    }

    private func persistPresets() {
        _ = WidgetPresetRepository.save(widgetPresets)
        WidgetCenter.shared.reloadTimelines(ofKind: "CountDownWidget")
    }

    func remove(_ event: CountEvent) {
        events.removeAll { $0.id == event.id }
        EventPhotoStore.remove(named: event.photoFilename)
        let orphaned = widgetPresets.filter { $0.eventID == event.id }
        orphaned.forEach { EventPhotoStore.remove(named: $0.photoFilename) }
        widgetPresets.removeAll { $0.eventID == event.id }
        persistPresets()
        persist()
    }

    private func persist() {
        _ = EventRepository.save(events)
        WidgetCenter.shared.reloadTimelines(ofKind: "CountDownWidget")
    }
}

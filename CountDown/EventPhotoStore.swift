import Foundation
import UIKit

enum EventPhotoStore {
    private static var folder: URL? {
        guard let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: EventRepository.appGroup
        ) else { return nil }
        let directory = group.appendingPathComponent("EventPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func image(named filename: String?) -> UIImage? {
        guard let filename,
              let folder,
              let data = try? Data(contentsOf: folder.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: data)
    }

    static func save(_ original: UIImage, for id: UUID) -> String? {
        guard let folder else { return nil }
        let maximum: CGFloat = 1600
        let ratio = min(1, maximum / max(original.size.width, original.size.height))
        let size = CGSize(width: max(1, original.size.width * ratio),
                          height: max(1, original.size.height * ratio))
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in original.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = rendered.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = id.uuidString + ".jpg"
        do {
            try data.write(to: folder.appendingPathComponent(filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func remove(named filename: String?) {
        guard let filename, let folder else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(filename))
    }
}

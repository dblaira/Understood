import UIKit

enum LocalImageStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recall-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func save(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: dir.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(name).path)
    }

    static func data(_ name: String?) -> Data? {
        guard let name else { return nil }
        return try? Data(contentsOf: dir.appendingPathComponent(name))
    }

    @discardableResult
    static func write(_ data: Data, name: String) -> String? {
        do {
            try data.write(to: dir.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path)
    }
}

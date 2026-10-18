import AppKit
import Foundation

/// 账号头像：走 Roblox 公开缩略图接口，落盘缓存。
final class AvatarStore {
    static let shared = AvatarStore()

    private var memory: [Int: NSImage] = [:]
    private var inFlight = Set<Int>()
    private let queue = DispatchQueue(label: "epmulti.avatar", qos: .utility)
    private let dir: URL

    private init() {
        dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/epmulti/avatars")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func cached(_ id: Int) -> NSImage? {
        if let m = memory[id] { return m }
        let p = dir.appendingPathComponent("\(id).png")
        if let img = NSImage(contentsOf: p), img.isValid {
            memory[id] = img
            return img
        }
        return nil
    }

    /// 有缓存立刻回调；没有就去拉，回调在主线程。
    func load(_ id: Int, done: @escaping (NSImage?) -> Void) {
        if let m = cached(id) { done(m); return }
        queue.async {
            if self.inFlight.contains(id) { return }
            self.inFlight.insert(id)
            defer { self.inFlight.remove(id) }

            guard let img = self.fetch(id) else {
                DispatchQueue.main.async { done(nil) }
                return
            }
            self.memory[id] = img
            if let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: self.dir.appendingPathComponent("\(id).png"))
            }
            DispatchQueue.main.async { done(img) }
        }
    }

    private func fetch(_ id: Int) -> NSImage? {
        let meta = "https://thumbnails.roblox.com/v1/users/avatar-headshot"
            + "?userIds=\(id)&size=150x150&format=Png&isCircular=true"
        guard let metaURL = URL(string: meta),
              let data = try? Data(contentsOf: metaURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["data"] as? [[String: Any]],
              let imageURL = arr.first?["imageUrl"] as? String,
              let imgURL = URL(string: imageURL),
              let imgData = try? Data(contentsOf: imgURL)
        else { return nil }
        return NSImage(data: imgData)
    }
}

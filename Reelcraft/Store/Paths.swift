import Foundation

enum Paths {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var media: URL { ensure(documents.appendingPathComponent("Media", isDirectory: true)) }
    static var thumbs: URL { ensure(documents.appendingPathComponent("Thumbs", isDirectory: true)) }
    static var renders: URL { ensure(documents.appendingPathComponent("Renders", isDirectory: true)) }
    static var voice: URL { ensure(documents.appendingPathComponent("Voice", isDirectory: true)) }

    static var projectsFile: URL { documents.appendingPathComponent("projects.json") }
    static var ideasFile: URL { documents.appendingPathComponent("ideas.json") }
    static var exportsFile: URL { documents.appendingPathComponent("exports.json") }

    @discardableResult
    static func ensure(_ url: URL) -> URL {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func mediaURL(for clip: Clip) -> URL {
        media.appendingPathComponent(clip.fileName)
    }

    static func thumbURL(for clip: Clip) -> URL? {
        clip.thumbnailURL
    }

    static func removeMedia(named fileName: String) {
        try? FileManager.default.removeItem(at: media.appendingPathComponent(fileName))
    }

    static func removeThumb(named name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: thumbs.appendingPathComponent(name))
    }
}

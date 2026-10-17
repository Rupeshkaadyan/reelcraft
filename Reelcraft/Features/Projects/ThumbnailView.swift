import SwiftUI
import UIKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func clear() {
        cache.removeAllObjects()
    }
}

struct LocalThumbnail: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    Theme.canvasGradient
                    Image(systemName: "film")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
        }
        .task(id: url?.path) {
            guard let url else { return }
            if let cached = ThumbnailCache.shared.image(for: url) {
                image = cached
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)
            }.value
            if !Task.isCancelled { image = loaded }
        }
    }
}

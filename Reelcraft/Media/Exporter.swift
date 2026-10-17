import Foundation
import AVFoundation
import Photos
import UIKit

enum ExportQuality: String, CaseIterable, Identifiable {
    case fullHD, ultraHD

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHD: return "1080p HD"
        case .ultraHD: return "4K UHD"
        }
    }

    var subtitle: String {
        switch self {
        case .fullHD: return "Fast export, great for social"
        case .ultraHD: return "Sharpest detail, slower export"
        }
    }

    var scale: CGFloat {
        switch self {
        case .fullHD: return 1
        case .ultraHD: return 2
        }
    }
}

enum ExportError: LocalizedError {
    case noExporter
    case cancelled
    case failed(String)
    case photoDenied

    var errorDescription: String? {
        switch self {
        case .noExporter: return "This device cannot export the video."
        case .cancelled: return "Export cancelled."
        case .failed(let message): return "Export failed: \(message)"
        case .photoDenied: return "Photo access is off. Allow it in Settings to save the video."
        }
    }
}

enum Exporter {

    static func export(project: VideoProject, quality: ExportQuality, onProgress: @escaping (Double) -> Void) async throws -> URL {
        let base = project.aspect.renderSize
        let renderSize = CGSize(width: base.width * quality.scale, height: base.height * quality.scale)
        let built = try await CompositionBuilder.build(project: project, renderSize: renderSize)

        let fileName = "Reelcraft-\(project.name.replacingOccurrences(of: " ", with: "-"))-\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = Paths.renders.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        guard let session = AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.noExporter
        }
        session.videoComposition = built.videoComposition
        session.audioMix = built.audioMix
        session.outputURL = outputURL
        session.outputFileType = session.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
        session.shouldOptimizeForNetworkUse = true

        let pollTask = Task {
            while !Task.isCancelled {
                let progress = Double(session.progress)
                await MainActor.run { onProgress(progress) }
                if session.status != .waiting && session.status != .exporting { break }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }

        await withCheckedContinuation { continuation in
            session.exportAsynchronously { continuation.resume() }
        }
        pollTask.cancel()
        await MainActor.run { onProgress(1) }

        switch session.status {
        case .completed:
            return outputURL
        case .cancelled:
            throw ExportError.cancelled
        default:
            let detail = session.error.map { "\($0.localizedDescription) (code \((($0 as NSError).code)))" } ?? "unknown error"
            throw ExportError.failed(detail)
        }
    }

    static func saveToPhotos(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ExportError.photoDenied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ExportError.failed(error?.localizedDescription ?? "could not save to Photos"))
                }
            })
        }
    }
}

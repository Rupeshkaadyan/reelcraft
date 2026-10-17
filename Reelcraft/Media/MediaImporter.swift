import Foundation
import AVFoundation
import UIKit
import CoreTransferable
import UniformTypeIdentifiers

/// A movie picked from the photo library, copied into app storage first.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = Paths.media.appendingPathComponent("\(UUID().uuidString).\(ext)")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedMovie(url: destination)
        }
    }
}

struct ImportedClip {
    let fileName: String
    let thumbnailName: String?
    let duration: Double
    let width: Double
    let height: Double
    let hasAudio: Bool
    let hasVideo: Bool
}

enum MediaImportError: LocalizedError {
    case noVideoTrack
    case unreadable
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "That file has no video track."
        case .unreadable: return "Reelcraft could not read that video."
        case .exportFailed(let message): return "Could not prepare the clip: \(message)"
        }
    }
}

enum MediaImporter {

    /// Normalises orientation, copies into the library and makes a poster frame.
    static func importVideo(at inputURL: URL) async throws -> ImportedClip {
        let asset = AVURLAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        guard duration.seconds.isFinite, duration.seconds > 0.05 else { throw MediaImportError.unreadable }
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw MediaImportError.noVideoTrack
        }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)

        let transformed = naturalSize.applying(transform)
        let cleanWidth = max(2, abs(transformed.width).rounded())
        let cleanHeight = max(2, abs(transformed.height).rounded())

        let needsTransform = !transform.isIdentity
        let ext = needsTransform ? "mov" : (inputURL.pathExtension.isEmpty ? "mov" : inputURL.pathExtension)
        let fileName = "\(UUID().uuidString).\(ext)"
        let outputURL = Paths.media.appendingPathComponent(fileName)

        if needsTransform {
            let composition = AVMutableComposition()
            guard let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw MediaImportError.unreadable
            }
            try videoCompositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
            if let audioTrack, let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? audioCompositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: audioTrack, at: .zero)
            }

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
            layerInstruction.setTransform(transform, at: .zero)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
            instruction.layerInstructions = [layerInstruction]

            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = [instruction]
            videoComposition.renderSize = CGSize(width: even(cleanWidth), height: even(cleanHeight))
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                throw MediaImportError.exportFailed("no exporter available")
            }
            exporter.videoComposition = videoComposition
            exporter.outputURL = outputURL
            exporter.outputFileType = .mov
            exporter.shouldOptimizeForNetworkUse = false
            try await runExport(exporter)
        } else {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.copyItem(at: inputURL, to: outputURL)
        }

        let thumbnailName = try await makeThumbnail(for: outputURL, preferredTransform: needsTransform ? .identity : transform, naturalSize: needsTransform ? CGSize(width: even(cleanWidth), height: even(cleanHeight)) : naturalSize)

        return ImportedClip(
            fileName: fileName,
            thumbnailName: thumbnailName,
            duration: duration.seconds,
            width: needsTransform ? cleanWidth : naturalSize.width,
            height: needsTransform ? cleanHeight : naturalSize.height,
            hasAudio: audioTrack != nil,
            hasVideo: true
        )
    }

    /// Creates a clip model from an already-prepared file.
    static func clip(from imported: ImportedClip) -> Clip {
        Clip(
            fileName: imported.fileName,
            sourceDuration: imported.duration,
            trimStart: 0,
            trimEnd: imported.duration,
            filter: .none,
            hasAudio: imported.hasAudio,
            hasVideo: imported.hasVideo,
            thumbnailName: imported.thumbnailName,
            sourceWidth: imported.width,
            sourceHeight: imported.height
        )
    }

    static func makeThumbnail(for url: URL, preferredTransform: CGAffineTransform = .identity, naturalSize: CGSize? = nil) async throws -> String? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let duration = (try? await asset.load(.duration).seconds) ?? 1
        let time = CMTime(seconds: min(0.2, max(0, duration * 0.1)), preferredTimescale: 600)
        do {
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            let name = "\(UUID().uuidString).jpg"
            let dest = Paths.thumbs.appendingPathComponent(name)
            if let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.82) {
                try data.write(to: dest, options: .atomic)
                return name
            }
        } catch {
            return nil
        }
        return nil
    }

    static func probe(url: URL) async -> (duration: Double, hasVideo: Bool, hasAudio: Bool) {
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds) ?? 0
        let video = (try? await asset.loadTracks(withMediaType: .video).first) != nil
        let audio = (try? await asset.loadTracks(withMediaType: .audio).first) != nil
        return (duration, video, audio)
    }

    private static func even(_ value: CGFloat) -> CGFloat {
        let rounded = Int(value.rounded())
        return CGFloat(rounded % 2 == 0 ? rounded : rounded + 1)
    }

    private static func runExport(_ exporter: AVAssetExportSession) async throws {
        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }
        switch exporter.status {
        case .completed:
            return
        case .cancelled:
            throw MediaImportError.exportFailed("cancelled")
        default:
            throw MediaImportError.exportFailed(exporter.error?.localizedDescription ?? "unknown error")
        }
    }
}

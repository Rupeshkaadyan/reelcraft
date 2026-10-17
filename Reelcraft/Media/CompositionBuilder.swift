import Foundation
import AVFoundation
import CoreImage
import UIKit

struct BuiltComposition {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    let audioMix: AVMutableAudioMix?
    let duration: Double

    var playerItem: AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        item.audioMix = audioMix
        return item
    }
}

enum CompositionBuilderError: LocalizedError {
    case emptyProject
    case noVideoTracks

    var errorDescription: String? {
        switch self {
        case .emptyProject: return "Add at least one clip to preview this project."
        case .noVideoTracks: return "None of these clips have a video track."
        }
    }
}

enum CompositionBuilder {

    static func build(project: VideoProject, renderSize requestedSize: CGSize? = nil, overlays: Bool = true) async throws -> BuiltComposition {
        guard !project.clips.isEmpty else { throw CompositionBuilderError.emptyProject }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CompositionBuilderError.noVideoTracks
        }
        var clipAudioTrack: AVMutableCompositionTrack?
        var clipAudioParams: AVMutableAudioMixInputParameters?
        var insertedClipAudio = false

        var cursor = CMTime.zero
        var filterWindows: [(start: Double, end: Double, filter: FilterPreset)] = []

        for clip in project.clips {
            let url = Paths.mediaURL(for: clip)
            let asset = AVURLAsset(url: url)
            let sourceDuration = (try? await asset.load(.duration)) ?? .zero
            guard let sourceVideo = try? await asset.loadTracks(withMediaType: .video).first else { continue }

            let start = CMTime(seconds: clip.trimStart, preferredTimescale: 600)
            let end = CMTime(seconds: min(clip.trimEnd, max(clip.trimStart + 0.05, sourceDuration.seconds)), preferredTimescale: 600)
            let range = CMTimeRange(start: start, end: end)
            guard range.duration.seconds > 0.01 else { continue }

            do {
                try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)
            } catch {
                continue
            }

            if let sourceAudio = try? await asset.loadTracks(withMediaType: .audio).first {
                if clipAudioTrack == nil {
                    clipAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    if let clipAudioTrack {
                        clipAudioParams = AVMutableAudioMixInputParameters(track: clipAudioTrack)
                    }
                }
                if let clipAudioTrack {
                    do {
                        try clipAudioTrack.insertTimeRange(range, of: sourceAudio, at: cursor)
                        insertedClipAudio = true
                    } catch {
                        // Clip without usable audio: keep the video, skip the sound.
                    }
                }
            }

            let insertedDuration = range.duration
            let rate = max(0.1, clip.speed)
            let finalDuration = CMTime(seconds: insertedDuration.seconds / rate, preferredTimescale: 600)

            if abs(rate - 1) > 0.001 {
                composition.scaleTimeRange(CMTimeRange(start: cursor, duration: insertedDuration), toDuration: finalDuration)
            }

            let clipVolume = clip.isMuted ? 0 : Float(max(0, min(1, clip.volume)))
            clipAudioParams?.setVolume(clipVolume, at: cursor)
            filterWindows.append((
                start: cursor.seconds,
                end: cursor.seconds + finalDuration.seconds,
                filter: clip.filter
            ))
            cursor = cursor + finalDuration
        }

        let totalDuration = cursor
        guard totalDuration.seconds > 0.01 else { throw CompositionBuilderError.noVideoTracks }

        // Background music, looped to cover the edit.
        var musicParams: AVMutableAudioMixInputParameters?
        if let musicURL = project.music.url,
           let musicAssetTrack = try? await AVURLAsset(url: musicURL).loadTracks(withMediaType: .audio).first,
           let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let musicAsset = AVURLAsset(url: musicURL)
            let musicDuration = (try? await musicAsset.load(.duration)) ?? CMTime(seconds: 8, preferredTimescale: 600)
            var musicCursor = CMTime.zero
            var guardCount = 0
            while musicCursor < totalDuration && guardCount < 60 {
                let remaining = totalDuration - musicCursor
                let chunk = CMTimeMinimum(musicDuration, remaining)
                if chunk.seconds <= 0.01 { break }
                try? musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: chunk), of: musicAssetTrack, at: musicCursor)
                musicCursor = musicCursor + chunk
                guardCount += 1
            }
            let params = AVMutableAudioMixInputParameters(track: musicTrack)
            let volume = Float(max(0, min(1, project.musicVolume)))
            params.setVolume(volume, at: .zero)
            if totalDuration.seconds > 1.5 {
                let fadeStart = CMTime(seconds: totalDuration.seconds - 1.2, preferredTimescale: 600)
                params.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0, timeRange: CMTimeRange(start: fadeStart, duration: CMTime(seconds: 1.2, preferredTimescale: 600)))
            }
            musicParams = params
        }

        var inputParams: [AVMutableAudioMixInputParameters] = []
        if insertedClipAudio, let clipAudioParams {
            inputParams.append(clipAudioParams)
        } else if let clipAudioTrack, clipAudioTrack.segments.isEmpty {
            // Never hand an empty audio track to the exporter.
            composition.removeTrack(clipAudioTrack)
        }
        if let musicParams { inputParams.append(musicParams) }

        let audioMix = AVMutableAudioMix()
        if !inputParams.isEmpty {
            audioMix.inputParameters = inputParams
        }

        // Text layers, pre-rendered once per build.
        let renderSize = requestedSize ?? project.aspect.renderSize
        var preparedOverlays: [(image: CIImage, start: Double, end: Double)] = []
        if overlays {
            for overlay in project.overlays {
                guard overlay.end > overlay.start,
                      let image = OverlayRenderer.image(for: overlay, renderSize: renderSize) else { continue }
                preparedOverlays.append((image, overlay.start, overlay.end))
            }
        }

        let windows = filterWindows
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            let time = max(0, request.compositionTime.seconds)
            let preset = windows.first(where: { time >= $0.start && time < $0.end })?.filter ?? .none
            var image = preset.apply(to: request.sourceImage)
            image = fill(image, into: renderSize)
            for overlay in preparedOverlays where time >= overlay.start && time <= overlay.end {
                image = overlay.image.composited(over: image)
            }
            request.finish(with: image, context: nil)
        }
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        return BuiltComposition(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: inputParams.isEmpty ? nil : audioMix,
            duration: totalDuration.seconds
        )
    }

    /// Aspect-fill the source into the project frame and centre-crop.
    static func fill(_ image: CIImage, into size: CGSize) -> CIImage {
        let extent = image.extent
        guard extent.width > 1, extent.height > 1 else { return image }
        let scale = max(size.width / extent.width, size.height / extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent
        let crop = CGRect(
            x: scaledExtent.midX - size.width / 2,
            y: scaledExtent.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let cropped = scaled.cropped(to: crop)
        return cropped.transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    }
}

import XCTest
import AVFoundation
import UIKit
@testable import Reelcraft

final class RenderPipelineTests: XCTestCase {

    override func setUp() async throws {
        try? FileManager.default.removeItem(at: Paths.projectsFile)
    }

    // MARK: Helpers

    /// Writes a short solid-colour clip so the pipeline has real media to work with.
    private func makeSampleVideo(seconds: Double, size: CGSize, color: UIColor) async throws -> ImportedClip {
        let fileName = "test-\(UUID().uuidString).mov"
        let url = Paths.media.appendingPathComponent(fileName)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )
        writer.add(input)
        XCTAssertTrue(writer.startWriting(), "writer should start: \(String(describing: writer.error))")
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let frameCount = max(1, Int(seconds * Double(fps)))
        var components = color.cgColor.components ?? [1, 1, 1, 1]
        if components.count < 3 { components = [1, 1, 1, 1] }

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { break }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let pixelBuffer = buffer else { break }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                let b = UInt8(max(0, min(1, components[2])) * 255)
                let g = UInt8(max(0, min(1, components[1])) * 255)
                let r = UInt8(max(0, min(1, components[0])) * 255)
                let ptr = base.assumingMemoryBound(to: UInt8.self)
                for row in 0..<height {
                    let rowPtr = ptr + row * bytesPerRow
                    for column in stride(from: 0, to: bytesPerRow, by: 4) {
                        rowPtr[column] = b
                        rowPtr[column + 1] = g
                        rowPtr[column + 2] = r
                        rowPtr[column + 3] = 255
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps))
        }

        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "writer should complete: \(String(describing: writer.error))")

        let thumbnail = try await MediaImporter.makeThumbnail(for: url)
        return ImportedClip(
            fileName: fileName,
            thumbnailName: thumbnail,
            duration: seconds,
            width: size.width,
            height: size.height,
            hasAudio: false,
            hasVideo: true
        )
    }

    private func makeProject(aspect: AspectRatio, clips: [ImportedClip]) -> VideoProject {
        var project = VideoProject(name: "Pipeline test", aspect: aspect)
        project.clips = clips.map { imported in
            var clip = MediaImporter.clip(from: imported)
            clip.filter = .ember
            return clip
        }
        return project
    }

    // MARK: Tests

    func testBuildsCompositionWithFiltersOverlaysAndSpeed() async throws {
        let first = try await makeSampleVideo(seconds: 1.0, size: CGSize(width: 1080, height: 1920), color: .systemOrange)
        let second = try await makeSampleVideo(seconds: 2.0, size: CGSize(width: 1920, height: 1080), color: .systemTeal)

        var project = makeProject(aspect: .square, clips: [first, second])
        project.clips[1].speed = 2               // 2s of source becomes 1s on the timeline
        project.clips[1].trimStart = 0.5
        project.clips[1].filter = .noir
        project.music = .drift
        project.overlays = [
            TextOverlay(text: "Hello Reelcraft", start: 0, duration: 1.5, position: .bottom, style: .pill),
            TextOverlay(text: "Second shot", start: 1.0, duration: 1.0, position: .top, style: .headline),
        ]

        let built = try await CompositionBuilder.build(project: project)

        // 1.0s of the first clip + (2.0 - 0.5) / 2.0 = 0.75s of the second.
        XCTAssertEqual(built.duration, 1.75, accuracy: 0.12, "timeline duration should honour trims and speed")
        XCTAssertEqual(built.videoComposition.renderSize.width, 1080)
        XCTAssertEqual(built.videoComposition.renderSize.height, 1080)
        XCTAssertEqual(built.composition.tracks(withMediaType: .video).count, 1)
        XCTAssertNotNil(built.audioMix, "music and clip audio should produce an audio mix")
    }

    func testExportsPlayableFileAtProjectAspect() async throws {
        let clip = try await makeSampleVideo(seconds: 1.2, size: CGSize(width: 1080, height: 1920), color: .systemPink)
        var project = makeProject(aspect: .square, clips: [clip])
        project.overlays = [TextOverlay(text: "Export me", start: 0, duration: 1, position: .center, style: .headline)]

        let url = try await Exporter.export(project: project, quality: .fullHD) { _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "export should write a file")
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        XCTAssertGreaterThan(size ?? 0, 2_000, "export should contain real video data")

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, 1.2, accuracy: 0.2, "exported duration should match the edit")

        let track = try await asset.loadTracks(withMediaType: .video).first
        let naturalSize = try await track?.load(.naturalSize)
        XCTAssertEqual(naturalSize?.width, 1080)
        XCTAssertEqual(naturalSize?.height, 1080, "square projects export as 1080x1080")
    }

    func testClipSpeedScalesTimelineDuration() async throws {
        let clip = try await makeSampleVideo(seconds: 2.0, size: CGSize(width: 1080, height: 1920), color: .systemGreen)
        var project = makeProject(aspect: .vertical, clips: [clip])
        project.clips[0].speed = 4
        XCTAssertEqual(project.duration, 0.5, accuracy: 0.02)

        let built = try await CompositionBuilder.build(project: project)
        XCTAssertEqual(built.duration, 0.5, accuracy: 0.05)
    }

    func testStoreRoundTripsProjectOnDisk() async throws {
        let clip = try await makeSampleVideo(seconds: 0.6, size: CGSize(width: 1080, height: 1920), color: .systemBlue)
        let store = ProjectStore()
        var project = store.createProject(name: "Round trip")
        project.clips = [MediaImporter.clip(from: clip)]
        project.music = .pulse
        store.update(project)

        let reloaded = ProjectStore()
        let found = reloaded.project(id: project.id)
        XCTAssertNotNil(found, "project should persist to disk")
        XCTAssertEqual(found?.clips.count, 1)
        XCTAssertEqual(found?.music, .pulse)
        XCTAssertEqual(found?.clips.first?.fileName, clip.fileName)
    }
}

import Foundation
import CoreGraphics
import CoreImage
import SwiftUI

// MARK: - Aspect ratio

enum AspectRatio: String, Codable, CaseIterable, Identifiable {
    case vertical, portrait, square, landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: return "9:16"
        case .portrait: return "4:5"
        case .square: return "1:1"
        case .landscape: return "16:9"
        }
    }

    var caption: String {
        switch self {
        case .vertical: return "Short-form vertical"
        case .portrait: return "Feed portrait"
        case .square: return "Square post"
        case .landscape: return "Widescreen"
        }
    }

    var renderSize: CGSize {
        switch self {
        case .vertical: return CGSize(width: 1080, height: 1920)
        case .portrait: return CGSize(width: 1080, height: 1350)
        case .square: return CGSize(width: 1080, height: 1080)
        case .landscape: return CGSize(width: 1920, height: 1080)
        }
    }

    var ratio: CGFloat { renderSize.width / renderSize.height }
}

// MARK: - Filters

enum FilterPreset: String, Codable, CaseIterable, Identifiable {
    case none, ember, vivid, fade, noir, film, cool, mint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Original"
        case .ember: return "Ember"
        case .vivid: return "Vivid"
        case .fade: return "Faded"
        case .noir: return "Noir"
        case .film: return "Film"
        case .cool: return "Cool"
        case .mint: return "Mint"
        }
    }

    var swatch: [Color] {
        switch self {
        case .none: return [Color(hex: 0x3A3A44), Color(hex: 0x1B1B21)]
        case .ember: return [Color(hex: 0xFF9A5C), Color(hex: 0xB8331B)]
        case .vivid: return [Color(hex: 0x6EC6FF), Color(hex: 0xFF5C9A)]
        case .fade: return [Color(hex: 0xD9CDBB), Color(hex: 0x8A9AA6)]
        case .noir: return [Color(hex: 0xE6E6E6), Color(hex: 0x2B2B2B)]
        case .film: return [Color(hex: 0xE7C58A), Color(hex: 0x5A4A32)]
        case .cool: return [Color(hex: 0x8FD3FF), Color(hex: 0x2D4E86)]
        case .mint: return [Color(hex: 0x9CFFC9), Color(hex: 0x1E6B4E)]
        }
    }

    /// Applies the look to an oriented source image. All filters are public Core Image presets.
    func apply(to image: CIImage) -> CIImage {
        let output: CIImage?
        switch self {
        case .none:
            return image
        case .ember:
            output = FilterPreset.chain(image, filters: [
                ("CIPhotoEffectTransfer", nil),
                ("CIColorControls", ["inputSaturation": 1.16, "inputContrast": 1.07, "inputBrightness": 0.015]),
            ])
        case .vivid:
            output = FilterPreset.chain(image, filters: [
                ("CIColorControls", ["inputSaturation": 1.42, "inputContrast": 1.09, "inputBrightness": 0.01]),
                ("CIVibrance", ["inputAmount": 0.35]),
            ])
        case .fade:
            output = FilterPreset.chain(image, filters: [
                ("CIPhotoEffectFade", nil),
                ("CIColorControls", ["inputSaturation": 0.88, "inputContrast": 0.94, "inputBrightness": 0.03]),
            ])
        case .noir:
            output = FilterPreset.chain(image, filters: [
                ("CIPhotoEffectNoir", nil),
                ("CIColorControls", ["inputContrast": 1.12]),
            ])
        case .film:
            output = FilterPreset.chain(image, filters: [
                ("CIPhotoEffectInstant", nil),
                ("CIColorControls", ["inputSaturation": 0.92, "inputContrast": 1.04]),
            ])
        case .cool:
            output = FilterPreset.chain(image, filters: [
                ("CITemperatureAndTint", nil),
                ("CIColorControls", ["inputSaturation": 1.05, "inputContrast": 1.03]),
            ])
        case .mint:
            output = FilterPreset.chain(image, filters: [
                ("CIHueAdjust", ["inputAngle": 0.28]),
                ("CIColorControls", ["inputSaturation": 1.12, "inputContrast": 1.02]),
            ])
        }
        return output ?? image
    }

    private static func chain(_ image: CIImage, filters: [(String, [String: Any]?)]) -> CIImage {
        var current = image
        for (name, params) in filters {
            guard let filter = CIFilter(name: name) else { continue }
            filter.setValue(current, forKey: kCIInputImageKey)
            if name == "CITemperatureAndTint" {
                filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                filter.setValue(CIVector(x: 7800, y: 16), forKey: "inputTargetNeutral")
            }
            if let params {
                for (key, value) in params {
                    filter.setValue(value, forKey: key)
                }
            }
            if let out = filter.outputImage {
                current = out
            }
        }
        return current
    }
}

// MARK: - Clips

struct Clip: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var fileName: String
    var sourceDuration: Double
    var trimStart: Double = 0
    var trimEnd: Double
    var speed: Double = 1
    var volume: Double = 1
    var isMuted: Bool = false
    var filter: FilterPreset = .none
    var hasAudio: Bool = true
    var hasVideo: Bool = true
    var thumbnailName: String?
    var sourceWidth: Double = 1080
    var sourceHeight: Double = 1920

    var trimmedDuration: Double { max(0.05, trimEnd - trimStart) }
    var effectiveDuration: Double { max(0.05, trimmedDuration / max(0.1, speed)) }
    var displayName: String { fileName }

    var thumbnailURL: URL? {
        guard let thumbnailName else { return nil }
        return Paths.thumbs.appendingPathComponent(thumbnailName)
    }

    var sourceSize: CGSize { CGSize(width: sourceWidth, height: sourceHeight) }
}

// MARK: - Text overlays

enum OverlayPosition: String, Codable, CaseIterable, Identifiable {
    case top, center, bottom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .top: return "Top"
        case .center: return "Middle"
        case .bottom: return "Bottom"
        }
    }
    /// Vertical centre as a fraction of render height.
    var yFraction: CGFloat {
        switch self {
        case .top: return 0.18
        case .center: return 0.5
        case .bottom: return 0.82
        }
    }
}

enum OverlayStyle: String, Codable, CaseIterable, Identifiable {
    case plain, pill, caption, headline
    var id: String { rawValue }
    var title: String {
        switch self {
        case .plain: return "Clean"
        case .pill: return "Pill"
        case .caption: return "Caption"
        case .headline: return "Headline"
        }
    }
}

struct TextOverlay: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String = "Your words"
    var start: Double = 0
    var duration: Double = 3
    var position: OverlayPosition = .bottom
    var style: OverlayStyle = .pill
    var colorHex: UInt32 = 0xF7F7F5
    var isCaption: Bool = false

    var end: Double { start + duration }
}

// MARK: - Music

enum MusicTrack: String, Codable, CaseIterable, Identifiable {
    case none, drift, pulse, hush, bloom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No music"
        case .drift: return "Drift"
        case .pulse: return "Pulse"
        case .hush: return "Hush"
        case .bloom: return "Bloom"
        }
    }

    var mood: String {
        switch self {
        case .none: return "Silent"
        case .drift: return "Warm pads"
        case .pulse: return "Steady groove"
        case .hush: return "Soft keys"
        case .bloom: return "Bright arps"
        }
    }

    var fileName: String? { self == .none ? nil : "\(rawValue).m4a" }

    var url: URL? {
        guard let fileName else { return nil }
        return Bundle.main.url(forResource: rawValue, withExtension: "m4a", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: rawValue, withExtension: "m4a")
    }
}

// MARK: - Project

struct VideoProject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "Untitled cut"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var aspect: AspectRatio = .vertical
    var clips: [Clip] = []
    var overlays: [TextOverlay] = []
    var music: MusicTrack = .none
    var musicVolume: Double = 0.35
    var exportCount: Int = 0
    var lastExportAt: Date? = nil

    var duration: Double { clips.reduce(0) { $0 + $1.effectiveDuration } }
    var isEmpty: Bool { clips.isEmpty }
    var coverClip: Clip? { clips.first }

    var coverURL: URL? { coverClip?.thumbnailURL }

    func timelineClip(at time: Double) -> (clip: Clip, index: Int, localStart: Double)? {
        var cursor = 0.0
        for (index, clip) in clips.enumerated() {
            let end = cursor + clip.effectiveDuration
            if time < end || index == clips.count - 1 {
                return (clip, index, cursor)
            }
            cursor = end
        }
        return nil
    }

    func startTime(ofClipAt index: Int) -> Double {
        clips.prefix(index).reduce(0) { $0 + $1.effectiveDuration }
    }
}

// MARK: - Templates

struct TemplatePreset: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var tagline: String
    var aspect: AspectRatio
    var filter: FilterPreset
    var overlayStyle: OverlayStyle
    var overlayPosition: OverlayPosition
    var music: MusicTrack
    var colors: [Color]
    var accentHex: UInt32
    var starterText: String

    static let all: [TemplatePreset] = [
        TemplatePreset(
            name: "Product Drop",
            tagline: "Punchy cuts, warm grade, price card",
            aspect: .vertical, filter: .ember, overlayStyle: .pill, overlayPosition: .bottom,
            music: .pulse, colors: [Color(hex: 0xFF8A4C), Color(hex: 0x8A1F0E)],
            accentHex: 0xFF8A4C, starterText: "New drop"
        ),
        TemplatePreset(
            name: "Talking Head",
            tagline: "Clean grade with caption bar",
            aspect: .vertical, filter: .vivid, overlayStyle: .caption, overlayPosition: .bottom,
            music: .hush, colors: [Color(hex: 0x7CFFB2), Color(hex: 0x12503A)],
            accentHex: 0x7CFFB2, starterText: "Here is the hook"
        ),
        TemplatePreset(
            name: "Travel Recap",
            tagline: "Faded film look, headline opener",
            aspect: .vertical, filter: .fade, overlayStyle: .headline, overlayPosition: .top,
            music: .drift, colors: [Color(hex: 0xE7C58A), Color(hex: 0x3F4E63)],
            accentHex: 0xE7C58A, starterText: "48 hours in"
        ),
        TemplatePreset(
            name: "Before / After",
            tagline: "High contrast split story",
            aspect: .square, filter: .noir, overlayStyle: .plain, overlayPosition: .center,
            music: .bloom, colors: [Color(hex: 0xE6E6E6), Color(hex: 0x1B1B21)],
            accentHex: 0xE6E6E6, starterText: "Before"
        ),
        TemplatePreset(
            name: "Lyric Card",
            tagline: "Bold type on a still",
            aspect: .portrait, filter: .cool, overlayStyle: .headline, overlayPosition: .center,
            music: .drift, colors: [Color(hex: 0x8FD3FF), Color(hex: 0x1B2C5A)],
            accentHex: 0x8FD3FF, starterText: "Say it louder"
        ),
        TemplatePreset(
            name: "Recipe Card",
            tagline: "Step captions and soft light",
            aspect: .vertical, filter: .film, overlayStyle: .caption, overlayPosition: .top,
            music: .hush, colors: [Color(hex: 0xFFC93C), Color(hex: 0x6B4A0F)],
            accentHex: 0xFFC93C, starterText: "Step 1"
        ),
    ]
}

// MARK: - Ideas

struct Idea: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var text: String
    var createdAt: Date = Date()
    var colorIndex: Int = 0
    var isDone: Bool = false
    var projectID: UUID? = nil

    static let palette: [Color] = [
        Color(hex: 0x2C2C36), Color(hex: 0x3A2418), Color(hex: 0x132E24),
        Color(hex: 0x1B2740), Color(hex: 0x3A2F12), Color(hex: 0x331A24),
    ]
    var color: Color { Idea.palette[min(max(colorIndex, 0), Idea.palette.count - 1)] }
}

// MARK: - Stats

struct ExportRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var projectName: String
    var date: Date
    var duration: Double
    var resolution: String
}

import Foundation
import Speech
import AVFoundation

struct CaptionCue {
    let text: String
    let start: Double
    let duration: Double
}

enum CaptionError: LocalizedError {
    case unavailable
    case denied
    case noSpeech
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Speech recognition is not available for this language on this device."
        case .denied: return "Speech recognition permission is off. Turn it on in Settings to auto-caption."
        case .noSpeech: return "No speech was detected in this clip."
        case .failed(let message): return "Could not transcribe: \(message)"
        }
    }
}

enum CaptionService {
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribes a prepared clip file and returns cues relative to the file.
    static func transcribe(url: URL, locale: Locale = Locale(identifier: "en-US")) async throws -> [CaptionCue] {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw CaptionError.unavailable
        }
        let asset = AVURLAsset(url: url)
        guard let audio = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw CaptionError.noSpeech
        }
        _ = audio

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.taskHint = .dictation

        let transcription: SFTranscription = try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                if let result, result.isFinal {
                    didResume = true
                    continuation.resume(returning: result.bestTranscription)
                } else if let error {
                    didResume = true
                    continuation.resume(throwing: CaptionError.failed(error.localizedDescription))
                }
            }
        }

        let segments = transcription.segments.filter { !$0.substring.isEmpty }
        guard !segments.isEmpty else { throw CaptionError.noSpeech }

        // Group words into readable cues of at most 6 words / 4 seconds.
        var cues: [CaptionCue] = []
        var buffer: [SFTranscriptionSegment] = []

        func flush() {
            guard let first = buffer.first, let last = buffer.last else { return }
            let text = buffer.map(\.substring).joined(separator: " ")
            let start = first.timestamp
            var duration = max(0.6, last.timestamp + last.duration - start)
            duration = min(duration + 0.35, 6)
            cues.append(CaptionCue(text: text, start: start, duration: duration))
            buffer.removeAll()
        }

        for segment in segments {
            if let first = buffer.first, segment.timestamp - first.timestamp > 4.0 {
                flush()
            }
            buffer.append(segment)
            if buffer.count >= 6 {
                flush()
            }
        }
        flush()
        return cues
    }
}

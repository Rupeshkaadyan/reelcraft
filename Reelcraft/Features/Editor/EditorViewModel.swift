import Foundation
import AVFoundation
import Combine

enum EditorTool: String, CaseIterable, Identifiable {
    case trim, text, filters, speed, audio, captions, frame

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trim: return "Trim"
        case .text: return "Text"
        case .filters: return "Filters"
        case .speed: return "Speed"
        case .audio: return "Audio"
        case .captions: return "Captions"
        case .frame: return "Frame"
        }
    }

    var icon: String {
        switch self {
        case .trim: return "scissors"
        case .text: return "textformat"
        case .filters: return "camera.filters"
        case .speed: return "speedometer"
        case .audio: return "speaker.wave.2"
        case .captions: return "captions.bubble"
        case .frame: return "rectangle.ratio.9.to.16"
        }
    }
}

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var project: VideoProject
    @Published var selectedClipID: UUID?
    @Published var selectedOverlayID: UUID?
    @Published var playhead: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying = false
    @Published var isBuilding = false
    @Published var buildError: String?
    @Published var captionStatus: String?
    @Published var isCaptioning = false

    let player = AVPlayer()
    private var timeObserver: Any?
    private var rebuildTask: Task<Void, Never>?
    private var undoStack: [VideoProject] = []
    private var redoStack: [VideoProject] = []
    private var hasPrepared = false

    init(project: VideoProject) {
        self.project = project
        self.duration = project.duration
        self.selectedClipID = project.clips.first?.id
        self.playhead = 0
        observeTime()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var selectedClip: Clip? {
        guard let selectedClipID else { return nil }
        return project.clips.first { $0.id == selectedClipID }
    }
    var selectedClipIndex: Int? {
        guard let selectedClipID else { return nil }
        return project.clips.firstIndex { $0.id == selectedClipID }
    }

    // MARK: Setup

    func prepare() {
        guard !hasPrepared else { return }
        hasPrepared = true
        rebuild(snapshot: project, preserveTime: 0, resume: false, immediate: true)
    }

    private func observeTime() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            if self.isPlaying {
                self.playhead = min(seconds, max(0, self.duration))
                if self.duration > 0.1, seconds >= self.duration - 0.04 {
                    self.isPlaying = false
                    self.player.pause()
                    self.playhead = self.duration
                }
            }
        }
    }

    // MARK: Build

    private func rebuild(snapshot: VideoProject, preserveTime: Double, resume: Bool, immediate: Bool) {
        rebuildTask?.cancel()
        let time = preserveTime
        rebuildTask = Task { [weak self] in
            if !immediate {
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
            guard !Task.isCancelled, let self else { return }
            self.isBuilding = true
            do {
                let built = try await CompositionBuilder.build(project: snapshot)
                guard !Task.isCancelled else { return }
                self.duration = built.duration
                self.player.pause()
                self.player.replaceCurrentItem(with: built.playerItem)
                let target = min(max(0, time), max(0, built.duration))
                await self.player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                self.playhead = target
                if resume, built.duration > 0.1 {
                    self.player.play()
                    self.isPlaying = true
                }
                self.buildError = nil
            } catch {
                self.buildError = error.localizedDescription
                self.isPlaying = false
            }
            self.isBuilding = false
        }
    }

    private func scheduleRebuild(preserveTime: Double? = nil, resume: Bool? = nil) {
        duration = project.duration
        rebuild(snapshot: project, preserveTime: preserveTime ?? playhead, resume: resume ?? isPlaying, immediate: false)
    }

    // MARK: Mutations

    func mutate(rebuild: Bool = true, _ change: (inout VideoProject) -> Void) {
        undoStack.append(project)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        change(&project)
        project.updatedAt = Date()
        if rebuild { scheduleRebuild() }
    }

    func mutateSelectedClip(_ change: (inout Clip) -> Void) {
        guard let selectedClipID else { return }
        mutate { project in
            guard let index = project.clips.firstIndex(where: { $0.id == selectedClipID }) else { return }
            change(&project.clips[index])
        }
    }

    /// Live slider changes: no undo entry per tick, rebuild is debounced.
    func mutateLive(_ change: (inout VideoProject) -> Void) {
        change(&project)
        project.updatedAt = Date()
        duration = project.duration
        scheduleRebuild()
    }

    func mutateSelectedClipLive(_ change: (inout Clip) -> Void) {
        guard let selectedClipID else { return }
        mutateLive { project in
            guard let index = project.clips.firstIndex(where: { $0.id == selectedClipID }) else { return }
            change(&project.clips[index])
        }
    }

    func updateOverlayLive(_ overlay: TextOverlay) {
        mutateLive { project in
            guard let index = project.overlays.firstIndex(where: { $0.id == overlay.id }) else { return }
            project.overlays[index] = overlay
            project.overlays.sort { $0.start < $1.start }
        }
    }

    func updateMusic(_ music: MusicTrack) {
        mutate { project in
            project.music = music
        }
    }

    func updateAspect(_ aspect: AspectRatio) {
        mutate { project in
            project.aspect = aspect
        }
        seek(to: min(playhead, project.duration))
    }

    func setMusicVolumeLive(_ volume: Double) {
        mutateLive { project in
            project.musicVolume = max(0, min(1, volume))
        }
    }

    func setClipVolumeLive(_ volume: Double) {
        mutateSelectedClipLive { clip in
            clip.volume = max(0, min(1, volume))
            clip.isMuted = volume <= 0.001
        }
    }

    func setClipSpeed(_ speed: Double) {
        mutateSelectedClip { clip in
            clip.speed = speed
        }
    }

    func toggleMuteSelectedClip() {
        mutateSelectedClip { clip in
            clip.isMuted.toggle()
            if !clip.isMuted && clip.volume < 0.05 { clip.volume = 1 }
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project)
        project = previous
        duration = previous.duration
        selectedClipID = previous.clips.first?.id
        scheduleRebuild(preserveTime: min(playhead, previous.duration), resume: false)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project)
        project = next
        duration = next.duration
        selectedClipID = next.clips.first?.id
        scheduleRebuild(preserveTime: min(playhead, next.duration), resume: false)
    }

    // MARK: Clips

    func addClip(_ clip: Clip, select: Bool = true) {
        mutate { project in
            project.clips.append(clip)
        }
        if select {
            selectedClipID = clip.id
            let start = project.startTime(ofClipAt: max(0, project.clips.count - 1))
            seek(to: start)
        }
    }

    func removeClip(id: UUID) {
        guard let index = project.clips.firstIndex(where: { $0.id == id }) else { return }
        mutate { project in
            project.clips.remove(at: index)
        }
        if selectedClipID == id {
            selectedClipID = project.clips[safe: index]?.id ?? project.clips.last?.id
        }
        if project.clips.isEmpty { seek(to: 0) }
    }

    func deleteSelectedClip() {
        guard let selectedClipID else { return }
        removeClip(id: selectedClipID)
    }

    func duplicateSelectedClip() {
        guard let index = selectedClipIndex else { return }
        var copy = project.clips[index]
        copy.id = UUID()
        mutate { project in
            project.clips.insert(copy, at: index + 1)
        }
        selectedClipID = copy.id
    }

    func moveSelectedClip(by offset: Int) {
        guard let index = selectedClipIndex else { return }
        let target = index + offset
        guard project.clips.indices.contains(target) else { return }
        mutate { project in
            project.clips.swapAt(index, target)
        }
    }

    func splitSelectedClipAtPlayhead() {
        guard let entry = project.timelineClip(at: playhead) else { return }
        let index = entry.index
        let clip = project.clips[index]
        let local = (playhead - entry.localStart) * clip.speed + clip.trimStart
        guard local > clip.trimStart + 0.15, local < clip.trimEnd - 0.15 else { return }

        var left = clip
        left.trimEnd = local
        var right = clip
        right.id = UUID()
        right.trimStart = local

        mutate { project in
            project.clips[index] = left
            project.clips.insert(right, at: index + 1)
        }
        selectedClipID = right.id
        scheduleRebuild(preserveTime: playhead, resume: false)
    }

    func resetTrim() {
        mutateSelectedClip { clip in
            clip.trimStart = 0
            clip.trimEnd = clip.sourceDuration
        }
    }

    func selectClip(_ id: UUID, seekToStart: Bool = false) {
        selectedClipID = id
        if seekToStart, let index = project.clips.firstIndex(where: { $0.id == id }) {
            seek(to: project.startTime(ofClipAt: index))
        }
    }

    func applyFilterToAll(_ filter: FilterPreset) {
        mutate { project in
            for index in project.clips.indices {
                project.clips[index].filter = filter
            }
        }
    }

    // MARK: Overlays

    func addOverlay(at playhead: Double? = nil, caption: Bool = false, text: String? = nil) {
        let start = min(playhead ?? self.playhead, max(0, duration - 0.5))
        let overlay = TextOverlay(
            text: text ?? (caption ? "New caption" : "Your words"),
            start: start,
            duration: max(1, min(caption ? 2.5 : 3, max(0.8, duration - start))),
            position: .bottom,
            style: caption ? .caption : .pill,
            isCaption: caption
        )
        mutate { project in
            project.overlays.append(overlay)
            project.overlays.sort { $0.start < $1.start }
        }
        selectedOverlayID = overlay.id
        seek(to: start)
    }

    func updateOverlay(_ overlay: TextOverlay) {
        mutate { project in
            guard let index = project.overlays.firstIndex(where: { $0.id == overlay.id }) else { return }
            project.overlays[index] = overlay
            project.overlays.sort { $0.start < $1.start }
        }
    }

    func deleteOverlay(id: UUID) {
        mutate { project in
            project.overlays.removeAll { $0.id == id }
        }
        if selectedOverlayID == id { selectedOverlayID = nil }
    }

    // MARK: Playback

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }
        if playhead >= max(0, duration - 0.08) {
            seek(to: 0)
        }
        player.play()
        isPlaying = true
    }

    func seek(to seconds: Double) {
        let clamped = min(max(0, seconds), max(0, duration))
        playhead = clamped
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func step(by seconds: Double) {
        seek(to: playhead + seconds)
    }

    // MARK: Captions

    func generateCaptions() async {
        guard !project.clips.isEmpty else {
            captionStatus = "Add a clip first."
            return
        }
        isCaptioning = true
        captionStatus = "Checking speech recognition…"
        let allowed = await CaptionService.requestPermission()
        guard allowed else {
            captionStatus = CaptionError.denied.errorDescription
            isCaptioning = false
            return
        }

        var cues: [TextOverlay] = []
        let clips = project.clips
        let starts = (0..<clips.count).map { project.startTime(ofClipAt: $0) }

        for (index, clip) in clips.enumerated() {
            captionStatus = "Listening to clip \(index + 1) of \(clips.count)…"
            let url = Paths.mediaURL(for: clip)
            do {
                let found = try await CaptionService.transcribe(url: url)
                let clipStart = starts[index]
                for cue in found {
                    let local = max(0, cue.start - clip.trimStart) / max(0.1, clip.speed)
                    let start = clipStart + local
                    let end = min(clipStart + clip.effectiveDuration, start + cue.duration / max(0.1, clip.speed))
                    guard end > start + 0.2 else { continue }
                    cues.append(TextOverlay(
                        text: cue.text,
                        start: start,
                        duration: end - start,
                        position: .bottom,
                        style: .caption,
                        isCaption: true
                    ))
                }
            } catch {
                if clips.count == 1 {
                    captionStatus = error.localizedDescription
                    isCaptioning = false
                    return
                }
            }
        }

        isCaptioning = false
        guard !cues.isEmpty else {
            captionStatus = "No speech found. Try a clip with dialogue."
            return
        }
        mutate { project in
            project.overlays.removeAll { $0.isCaption }
            project.overlays.append(contentsOf: cues)
            project.overlays.sort { $0.start < $1.start }
        }
        captionStatus = "Added \(cues.count) caption\(cues.count == 1 ? "" : "s"). Drag their timing in the Text tool."
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

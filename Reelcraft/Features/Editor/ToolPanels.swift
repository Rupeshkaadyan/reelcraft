import SwiftUI

// MARK: - Container

struct InspectorPanel<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Theme.surfaceStroke)
                .frame(width: 34, height: 4)
                .padding(.top, 7)

            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Theme.title(16)).foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle).font(Theme.body(11)).foregroundStyle(Theme.inkTertiary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 28, height: 28)
                        .background(Theme.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.gutter)

            ScrollView {
                content()
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 18)
            }
        }
        .frame(maxHeight: 310)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.surfaceStroke).frame(height: 1)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Trim

struct TrimPanel: View {
    @ObservedObject var vm: EditorViewModel
    let onClose: () -> Void

    var body: some View {
        InspectorPanel(title: "Trim clip", subtitle: vm.selectedClipIndex.map { "Clip \($0 + 1) of \(vm.project.clips.count)" }, onClose: onClose) {
            if let clip = vm.selectedClip {
                VStack(spacing: 14) {
                    rangeRow(
                        title: "In point",
                        value: Format.timecode(clip.trimStart),
                        slider: Binding(
                            get: { clip.trimStart },
                            set: { newValue in
                                vm.mutateSelectedClipLive { c in
                                    c.trimStart = min(newValue, max(0, c.trimEnd - 0.12))
                                }
                            }
                        ),
                        range: 0...max(0.12, clip.trimEnd - 0.12)
                    )

                    rangeRow(
                        title: "Out point",
                        value: Format.timecode(clip.trimEnd),
                        slider: Binding(
                            get: { clip.trimEnd },
                            set: { newValue in
                                vm.mutateSelectedClipLive { c in
                                    c.trimEnd = max(newValue, min(c.sourceDuration, c.trimStart + 0.12))
                                }
                            }
                        ),
                        range: min(clip.sourceDuration, clip.trimStart + 0.12)...max(clip.trimStart + 0.13, clip.sourceDuration)
                    )

                    HStack(spacing: 8) {
                        actionTile("Split", icon: "scissors") { vm.splitSelectedClipAtPlayhead() }
                        actionTile("Copy", icon: "plus.square.on.square") { vm.duplicateSelectedClip() }
                        actionTile("Left", icon: "arrow.left") { vm.moveSelectedClip(by: -1) }
                        actionTile("Right", icon: "arrow.right") { vm.moveSelectedClip(by: 1) }
                        actionTile("Delete", icon: "trash", danger: true) { vm.deleteSelectedClip() }
                    }

                    HStack {
                        Text("Clip length \(Format.timecode(clip.effectiveDuration)) · source \(Format.timecode(clip.sourceDuration))")
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.inkTertiary)
                        Spacer()
                        Button("Reset") { vm.resetTrim() }
                            .font(Theme.label(11))
                            .foregroundStyle(Theme.ember)
                    }
                }
            } else {
                Text("Select a clip on the timeline to trim it.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private func rangeRow(title: String, value: String, slider: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(Theme.label(11)).foregroundStyle(Theme.inkSecondary)
                Spacer()
                Text(value).font(Theme.mono(10)).foregroundStyle(Theme.ink)
            }
            Slider(value: slider, in: range)
                .tint(Theme.ember)
        }
    }

    private func actionTile(_ title: String, icon: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(title).font(Theme.body(9))
            }
            .foregroundStyle(danger ? Theme.danger : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filters

struct FilterPanel: View {
    @ObservedObject var vm: EditorViewModel
    let onClose: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: 10)]

    var body: some View {
        InspectorPanel(title: "Filters", subtitle: "Applied to the selected clip", onClose: onClose) {
            VStack(spacing: 14) {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(FilterPreset.allCases) { preset in
                        Button {
                            vm.mutateSelectedClip { $0.filter = preset }
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    LinearGradient(colors: preset.swatch, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    if vm.selectedClip?.filter == preset {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Theme.bg)
                                            .frame(width: 22, height: 22)
                                            .background(Theme.ink, in: Circle())
                                    }
                                }
                                .frame(height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .stroke(vm.selectedClip?.filter == preset ? Theme.ember : Theme.surfaceStroke, lineWidth: vm.selectedClip?.filter == preset ? 2 : 1)
                                )
                                Text(preset.title)
                                    .font(Theme.body(10))
                                    .foregroundStyle(vm.selectedClip?.filter == preset ? Theme.ink : Theme.inkSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("One grade for the whole edit keeps it cohesive.")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkTertiary)
                    Spacer()
                    Button("Apply to all") {
                        if let preset = vm.selectedClip?.filter {
                            vm.applyFilterToAll(preset)
                        }
                    }
                    .font(Theme.label(11))
                    .foregroundStyle(Theme.ember)
                    .disabled(vm.selectedClip == nil)
                }
            }
        }
    }
}

// MARK: - Text

struct TextPanel: View {
    @ObservedObject var vm: EditorViewModel
    let onClose: () -> Void

    private var overlay: TextOverlay? {
        guard let id = vm.selectedOverlayID else { return vm.project.overlays.first }
        return vm.project.overlays.first { $0.id == id } ?? vm.project.overlays.first
    }

    var body: some View {
        InspectorPanel(title: "Text", subtitle: "Overlays stay in place on the timeline", onClose: onClose) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        vm.addOverlay()
                    } label: {
                        Label("Add text", systemImage: "plus")
                            .font(Theme.label(11))
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Theme.ember, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    if !vm.project.overlays.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(vm.project.overlays) { item in
                                    Button {
                                        vm.selectedOverlayID = item.id
                                        vm.seek(to: item.start)
                                    } label: {
                                        Text(item.text.isEmpty ? "Empty" : item.text)
                                            .font(Theme.body(10))
                                            .foregroundStyle(vm.selectedOverlayID == item.id ? Theme.bg : Theme.inkSecondary)
                                            .lineLimit(1)
                                            .padding(.horizontal, 10)
                                            .frame(height: 28)
                                            .background(vm.selectedOverlayID == item.id ? Theme.ink : Theme.surfaceRaised, in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    } else {
                        Spacer()
                    }
                }

                if let overlay {
                    VStack(spacing: 10) {
                        TextField("Your words", text: Binding(
                            get: { overlay.text },
                            set: { value in
                                var copy = overlay
                                copy.text = value
                                vm.updateOverlayLive(copy)
                            }
                        ), axis: .vertical)
                        .font(Theme.body(14))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1...2)
                        .padding(10)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                                .stroke(Theme.inputStroke, lineWidth: 1)
                        )

                        HStack(spacing: 6) {
                            ForEach(OverlayStyle.allCases) { style in
                                Chip(title: style.title, selected: overlay.style == style) {
                                    var copy = overlay
                                    copy.style = style
                                    vm.updateOverlay(copy)
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            ForEach(OverlayPosition.allCases) { position in
                                Chip(title: position.title, selected: overlay.position == position) {
                                    var copy = overlay
                                    copy.position = position
                                    vm.updateOverlay(copy)
                                }
                            }
                            Spacer()
                            ForEach([UInt32(0xF7F7F5), 0xFF5C38, 0x7CFFB2, 0xFFC93C, 0x111111], id: \.self) { hex in
                                Button {
                                    var copy = overlay
                                    copy.colorHex = hex
                                    vm.updateOverlay(copy)
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle().stroke(overlay.colorHex == hex ? Theme.ember : Theme.surfaceStroke, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 12) {
                            timeSlider(title: "Start", value: overlay.start, range: 0...max(0.1, vm.duration - 0.4)) { value in
                                var copy = overlay
                                copy.start = value
                                copy.duration = min(copy.duration, max(0.4, vm.duration - value))
                                vm.updateOverlayLive(copy)
                            }
                            timeSlider(title: "Length", value: overlay.duration, range: 0.4...max(0.5, vm.duration - overlay.start)) { value in
                                var copy = overlay
                                copy.duration = value
                                vm.updateOverlayLive(copy)
                            }
                        }

                        HStack {
                            Text("\(Format.timecode(overlay.start)) → \(Format.timecode(overlay.end))")
                                .font(Theme.mono(9))
                                .foregroundStyle(Theme.inkTertiary)
                            Spacer()
                            Button {
                                vm.deleteOverlay(id: overlay.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(Theme.label(10))
                                    .foregroundStyle(Theme.danger)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("No text yet. Add a title, a hook or a credit.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            if vm.selectedOverlayID == nil {
                vm.selectedOverlayID = vm.project.overlays.first?.id
            }
        }
    }

    private func timeSlider(title: String, value: Double, range: ClosedRange<Double>, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(Theme.body(9)).foregroundStyle(Theme.inkTertiary)
                Spacer()
                Text(Format.timecode(value, showMillis: false)).font(Theme.mono(8)).foregroundStyle(Theme.inkSecondary)
            }
            Slider(value: Binding(get: { value }, set: onChange), in: range)
                .tint(Theme.ember)
        }
    }
}

// MARK: - Speed

struct SpeedPanel: View {
    @ObservedObject var vm: EditorViewModel
    let onClose: () -> Void

    var body: some View {
        InspectorPanel(title: "Speed", subtitle: "Retime the selected clip", onClose: onClose) {
            VStack(spacing: 14) {
                if let clip = vm.selectedClip {
                    Text(String(format: "%g×", clip.speed))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ember)
                    Text("\(Format.timecode(clip.sourceDuration)) source becomes \(Format.timecode(clip.effectiveDuration)) on the timeline")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        ForEach([0.25, 0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { rate in
                            Button {
                                vm.setClipSpeed(rate)
                            } label: {
                                Text(rate == 1 ? "1×" : String(format: "%g×", rate))
                                    .font(Theme.label(12))
                                    .foregroundStyle(abs(clip.speed - rate) < 0.01 ? Theme.bg : Theme.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(abs(clip.speed - rate) < 0.01 ? Theme.ember : Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Audio keeps its pitch. Slow motion above 2× reads best with a music bed.")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkTertiary)
                } else {
                    Text("Select a clip to change its speed.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
    }
}

// MARK: - Audio

struct AudioPanel: View {
    @ObservedObject var vm: EditorViewModel
    let onClose: () -> Void

    var body: some View {
        InspectorPanel(title: "Audio", subtitle: "Clip levels and music", onClose: onClose) {
            VStack(spacing: 14) {
                if let clip = vm.selectedClip {
                    HStack {
                        Label("Clip audio", systemImage: clip.isMuted ? "speaker.slash" : "speaker.wave.2")
                            .font(Theme.label(12))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Button(clip.isMuted ? "Unmute" : "Mute") {
                            vm.toggleMuteSelectedClip()
                        }
                        .font(Theme.label(11))
                        .foregroundStyle(Theme.ember)
                    }
                    Slider(value: Binding(
                        get: { clip.isMuted ? 0 : clip.volume },
                        set: { vm.setClipVolumeLive($0) }
                    ), in: 0...1)
                    .tint(Theme.ember)
                }

                Divider().overlay(Theme.surfaceStroke)

                HStack {
                    Text("Music bed").font(Theme.label(12)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(vm.project.music.title).font(Theme.body(11)).foregroundStyle(Theme.inkSecondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], spacing: 6) {
                    ForEach(MusicTrack.allCases) { track in
                        Button {
                            vm.updateMusic(track)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).font(Theme.label(10)).foregroundStyle(vm.project.music == track ? Theme.bg : Theme.ink)
                                Text(track.mood).font(Theme.body(8)).foregroundStyle(vm.project.music == track ? Theme.bg.opacity(0.7) : Theme.inkTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .frame(height: 40)
                            .background(vm.project.music == track ? Theme.ember : Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if vm.project.music != .none {
                    HStack {
                        Text("Music volume").font(Theme.body(10)).foregroundStyle(Theme.inkTertiary)
                        Slider(value: Binding(get: { vm.project.musicVolume }, set: { vm.setMusicVolumeLive($0) }), in: 0...1)
                            .tint(Theme.mint)
                        Text("\(Int(vm.project.musicVolume * 100))%")
                            .font(Theme.mono(9)).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Captions

struct CaptionsPanel: View {
    @ObservedObject var vm: EditorViewModel
    let onClose: () -> Void

    private var captions: [TextOverlay] {
        vm.project.overlays.filter(\.isCaption).sorted { $0.start < $1.start }
    }

    var body: some View {
        InspectorPanel(title: "Captions", subtitle: "On-device speech recognition", onClose: onClose) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Generate timed captions from the audio in your clips. Reelcraft processes speech on this iPhone and sends nothing to a server.")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    PrimaryButton(title: vm.isCaptioning ? "Listening…" : "Generate captions", systemImage: "captions.bubble", enabled: !vm.isCaptioning) {
                        Task { await vm.generateCaptions() }
                    }
                    GhostButton(title: "Add manually", systemImage: "text.badge.plus") {
                        vm.addOverlay(caption: true)
                    }
                }

                if let status = vm.captionStatus {
                    Text(status)
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !captions.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(captions) { caption in
                            HStack(spacing: 8) {
                                Text(Format.timecode(caption.start, showMillis: false))
                                    .font(Theme.mono(9))
                                    .foregroundStyle(Theme.ember)
                                    .frame(width: 38, alignment: .leading)
                                Text(caption.text)
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    vm.deleteOverlay(id: caption.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.inkTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 32)
                            .background(Theme.surfaceRaised.opacity(0.6))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Frame

struct FramePanel: View {
    @ObservedObject var vm: EditorViewModel
    let onClose: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        InspectorPanel(title: "Frame", subtitle: "Choose the export shape", onClose: onClose) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AspectRatio.allCases) { ratio in
                    Button {
                        vm.updateAspect(ratio)
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(vm.project.aspect == ratio ? Theme.ember : Theme.inkTertiary, lineWidth: 2)
                                .aspectRatio(ratio.ratio, contentMode: .fit)
                                .frame(height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ratio.title).font(Theme.label(12)).foregroundStyle(Theme.ink)
                                Text(ratio.caption).font(Theme.body(9)).foregroundStyle(Theme.inkTertiary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 54)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                                .stroke(vm.project.aspect == ratio ? Theme.ember : Theme.surfaceStroke, lineWidth: vm.project.aspect == ratio ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Clips are centre-cropped to fill the frame. Change this before you export to avoid double work.")
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.top, 10)
        }
    }
}

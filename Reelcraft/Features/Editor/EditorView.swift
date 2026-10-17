import SwiftUI
import PhotosUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ProjectStore

    @StateObject private var vm: EditorViewModel
    @State private var activeTool: EditorTool?
    @State private var showExport = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDelete = false

    init(project: VideoProject) {
        _vm = StateObject(wrappedValue: EditorViewModel(project: project))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                preview
                transport
                TimelineView(
                    project: vm.project,
                    playhead: vm.playhead,
                    selectedClipID: vm.selectedClipID,
                    onSelect: { vm.selectClip($0) },
                    onSeek: { vm.seek(to: $0) },
                    onAdd: { showPicker = true }
                )
                .padding(.bottom, 6)

                if let tool = activeTool {
                    panel(for: tool)
                } else {
                    toolRow
                }
            }

            if isImporting {
                importingOverlay
            }
        }
        .task { vm.prepare() }
        .onDisappear {
            vm.player.pause()
            store.update(vm.project)
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .videos)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            importClip(item)
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(project: vm.project) { quality in
                store.update(vm.project)
                store.recordExport(project: vm.project, resolution: quality.title)
            }
        }
        .alert("Rename project", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    vm.mutate(rebuild: false) { $0.name = trimmed }
                }
            }
        }
        .confirmationDialog("Delete this project?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(vm.project.id)
                dismiss()
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Its clips and changes are removed from this device.")
        }
        .alert("Import failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                vm.player.pause()
                store.update(vm.project)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Theme.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    renameText = vm.project.name
                    showRename = true
                } label: {
                    Label("Rename project", systemImage: "pencil")
                }
                Button {
                    store.duplicate(vm.project.id)
                } label: {
                    Label("Duplicate project", systemImage: "doc.on.doc")
                }
                Divider()
                Button(role: .destructive) {
                    showDelete = true
                } label: {
                    Label("Delete project", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.project.name)
                        .font(Theme.label(14))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            Spacer()

            Button {
                vm.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(vm.canUndo ? Theme.ink : Theme.inkTertiary.opacity(0.4))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(!vm.canUndo)

            Button {
                vm.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(vm.canRedo ? Theme.ink : Theme.inkTertiary.opacity(0.4))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(!vm.canRedo)

            Button {
                showExport = true
            } label: {
                Text("Export")
                    .font(Theme.label(12))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Theme.emberGradient, in: Capsule())
                    .opacity(vm.project.clips.isEmpty ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(vm.project.clips.isEmpty)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            Color.black

            if vm.project.clips.isEmpty {
                emptyCanvas
            } else {
                PlayerSurface(player: vm.player)
                    .aspectRatio(vm.project.aspect.ratio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.vertical, 6)
                    .onTapGesture { vm.togglePlayback() }

                if !vm.isPlaying && !vm.isBuilding {
                    Button {
                        vm.togglePlayback()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 62, height: 62)
                            .background(.black.opacity(0.45), in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if vm.isBuilding {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini).tint(Theme.ink)
                                Text("Rendering").font(Theme.mono(9)).foregroundStyle(Theme.inkSecondary)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(.black.opacity(0.55), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let error = vm.buildError, !vm.project.clips.isEmpty {
                Text(error)
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.danger)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.7), in: Capsule())
                    .padding(.bottom, 10)
            }
        }
    }

    private var emptyCanvas: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                    .foregroundStyle(Theme.surfaceStroke)
                    .frame(width: 120, height: 190)
                Image(systemName: "film")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.ember)
            }
            Text("Add a clip to begin").font(Theme.title(17)).foregroundStyle(Theme.ink)
            Text("Trim, grade and caption it here. Export clean when it feels right.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Import video")
                }
                .font(Theme.label(13))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(Theme.ember, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: 16) {
            Button { vm.step(by: -1.0 / 30.0) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .buttonStyle(.plain)

            Button { vm.togglePlayback() } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.surfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)

            Button { vm.step(by: 1.0 / 30.0) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .buttonStyle(.plain)

            Text(Format.timecode(vm.playhead))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.ink)
            Text("/")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.inkTertiary)
            Text(Format.timecode(max(vm.duration, vm.project.duration)))
                .font(Theme.mono(10))
                .foregroundStyle(Theme.inkTertiary)

            Spacer()

            if !vm.project.overlays.isEmpty {
                Label("\(vm.project.overlays.count)", systemImage: "textformat")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.inkTertiary)
            }
            if vm.project.music != .none {
                Label(vm.project.music.title, systemImage: "waveform")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .frame(height: 44)
    }

    // MARK: Tools

    private var toolRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EditorTool.allCases) { tool in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            activeTool = tool
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 16, weight: .medium))
                            Text(tool.title)
                                .font(Theme.body(9))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(width: 60, height: 54)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.surfaceStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 8)
        }
        .frame(height: 70)
        .background(Theme.bg)
    }

    @ViewBuilder
    private func panel(for tool: EditorTool) -> some View {
        Group {
            switch tool {
            case .trim: TrimPanel(vm: vm) { activeTool = nil }
            case .text: TextPanel(vm: vm) { activeTool = nil }
            case .filters: FilterPanel(vm: vm) { activeTool = nil }
            case .speed: SpeedPanel(vm: vm) { activeTool = nil }
            case .audio: AudioPanel(vm: vm) { activeTool = nil }
            case .captions: CaptionsPanel(vm: vm) { activeTool = nil }
            case .frame: FramePanel(vm: vm) { activeTool = nil }
            }
        }
        .padding(.bottom, 0)
    }

    // MARK: Import

    private func importClip(_ item: PhotosPickerItem) {
        isImporting = true
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    throw MediaImportError.unreadable
                }
                let imported = try await MediaImporter.importVideo(at: movie.url)
                try? FileManager.default.removeItem(at: movie.url)
                await MainActor.run {
                    vm.addClip(MediaImporter.clip(from: imported))
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView().tint(Theme.ember)
                Text("Preparing clip…").font(Theme.label(12)).foregroundStyle(Theme.ink)
            }
            .padding(24)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        }
    }
}

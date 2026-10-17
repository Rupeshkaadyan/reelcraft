import SwiftUI
import PhotosUI
import AVFoundation

struct RecordView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var router: AppRouter
    @StateObject private var camera = CameraModel()

    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if camera.isAvailable && !camera.permissionDenied {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                        .overlay(
                            LinearGradient(colors: [.black.opacity(0.55), .clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                                .ignoresSafeArea()
                        )
                } else {
                    unavailableBackdrop
                }

                VStack {
                    topBar
                    Spacer()
                    if camera.isRecording {
                        recordingBadge
                    }
                    Spacer()
                    bottomBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 18)

                if isProcessing {
                    processingOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { camera.prepare() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.justRecorded) { _, url in
            guard let url else { return }
            camera.justRecorded = nil
            handleRecording(url)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            importPicked(item)
        }
        .alert("Camera", isPresented: Binding(
            get: { camera.permissionDenied },
            set: { _ in }
        )) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Allow camera access in Settings to record clips inside Reelcraft. You can still import from your library.")
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil || camera.errorMessage != nil },
            set: { if !$0 { errorMessage = nil; camera.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil; camera.errorMessage = nil }
        } message: {
            Text(errorMessage ?? camera.errorMessage ?? "")
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Record")
                    .font(Theme.display(26))
                    .foregroundStyle(.white)
                Text(camera.isAvailable ? "Up to 10 minutes per clip" : "Camera unavailable in this environment")
                    .font(Theme.body(11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if camera.isAvailable {
                Button {
                    camera.toggleTorch()
                } label: {
                    Image(systemName: camera.torchOn ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(camera.torchOn ? Theme.amber : .white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .buttonStyle(.plain)
            }
            PhotosPicker(selection: $pickerItem, matching: .videos) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.4), in: Circle())
            }
        }
    }

    private var recordingBadge: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.danger).frame(width: 8, height: 8)
            Text(Format.timecode(camera.elapsed, showMillis: false))
                .font(Theme.mono(13))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(.black.opacity(0.6), in: Capsule())
    }

    private var bottomBar: some View {
        VStack(spacing: 18) {
            if camera.isAvailable {
                HStack {
                    Spacer()
                    Button {
                        camera.toggleRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.85), lineWidth: 4)
                                .frame(width: 78, height: 78)
                            RoundedRectangle(cornerRadius: camera.isRecording ? 6 : 32, style: .continuous)
                                .fill(Theme.ember)
                                .frame(width: camera.isRecording ? 32 : 62, height: camera.isRecording ? 32 : 62)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: camera.isRecording)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button {
                        camera.flip()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text("Tap to record · clips land in Projects")
                    .font(Theme.body(11))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                unavailableActions
            }
        }
    }

    private var unavailableBackdrop: some View {
        ZStack {
            Theme.canvasGradient.ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.surfaceRaised).frame(width: 90, height: 90)
                    Image(systemName: "camera.metering.unknown")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Theme.ember)
                }
                Text("No camera here")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.ink)
                Text("The simulator has no camera. Record on a device, or import a clip to start editing now.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
    }

    private var unavailableActions: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .videos) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import a clip").font(Theme.label(15))
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.emberGradient, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            }
            SecondaryButton(title: "Start a blank project", systemImage: "plus") {
                let project = store.createProject()
                router.selectedTab = .projects
                router.open(project)
            }
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(Theme.ember)
                Text("Building your project…")
                    .font(Theme.label(13))
                    .foregroundStyle(.white)
            }
            .padding(26)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        }
    }

    // MARK: Actions

    private func handleRecording(_ url: URL) {
        isProcessing = true
        Task {
            do {
                let imported = try await MediaImporter.importVideo(at: url)
                try? FileManager.default.removeItem(at: url)
                var project = store.createProject(name: "Camera clip")
                project.clips = [MediaImporter.clip(from: imported)]
                store.update(project)
                await MainActor.run {
                    isProcessing = false
                    router.selectedTab = .projects
                    router.open(project)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func importPicked(_ item: PhotosPickerItem) {
        isProcessing = true
        pickerItem = nil
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    throw MediaImportError.unreadable
                }
                let imported = try await MediaImporter.importVideo(at: movie.url)
                try? FileManager.default.removeItem(at: movie.url)
                var project = store.createProject()
                project.clips = [MediaImporter.clip(from: imported)]
                store.update(project)
                await MainActor.run {
                    isProcessing = false
                    router.selectedTab = .projects
                    router.open(project)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

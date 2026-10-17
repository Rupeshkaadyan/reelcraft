import SwiftUI

struct ExportSheet: View {
    let project: VideoProject
    let onExported: (ExportQuality) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quality: ExportQuality = .fullHD
    @State private var isExporting = false
    @State private var progress: Double = 0
    @State private var outputURL: URL?
    @State private var savedToPhotos = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let outputURL {
                successState(outputURL)
            } else {
                setupState
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg)
        .interactiveDismissDisabled(isExporting)
        .alert("Export problem", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Export").font(Theme.title(22)).foregroundStyle(Theme.ink)
                Text(project.name).font(Theme.body(12)).foregroundStyle(Theme.inkSecondary).lineLimit(1)
            }
            Spacer()
            if !isExporting {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(width: 30, height: 30)
                        .background(Theme.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var setupState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                summaryPill(icon: "rectangle.ratio.9.to.16", text: project.aspect.title)
                summaryPill(icon: "clock", text: Format.duration(project.duration))
                summaryPill(icon: "square.stack.3d.up", text: "\(project.clips.count) clips")
            }

            VStack(spacing: 8) {
                ForEach(ExportQuality.allCases) { option in
                    Button {
                        quality = option
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: quality == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(quality == option ? Theme.ember : Theme.inkTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title).font(Theme.label(14)).foregroundStyle(Theme.ink)
                                Text(option.subtitle).font(Theme.body(11)).foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer()
                            Text(option == .ultraHD ? "2160p" : "1080p")
                                .font(Theme.mono(10))
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                                .stroke(quality == option ? Theme.ember : Theme.surfaceStroke, lineWidth: quality == option ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "drop.fill").foregroundStyle(Theme.mint).font(.system(size: 11))
                Text("No watermark. No account. Saved straight to Photos.")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.inkSecondary)
            }

            if isExporting {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(Theme.ember)
                    Text(progress < 0.95 ? "Rendering \(Int(progress * 100))%" : "Saving to Photos…")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }

            PrimaryButton(title: isExporting ? "Exporting…" : "Export video", systemImage: "square.and.arrow.up", enabled: !isExporting && !project.clips.isEmpty) {
                beginExport()
            }

            Text("Keep the app open until the export finishes. Projects stay editable on this device.")
                .font(Theme.body(10))
                .foregroundStyle(Theme.inkTertiary)
        }
    }

    private func successState(_ url: URL) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.mint.opacity(0.16)).frame(width: 82, height: 82)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.mint)
            }
            Text("Your cut is ready")
                .font(Theme.title(20))
                .foregroundStyle(Theme.ink)
            Text(savedToPhotos ? "Saved to Photos in \(quality.title)." : "Exported in \(quality.title). Save it to Photos or share it now.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)

            ShareLink(item: url) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share video").font(Theme.label(15))
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.emberGradient, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            }

            if !savedToPhotos {
                SecondaryButton(title: "Save to Photos", systemImage: "photo") {
                    saveToPhotos(url)
                }
            }

            SecondaryButton(title: "Back to editor", systemImage: "arrow.uturn.left") {
                dismiss()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func summaryPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(Theme.mono(10))
        }
        .foregroundStyle(Theme.inkSecondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Theme.surfaceRaised, in: Capsule())
    }

    private func beginExport() {
        isExporting = true
        progress = 0.02
        errorMessage = nil
        let snapshot = project
        Task {
            do {
                let url = try await Exporter.export(project: snapshot, quality: quality) { value in
                    progress = max(progress, value)
                }
                outputURL = url
                onExported(quality)
                do {
                    try await Exporter.saveToPhotos(url)
                    savedToPhotos = true
                } catch {
                    savedToPhotos = false
                    errorMessage = "The video exported, but Photos could not save it. Use Share to keep a copy. \(error.localizedDescription)"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func saveToPhotos(_ url: URL) {
        Task {
            do {
                try await Exporter.saveToPhotos(url)
                savedToPhotos = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

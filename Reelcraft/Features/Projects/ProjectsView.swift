import SwiftUI
import PhotosUI

struct ProjectsView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var router: AppRouter

    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importStatus = "Preparing clip…"
    @State private var errorMessage: String?
    @State private var renameTarget: VideoProject?
    @State private var renameText = ""
    @State private var deleteTarget: VideoProject?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        libraryStats
                        if store.projects.isEmpty {
                            emptyState
                        } else {
                            grid
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 32)
                }
                .refreshable {
                    ThumbnailCache.shared.clear()
                }

                if isImporting {
                    importingOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            importVideo(newValue)
        }
        .alert("Rename project", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Project name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                if let target = renameTarget {
                    store.rename(target.id, to: renameText)
                }
                renameTarget = nil
            }
        }
        .confirmationDialog("Delete this project?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    ThumbnailCache.shared.clear()
                    store.delete(target.id)
                }
                deleteTarget = nil
            }
            Button("Keep", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("The video files in this project are removed from Reelcraft. This cannot be undone.")
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

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projects")
                        .font(Theme.display(32))
                        .foregroundStyle(Theme.ink)
                    Text("Drafts, cuts and finished videos")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 42, height: 42)
                            .background(Theme.surfaceRaised, in: Circle())
                            .overlay(Circle().stroke(Theme.surfaceStroke, lineWidth: 1))
                    }
                    Button {
                        let project = store.createProject()
                        router.open(project)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .frame(width: 42, height: 42)
                            .background(Theme.emberGradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }

    private var libraryStats: some View {
        HStack(spacing: 0) {
            stat(value: "\(store.totalProjects)", label: "projects")
            divider
            stat(value: Format.duration(store.projects.reduce(0) { $0 + $1.duration }), label: "timeline")
            divider
            stat(value: "\(store.totalClips)", label: "clips")
            Spacer()
            Menu {
                Picker("Sort", selection: $store.sort) {
                    ForEach(ProjectStore.SortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(store.sort.title)
                }
                .font(Theme.label(11))
                .foregroundStyle(Theme.inkSecondary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
            }
        }
        .frame(height: 54)
        .padding(.horizontal, 16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Theme.title(15)).foregroundStyle(Theme.ink)
            Text(label).font(Theme.body(10)).foregroundStyle(Theme.inkTertiary)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.surfaceStroke).frame(width: 1, height: 26).padding(.horizontal, 14)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(store.sortedProjects) { project in
                Button {
                    router.open(project)
                } label: {
                    ProjectCard(project: project)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        renameTarget = project
                        renameText = project.name
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        store.duplicate(project.id)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        deleteTarget = project
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            EmptyStateView(
                icon: "film.stack",
                title: "Your first cut starts here",
                message: "Import a clip from your library or start a blank project. Everything stays on this device."
            )
            PhotosPicker(selection: $pickerItem, matching: .videos) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import a video").font(Theme.label(15))
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.emberGradient, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            }
            SecondaryButton(title: "Start a blank project", systemImage: "plus") {
                let project = store.createProject()
                router.open(project)
            }
        }
        .padding(.top, 10)
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(Theme.ember).scaleEffect(1.2)
                Text(importStatus).font(Theme.label(14)).foregroundStyle(Theme.ink)
                Text("Long clips take a moment to prepare.")
                    .font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
            }
            .padding(28)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        }
    }

    // MARK: Import

    private func importVideo(_ item: PhotosPickerItem) {
        isImporting = true
        importStatus = "Reading clip…"
        pickerItem = nil
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    throw MediaImportError.unreadable
                }
                importStatus = "Preparing timeline…"
                let imported = try await MediaImporter.importVideo(at: movie.url)
                try? FileManager.default.removeItem(at: movie.url)

                var project = store.createProject()
                project.clips = [MediaImporter.clip(from: imported)]
                project.aspect = .vertical
                store.update(project)

                await MainActor.run {
                    isImporting = false
                    router.open(project)
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Card

struct ProjectCard: View {
    let project: VideoProject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                LocalThumbnail(url: project.coverURL)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack {
                    Text(project.aspect.title)
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                    Spacer()
                    Text(Format.duration(project.duration))
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                }
                .padding(9)

                VStack(alignment: .leading, spacing: 2) {
                    Spacer(minLength: 0)
                    Text(project.name)
                        .font(Theme.label(13))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text("\(project.clips.count) clip\(project.clips.count == 1 ? "" : "s") · \(relative(project.updatedAt))")
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                if project.clips.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "film")
                            .font(.system(size: 22, weight: .light))
                        Text("Empty").font(Theme.body(10))
                    }
                    .foregroundStyle(Theme.inkTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 30)
                }
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Helpers

extension Binding where Value == Bool {
    /// A permanently false binding for PhotosPicker's `isPresented` variant.
    static var never: Binding<Bool> {
        Binding<Bool>(get: { false }, set: { _ in })
    }
}

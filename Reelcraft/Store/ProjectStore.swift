import Foundation
import Combine
import SwiftUI
import AVFoundation
import UIKit

/// Single source of truth for the library. Persists to JSON in Documents.
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [VideoProject] = []
    @Published private(set) var exports: [ExportRecord] = []
    @Published private(set) var ideas: [Idea] = []

    @Published var sort: SortOption = .recentlyEdited

    enum SortOption: String, CaseIterable, Identifiable {
        case recentlyEdited, newest, oldest, alphabetical, longest
        var id: String { rawValue }
        var title: String {
            switch self {
            case .recentlyEdited: return "Last edited"
            case .newest: return "Newest"
            case .oldest: return "Oldest"
            case .alphabetical: return "A–Z"
            case .longest: return "Longest"
            }
        }
    }

    init() {
        load()
    }

    // MARK: Loading and saving

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: Paths.projectsFile),
           let decoded = try? decoder.decode([VideoProject].self, from: data) {
            projects = decoded
        }
        if let data = try? Data(contentsOf: Paths.exportsFile),
           let decoded = try? decoder.decode([ExportRecord].self, from: data) {
            exports = decoded
        }
        if let data = try? Data(contentsOf: Paths.ideasFile),
           let decoded = try? decoder.decode([Idea].self, from: data) {
            ideas = decoded
        }
    }

    private func persistProjects() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(projects) {
            try? data.write(to: Paths.projectsFile, options: .atomic)
        }
    }

    private func persistExports() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(exports) {
            try? data.write(to: Paths.exportsFile, options: .atomic)
        }
    }

    private func persistIdeas() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(ideas) {
            try? data.write(to: Paths.ideasFile, options: .atomic)
        }
    }

    // MARK: Project access

    var sortedProjects: [VideoProject] {
        switch sort {
        case .recentlyEdited: return projects.sorted { $0.updatedAt > $1.updatedAt }
        case .newest: return projects.sorted { $0.createdAt > $1.createdAt }
        case .oldest: return projects.sorted { $0.createdAt < $1.createdAt }
        case .alphabetical: return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .longest: return projects.sorted { $0.duration > $1.duration }
        }
    }

    func project(id: UUID) -> VideoProject? { projects.first { $0.id == id } }

    @discardableResult
    func createProject(name: String? = nil, aspect: AspectRatio = .vertical) -> VideoProject {
        let count = projects.count + 1
        let project = VideoProject(name: name ?? "Cut \(String(format: "%02d", count))", aspect: aspect)
        projects.insert(project, at: 0)
        persistProjects()
        return project
    }

    func update(_ project: VideoProject) {
        var copy = project
        copy.updatedAt = Date()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            // Never let a stale editor snapshot roll back export history.
            if projects[index].exportCount > copy.exportCount {
                copy.exportCount = projects[index].exportCount
                copy.lastExportAt = projects[index].lastExportAt
            }
            projects[index] = copy
        } else {
            projects.insert(copy, at: 0)
        }
        persistProjects()
    }

    func rename(_ projectID: UUID, to name: String) {
        guard var project = project(id: projectID) else { return }
        project.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? project.name : name
        project.updatedAt = Date()
        if let index = projects.firstIndex(where: { $0.id == projectID }) { projects[index] = project }
        persistProjects()
    }

    func duplicate(_ projectID: UUID) {
        guard var project = project(id: projectID) else { return }
        project.id = UUID()
        project.name += " copy"
        project.createdAt = Date()
        project.updatedAt = Date()
        project.exportCount = 0
        project.lastExportAt = nil
        var newClips: [Clip] = []
        for var clip in project.clips {
            let oldName = clip.fileName
            let ext = (oldName as NSString).pathExtension
            let newName = "\(UUID().uuidString).\(ext)"
            let source = Paths.media.appendingPathComponent(oldName)
            let dest = Paths.media.appendingPathComponent(newName)
            if FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.copyItem(at: source, to: dest)
            }
            clip.id = UUID()
            clip.fileName = newName
            if let thumbName = clip.thumbnailName {
                let newThumb = "\(clip.id.uuidString).jpg"
                let ts = Paths.thumbs.appendingPathComponent(thumbName)
                let td = Paths.thumbs.appendingPathComponent(newThumb)
                if FileManager.default.fileExists(atPath: ts.path) {
                    try? FileManager.default.copyItem(at: ts, to: td)
                }
                clip.thumbnailName = newThumb
            }
            newClips.append(clip)
        }
        project.clips = newClips
        project.overlays = project.overlays.map { var o = $0; o.id = UUID(); return o }
        projects.insert(project, at: 0)
        persistProjects()
    }

    func delete(_ projectID: UUID) {
        guard let project = project(id: projectID) else { return }
        for clip in project.clips {
            Paths.removeMedia(named: clip.fileName)
            Paths.removeThumb(named: clip.thumbnailName)
        }
        projects.removeAll { $0.id == projectID }
        persistProjects()
    }

    func recordExport(project: VideoProject, resolution: String) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].exportCount += 1
            projects[index].lastExportAt = Date()
            projects[index].updatedAt = Date()
            persistProjects()
        }
        exports.insert(ExportRecord(projectName: project.name, date: Date(), duration: project.duration, resolution: resolution), at: 0)
        if exports.count > 300 { exports.removeLast(exports.count - 300) }
        persistExports()
    }

    // MARK: Ideas

    func addIdea(text: String, colorIndex: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ideas.insert(Idea(text: trimmed, colorIndex: colorIndex), at: 0)
        persistIdeas()
    }

    func updateIdea(_ idea: Idea) {
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            ideas[index] = idea
            persistIdeas()
        }
    }

    func deleteIdea(_ ideaID: UUID) {
        ideas.removeAll { $0.id == ideaID }
        persistIdeas()
    }

    func toggleIdeaDone(_ ideaID: UUID) {
        guard let index = ideas.firstIndex(where: { $0.id == ideaID }) else { return }
        ideas[index].isDone.toggle()
        persistIdeas()
    }

    @discardableResult
    func projectFromIdea(_ idea: Idea) -> VideoProject {
        let project = createProject(name: String(idea.text.prefix(28)))
        update(project)
        if let index = ideas.firstIndex(where: { $0.id == idea.id }) {
            ideas[index].projectID = project.id
            persistIdeas()
        }
        return project
    }

    // MARK: Stats

    var totalProjects: Int { projects.count }
    var totalExports: Int { exports.count }
    var totalExportedSeconds: Double { exports.reduce(0) { $0 + $1.duration } }
    var totalClips: Int { projects.reduce(0) { $0 + $1.clips.count } }

    var averageProjectLength: Double {
        guard !projects.isEmpty else { return 0 }
        return projects.reduce(0) { $0 + $1.duration } / Double(projects.count)
    }

    func exportsThisWeek() -> [ExportRecord] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) ?? Date()
        return exports.filter { $0.date >= start }
    }

    /// Seven buckets, oldest first, for the insights chart.
    func weeklyExportBuckets() -> [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = exports.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
            return (day, count)
        }
    }

    func mostUsedMusic() -> MusicTrack? {
        let counts = Dictionary(grouping: projects, by: { $0.music }).mapValues(\.count)
        return counts.filter { $0.key != .none }.max { $0.value < $1.value }?.key
    }

    func mostUsedFilter() -> FilterPreset? {
        let filters = projects.flatMap { $0.clips.map(\.filter) }.filter { $0 != .none }
        let counts = Dictionary(grouping: filters, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }
}

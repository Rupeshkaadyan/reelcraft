import SwiftUI

struct IdeasView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var router: AppRouter

    @State private var composing = false
    @State private var draftText = ""
    @State private var draftColor = 0
    @State private var editingIdea: Idea?
    @State private var showCompleted = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var visibleIdeas: [Idea] {
        store.ideas.filter { showCompleted || !$0.isDone }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        filterRow
                        if visibleIdeas.isEmpty {
                            EmptyStateView(
                                icon: "lightbulb",
                                title: "No ideas yet",
                                message: "Park a hook, a caption or a shot list here. When it is ready, turn the note into a project."
                            )
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(visibleIdeas) { idea in
                                    ideaCard(idea)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $composing) {
            ideaComposer(idea: nil)
                .presentationDetents([.medium])
                .presentationBackground(Theme.surface)
        }
        .sheet(item: $editingIdea) { idea in
            ideaComposer(idea: idea)
                .presentationDetents([.medium])
                .presentationBackground(Theme.surface)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ideas")
                    .font(Theme.display(32))
                    .foregroundStyle(Theme.ink)
                Text("Stickies for your next cut")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Button {
                draftText = ""
                draftColor = Int.random(in: 0..<Idea.palette.count)
                composing = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 42, height: 42)
                    .background(Theme.emberGradient, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            Chip(title: "Open", selected: !showCompleted) { showCompleted = false }
            Chip(title: "All", selected: showCompleted) { showCompleted = true }
            Spacer()
            Text("\(store.ideas.count) saved")
                .font(Theme.body(11))
                .foregroundStyle(Theme.inkTertiary)
        }
    }

    private func ideaCard(_ idea: Idea) -> some View {
        Button {
            editingIdea = idea
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: idea.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(idea.isDone ? Theme.mint : Theme.inkTertiary)
                    Spacer()
                    Text(idea.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.inkTertiary)
                }
                Text(idea.text)
                    .font(Theme.body(14))
                    .foregroundStyle(idea.isDone ? Theme.inkSecondary : Theme.ink)
                    .strikethrough(idea.isDone, color: Theme.inkTertiary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    if idea.projectID != nil {
                        Label("Project", systemImage: "film")
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.mint)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "film")
                            Text("Make a cut")
                        }
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .frame(minHeight: 148, alignment: .topLeading)
            .background(idea.color.opacity(idea.isDone ? 0.5 : 1), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.toggleIdeaDone(idea.id)
            } label: {
                Label(idea.isDone ? "Mark as open" : "Mark as done", systemImage: idea.isDone ? "arrow.uturn.left" : "checkmark")
            }
            Button {
                var copy = idea
                copy.id = UUID()
                store.updateIdea(copy)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Button {
                let project = store.projectFromIdea(idea)
                router.selectedTab = .projects
                router.open(project)
            } label: {
                Label("Start a project", systemImage: "film")
            }
            Button(role: .destructive) {
                store.deleteIdea(idea.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Composer

    private func ideaComposer(idea: Idea?) -> some View {
        IdeaComposer(
            initialText: idea?.text ?? draftText,
            initialColor: idea?.colorIndex ?? draftColor,
            isEditing: idea != nil,
            onSave: { text, color in
                if var copy = idea {
                    copy.text = text
                    copy.colorIndex = color
                    store.updateIdea(copy)
                    editingIdea = nil
                } else {
                    store.addIdea(text: text, colorIndex: color)
                    draftText = ""
                    draftColor = color
                    composing = false
                }
            },
            onDelete: idea.map { value in
                {
                    store.deleteIdea(value.id)
                    editingIdea = nil
                }
            }
        )
    }
}

private struct IdeaComposer: View {
    let initialText: String
    let initialColor: Int
    let isEditing: Bool
    let onSave: (String, Int) -> Void
    var onDelete: (() -> Void)?

    @State private var text: String
    @State private var colorIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(initialText: String, initialColor: Int, isEditing: Bool, onSave: @escaping (String, Int) -> Void, onDelete: (() -> Void)? = nil) {
        self.initialText = initialText
        self.initialColor = initialColor
        self.isEditing = isEditing
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: initialText)
        _colorIndex = State(initialValue: initialColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isEditing ? "Edit idea" : "New idea")
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.ink)
                Spacer()
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

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("What is the hook?")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                }
                TextEditor(text: $text)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
            }
            .frame(minHeight: 120)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .stroke(Theme.inputStroke, lineWidth: 1)
            )

            HStack(spacing: 10) {
                ForEach(0..<Idea.palette.count, id: \.self) { index in
                    Button {
                        colorIndex = index
                    } label: {
                        Circle()
                            .fill(Idea.palette[index])
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(colorIndex == index ? Theme.ink : Theme.surfaceStroke, lineWidth: colorIndex == index ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .frame(width: 38, height: 38)
                            .background(Theme.surfaceRaised, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            PrimaryButton(title: "Save idea", systemImage: "checkmark", enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                onSave(text, colorIndex)
                dismiss()
            }
        }
        .padding(20)
        .background(Theme.surface)
    }
}

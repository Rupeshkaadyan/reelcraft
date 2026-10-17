import SwiftUI
import AVFoundation

struct DiscoverView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var router: AppRouter
    @State private var selected: TemplatePreset?
    @State private var previewing: MusicTrack?
    @State private var audioPlayer: AVAudioPlayer?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        templateGrid
                        soundPacks
                        howItWorks
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selected) { template in
            TemplateSheet(template: template) {
                apply(template)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.surface)
        }
        .onDisappear { audioPlayer?.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Discover")
                .font(Theme.display(32))
                .foregroundStyle(Theme.ink)
            Text("Start from a look, not a blank timeline")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, 8)
    }

    private var templateGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Templates", subtitle: "Ready-made grades, type and sound")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(TemplatePreset.all) { template in
                    Button {
                        selected = template
                    } label: {
                        TemplateCard(template: template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var soundPacks: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Sound packs", subtitle: "Made in-house, free to use in your videos")
            VStack(spacing: 8) {
                ForEach(MusicTrack.allCases.filter { $0 != .none }) { track in
                    HStack(spacing: 12) {
                        Button {
                            togglePreview(track)
                        } label: {
                            Image(systemName: previewing == track ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.bg)
                                .frame(width: 32, height: 32)
                                .background(Theme.mint, in: Circle())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(track.title).font(Theme.label(14)).foregroundStyle(Theme.ink)
                            Text(track.mood).font(Theme.body(11)).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Text("0:24").font(Theme.mono(10)).foregroundStyle(Theme.inkTertiary)
                    }
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.surfaceStroke, lineWidth: 1))
                }
            }
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "How Reelcraft works")
            HStack(spacing: 10) {
                step(number: "1", title: "Pick a look", detail: "Frame, grade and type")
                step(number: "2", title: "Drop clips", detail: "Trim to the beat")
                step(number: "3", title: "Export clean", detail: "4K, no watermark")
            }
        }
    }

    private func step(number: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(number)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.ember)
            Text(title).font(Theme.label(12)).foregroundStyle(Theme.ink).lineLimit(1)
            Text(detail).font(Theme.body(10)).foregroundStyle(Theme.inkSecondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous).stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private func apply(_ template: TemplatePreset) {
        var project = store.createProject(name: template.name, aspect: template.aspect)
        project.music = template.music
        project.overlays = [TextOverlay(
            text: template.starterText,
            start: 0,
            duration: 3,
            position: template.overlayPosition,
            style: template.overlayStyle
        )]
        store.update(project)
        selected = nil
        router.selectedTab = .projects
        router.open(project)
    }

    private func togglePreview(_ track: MusicTrack) {
        if previewing == track {
            audioPlayer?.stop()
            previewing = nil
            return
        }
        audioPlayer?.stop()
        guard let url = track.url else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.volume = 0.6
        audioPlayer?.play()
        previewing = track
    }
}

private struct TemplateCard: View {
    let template: TemplatePreset

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: template.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                // A simple frame motif, drawn with shapes.
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                    .padding(18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.starterText)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(template.aspect.title)
                        .font(Theme.mono(9))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(14)
            }
            .frame(height: 132)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(Theme.label(13)).foregroundStyle(Theme.ink)
                Text(template.tagline)
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.surfaceStroke, lineWidth: 1))
    }
}

private struct TemplateSheet: View {
    let template: TemplatePreset
    let onUse: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name).font(Theme.title(22)).foregroundStyle(Theme.ink)
                    Text(template.tagline).font(Theme.body(13)).foregroundStyle(Theme.inkSecondary)
                }
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

            HStack(spacing: 12) {
                spec(title: "Frame", value: template.aspect.title)
                spec(title: "Grade", value: template.filter.title)
                spec(title: "Type", value: template.overlayStyle.title)
                spec(title: "Sound", value: template.music.title)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Included").font(Theme.label(12)).foregroundStyle(Theme.inkSecondary)
                bullet("Frame size set to \(template.aspect.title) (\(template.aspect.caption))")
                bullet("\(template.filter.title) grade applied to every clip you add")
                bullet("\(template.overlayStyle.title) text style at the \(template.overlayPosition.title.lowercased())")
                bullet("\(template.music.title) music bed, looped to your cut")
            }

            Spacer(minLength: 0)

            PrimaryButton(title: "Use this template", systemImage: "wand.and.stars") {
                onUse()
            }
        }
        .padding(20)
        .background(Theme.surface)
    }

    private func spec(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.body(10)).foregroundStyle(Theme.inkTertiary)
            Text(value).font(Theme.label(12)).foregroundStyle(Theme.ink).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.ember).frame(width: 4, height: 4).padding(.top, 6)
            Text(text).font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

import SwiftUI

struct TimelineView: View {
    let project: VideoProject
    let playhead: Double
    let selectedClipID: UUID?
    let onSelect: (UUID) -> Void
    let onSeek: (Double) -> Void
    let onAdd: () -> Void

    private let pixelsPerSecond: CGFloat = 46
    private let stripHeight: CGFloat = 58

    private var contentWidth: CGFloat {
        max(320, CGFloat(project.duration) * pixelsPerSecond + 24)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("TIMELINE")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.inkTertiary)
                Text("· \(project.clips.count) clip\(project.clips.count == 1 ? "" : "s")")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.inkTertiary)
                Spacer()
                Text(Format.timecode(playhead))
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.ember)
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Clip")
                    }
                    .font(Theme.label(10))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Theme.surfaceRaised, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.gutter)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            ruler
                            HStack(spacing: 3) {
                                ForEach(Array(project.clips.enumerated()), id: \.element.id) { index, clip in
                                    segment(clip: clip, index: index)
                                        .id(clip.id)
                                }
                                if project.clips.isEmpty {
                                    Button(action: onAdd) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle")
                                            Text("Add your first clip")
                                        }
                                        .font(Theme.label(11))
                                        .foregroundStyle(Theme.inkSecondary)
                                        .frame(width: 240, height: stripHeight)
                                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                                .foregroundStyle(Theme.surfaceStroke)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(height: stripHeight)
                        }
                        .padding(.horizontal, Theme.gutter)

                        playheadLine
                            .padding(.leading, Theme.gutter)
                    }
                    .frame(width: contentWidth + Theme.gutter * 2, height: stripHeight + 26, alignment: .topLeading)
                }
                .onChange(of: selectedClipID) { _, newValue in
                    if let newValue {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: stripHeight + 26)
        }
    }

    private var ruler: some View {
        Canvas { context, size in
            let seconds = Int(ceil(Double(size.width) / Double(pixelsPerSecond)))
            for second in 0...max(1, seconds) {
                let x = CGFloat(second) * pixelsPerSecond
                let major = second % 5 == 0
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x, y: size.height - (major ? 8 : 4)))
                }
                context.stroke(path, with: .color(Theme.surfaceStroke), lineWidth: 1)
                if major && second > 0 {
                    let label = Text(Format.timecode(Double(second), showMillis: false))
                        .font(Theme.mono(8))
                        .foregroundColor(Theme.inkTertiary)
                    context.draw(label, at: CGPoint(x: x + 2, y: 2), anchor: .topLeading)
                }
            }
        }
        .frame(height: 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onSeek(Double(max(0, value.location.x) / pixelsPerSecond))
                }
        )
    }

    private func segment(clip: Clip, index: Int) -> some View {
        let width = max(46, CGFloat(clip.effectiveDuration) * pixelsPerSecond - 2)
        let isSelected = clip.id == selectedClipID
        return Button {
            onSelect(clip.id)
            onSeek(project.startTime(ofClipAt: index))
        } label: {
            ZStack(alignment: .bottomLeading) {
                LocalThumbnail(url: clip.thumbnailURL)
                    .frame(width: width, height: stripHeight)
                    .clipped()
                    .opacity(0.85)

                Rectangle()
                    .fill(Color.black.opacity(0.25))

                // Speed / filter markers
                HStack(spacing: 3) {
                    if abs(clip.speed - 1) > 0.01 {
                        Text(String(format: "%gx", clip.speed))
                            .font(Theme.mono(8))
                            .foregroundStyle(Theme.bg)
                            .padding(.horizontal, 4)
                            .frame(height: 13)
                            .background(Theme.amber, in: Capsule())
                    }
                    if clip.filter != .none {
                        Image(systemName: "camera.filters")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .frame(width: 13, height: 13)
                            .background(Theme.mint, in: Circle())
                    }
                    Spacer(minLength: 0)
                }
                .padding(4)

                HStack {
                    Text("\(index + 1)")
                        .font(Theme.mono(8))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 4)
                        .frame(height: 13)
                        .background(.black.opacity(0.55), in: Capsule())
                    Spacer()
                }
                .padding(4)
                .frame(maxHeight: .infinity, alignment: .top)

                Text(Format.timecode(clip.effectiveDuration, showMillis: false))
                    .font(Theme.mono(8))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 4)
                    .frame(height: 13)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(4)
            }
            .frame(width: width, height: stripHeight)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? Theme.ember : Theme.surfaceStroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var playheadLine: some View {
        let x = CGFloat(playhead) * pixelsPerSecond
        return ZStack(alignment: .top) {
            Rectangle()
                .fill(Theme.ember)
                .frame(width: 2, height: stripHeight + 18)
            Circle()
                .fill(Theme.ember)
                .frame(width: 9, height: 9)
                .offset(y: -4)
        }
        .offset(x: x - 1, y: 4)
        .allowsHitTesting(false)
    }
}

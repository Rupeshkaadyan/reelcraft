import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        statGrid
                        activityCard
                        habitsCard
                        noteCard
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Insights")
                .font(Theme.display(32))
                .foregroundStyle(Theme.ink)
            Text("Your editing habits, measured on this device")
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, 8)
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statCard(value: "\(store.totalExports)", label: "Exports", detail: "videos finished", accent: Theme.ember)
            statCard(value: Format.minutes(store.totalExportedSeconds), label: "Minutes", detail: "exported", accent: Theme.mint)
            statCard(value: "\(store.totalProjects)", label: "Projects", detail: "\(store.totalClips) clips total", accent: Theme.amber)
            statCard(value: Format.duration(store.averageProjectLength), label: "Avg. cut", detail: "per project", accent: Theme.ink)
        }
    }

    private func statCard(value: String, label: String, detail: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.inkTertiary)
                Spacer()
                Circle().fill(accent).frame(width: 6, height: 6)
            }
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(detail).font(Theme.body(11)).foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "This week", subtitle: "Exports per day")

            if store.exportsEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No exports yet").font(Theme.label(14)).foregroundStyle(Theme.ink)
                    Text("Finish a project and your activity shows up here. Nothing leaves this device.")
                        .font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            } else {
                Chart {
                    ForEach(Array(store.weeklyExportBuckets().enumerated()), id: \.offset) { _, bucket in
                        BarMark(
                            x: .value("Day", bucket.date, unit: .day),
                            y: .value("Exports", bucket.count)
                        )
                        .foregroundStyle(Theme.emberGradient)
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke)
                        AxisValueLabel().foregroundStyle(Theme.inkTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private var habitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your palette", subtitle: "Most used looks")
            HStack(spacing: 10) {
                habit(
                    title: "Grade",
                    value: store.mostUsedFilter()?.title ?? "None yet",
                    icon: "camera.filters",
                    tint: store.mostUsedFilter()?.swatch.first ?? Theme.surfaceRaised
                )
                habit(
                    title: "Sound",
                    value: store.mostUsedMusic()?.title ?? "No music",
                    icon: "waveform",
                    tint: Theme.mint
                )
                habit(
                    title: "Streak",
                    value: "\(Set(store.weeklyExportBuckets().filter { $0.count > 0 }.map { $0.date }).count) days",
                    icon: "flame",
                    tint: Theme.amber
                )
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous).stroke(Theme.surfaceStroke, lineWidth: 1))
    }

    private func habit(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: Circle())
            Text(value).font(Theme.label(13)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(Theme.body(10)).foregroundStyle(Theme.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }

    private var noteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.mint)
            Text("Reelcraft has no account, no network calls and no tracking. These numbers are computed from your own projects on this iPhone.")
                .font(Theme.body(11))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Theme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
    }
}

extension ProjectStore {
    var exportsEmpty: Bool { exports.isEmpty }
}

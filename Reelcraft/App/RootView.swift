import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        TabView(selection: $router.selectedTab) {
            IdeasView()
                .tag(AppTab.ideas)
                .tabItem { Label("Ideas", systemImage: "lightbulb") }

            DiscoverView()
                .tag(AppTab.discover)
                .tabItem { Label("Discover", systemImage: "sparkles") }

            ProjectsView()
                .tag(AppTab.projects)
                .tabItem { Label("Projects", systemImage: "square.stack") }

            RecordView()
                .tag(AppTab.record)
                .tabItem { Label("Record", systemImage: "record.circle") }

            InsightsView()
                .tag(AppTab.insights)
                .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
        }
        .tint(Theme.ember)
        .toolbarBackground(Theme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(item: $router.editor) { route in
            EditorView(project: route.project)
        }
        .task { applyLaunchArguments() }
    }

    /// Debug-only capture aids: `-startTab <tab>` and `-openFirstProject`.
    private func applyLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-startTab"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "ideas": router.selectedTab = .ideas
            case "discover": router.selectedTab = .discover
            case "record": router.selectedTab = .record
            case "insights": router.selectedTab = .insights
            default: router.selectedTab = .projects
            }
        }
        if arguments.contains("-openFirstProject"), let project = store.sortedProjects.first {
            router.selectedTab = .projects
            router.open(project)
        }
        #endif
    }
}

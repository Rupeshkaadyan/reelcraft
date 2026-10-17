import SwiftUI

@main
struct ReelcraftApp: App {
    @StateObject private var store = ProjectStore()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                .tint(Theme.ember)
        }
    }
}

final class AppRouter: ObservableObject {
    @Published var editor: EditorRoute?
    @Published var selectedTab: AppTab = .projects

    func open(_ project: VideoProject) {
        editor = EditorRoute(id: project.id, project: project)
    }
}

struct EditorRoute: Identifiable, Hashable {
    let id: UUID
    let project: VideoProject
}

enum AppTab: Hashable {
    case ideas, discover, projects, record, insights
}

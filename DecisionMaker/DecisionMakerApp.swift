import SwiftUI
import SwiftData

@main
struct DecisionMakerApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [DecisionSet.self, Choice.self])
    }
}

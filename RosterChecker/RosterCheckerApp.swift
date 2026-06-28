import SwiftUI

@main
struct RosterCheckerApp: App {
    @StateObject private var viewModel = RosterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 900, minHeight: 650)
        }
        .windowResizability(.contentSize)
    }
}

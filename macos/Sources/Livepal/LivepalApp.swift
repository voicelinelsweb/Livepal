import SwiftUI

@main
struct LivepalApp: App {
    @StateObject private var session = SessionController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
        .defaultSize(width: 560, height: 720)
    }
}

import SwiftUI

@main
struct WidtgetHostApp: App {
    var body: some Scene {
        WindowGroup {
            WidgetSettingsView()
                .frame(width: 420)
        }
        .defaultSize(width: 420, height: 620)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

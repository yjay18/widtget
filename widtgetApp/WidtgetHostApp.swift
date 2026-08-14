import SwiftUI

@main
struct WidtgetHostApp: App {
    var body: some Scene {
        Window("widtget", id: "settings") {
            WidgetSettingsView()
                .frame(width: 420)
        }
        .defaultSize(width: 420, height: 620)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["refresh"])
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

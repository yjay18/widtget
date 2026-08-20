import SwiftUI

@main
struct WidtgetHostApp: App {
    var body: some Scene {
        Window("widtget", id: "settings") {
            WidgetSettingsView()
        }
        .defaultSize(width: 980, height: 760)
        .windowResizability(.contentMinSize)
        .handlesExternalEvents(matching: ["refresh"])
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

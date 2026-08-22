import SwiftUI
import WidgetKit

@main
struct WidtgetWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidtgetWidget()
    }
}

struct WidtgetWidget: Widget {
    static let kind = WidtgetWidgetKind.value

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: WidtgetConfigurationIntent.self,
            provider: ActivityProvider()
        ) { entry in
            WidtgetWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    entry.preferences.visualTheme.containerBackgroundColor
                }
        }
        .configurationDisplayName("widtget")
        .description("A focused view of additions, deletions, commits, and repository activity.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

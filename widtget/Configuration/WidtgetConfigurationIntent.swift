import AppIntents
import WidgetKit

enum ActivityPeriod: String, AppEnum, CaseIterable, Sendable {
    case daily
    case weekly

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Period")
    static let caseDisplayRepresentations: [ActivityPeriod: DisplayRepresentation] = [
        .daily: "Daily",
        .weekly: "Weekly"
    ]

    var displayName: String { rawValue.uppercased() }
}

struct WidtgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Activity period"
    static let description = IntentDescription("Choose daily or weekly code activity.")

    @Parameter(title: "Period", default: .daily)
    var period: ActivityPeriod

    init() {
        period = .daily
    }

    init(period: ActivityPeriod) {
        self.period = period
    }
}

struct RefreshActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh activity"
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: WidtgetWidget.kind)
        return .result()
    }
}

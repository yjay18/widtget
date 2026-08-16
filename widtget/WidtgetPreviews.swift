import SwiftUI
import WidgetKit

#Preview("Small · Daily", as: .systemSmall) {
    WidtgetWidget()
} timeline: {
    ActivityEntry(date: .now, configuredPeriod: .daily, period: .daily, username: "yjay18", snapshot: .daily)
    ActivityEntry(date: .now, configuredPeriod: .daily, period: .daily, username: "yjay18", snapshot: .noActivity)
}

#Preview("Medium · Weekly", as: .systemMedium) {
    WidtgetWidget()
} timeline: {
    ActivityEntry(date: .now, configuredPeriod: .weekly, period: .weekly, username: "yjay18", snapshot: .weekly)
    ActivityEntry(date: .now, configuredPeriod: .weekly, period: .weekly, username: "yjay18", snapshot: .error)
}

#Preview("Large · States", as: .systemLarge) {
    WidtgetWidget()
} timeline: {
    ActivityEntry(date: .now, configuredPeriod: .daily, period: .daily, username: "yjay18", snapshot: .loading)
    ActivityEntry(date: .now, configuredPeriod: .weekly, period: .weekly, username: "yjay18", snapshot: .weekly)
}

#Preview("Extra Large · Weekly", as: .systemExtraLarge) {
    WidtgetWidget()
} timeline: {
    ActivityEntry(date: .now, configuredPeriod: .weekly, period: .weekly, username: "yjay18", snapshot: .weekly)
    ActivityEntry(date: .now, configuredPeriod: .daily, period: .daily, username: "yjay18", snapshot: .noActivity)
    ActivityEntry(date: .now, configuredPeriod: .daily, period: .daily, username: "", snapshot: .setupRequired)
    ActivityEntry(date: .now, configuredPeriod: .daily, period: .daily, username: "yjay18", snapshot: .loading)
    ActivityEntry(date: .now, configuredPeriod: .daily, period: .daily, username: "yjay18", snapshot: .error)
}

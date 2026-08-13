import SwiftUI
import WidgetKit

#Preview("Small · Daily", as: .systemSmall) {
    WidtgetWidget()
} timeline: {
    ActivityEntry(date: .now, period: .daily, snapshot: .daily)
    ActivityEntry(date: .now, period: .daily, snapshot: .noActivity)
}

#Preview("Medium · Weekly", as: .systemMedium) {
    WidtgetWidget()
} timeline: {
    ActivityEntry(date: .now, period: .weekly, snapshot: .weekly)
    ActivityEntry(date: .now, period: .weekly, snapshot: .error)
}

#Preview("Large · States", as: .systemLarge) {
    WidtgetWidget()
} timeline: {
    ActivityEntry(date: .now, period: .daily, snapshot: .loading)
    ActivityEntry(date: .now, period: .weekly, snapshot: .weekly)
}

import SwiftUI
import WidgetKit

// Derived metrics shared by the fixed themes so each view reuses one derivation
// instead of recomputing net / average / peak inline.
extension ActivitySnapshot {
    var net: Int { additions - deletions }

    var averagePerCommit: Int {
        guard commits > 0 else { return 0 }
        return Int((Double(additions + deletions) / Double(commits)).rounded())
    }

    var activeIntervals: Int {
        activity.filter { $0.totalChanged > 0 }.count
    }

    var peakIndex: Int? {
        activity.enumerated().max { $0.element.totalChanged < $1.element.totalChanged }?.offset
    }
}

extension ActivityEntry {
    // Weekday / hour labels for this entry's period, aligned to the activity cells.
    func intervalLabels(style: ActivityIntervalLabelStyle = .compact) -> [String] {
        ActivityIntervalLabels.labels(
            period: period,
            windowMode: preferences.periodWindowMode,
            referenceDate: date,
            cellCount: snapshot.activity.count,
            style: style
        )
    }

    var peakLabel: String {
        guard let index = snapshot.peakIndex else { return "—" }
        let labels = intervalLabels()
        return labels.indices.contains(index) ? labels[index] : "—"
    }
}

extension WidgetVisualTheme {
    // Base colour painted behind the widget content and into the bleed margin.
    var containerBackgroundColor: Color {
        switch self {
        case .defaultTheme: Color(red: 0.035, green: 0.047, blue: 0.063)
        case .blockwork: Color(red: 0.937, green: 0.898, blue: 0.804)
        case .glasshouse: Color(red: 0.110, green: 0.114, blue: 0.129)
        case .phosphor: Color(red: 0.024, green: 0.035, blue: 0.039)
        case .broadsheet: Color(red: 0.914, green: 0.894, blue: 0.835)
        }
    }
}

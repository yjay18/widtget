import SwiftUI

enum ActivityIntervalLabelStyle {
    case expanded
    case compact
}

enum ActivityIntervalLabels {
    static func labels(
        period: ActivityPeriod,
        windowMode: PeriodWindowMode,
        referenceDate: Date,
        cellCount: Int,
        style: ActivityIntervalLabelStyle,
        calendar: Calendar = .current
    ) -> [String] {
        guard cellCount > 0 else { return [] }

        let interval = interval(
            period: period,
            windowMode: windowMode,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let cellDuration = interval.duration / Double(cellCount)

        return (0..<cellCount).map { index in
            let start = interval.start.addingTimeInterval(cellDuration * Double(index))
            let end = interval.start.addingTimeInterval(cellDuration * Double(index + 1))

            switch period {
            case .daily:
                return hourLabel(start: start, end: end, style: style, calendar: calendar)
            case .weekly:
                return weekdayLabel(start, style: style)
            }
        }
    }

    private static func interval(
        period: ActivityPeriod,
        windowMode: PeriodWindowMode,
        referenceDate: Date,
        calendar: Calendar
    ) -> DateInterval {
        switch (period, windowMode) {
        case (.daily, .fixed):
            let start = calendar.startOfDay(for: referenceDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)
                ?? start.addingTimeInterval(24 * 60 * 60)
            return DateInterval(start: start, end: end)
        case (.weekly, .fixed):
            let start = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
                ?? calendar.startOfDay(for: referenceDate)
            let end = calendar.date(byAdding: .day, value: 7, to: start)
                ?? start.addingTimeInterval(7 * 24 * 60 * 60)
            return DateInterval(start: start, end: end)
        case (.daily, .rolling):
            return DateInterval(
                start: referenceDate.addingTimeInterval(-24 * 60 * 60),
                end: referenceDate
            )
        case (.weekly, .rolling):
            return DateInterval(
                start: referenceDate.addingTimeInterval(-7 * 24 * 60 * 60),
                end: referenceDate
            )
        }
    }

    private static func hourLabel(
        start: Date,
        end: Date,
        style: ActivityIntervalLabelStyle,
        calendar: Calendar
    ) -> String {
        let startHour = calendar.component(.hour, from: start)
        if case .compact = style {
            return startHour.formatted(.number.grouping(.never).precision(.integerLength(2)))
        }

        let endHour = calendar.component(.hour, from: end)
        let startText = startHour.formatted(.number.grouping(.never).precision(.integerLength(2)))
        let endText = endHour.formatted(.number.grouping(.never).precision(.integerLength(2)))
        return "\(startText)–\(endText)"
    }

    private static func weekdayLabel(_ date: Date, style: ActivityIntervalLabelStyle) -> String {
        switch style {
        case .expanded:
            date.formatted(.dateTime.weekday(.abbreviated))
        case .compact:
            date.formatted(.dateTime.weekday(.narrow))
        }
    }
}

struct ActivityAxisLabels: View {
    let labels: [String]
    var fontSize: CGFloat = 7

    var body: some View {
        HStack(spacing: 2) {
            ForEach(labels.indices, id: \.self) { index in
                Text(labels[index])
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidtgetPalette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ActivityInsights: View {
    let snapshot: ActivitySnapshot
    let labels: [String]
    var compact = false

    private var totalChanged: Int {
        snapshot.additions + snapshot.deletions
    }

    private var netChanged: Int {
        snapshot.additions - snapshot.deletions
    }

    private var averagePerCommit: Int {
        guard snapshot.commits > 0 else { return 0 }
        return Int((Double(totalChanged) / Double(snapshot.commits)).rounded())
    }

    private var peak: (index: Int, cell: ActivityCell)? {
        guard let peak = snapshot.activity.enumerated().max(by: {
            $0.element.totalChanged < $1.element.totalChanged
        }) else { return nil }
        return (index: peak.offset, cell: peak.element)
    }

    private var peakLabel: String {
        guard let peak, peak.cell.totalChanged > 0, labels.indices.contains(peak.index) else {
            return "—"
        }
        return labels[peak.index].uppercased()
    }

    private var peakChanged: Int {
        peak?.cell.totalChanged ?? 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 6 : 10) {
            insight(
                title: "NET",
                value: signedCompact(netChanged),
                detail: "LINES",
                color: netColor
            )

            separator

            insight(
                title: "PEAK",
                value: peakLabel,
                detail: peakChanged == 0 ? "NO ACTIVITY" : "\(unsignedCompact(peakChanged)) LINES",
                color: WidtgetPalette.primaryText
            )

            separator

            insight(
                title: "AVG",
                value: unsignedCompact(averagePerCommit),
                detail: "LINES / COMMIT",
                color: WidtgetPalette.primaryText
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Net \(netChanged) lines, peak interval \(peakLabel), average \(averagePerCommit) lines per commit"
        )
    }

    private func insight(title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            Text(title)
                .font(.system(size: compact ? 6.5 : 7.5, weight: .bold, design: .rounded))
                .tracking(compact ? 0.7 : 0.9)
                .foregroundStyle(WidtgetPalette.secondaryText)

            Text(value)
                .font(.system(size: compact ? 12 : 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(detail)
                .font(.system(size: compact ? 5.5 : 6.5, weight: .semibold, design: .rounded))
                .foregroundStyle(WidtgetPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separator: some View {
        Rectangle()
            .fill(WidtgetPalette.border)
            .frame(width: 1, height: compact ? 35 : 42)
    }

    private var netColor: Color {
        if netChanged > 0 { return WidtgetPalette.green }
        if netChanged < 0 { return WidtgetPalette.coral }
        return WidtgetPalette.secondaryText
    }

    private func signedCompact(_ value: Int) -> String {
        ActivityNumberFormat.compact(value, sign: value < 0 ? "−" : "+")
    }

    private func unsignedCompact(_ value: Int) -> String {
        String(ActivityNumberFormat.compact(value, sign: "+").dropFirst())
    }
}

struct ActivityStrip: View {
    let cells: [ActivityCell]
    var height: CGFloat = 12

    private var maximum: CGFloat {
        CGFloat(max(cells.map(\.totalChanged).max() ?? 0, 1))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(cells) { cell in
                ActivityBar(cell: cell, maximum: maximum)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity intensity for \(cells.count) intervals")
    }
}

private struct ActivityBar: View {
    let cell: ActivityCell
    let maximum: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let available = proxy.size.height
            let totalHeight = max(3, available * CGFloat(cell.totalChanged) / maximum)
            let additionShare = cell.totalChanged == 0 ? 0 : CGFloat(cell.additions) / CGFloat(cell.totalChanged)
            let deletionShare = cell.totalChanged == 0 ? 0 : CGFloat(cell.deletions) / CGFloat(cell.totalChanged)

            VStack(spacing: 1) {
                Spacer(minLength: 0)
                if cell.totalChanged == 0 {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(WidtgetPalette.neutral)
                        .frame(height: 3)
                } else {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(WidtgetPalette.green.opacity(0.5 + 0.5 * Double(totalHeight / available)))
                        .frame(height: max(1, totalHeight * additionShare))
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(WidtgetPalette.coral.opacity(0.45 + 0.5 * Double(totalHeight / available)))
                        .frame(height: max(1, totalHeight * deletionShare))
                }
            }
        }
    }
}

struct ActivityGrid: View {
    let cells: [ActivityCell]
    var labels: [String] = []
    var labelFontSize: CGFloat = 6.5

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var maximum: Double {
        Double(max(cells.map(\.totalChanged).max() ?? 0, 1))
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                let intensity = Double(cell.totalChanged) / maximum
                let additionShare = cell.totalChanged == 0 ? 0 : Double(cell.additions) / Double(cell.totalChanged)

                VStack(spacing: labels.indices.contains(index) ? 3 : 0) {
                    GeometryReader { proxy in
                        HStack(spacing: 0) {
                            WidtgetPalette.green
                                .opacity(cell.totalChanged == 0 ? 0 : 0.25 + intensity * 0.75)
                                .frame(width: proxy.size.width * additionShare)
                            WidtgetPalette.coral
                                .opacity(cell.totalChanged == 0 ? 0 : 0.22 + intensity * 0.68)
                        }
                        .background(WidtgetPalette.neutral)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay {
                            if cell.totalChanged > 0 && Double(cell.totalChanged) == maximum {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(WidtgetPalette.primaryText.opacity(0.62), lineWidth: 1)
                            }
                        }
                    }
                    .aspectRatio(1.7, contentMode: .fit)

                    if labels.indices.contains(index) {
                        Text(labels[index])
                            .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(WidtgetPalette.secondaryText)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityLabel("\(cell.additions) additions, \(cell.deletions) deletions")
            }
        }
    }
}

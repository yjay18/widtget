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

private enum CodingPetMood {
    case sleeping
    case curious
    case focused
    case celebrating
    case setupRequired
    case loading
    case worried

    init(snapshot: ActivitySnapshot) {
        switch snapshot.state {
        case .error:
            self = .worried
        case .setupRequired:
            self = .setupRequired
        case .loading:
            self = .loading
        case .loaded, .noActivity:
            let averageInterval = (snapshot.additions + snapshot.deletions)
                / max(snapshot.activity.count, 1)
            switch averageInterval {
            case 0:
                self = .sleeping
            case 1..<500:
                self = .curious
            case 500..<2_500:
                self = .focused
            default:
                self = .celebrating
            }
        }
    }

    var title: String {
        switch self {
        case .sleeping: "BYTE IS NAPPING"
        case .curious: "BYTE WOKE UP"
        case .focused: "BYTE IS LOCKED IN"
        case .celebrating: "BYTE IS THRIVING"
        case .setupRequired: "BYTE NEEDS A LOGIN"
        case .loading: "BYTE IS SNIFFING AROUND"
        case .worried: "BYTE LOST THE SIGNAL"
        }
    }

    var energy: Int {
        switch self {
        case .sleeping, .worried: 1
        case .setupRequired: 1
        case .loading: 2
        case .curious: 3
        case .focused: 4
        case .celebrating: 5
        }
    }

    var accent: Color {
        switch self {
        case .worried: WidtgetPalette.coral
        case .sleeping, .setupRequired, .loading: WidtgetPalette.secondaryText
        case .curious, .focused, .celebrating: WidtgetPalette.green
        }
    }
}

struct CodingPetView: View {
    let snapshot: ActivitySnapshot

    private var mood: CodingPetMood {
        CodingPetMood(snapshot: snapshot)
    }

    private var linesMoved: Int {
        snapshot.additions + snapshot.deletions
    }

    var body: some View {
        ZStack {
            PixelPetBackdrop(mood: mood)

            HStack(spacing: 10) {
                PixelCodingPet(mood: mood)
                    .frame(width: 82, height: 66)

                VStack(alignment: .leading, spacing: 5) {
                    Text("CODE COMPANION")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(WidtgetPalette.secondaryText)

                    Text(mood.title)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(WidtgetPalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: 6) {
                        Text(activityDescription)
                            .font(.system(size: 7, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(mood.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer(minLength: 1)

                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { index in
                                Rectangle()
                                    .fill(index < mood.energy ? mood.accent : WidtgetPalette.neutral)
                                    .frame(width: 6, height: 3)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Code companion. \(mood.title). \(activityDescription).")
    }

    private var activityDescription: String {
        switch mood {
        case .setupRequired:
            "CONNECT GITHUB"
        case .loading:
            "FETCHING ACTIVITY"
        case .worried:
            "REFRESH NEEDED"
        case .sleeping:
            "NO LINES MOVED"
        case .curious, .focused, .celebrating:
            "\(unsignedCompact(linesMoved)) LINES MOVED"
        }
    }

    private func unsignedCompact(_ value: Int) -> String {
        String(ActivityNumberFormat.compact(value, sign: "+").dropFirst())
    }
}

private struct PixelPetBackdrop: View {
    let mood: CodingPetMood

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            let cloudColor = WidtgetPalette.secondaryText.opacity(0.18)
            let dotSpacing: CGFloat = 2.1
            let dotSize: CGFloat = 0.85
            let cloudOrigin = CGPoint(x: max(8, size.width - 75), y: 7)

            for row in 0..<8 {
                let range: Range<Int>
                switch row {
                case 0...1: range = 12..<24
                case 2...3: range = 6..<29
                default: range = 0..<34
                }
                for column in range {
                    let rect = CGRect(
                        x: cloudOrigin.x + CGFloat(column) * dotSpacing,
                        y: cloudOrigin.y + CGFloat(row) * dotSpacing,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(rect), with: .color(cloudColor))
                }
            }

            let stars: [(CGFloat, CGFloat)] = [
                (0.08, 0.25), (0.43, 0.13), (0.88, 0.46), (0.68, 0.72)
            ]
            for (index, star) in stars.enumerated() {
                let center = CGPoint(x: size.width * star.0, y: size.height * star.1)
                let color = index.isMultiple(of: 2)
                    ? WidtgetPalette.green.opacity(0.52)
                    : WidtgetPalette.coral.opacity(0.48)
                let vertical = CGRect(x: center.x - 0.6, y: center.y - 3, width: 1.2, height: 6)
                let horizontal = CGRect(x: center.x - 3, y: center.y - 0.6, width: 6, height: 1.2)
                context.fill(Path(vertical), with: .color(color))
                context.fill(Path(horizontal), with: .color(color))
            }

            let groundY = size.height - 9
            for x in stride(from: CGFloat(0), through: size.width, by: 4) {
                let isLive = Int(x / 4).isMultiple(of: 7)
                let color = isLive ? mood.accent.opacity(0.62) : WidtgetPalette.border.opacity(0.85)
                let rect = CGRect(x: x, y: groundY, width: 1.6, height: 1.6)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct PixelCodingPet: View {
    let mood: CodingPetMood

    private let sprite = [
        "......##......",
        "......##......",
        "....######....",
        "..##########..",
        ".############.",
        ".############.",
        "..##########..",
        "...########...",
        "...##.##.##...",
        "..###.##.###..",
        "..##......##.."
    ]

    var body: some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            let columns: CGFloat = 16
            let rows: CGFloat = 12
            let pixel = max(2, floor(min(size.width / columns, size.height / rows)))
            let origin = CGPoint(
                x: (size.width - 14 * pixel) / 2,
                y: (size.height - 11 * pixel) / 2
            )

            for (row, line) in sprite.enumerated() {
                for (column, value) in line.enumerated() where value == "#" {
                    let rect = CGRect(
                        x: origin.x + CGFloat(column) * pixel,
                        y: origin.y + CGFloat(row) * pixel,
                        width: pixel - 0.55,
                        height: pixel - 0.55
                    )
                    context.fill(Path(rect), with: .color(bodyColor))
                }
            }

            let armPixels: [(Int, Int)]
            switch mood {
            case .celebrating:
                armPixels = [(-1, 2), (0, 3), (13, 3), (14, 2)]
            case .curious:
                armPixels = [(-1, 5), (13, 3), (14, 2)]
            case .worried:
                armPixels = [(-1, 6), (14, 6)]
            default:
                armPixels = [(-1, 5), (14, 5)]
            }
            for (column, row) in armPixels {
                let rect = CGRect(
                    x: origin.x + CGFloat(column) * pixel,
                    y: origin.y + CGFloat(row) * pixel,
                    width: pixel - 0.55,
                    height: pixel - 0.55
                )
                context.fill(Path(rect), with: .color(bodyColor))
            }

            let eyeWidth = mood == .sleeping ? pixel * 1.8 : pixel * 1.45
            let eyeHeight = mood == .sleeping ? max(1, pixel * 0.28) : pixel * 1.18
            let eyeY = origin.y + pixel * (mood == .sleeping ? 5.0 : 4.45)
            for column in [3.0, 9.55] {
                let rect = CGRect(
                    x: origin.x + pixel * column,
                    y: eyeY,
                    width: eyeWidth,
                    height: eyeHeight
                )
                context.fill(Path(rect), with: .color(eyeColor))
            }

            if mood == .celebrating {
                let mouth = CGRect(
                    x: origin.x + pixel * 6,
                    y: origin.y + pixel * 6.1,
                    width: pixel * 2,
                    height: pixel * 0.65
                )
                context.fill(Path(mouth), with: .color(eyeColor))
            }
        }
        .accessibilityHidden(true)
    }

    private var bodyColor: Color {
        switch mood {
        case .sleeping, .setupRequired, .loading:
            WidtgetPalette.secondaryText.opacity(0.62)
        case .curious:
            WidtgetPalette.coral.opacity(0.72)
        case .focused:
            WidtgetPalette.coral.opacity(0.88)
        case .celebrating, .worried:
            WidtgetPalette.coral
        }
    }

    private var eyeColor: Color {
        mood == .worried ? WidtgetPalette.green.opacity(0.82) : Color.black.opacity(0.72)
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

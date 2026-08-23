import SwiftUI
import WidgetKit

// Phosphor: the week as terminal output. Monospaced throughout, block-glyph
// sparklines instead of bar views, amber deletions, a static caret marking it live.
enum PhosphorPalette {
    static let base = Color(red: 0.024, green: 0.035, blue: 0.039)
    static let green = Color(red: 0.290, green: 0.941, blue: 0.541)
    static let dim = Color(red: 0.173, green: 0.561, blue: 0.345)
    static let amber = Color(red: 1.0, green: 0.702, blue: 0.251)
    static let light = Color(red: 0.812, green: 0.910, blue: 0.847)
}

private let sparkBlocks = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

private func sparkline(_ cells: [ActivityCell]) -> String {
    let peak = max(cells.map(\.totalChanged).max() ?? 0, 1)
    return cells.map { cell -> String in
        let level = Int((7.0 * Double(cell.totalChanged) / Double(peak)).rounded())
        return sparkBlocks[min(max(level, 0), 7)]
    }.joined()
}

private func meterBar(fraction: Double, width: Int = 8) -> String {
    let filled = min(max(Int((Double(width) * fraction).rounded()), 0), width)
    return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
}

struct PhosphorWidgetView: View {
    // Clear the opaque ground when macOS de-emphasizes the widget (vibrant mode).
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: ActivityEntry
    let preferences: WidgetViewPreferences
    let family: WidgetLayoutFamily

    var body: some View {
        Group {
            switch family {
            case .small: small
            case .medium: medium
            case .large: large
            case .extraLarge: extraLarge
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .padding(13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(renderingMode == .fullColor ? PhosphorPalette.base : Color.clear)
        .foregroundStyle(PhosphorPalette.green)
    }

    private var loading: Bool { entry.snapshot.state == .loading }
    private var user: String { entry.username.isEmpty ? "github" : entry.username }
    private var netSign: Character { entry.snapshot.net < 0 ? "−" : "+" }

    private func value(_ v: Int, sign: Character) -> String {
        loading ? "\(sign)—" : "\(sign)\(abs(v))"
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            PhosphorHeader(entry: entry, user: user, compact: true)
            dim("$ git log --stat")
            Text(value(entry.snapshot.additions, sign: "+"))
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundStyle(PhosphorPalette.green).lineLimit(1).minimumScaleFactor(0.5)
            Text(value(entry.snapshot.deletions, sign: "−"))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(PhosphorPalette.amber)
            Text(sparkline(entry.snapshot.activity))
                .font(.system(size: 16, design: .monospaced)).foregroundStyle(PhosphorPalette.green)
            Spacer(minLength: 0)
            dim("\(entry.snapshot.commits) commits · \(entry.snapshot.repositories.count) repos")
            HStack(spacing: 4) {
                dim("peak \(entry.peakLabel.lowercased())")
                Text("█").foregroundStyle(PhosphorPalette.green)
            }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            PhosphorHeader(entry: entry, user: user)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    dim("$ git log --numstat --since=1.week")
                    Text(value(entry.snapshot.additions, sign: "+"))
                        .font(.system(size: 30, weight: .bold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.5)
                    Text(value(entry.snapshot.deletions, sign: "−"))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PhosphorPalette.amber)
                    Text(sparkline(entry.snapshot.activity)).font(.system(size: 16, design: .monospaced))
                    Spacer(minLength: 0)
                    dim(axisString + " · net \(value(entry.snapshot.net, sign: netSign))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                repoColumn(limit: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(PhosphorPalette.dim.opacity(0.5)).frame(width: 1).offset(x: -7)
                    }
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhosphorHeader(entry: entry, user: user)
            dim("$ git log --numstat --since=1.week")
            Text(value(entry.snapshot.additions, sign: "+"))
                .font(.system(size: 38, weight: .bold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.5)
            Text(value(entry.snapshot.deletions, sign: "−"))
                .font(.system(size: 18, weight: .semibold, design: .monospaced)).foregroundStyle(PhosphorPalette.amber)
            Text(sparkline(entry.snapshot.activity)).font(.system(size: 22, design: .monospaced))
            dim(axisString)
            statsLine
            Rectangle().fill(PhosphorPalette.dim.opacity(0.4)).frame(height: 1).padding(.vertical, 2)
            repoColumn(limit: preferences.repositoryDetail.largeLimit)
            Spacer(minLength: 0)
        }
    }

    private var extraLarge: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhosphorHeader(entry: entry, user: user)
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    dim("$ git log --numstat")
                    Text(value(entry.snapshot.additions, sign: "+"))
                        .font(.system(size: 46, weight: .bold, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.5)
                    Text(value(entry.snapshot.deletions, sign: "−"))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced)).foregroundStyle(PhosphorPalette.amber)
                    Spacer(minLength: 0)
                    statsLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    dim("activity")
                    Text(sparkline(entry.snapshot.activity)).font(.system(size: 30, design: .monospaced))
                    dim(axisString)
                    Spacer(minLength: 0)
                    dim("peak \(entry.peakLabel.lowercased()) · \(entry.snapshot.activeIntervals)/\(max(entry.snapshot.activity.count, 1)) active")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    Rectangle().fill(PhosphorPalette.dim.opacity(0.5)).frame(width: 1).offset(x: -9)
                }

                repoColumn(limit: preferences.repositoryDetail.extraLargeLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(PhosphorPalette.dim.opacity(0.5)).frame(width: 1).offset(x: -9)
                    }
            }
        }
    }

    private var statsLine: some View {
        dim("net \(value(entry.snapshot.net, sign: netSign)) · avg \(entry.snapshot.averagePerCommit) · peak \(entry.peakLabel.lowercased())")
    }

    private var axisString: String {
        entry.intervalLabels().map { $0.lowercased() }.joined(separator: " ")
    }

    private func repoColumn(limit: Int) -> some View {
        let peak = max(entry.snapshot.repositories.map(\.additions).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 3) {
            dim("\(entry.snapshot.repositories.count) repositories")
            if entry.snapshot.repositories.isEmpty {
                dim("no repository activity")
            } else {
                ForEach(entry.snapshot.visibleRepositories(limit: limit)) { repo in
                    HStack(spacing: 6) {
                        Text(repo.name).foregroundStyle(PhosphorPalette.light).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(meterBar(fraction: Double(repo.additions) / Double(peak)))
                            .foregroundStyle(PhosphorPalette.dim)
                        Text(ActivityNumberFormat.compact(repo.additions, sign: "+"))
                            .foregroundStyle(PhosphorPalette.green)
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                dim("\(entry.snapshot.averagePerCommit) avg/commit")
                Text("█").foregroundStyle(PhosphorPalette.green).font(.system(size: 10, design: .monospaced))
            }
        }
    }

    private func dim(_ text: String) -> some View {
        Text(text).foregroundStyle(PhosphorPalette.dim).lineLimit(1).minimumScaleFactor(0.6)
    }
}

private struct PhosphorHeader: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: ActivityEntry
    let user: String
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Text("~/\(user)").foregroundStyle(PhosphorPalette.green).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Link(destination: URL(string: "widtget://refresh")!) {
                Text("↻").foregroundStyle(entry.snapshot.state == .error ? PhosphorPalette.amber : PhosphorPalette.dim)
            }
            .accessibilityLabel("Refresh GitHub activity")
            Button(intent: SetActivityPeriodIntent(
                period: entry.period.toggled,
                family: ActivityWidgetFamily(widgetFamily: widgetFamily),
                configuredPeriod: entry.configuredPeriod
            )) {
                Text("[\(entry.period.rawValue.lowercased())]").foregroundStyle(PhosphorPalette.light)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(entry.period.toggled.rawValue) activity")
        }
        .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
    }
}

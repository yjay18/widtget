import SwiftUI

struct PeriodHeader: View {
    @Environment(\.widgetFamily) private var family

    let entry: ActivityEntry
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 7) {
            Text(entry.username.isEmpty ? "GitHub" : "@\(entry.username)")
                .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded))
                .foregroundStyle(WidtgetPalette.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 4)

            Link(destination: URL(string: "widtget://refresh")!) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(refreshColor)
                    .frame(width: 16, height: 16)
            }
            .accessibilityLabel("Refresh GitHub activity")

            Button(
                intent: SetActivityPeriodIntent(
                    period: entry.period.toggled,
                    family: ActivityWidgetFamily(widgetFamily: family),
                    configuredPeriod: entry.configuredPeriod
                )
            ) {
                Text(entry.period.displayName)
                    .font(.system(size: compact ? 7 : 8, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(WidtgetPalette.ink)
                    .padding(.horizontal, compact ? 5 : 7)
                    .padding(.vertical, compact ? 3 : 4)
                    .background(WidtgetPalette.lime)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(entry.period.toggled.rawValue) activity")
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 6 : 7)
        .background(WidtgetPalette.ink)
    }

    private var refreshColor: Color {
        entry.snapshot.state == .error ? WidtgetPalette.orange : WidtgetPalette.lime
    }
}

struct PrimaryMetric: View {
    let value: Int
    let label: String
    let sign: Character
    let color: Color
    let fontSize: CGFloat
    let loading: Bool

    var body: some View {
        Text(loading ? "\(sign)––,–––" : ActivityNumberFormat.exact(value, sign: sign))
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(loading ? WidtgetPalette.secondaryText.opacity(0.45) : color)
            .lineLimit(1)
            .minimumScaleFactor(0.48)
            .contentTransition(.numericText())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

struct SecondaryMetrics: View {
    let snapshot: ActivitySnapshot
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 12) {
            metric(value: snapshot.commits, label: "commit")
            Rectangle()
                .fill(WidtgetPalette.ink)
                .frame(width: 1, height: 11)
            metric(value: snapshot.repositories.count, label: "repository")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 9 : 11)
        .frame(height: compact ? 25 : 30)
        .background(WidtgetPalette.lime)
    }

    private func metric(value: Int, label: String) -> some View {
        let displayLabel = value == 1 ? label : "\(label)s"

        return HStack(spacing: 3) {
            Text(snapshot.state == .loading ? "––" : value.formatted())
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WidtgetPalette.ink)
            Text(displayLabel)
                .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                .foregroundStyle(WidtgetPalette.ink.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(displayLabel)")
    }
}

struct UpdateStatus: View {
    let snapshot: ActivitySnapshot

    var body: some View {
        Group {
            if snapshot.state == .setupRequired {
                Text("Open app to connect")
            } else if snapshot.state == .error {
                Text(snapshot.errorMessage ?? "Couldn’t refresh")
                    .foregroundStyle(WidtgetPalette.coral)
            } else if snapshot.state == .noActivity {
                Text("No activity")
            } else if snapshot.state == .loading {
                Text("Loading activity")
            } else if snapshot.isStale {
                Text("Stale · \(snapshot.updatedAt, style: .relative)")
            } else {
                Text("Updated \(snapshot.updatedAt, style: .relative)")
            }
        }
        .font(.system(size: 8, weight: .medium, design: .rounded))
        .foregroundStyle(WidtgetPalette.ink.opacity(0.64))
        .lineLimit(1)
    }
}

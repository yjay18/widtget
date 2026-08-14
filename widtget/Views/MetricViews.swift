import SwiftUI

struct PeriodHeader: View {
    @Environment(\.widgetFamily) private var family

    let entry: ActivityEntry
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 7) {
            if !compact {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WidtgetPalette.green)
            }

            Text(entry.username.isEmpty ? "GitHub" : "@\(entry.username)")
                .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WidtgetPalette.primaryText)
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
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(WidtgetPalette.primaryText)
                    .padding(.horizontal, compact ? 5 : 7)
                    .padding(.vertical, 4)
                    .background(.clear)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(WidtgetPalette.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(entry.period.toggled.rawValue) activity")
        }
    }

    private var refreshColor: Color {
        entry.snapshot.state == .error ? WidtgetPalette.coral : WidtgetPalette.secondaryText
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
                .fill(WidtgetPalette.border)
                .frame(width: 1, height: 11)
            metric(value: snapshot.repositories.count, label: "repository")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .frame(height: compact ? 23 : 27)
        .widtgetSurface(cornerRadius: 8)
    }

    private func metric(value: Int, label: String) -> some View {
        let displayLabel = value == 1 ? label : "\(label)s"

        return HStack(spacing: 3) {
            Text(snapshot.state == .loading ? "––" : value.formatted())
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WidtgetPalette.primaryText)
            Text(displayLabel)
                .font(.system(size: compact ? 8 : 9, weight: .medium, design: .rounded))
                .foregroundStyle(WidtgetPalette.secondaryText)
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
        .foregroundStyle(WidtgetPalette.secondaryText)
        .lineLimit(1)
    }
}

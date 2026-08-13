import SwiftUI

struct PeriodHeader: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WidtgetPalette.green)

            Text("widtget")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WidtgetPalette.primaryText)

            Spacer(minLength: 4)

            statusView

            Text(entry.period.displayName)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(WidtgetPalette.primaryText)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(WidtgetPalette.raisedSurface)
                .clipShape(Capsule())
                .overlay { Capsule().stroke(WidtgetPalette.border, lineWidth: 1) }
                .accessibilityLabel("Period: \(entry.period.rawValue)")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch entry.snapshot.state {
        case .loading:
            Text("SYNCING")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(WidtgetPalette.secondaryText)
        case .error:
            Button(intent: RefreshActivityIntent()) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(WidtgetPalette.coral)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry activity refresh")
        case .loaded, .noActivity:
            EmptyView()
        }
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
        VStack(alignment: .leading, spacing: 0) {
            Text(loading ? "\(sign)––,–––" : ActivityNumberFormat.exact(value, sign: sign))
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(loading ? WidtgetPalette.secondaryText.opacity(0.45) : color)
                .lineLimit(1)
                .minimumScaleFactor(0.48)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(WidtgetPalette.secondaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

struct SecondaryMetrics: View {
    let snapshot: ActivitySnapshot
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 12) {
            metric(value: snapshot.commits, label: "commits")
            Rectangle()
                .fill(WidtgetPalette.border)
                .frame(width: 1, height: 11)
            metric(value: snapshot.repositories.count, label: "repositories")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .frame(height: compact ? 23 : 27)
        .widtgetSurface(cornerRadius: 8)
    }

    private func metric(value: Int, label: String) -> some View {
        HStack(spacing: 3) {
            Text(snapshot.state == .loading ? "––" : value.formatted())
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WidtgetPalette.primaryText)
            Text(label)
                .font(.system(size: compact ? 8 : 9, weight: .medium, design: .rounded))
                .foregroundStyle(WidtgetPalette.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

struct UpdateStatus: View {
    let snapshot: ActivitySnapshot

    var body: some View {
        Group {
            if snapshot.state == .error {
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

import SwiftUI

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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var maximum: Double {
        Double(max(cells.map(\.totalChanged).max() ?? 0, 1))
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(cells) { cell in
                let intensity = Double(cell.totalChanged) / maximum
                let additionShare = cell.totalChanged == 0 ? 0 : Double(cell.additions) / Double(cell.totalChanged)

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
                .accessibilityLabel("\(cell.additions) additions, \(cell.deletions) deletions")
            }
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

private enum HostSection: String, CaseIterable, Identifiable {
    case dashboard
    case widgets
    case connections

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .widgets: "Widget Studio"
        case .connections: "Connections"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "waveform.path.ecg"
        case .widgets: "square.grid.3x3.fill"
        case .connections: "key.horizontal.fill"
        }
    }
}

struct WidgetSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var github = GitHubAccountModel()
    @State private var showingDisconnectConfirmation = false
    @State private var showingRemoveOrganizationConfirmation = false
    @State private var organizationPendingRemoval: GitHubConnectionSummary?
    @State private var isReplacingAccountToken = false
    @State private var isAddingOrganization = false
    @State private var selectedSection: HostSection = .dashboard
    @State private var dashboardWindowMode = PeriodWindowMode.fixed
    @State private var paneOrder = SharedPreferences.modularPreferences.paneOrder
    @State private var enabledPanes = SharedPreferences.modularPreferences.enabledPanes
    @State private var blockworkColorway = SharedPreferences.modularPreferences.colorway
    @State private var visualTheme = SharedPreferences.modularPreferences.visualTheme
    @State private var familyLayouts = SharedPreferences.modularPreferences.familyLayouts
    @State private var blockColors = SharedPreferences.modularPreferences.blockColors
    @State private var selectedBlock: WidgetPane = .additions
    @State private var draggedPane: WidgetPane?
    @State private var draggedOrigin: WidgetSlotOrigin?

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Group {
                switch selectedSection {
                case .dashboard:
                    if visualTheme == .blockwork {
                        BlockworkAnalyticsDashboardView(
                            github: github,
                            windowMode: $dashboardWindowMode,
                            openConnections: { selectedSection = .connections }
                        )
                    } else {
                        AnalyticsDashboardView(
                            github: github,
                            windowMode: $dashboardWindowMode,
                            openConnections: { selectedSection = .connections }
                        )
                    }
                case .widgets:
                    widgetStudioContent
                case .connections:
                    connectionsContent
                }
            }
        }
        .frame(minWidth: 880, minHeight: 640)
        .background(DashboardPalette.ink)
        .preferredColorScheme(.dark)
        .task {
            migrateToFixedDefaultIfNeeded()
            reloadWidgets()
            await github.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await github.handleActivation() }
        }
        .onChange(of: paneOrder) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: enabledPanes) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: blockworkColorway) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: visualTheme) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: familyLayouts) { _, _ in
            saveWidgetStudio()
        }
        .onChange(of: blockColors) { _, _ in
            saveWidgetStudio()
        }
        .onOpenURL { url in
            guard url.scheme == "widtget", url.host == "refresh" else { return }
            Task { await github.refresh(scope: .recentBranches) }
        }
        .confirmationDialog(
            "Disconnect @\(github.username)?",
            isPresented: $showingDisconnectConfirmation
        ) {
            Button("Disconnect GitHub", role: .destructive) {
                github.disconnect()
            }
        } message: {
            Text("The Keychain token and cached widget activity will be removed from this Mac.")
        }
        .confirmationDialog(
            "Remove \(organizationPendingRemoval?.owner ?? "organization")?",
            isPresented: $showingRemoveOrganizationConfirmation
        ) {
            Button("Remove organization", role: .destructive) {
                guard let id = organizationPendingRemoval?.id else { return }
                Task { await github.removeOrganization(id: id) }
            }
        } message: {
            Text("Its token will be removed from Keychain and its repositories will stop contributing to the widget.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DashboardPalette.green)
                    Text("W")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(DashboardPalette.ink)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("widtget")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text("GITHUB SIGNAL")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(DashboardPalette.muted)
                }
            }
            .padding(.horizontal, 14)

            VStack(spacing: 5) {
                ForEach(HostSection.allCases) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 18)
                            Text(section.title)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundStyle(selectedSection == section ? DashboardPalette.text : DashboardPalette.muted)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            selectedSection == section ? DashboardPalette.lifted : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .overlay(alignment: .leading) {
                            if selectedSection == section {
                                Capsule()
                                    .fill(DashboardPalette.green)
                                    .frame(width: 3, height: 18)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)

            Spacer()

            if github.hasStoredToken {
                VStack(alignment: .leading, spacing: 5) {
                    Text(github.username.isEmpty ? "CONNECTED" : "@\(github.username)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(github.phase == .failed ? DashboardPalette.coral : DashboardPalette.green)
                            .frame(width: 6, height: 6)
                        Text(github.phase == .failed ? "REFRESH NEEDED" : "SNAPSHOT READY")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(DashboardPalette.muted)
                    }
                }
                .padding(14)
            }
        }
        .padding(.vertical, 14)
        .frame(width: 176)
        .background(DashboardPalette.panel.opacity(0.9))
        .overlay(alignment: .trailing) {
            Rectangle().fill(DashboardPalette.line).frame(width: 1)
        }
        .foregroundStyle(DashboardPalette.text)
    }

    private var widgetStudioContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        visualTheme == .blockwork
                            ? "BLOCKWORK / WIDGET SYSTEM"
                            : "\(visualTheme.displayName.uppercased()) / FIXED LAYOUT"
                    )
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(studioOrange)
                    Text(visualTheme == .blockwork ? "Build your widtget" : visualTheme.displayName)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(-1.2)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text("THEME · APPLIES TO WIDGETS + DASHBOARD")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(studioMuted)
                    Picker("Theme", selection: $visualTheme) {
                        ForEach(WidgetVisualTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 230)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .foregroundStyle(studioPaper)
            .background(studioInk)

            if visualTheme == .blockwork {
                HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BLOCK LIBRARY")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1)
                            Text("Drag a block into any family slot")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(studioMuted)
                        }
                        Spacer()
                        Text("\(WidgetPane.allCases.count)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }

                    VStack(spacing: 0) {
                        ForEach(WidgetPane.allCases) { pane in
                            blockLibraryRow(pane)
                        }
                    }
                    .overlay {
                        Rectangle()
                            .stroke(studioInk, lineWidth: 2)
                    }

                    blockColorEditor

                    Spacer()
                }
                .padding(24)
                .frame(width: 330)
                .background(studioPaper)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("FAMILY COMPOSER")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1)
                        Spacer()
                        Text("1 / 2 / 3 / 4 FIXED SLOTS")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(studioMuted)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        familyComposer(.small, width: 170, height: 170)
                        familyComposer(.medium, width: 360, height: 170)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        familyComposer(.large, width: 360, height: 330)
                        Spacer(minLength: 0)
                    }

                    familyComposer(.extraLarge, width: 650, height: 310)

                    HStack(spacing: 7) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Changes reload WidgetKit timelines automatically")
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(studioMuted)

                    Spacer()
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.62, green: 0.18, blue: 0.32))
                }
            } else {
                defaultWidgetStudioOverview
            }
        }
    }

    private var defaultWidgetStudioOverview: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(visualTheme.displayName.uppercased()) IS FIXED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(DashboardPalette.green)
                    Text("A fixed size-specific layout")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .tracking(-0.6)
                    Text("\(visualTheme.displayName) keeps its own size-specific hierarchy. Blockwork slots, block order, and poster colors never alter it.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(DashboardPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    defaultRule("Small, Medium, Large, and Extra Large keep their original compositions")
                    defaultRule("Daily / Weekly and per-widget App Intent controls still apply")
                    defaultRule("Activity values normalize inside bounded chart frames")
                    defaultRule("Repository detail and update visibility remain supported")
                }
                .padding(14)
                .background(DashboardPalette.lifted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DashboardPalette.line, lineWidth: 1)
                }

                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        visualTheme = .blockwork
                    }
                } label: {
                    Label("Customize Blockwork", systemImage: "square.grid.3x3.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DashboardPalette.green)
                .foregroundStyle(DashboardPalette.ink)

                Spacer()
            }
            .padding(24)
            .frame(width: 330)
            .foregroundStyle(DashboardPalette.text)
            .background(DashboardPalette.panel)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("FIXED FAMILY LAYOUTS")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1)
                            Text("Read-only previews · no slots or block colors")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(DashboardPalette.muted)
                        }
                        Spacer()
                        Text("ORIGINAL")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(DashboardPalette.green)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        fixedDefaultPreview(.small, width: 170, height: 170)
                        fixedDefaultPreview(.medium, width: 360, height: 170)
                    }

                    fixedDefaultPreview(.large, width: 360, height: 330)
                    fixedDefaultPreview(.extraLarge, width: 650, height: 310)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(DashboardPalette.text)
            .background(DashboardPalette.ink)
        }
    }

    private func defaultRule(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DashboardPalette.green)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(DashboardPalette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fixedDefaultPreview(
        _ family: WidgetLayoutFamily,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(family.displayName.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.9)
                Spacer()
                Text("FIXED")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(DashboardPalette.green)
            }

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    if family != .small {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundStyle(DashboardPalette.green)
                    }
                    Text(github.username.isEmpty ? "@yjay18" : "@\(github.username)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("DAILY")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .overlay { Capsule().stroke(DashboardPalette.line, lineWidth: 1) }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)

                defaultPreviewBody(family)
                    .padding(family == .small ? 9 : 10)
            }
            .frame(width: width, height: height)
            .background(DashboardPalette.ink)
            .clipShape(RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.24), radius: 14, y: 9)
        }
    }

    @ViewBuilder
    private func defaultPreviewBody(_ family: WidgetLayoutFamily) -> some View {
        switch family {
        case .small:
            VStack(alignment: .leading, spacing: 4) {
                defaultPreviewMetric("+25,036", color: DashboardPalette.green, size: 25)
                defaultPreviewMetric("−1,031", color: DashboardPalette.coral, size: 21)
                Spacer(minLength: 0)
                defaultPreviewSummary
                defaultPreviewBars(height: 8)
            }
        case .medium:
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    defaultPreviewMetric("+25,036", color: DashboardPalette.green, size: 24)
                    defaultPreviewMetric("−1,031", color: DashboardPalette.coral, size: 21)
                    defaultPreviewSummary
                }
                Rectangle().fill(DashboardPalette.line).frame(width: 1)
                VStack(alignment: .leading, spacing: 7) {
                    defaultPreviewRepos(rows: 2)
                    Spacer(minLength: 0)
                    defaultPreviewBars(height: 13)
                }
            }
        case .large:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    defaultPreviewCard("+25,036", color: DashboardPalette.green)
                    defaultPreviewCard("−1,031", color: DashboardPalette.coral)
                }
                defaultPreviewSummary
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ACTIVITY").font(.system(size: 7, weight: .bold, design: .rounded))
                        defaultPreviewBars(height: 38)
                        HStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DashboardPalette.green.opacity(0.5))
                                    .frame(height: 10)
                            }
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))

                    defaultPreviewRepos(rows: 4)
                        .padding(9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
                }
            }
        case .extraLarge:
            HStack(spacing: 10) {
                VStack(spacing: 8) {
                    defaultPreviewCard("+25,036", color: DashboardPalette.green)
                    defaultPreviewCard("−1,031", color: DashboardPalette.coral)
                    defaultPreviewSummary
                }
                VStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ACTIVITY").font(.system(size: 7, weight: .bold, design: .rounded))
                        defaultPreviewBars(height: 48)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
                    HStack(spacing: 3) {
                        ForEach(0..<12, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index < 8 ? DashboardPalette.green : DashboardPalette.lifted)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
                }
                defaultPreviewRepos(rows: 6)
                    .padding(9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private func defaultPreviewMetric(_ text: String, color: Color, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var defaultPreviewSummary: some View {
        HStack(spacing: 7) {
            Text("29 commits")
            Rectangle().fill(DashboardPalette.line).frame(width: 1, height: 9)
            Text("3 repositories")
            Spacer(minLength: 0)
        }
        .font(.system(size: 7, weight: .semibold, design: .rounded))
        .foregroundStyle(DashboardPalette.muted)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 7))
    }

    private func defaultPreviewCard(_ text: String, color: Color) -> some View {
        defaultPreviewMetric(text, color: color, size: 25)
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(DashboardPalette.panel, in: RoundedRectangle(cornerRadius: 9))
    }

    private func defaultPreviewBars(height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array([0.22, 0.68, 0.34, 0.92, 0.08, 0.56, 0.75].enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DashboardPalette.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(2, height * value))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)
        .clipped()
    }

    private func defaultPreviewRepos(rows: Int) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(0..<rows), id: \.self) { index in
                VStack(spacing: 3) {
                    HStack {
                        Text(["widtget", "studio", "signal", "tools", "notes", "parser"][index % 6])
                        Spacer()
                        Text("+\(index + 1)k")
                            .foregroundStyle(DashboardPalette.green)
                    }
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DashboardPalette.lifted)
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DashboardPalette.green)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(x: 1 - Double(index) * 0.12, anchor: .leading)
                        }
                }
            }
        }
    }

    private func blockLibraryRow(_ block: WidgetPane) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedBlock = block
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(studioMuted)

                Image(systemName: block.studioSymbol)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.displayName)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                    Text(block.detail)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(studioMuted)
                        .lineLimit(1)
                }

                Spacer()

                if selectedBlock == block {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(studioOrange)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 46)
            .background(selectedBlock == block ? studioLime.opacity(0.26) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(studioInk.opacity(0.22)).frame(height: 1)
        }
        .onDrag {
            selectedBlock = block
            draggedPane = block
            draggedOrigin = nil
            return NSItemProvider(object: block.rawValue as NSString)
        }
    }

    private var blockColorEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SELECTED BLOCK")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(studioMuted)
                    Text(selectedBlock.displayName)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                }
                Spacer()
                Image(systemName: selectedBlock.studioSymbol)
                    .font(.system(size: 15, weight: .black))
            }

            HStack(spacing: 8) {
                ForEach(WidgetBlockColor.allCases) { color in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            blockColors[selectedBlock] = color
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(studioSwatch(color))
                                .frame(width: 24, height: 24)
                            if selectedBlockColor == color {
                                Image(systemName: color == .automatic ? "a.circle.fill" : "checkmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(color == .ink ? studioPaper : studioInk)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(color.displayName)
                }
            }

            Text("Auto uses Blockwork's semantic poster color for this block.")
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(studioMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(studioInk.opacity(0.055))
        .overlay {
            Rectangle().stroke(studioInk, lineWidth: 2)
        }
    }

    private func familyComposer(
        _ family: WidgetLayoutFamily,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(family.displayName.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.9)
                Spacer()
                Text("\(family.slotCount) \(family.slotCount == 1 ? "SLOT" : "SLOTS")")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(studioMuted)
            }

            VStack(spacing: 0) {
                HStack {
                    Text(github.username.isEmpty ? "@yjay18" : "@\(github.username)")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                    Spacer()
                    Text("W")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .foregroundStyle(studioInk)
                        .background(studioLime)
                }
                .padding(.horizontal, 9)
                .frame(height: 30)
                .foregroundStyle(studioPaper)
                .background(studioInk)

                GeometryReader { proxy in
                    familySlotLayout(family, size: proxy.size)
                        .padding(3)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .background(studioInk)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: family == .small ? 24 : 20, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 9)
        }
    }

    @ViewBuilder
    private func familySlotLayout(_ family: WidgetLayoutFamily, size: CGSize) -> some View {
        let slots = familyLayouts[family]
            ?? WidgetModularPreferences.defaults.familyLayouts[family]
            ?? []
        let spacing: CGFloat = 3

        switch family {
        case .small:
            if let block = slots.first {
                composerSlot(family: family, index: 0, block: block)
            }
        case .medium:
            HStack(spacing: spacing) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, block in
                    composerSlot(family: family, index: index, block: block)
                }
            }
        case .large:
            VStack(spacing: spacing) {
                if let first = slots.first {
                    composerSlot(family: family, index: 0, block: first)
                        .frame(height: max(0, (size.height - spacing) * 0.44))
                }
                HStack(spacing: spacing) {
                    ForEach(Array(slots.dropFirst().enumerated()), id: \.offset) { offset, block in
                        composerSlot(family: family, index: offset + 1, block: block)
                    }
                }
            }
        case .extraLarge:
            HStack(spacing: spacing) {
                ForEach(Array(slots.enumerated()), id: \.offset) { index, block in
                    composerSlot(family: family, index: index, block: block)
                }
            }
        }
    }

    private func composerSlot(
        family: WidgetLayoutFamily,
        index: Int,
        block: WidgetPane
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedBlock = block
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: block.studioSymbol)
                    Spacer()
                    Text("\(index + 1)")
                }
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .opacity(0.68)

                Spacer(minLength: 0)

                Text(block.displayName)
                    .font(.system(size: family == .extraLarge ? 10 : 9, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(blockPreviewValue(block))
                    .font(.system(size: family == .small ? 18 : 15, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .padding(family == .small ? 9 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(studioBlockForeground(block))
            .background(studioBlockFill(block))
            .overlay {
                Rectangle()
                    .stroke(
                        selectedBlock == block ? studioOrange : Color.clear,
                        lineWidth: 3
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag {
            selectedBlock = block
            draggedPane = block
            draggedOrigin = WidgetSlotOrigin(family: family, index: index)
            return NSItemProvider(object: block.rawValue as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: WidgetSlotDropDelegate(
                destination: WidgetSlotOrigin(family: family, index: index),
                layouts: $familyLayouts,
                draggedPane: $draggedPane,
                draggedOrigin: $draggedOrigin
            )
        )
    }

    private var selectedBlockColor: WidgetBlockColor {
        blockColors[selectedBlock] ?? .automatic
    }

    private func studioSwatch(_ color: WidgetBlockColor) -> Color {
        switch color {
        case .automatic:
            studioPaper
        case .orange: studioOrange
        case .lime: studioLime
        case .sky: studioSky
        case .ink: studioInk
        case .paper: studioPaper
        }
    }

    private func studioBlockFill(_ block: WidgetPane) -> Color {
        let selected = blockColors[block] ?? .automatic
        if selected != .automatic {
            return studioSwatch(selected)
        }
        switch block {
        case .additions: return studioOrange
        case .deletions, .snake: return studioInk
        case .summary, .insights: return studioLime
        case .activity, .activityTable: return studioSky
        case .repositories: return studioPaper
        }
    }

    private func studioBlockForeground(_ block: WidgetPane) -> Color {
        let selected = blockColors[block] ?? .automatic
        let fillChoice: WidgetBlockColor
        if selected == .automatic {
            fillChoice = block == .deletions || block == .snake ? .ink : .paper
        } else {
            fillChoice = selected
        }
        return fillChoice == .ink ? studioPaper : studioInk
    }

    private func blockPreviewValue(_ block: WidgetPane) -> String {
        switch block {
        case .additions: "+25k"
        case .deletions: "−1k"
        case .summary: "29 / 3"
        case .activity: "▂▇▃▅"
        case .activityTable: "▦ ▦"
        case .insights: "+24k"
        case .repositories: "3 repos"
        case .snake: "snek happy"
        }
    }

    private func paneLibraryRow(_ pane: WidgetPane) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(studioMuted)

            Image(systemName: pane.studioSymbol)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(pane.displayName)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                Text(pane.detail)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(studioMuted)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: paneEnabledBinding(pane))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .frame(height: 54)
        .background(enabledPanes.contains(pane) ? studioLime.opacity(0.24) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(studioInk.opacity(0.24)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .onDrag {
            draggedPane = pane
            return NSItemProvider(object: pane.rawValue as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: WidgetPaneDropDelegate(
                destination: pane,
                panes: $paneOrder,
                draggedPane: $draggedPane
            )
        )
    }

    private var studioWidgetPreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text(github.username.isEmpty ? "@yjay18" : "@\(github.username)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                Spacer()
                Text("WEEKLY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(studioInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(studioLime)
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(studioLime)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .foregroundStyle(studioPaper)
            .background(studioInk)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 3),
                    GridItem(.flexible(), spacing: 3)
                ],
                spacing: 3
            ) {
                ForEach(paneOrder.filter(enabledPanes.contains)) { pane in
                    studioPanePreview(pane)
                }
            }
            .padding(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(studioInk)
        }
        .frame(maxWidth: 590, minHeight: 360, maxHeight: 430)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 22, y: 14)
        .hueRotation(studioHueRotation)
        .saturation(blockworkColorway == .mono ? 0 : 1)
        .animation(.snappy(duration: 0.28), value: paneOrder)
        .animation(.snappy(duration: 0.28), value: enabledPanes)
    }

    @ViewBuilder
    private func studioPanePreview(_ pane: WidgetPane) -> some View {
        switch pane {
        case .additions:
            studioPreviewTile(title: "LINES MADE", value: "+25,036", color: studioOrange)
        case .deletions:
            studioPreviewTile(
                title: "LINES REMOVED",
                value: "−1,031",
                color: studioInk,
                foreground: studioPaper,
                valueColor: studioOrange
            )
        case .summary:
            studioPreviewTile(title: "SUMMARY", value: "29 / 3", color: studioLime)
        case .activity:
            VStack(alignment: .leading, spacing: 10) {
                Text("ACTIVITY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array([0.92, 0.72, 0.23, 0.05, 0.78, 0.69, 0.66].enumerated()), id: \.offset) { _, value in
                        Rectangle()
                            .fill(studioInk)
                            .frame(height: 52 * value)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(studioSky)
        case .activityTable:
            studioPreviewTile(title: "ACTIVITY TABLE", value: "▦ ▦ ▦", color: studioSky)
        case .insights:
            studioPreviewTile(title: "NET / PEAK / AVG", value: "+24k", color: studioLime)
        case .repositories:
            VStack(alignment: .leading, spacing: 8) {
                Text("REPOSITORIES / 03")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                ForEach(["linguist  +19k", "Studio  +5k", "storymode  +659"], id: \.self) { repository in
                    Text(repository)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(studioInk).frame(height: 1)
                        }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(studioPaper)
        case .snake:
            HStack(spacing: 12) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 31, weight: .black))
                    .foregroundStyle(studioLime)
                VStack(alignment: .leading, spacing: 2) {
                    Text("snek happy")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Text("29 COMMITS")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(studioLime)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .foregroundStyle(studioPaper)
            .background(studioInk)
        }
    }

    private func studioPreviewTile(
        title: String,
        value: String,
        color: Color,
        foreground: Color? = nil,
        valueColor: Color? = nil
    ) -> some View {
        let foreground = foreground ?? studioInk
        return VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
            Text(value)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .tracking(-1.4)
                .foregroundStyle(valueColor ?? foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .foregroundStyle(foreground)
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .background(color)
    }

    private func paneEnabledBinding(_ pane: WidgetPane) -> Binding<Bool> {
        Binding {
            enabledPanes.contains(pane)
        } set: { isEnabled in
            withAnimation(.snappy(duration: 0.22)) {
                if isEnabled {
                    enabledPanes.insert(pane)
                } else {
                    enabledPanes.remove(pane)
                }
            }
        }
    }

    private var studioInk: Color {
        Color(red: 0.063, green: 0.067, blue: 0.059)
    }

    private var studioPaper: Color {
        Color(red: 0.937, green: 0.898, blue: 0.804)
    }

    private var studioOrange: Color {
        Color(red: 0.953, green: 0.357, blue: 0.173)
    }

    private var studioLime: Color {
        Color(red: 0.725, green: 0.863, blue: 0.235)
    }

    private var studioSky: Color {
        Color(red: 0.412, green: 0.729, blue: 0.859)
    }

    private var studioMuted: Color {
        Color(red: 0.46, green: 0.45, blue: 0.41)
    }

    private var studioHueRotation: Angle {
        blockworkColorway == .cobalt ? .degrees(198) : .zero
    }

    private var connectionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if !github.hasStoredToken {
                    githubConnectionSection
                } else {
                    connectionManagementSection
                    if let message = github.message {
                        connectionError(message)
                    }
                    if let notice = github.notice {
                        connectionNotice(notice)
                    }
                }
                widgetConfigurationGuide
            }
            .padding(28)
            .frame(maxWidth: 660, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color(red: 0.22, green: 0.80, blue: 0.46))
                .frame(width: 42, height: 42)
                .background(Color.primary.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(github.hasStoredToken && !github.username.isEmpty ? "@\(github.username)" : "GitHub activity")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                if github.hasStoredToken, let lastRefresh = github.lastRefresh {
                    Text("Updated \(lastRefresh, style: .relative)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Connect GitHub and configure the widget")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if github.hasStoredToken {
                if github.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(github.phase == .refreshing ? "Refreshing…" : "Refresh") {
                    Task { await github.refresh(scope: .allBranches) }
                }
                .disabled(github.isBusy)
                .help("Discover activity across every accessible branch")

                Button {
                    showingDisconnectConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Disconnect GitHub")
                .disabled(github.isBusy)
            }
        }
    }

    private var githubConnectionSection: some View {
        GroupBox("GitHub activity") {
            VStack(alignment: .leading, spacing: 12) {
                SecureField("Fine-grained personal access token", text: $github.tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard github.canConnect else { return }
                        Task { await github.connect() }
                    }

                HStack {
                    Link(
                        "Create a fine-grained token",
                        destination: GitHubTokenTemplate.url()
                    )
                    .font(.system(size: 11, weight: .medium))

                    Spacer()

                    if github.isBusy {
                        ProgressView().controlSize(.small)
                    }

                    Button(github.phase == .connecting ? "Connecting…" : "Connect GitHub") {
                        Task { await github.connect() }
                    }
                    .disabled(!github.canConnect)
                }

                Text("Choose your account as the resource owner, select the repositories to include, and leave the prefilled Contents permission at read-only. Organization connections can be added next.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let message = github.message {
                    connectionError(message)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var connectionManagementSection: some View {
        GroupBox("GitHub connections") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(github.connections) { connection in
                    connectionRow(connection)
                    if connection.id != github.connections.last?.id {
                        Divider()
                    }
                }

                Divider()

                tokenDisclosure(title: "Replace account token", isExpanded: $isReplacingAccountToken) {
                    VStack(alignment: .leading, spacing: 8) {

                    HStack {
                        Link(
                            "Create replacement token",
                            destination: GitHubTokenTemplate.url()
                        )
                        .font(.system(size: 10, weight: .medium))

                        Spacer()

                        Text("Include your private repositories and Contents: Read-only.")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    SecureField(
                        "Paste replacement account token",
                        text: $github.replacementAccountTokenInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard github.canReplaceAccountToken else { return }
                        Task { await github.replaceAccountToken() }
                    }

                    HStack(alignment: .top) {
                        Text("widtget checks the token belongs to @\(github.username), refreshes every branch, then replaces the saved Keychain token. Your current token stays active if validation fails.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 12)

                        Button(github.phase == .connecting ? "Replacing…" : "Replace token") {
                            Task { await github.replaceAccountToken() }
                        }
                        .disabled(!github.canReplaceAccountToken)
                    }
                    }
                }

                Divider()

                tokenDisclosure(title: "Add organization", isExpanded: $isAddingOrganization) {
                    VStack(alignment: .leading, spacing: 8) {

                    TextField("GitHub organization name", text: $github.organizationInput)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Link(
                            "1. Create read-only token on GitHub",
                            destination: github.organizationTokenURL
                        )
                        .font(.system(size: 10, weight: .medium))
                        .disabled(!github.canCreateOrganizationToken)

                        Spacer()

                        Text("Select the repositories on GitHub, then generate the token.")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    SecureField(
                        "2. Paste the organization token",
                        text: $github.additionalTokenInput
                    )
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard github.canAddToken else { return }
                        Task { await github.addOrganization() }
                    }

                    HStack(alignment: .top) {
                        Text("widtget verifies the organization and repository access before saving. If approval is required, ask an organization owner to approve the token first.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 12)

                        Button(github.phase == .connecting ? "Adding…" : "Add organization") {
                            Task { await github.addOrganization() }
                        }
                        .disabled(!github.canAddToken)
                    }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func connectionRow(_ connection: GitHubConnectionSummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: connection.kind == .account ? "person.crop.circle.fill" : "building.2.fill")
                .font(.system(size: 17))
                .foregroundStyle(connection.kind == .account ? Color.secondary : Color.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.kind == .account ? "@\(connection.owner)" : connection.owner)
                    .font(.system(size: 12, weight: .semibold))

                if let repositoryCount = connection.repositoryCount,
                   let privateRepositoryCount = connection.privateRepositoryCount {
                    Text("\(repositoryCount) \(repositoryCount == 1 ? "repository" : "repositories") · \(privateRepositoryCount) private")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text(connection.kind == .account ? "GitHub account" : "Connected resource owner")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if connection.kind == .organization {
                Button {
                    organizationPendingRemoval = connection
                    showingRemoveOrganizationConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove \(connection.owner)")
                .disabled(github.isBusy)
            }
        }
    }

    private func connectionError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func connectionNotice(_ message: String) -> some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var widgetConfigurationGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DashboardPalette.green)
                    .frame(width: 34, height: 34)
                    .background(DashboardPalette.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Per-widget controls stay with the widget")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("Right-click a widtget on the desktop and choose Edit Widget.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Each widget chooses its own period, window, repository detail, and commits per snek block. Widget Studio supplies the shared pane order and colorway.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tokenDisclosure<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: isExpanded.wrappedValue ? "minus.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(.tint)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidtgetWidgetKind.value)
    }

    private func migrateToFixedDefaultIfNeeded() {
        let currentVersion = SharedPreferences.defaults.integer(
            forKey: SharedPreferences.Key.themeScopeVersion
        )
        guard currentVersion < 1 else { return }

        visualTheme = .defaultTheme
        SharedPreferences.defaults.set(1, forKey: SharedPreferences.Key.themeScopeVersion)
        saveWidgetStudio()
    }

    private func saveWidgetStudio() {
        SharedPreferences.saveModularPreferences(
            WidgetModularPreferences(
                paneOrder: paneOrder,
                enabledPanes: enabledPanes,
                colorway: blockworkColorway,
                visualTheme: visualTheme,
                familyLayouts: familyLayouts,
                blockColors: blockColors
            )
        )
        reloadWidgets()
    }
}

private struct WidgetSlotOrigin: Equatable {
    let family: WidgetLayoutFamily
    let index: Int
}

private struct WidgetSlotDropDelegate: DropDelegate {
    let destination: WidgetSlotOrigin
    @Binding var layouts: [WidgetLayoutFamily: [WidgetPane]]
    @Binding var draggedPane: WidgetPane?
    @Binding var draggedOrigin: WidgetSlotOrigin?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedPane else { return false }

        var destinationLayout = layouts[destination.family]
            ?? WidgetModularPreferences.defaults.familyLayouts[destination.family]
            ?? []
        guard destinationLayout.indices.contains(destination.index) else { return false }

        let displaced = destinationLayout[destination.index]
        destinationLayout[destination.index] = draggedPane
        layouts[destination.family] = destinationLayout

        if let draggedOrigin,
           draggedOrigin != destination {
            var sourceLayout = layouts[draggedOrigin.family]
                ?? WidgetModularPreferences.defaults.familyLayouts[draggedOrigin.family]
                ?? []
            if sourceLayout.indices.contains(draggedOrigin.index) {
                sourceLayout[draggedOrigin.index] = displaced
                layouts[draggedOrigin.family] = sourceLayout
            }
        }

        self.draggedPane = nil
        self.draggedOrigin = nil
        return true
    }
}

private struct WidgetPaneDropDelegate: DropDelegate {
    let destination: WidgetPane
    @Binding var panes: [WidgetPane]
    @Binding var draggedPane: WidgetPane?

    func dropEntered(info: DropInfo) {
        guard let draggedPane,
              draggedPane != destination,
              let sourceIndex = panes.firstIndex(of: draggedPane),
              let destinationIndex = panes.firstIndex(of: destination)
        else {
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            panes.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedPane = nil
        return true
    }
}

private extension WidgetPane {
    var studioSymbol: String {
        switch self {
        case .additions: "plus"
        case .deletions: "minus"
        case .summary: "number"
        case .activity: "chart.bar.fill"
        case .activityTable: "square.grid.3x3.fill"
        case .insights: "scope"
        case .repositories: "shippingbox.fill"
        case .snake: "circle.grid.3x3.fill"
        }
    }
}

#Preview {
    WidgetSettingsView()
}

import SwiftUI
import WidgetKit

struct WidgetSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var github = GitHubAccountModel()
    @State private var showingDisconnectConfirmation = false
    @State private var showingRemoveOrganizationConfirmation = false
    @State private var organizationPendingRemoval: GitHubConnectionSummary?

    @AppStorage(SharedPreferences.Key.showRepositories, store: SharedPreferences.defaults)
    private var showRepositories = WidgetViewPreferences.defaults.showRepositories

    @AppStorage(SharedPreferences.Key.showActivity, store: SharedPreferences.defaults)
    private var showActivity = WidgetViewPreferences.defaults.showActivity

    @AppStorage(SharedPreferences.Key.showUpdateTime, store: SharedPreferences.defaults)
    private var showUpdateTime = WidgetViewPreferences.defaults.showUpdateTime

    @AppStorage(SharedPreferences.Key.repositoryDetail, store: SharedPreferences.defaults)
    private var repositoryDetail = WidgetViewPreferences.defaults.repositoryDetail

    @AppStorage(SharedPreferences.Key.periodWindowMode, store: SharedPreferences.defaults)
    private var periodWindowMode = PeriodWindowMode.fixed

    @AppStorage(SharedPreferences.Key.snakeMinimumSegments, store: SharedPreferences.defaults)
    private var snakeMinimumSegments = CommitSnakeLimits.defaultMinimum

    @AppStorage(SharedPreferences.Key.snakeMaximumSegments, store: SharedPreferences.defaults)
    private var snakeMaximumSegments = CommitSnakeLimits.defaultMaximum

    var body: some View {
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
                appearanceSection

                HStack {
                    Button("Reset appearance") {
                        showRepositories = WidgetViewPreferences.defaults.showRepositories
                        showActivity = WidgetViewPreferences.defaults.showActivity
                        showUpdateTime = WidgetViewPreferences.defaults.showUpdateTime
                        repositoryDetail = WidgetViewPreferences.defaults.repositoryDetail
                        periodWindowMode = .fixed
                        snakeMinimumSegments = WidgetViewPreferences.defaults.snakeMinimumSegments
                        snakeMaximumSegments = WidgetViewPreferences.defaults.snakeMaximumSegments
                        reloadWidgets()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Label("Widget reloads after refresh", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .onChange(of: showRepositories) { _, _ in reloadWidgets() }
        .onChange(of: showActivity) { _, _ in reloadWidgets() }
        .onChange(of: showUpdateTime) { _, _ in reloadWidgets() }
        .onChange(of: repositoryDetail) { _, _ in reloadWidgets() }
        .onChange(of: snakeMinimumSegments) { _, newValue in
            if newValue > snakeMaximumSegments {
                snakeMaximumSegments = newValue
            }
            reloadWidgets()
        }
        .onChange(of: snakeMaximumSegments) { _, newValue in
            if newValue < snakeMinimumSegments {
                snakeMinimumSegments = newValue
            }
            reloadWidgets()
        }
        .onChange(of: periodWindowMode) { _, _ in
            reloadWidgets()
            guard github.hasStoredToken, !github.isBusy else { return }
            Task { await github.refresh(scope: .recentBranches) }
        }
        .task {
            reloadWidgets()
            await github.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await github.handleActivation() }
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add organization")
                        .font(.system(size: 12, weight: .semibold))

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

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Appearance") {
                VStack(spacing: 0) {
                    preferenceToggle(
                        title: "Repository breakdown",
                        detail: "Show ranked repositories and line-change bars.",
                        isOn: $showRepositories
                    )

                    Divider().padding(.leading, 38)

                    preferenceToggle(
                        title: "Activity visualization",
                        detail: "Show the two-color activity strip or grid.",
                        isOn: $showActivity
                    )

                    Divider().padding(.leading, 38)

                    preferenceToggle(
                        title: "Last update time",
                        detail: "Show fresh, stale, and error status text.",
                        isOn: $showUpdateTime
                    )
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity window")
                        .font(.system(size: 13, weight: .medium))
                    Text(periodWindowMode.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Activity window", selection: $periodWindowMode) {
                    ForEach(PeriodWindowMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            HStack {
                Text("Repository detail")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Picker("Repository detail", selection: $repositoryDetail) {
                    ForEach(RepositoryDetail.allCases) { detail in
                        Text(detail.displayName).tag(detail)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .disabled(!showRepositories)

            GroupBox("Commit snake") {
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Body length")
                                .font(.system(size: 13, weight: .medium))
                            Text("One block per commit, held within these visual limits.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(snakeMinimumSegments)–\(snakeMaximumSegments) blocks")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 22) {
                        Stepper(
                            "Minimum: \(snakeMinimumSegments)",
                            value: $snakeMinimumSegments,
                            in: CommitSnakeLimits.minimumRange
                        )
                        Stepper(
                            "Maximum: \(snakeMaximumSegments)",
                            value: $snakeMaximumSegments,
                            in: CommitSnakeLimits.maximumRange
                        )
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func preferenceToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 10)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidtgetWidgetKind.value)
    }
}

#Preview {
    WidgetSettingsView()
}

import EnvLatchCore
import AppKit
import SwiftUI

struct VaultView: View {
    @StateObject private var model: VaultViewModel
    @State private var editor: KeyEditorState?
    @State private var pendingDeletion: CredentialName?
    @State private var launchProfileEditor: LaunchProfileEditorState?
    @State private var pendingLaunchProfileDeletion: LaunchProfile?
    @State private var copiedCommand: String?
    @State private var setupExpanded = false
    @State private var pairedHosts: [PairedHost] = []
    @State private var pairingError: String?
    @State private var searchText = ""

    private let inspector = InstallationInspector.current()
    private let keyColumns = [
        GridItem(.adaptive(minimum: 290, maximum: 430), spacing: 12),
    ]

    init(model: VaultViewModel? = nil) {
        _model = StateObject(wrappedValue: model ?? VaultViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    keyContent
                    if model.showsKeyGroups {
                        keyGroupSection
                    }
                    launchSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editor) { state in
            KeyEditorSheet(
                existingName: state.existingName,
                existingProfile: state.profile,
                onSave: { name, value, profile in
                    model.save(rawName: name, value: value, profile: profile)
                }
            )
        }
        .sheet(item: $launchProfileEditor) { state in
            LaunchProfileEditorSheet(
                availableCredentials: model.names,
                existingProfile: state.profile,
                onSave: model.saveLaunchProfile
            )
        }
        .alert(
            AppLocalization.text(
                "vault.deleteKey.title",
                "Delete \(pendingDeletion?.rawValue ?? "key")?"
            ),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { name in
            Button(AppLocalization.text("action.delete", "Delete"), role: .destructive) {
                model.delete(name)
                pendingDeletion = nil
            }
            Button(AppLocalization.text("action.cancel", "Cancel"), role: .cancel) {
                pendingDeletion = nil
            }
        } message: { _ in
            Text(
                AppLocalization.text(
                    "vault.deleteKey.message",
                    "This permanently removes the value from your default Keychain."
                )
            )
        }
        .alert(
            AppLocalization.text(
                "vault.deleteGroup.title",
                "Delete key group \(pendingLaunchProfileDeletion?.name ?? "group")?"
            ),
            isPresented: Binding(
                get: { pendingLaunchProfileDeletion != nil },
                set: { if !$0 { pendingLaunchProfileDeletion = nil } }
            ),
            presenting: pendingLaunchProfileDeletion
        ) { profile in
            Button(AppLocalization.text("action.delete", "Delete"), role: .destructive) {
                model.deleteLaunchProfile(profile)
                pendingLaunchProfileDeletion = nil
            }
            Button(AppLocalization.text("action.cancel", "Cancel"), role: .cancel) {
                pendingLaunchProfileDeletion = nil
            }
        } message: { _ in
            Text(
                AppLocalization.text(
                    "vault.deleteGroup.message",
                    "Saved keys remain in Keychain."
                )
            )
        }
        .alert(
            AppLocalization.text(
                "vault.error.title",
                "EnvLatch couldn't complete that action"
            ),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(AppLocalization.text("action.ok", "OK"), role: .cancel) {
                model.errorMessage = nil
            }
            Button(AppLocalization.text("action.retry", "Retry")) { model.refresh() }
        } message: {
            Text(
                model.errorMessage
                    ?? AppLocalization.text("error.unknown", "Unknown error")
            )
        }
        .onAppear(perform: refreshPairingStatus)
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("EnvLatch")
                        .font(.title2.weight(.semibold))
                    Text(
                        AppLocalization.text(
                            "vault.header.tagline",
                            "One Keychain for every local agent"
                        )
                    )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    editor = KeyEditorState(existingName: nil, profile: nil)
                } label: {
                    Label(
                        AppLocalization.text("vault.action.addKey", "Add Key"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .controlAccentColor))
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityHint(
                    AppLocalization.text(
                        "vault.action.addKey.hint",
                        "Opens a secure form for a new credential"
                    )
                )
            }

            HStack(spacing: 8) {
                StatusChip(
                    text: AppLocalization.keyCount(model.names.count),
                    systemImage: "key.fill"
                )
                StatusChip(
                    text: AppLocalization.groupCount(model.launchProfiles.count),
                    systemImage: "square.stack.3d.up.fill"
                )
                StatusChip(
                    text: pairingStatus == .paired
                        ? AppLocalization.text(
                            "vault.agentSetup.readyChip",
                            "Agent setup ready"
                        )
                        : AppLocalization.text(
                            "vault.agentSetup.repairChip",
                            "Setup needs repair"
                        ),
                    systemImage: pairingStatus == .paired
                        ? "checkmark.shield.fill"
                        : "exclamationmark.shield.fill",
                    color: pairingStatus == .paired ? .green : .orange
                )

                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(
                        AppLocalization.text("vault.search.placeholder", "Search keys"),
                        text: $searchText
                    )
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(width: 220, height: 28)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                }
                .accessibilityElement(children: .contain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var keyContent: some View {
        if model.isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text(
                    AppLocalization.text(
                        "vault.loading",
                        "Reading Keychain…"
                    )
                )
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 280)
        } else if model.names.isEmpty {
            VStack(spacing: 12) {
                ProviderMark(
                    presentation: ProviderPresentation(
                        name: AppLocalization.text("vault.keychain", "Keychain"),
                        iconAssetName: nil,
                        usesOriginalIconColor: false,
                        fallbackSymbolName: "lock.shield.fill",
                        color: .accentColor
                    ),
                    size: 52
                )
                Text(
                    AppLocalization.text(
                        "vault.empty.title",
                        "Your Keychain is ready"
                    )
                )
                    .font(.title3.weight(.semibold))
                Text(
                    AppLocalization.text(
                        "vault.empty.detail",
                        "Add a provider key once, then launch any agent or backend with the normal environment variable it already expects."
                    )
                )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 440)
                Button(
                    AppLocalization.text(
                        "vault.empty.action",
                        "Add your first key"
                    )
                ) {
                    editor = KeyEditorState(existingName: nil, profile: nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(32)
            .frame(maxWidth: .infinity, minHeight: 300)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: AppLocalization.text("vault.keys.title", "Keys"),
                    detail: searchText.isEmpty
                        ? AppLocalization.text(
                            "vault.keys.hiddenDetail",
                            "Values stay hidden in macOS Keychain"
                        )
                        : AppLocalization.matchingCount(filteredNames.count)
                )

                if filteredNames.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(
                            AppLocalization.text(
                                "vault.search.emptyTitle",
                                "No matching keys"
                            )
                        )
                            .font(.headline)
                        Text(
                            AppLocalization.text(
                                "vault.search.emptyDetail",
                                "Try a provider, environment name, contract, or endpoint."
                            )
                        )
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    LazyVGrid(columns: keyColumns, alignment: .leading, spacing: 12) {
                        ForEach(filteredNames, id: \.rawValue) { name in
                            KeyCard(
                                name: name,
                                profile: model.profile(for: name),
                                onEdit: {
                                    editor = KeyEditorState(
                                        existingName: name,
                                        profile: model.profile(for: name)
                                    )
                                },
                                onDelete: { pendingDeletion = name }
                            )
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                AppLocalization.text(
                    "vault.keys.accessibilityLabel",
                    "Saved API keys"
                )
            )
        }
    }

    private var keyGroupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(
                    title: AppLocalization.text(
                        "vault.groups.title",
                        "Key groups"
                    ),
                    detail: AppLocalization.text(
                        "vault.groups.detail",
                        "Reusable combinations for commands that need several keys"
                    )
                )
                Spacer()
                Button {
                    launchProfileEditor = LaunchProfileEditorState(profile: nil)
                } label: {
                    Label(
                        AppLocalization.text(
                            "vault.groups.new",
                            "New Group"
                        ),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityHint(
                    AppLocalization.text(
                        "vault.groups.new.hint",
                        "Creates an optional named set of saved keys"
                    )
                )
            }

            if model.launchProfiles.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(
                        AppLocalization.text(
                            "vault.groups.empty",
                            "Create a group when the same backend or agent repeatedly needs several keys."
                        )
                    )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVGrid(columns: keyColumns, alignment: .leading, spacing: 12) {
                    ForEach(model.launchProfiles) { profile in
                        LaunchProfileCard(
                            profile: profile,
                            onEdit: {
                                launchProfileEditor = LaunchProfileEditorState(profile: profile)
                            },
                            onDelete: { pendingLaunchProfileDeletion = profile }
                        )
                    }
                }
            }
        }
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            AgentSetupDisclosure(
                isExpanded: $setupExpanded,
                sharedStatus: pairingStatus,
                pairedHosts: pairedHosts,
                setupPrompt: inspector.setupPrompt,
                copiedContent: $copiedCommand,
                errorMessage: pairingError,
                onRefresh: refreshPairingStatus
            )

            Label(
                AppLocalization.text(
                    "vault.launch.guidance",
                    "Use one key directly, repeat `--using` for a one-off multi-key command, or save a reusable key group."
                ),
                systemImage: "exclamationmark.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if let status = model.statusMessage {
                Label(status, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(status)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var filteredNames: [CredentialName] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.names }
        return model.names.filter { name in
            let profile = model.profile(for: name)
            return [
                name.rawValue,
                profile?.providerName ?? "",
                profile?.contract.displayName ?? "",
                profile?.baseURL ?? "",
            ].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var pairingStatus: AgentPairingStatus {
#if DEBUG
        if ProcessInfo.processInfo.environment["ENVLATCH_PREVIEW_DATA"] == "1" {
            return .paired
        }
#endif
        return inspector.pairingStatus()
    }

    private func refreshPairingStatus() {
        do {
            pairedHosts = try PairedHostStore.current().list()
            pairingError = nil
        } catch {
            pairingError = AppLocalization.message(for: error)
        }
    }
}

private struct StatusChip: View {
    let text: String
    let systemImage: String
    var color: Color = .secondary

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.09), in: Capsule())
    }
}

private struct SectionHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct KeyCard: View {
    let name: CredentialName
    let profile: EndpointProfile?
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        let presentation = ProviderPresentation.resolve(credential: name, endpoint: profile)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ProviderMark(presentation: presentation)

                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.name)
                        .font(.callout.weight(.semibold))
                    Text(name.rawValue)
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                Menu {
                    Button(
                        AppLocalization.text("action.edit", "Edit"),
                        systemImage: "pencil",
                        action: onEdit
                    )
                    Divider()
                    Button(
                        AppLocalization.text("action.delete", "Delete"),
                        systemImage: "trash",
                        role: .destructive,
                        action: onDelete
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .accessibilityLabel(
                    AppLocalization.text(
                        "vault.key.actions",
                        "Actions for \(name.rawValue)"
                    )
                )
            }

            if let profile {
                HStack(spacing: 6) {
                    Text(profile.contract.displayName)
                    Text("·")
                    Text(endpointHost(profile.baseURL))
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(
                    AppLocalization.text(
                        "vault.key.directEnvironment",
                        "Direct environment variable"
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text(
                    AppLocalization.text(
                        "vault.key.valueHidden",
                        "Value hidden in Keychain"
                    )
                )
                Spacer()
                Button(AppLocalization.text("action.edit", "Edit"), action: onEdit)
                    .buttonStyle(.link)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovering
                        ? presentation.color.opacity(0.55)
                        : Color(nsColor: .separatorColor),
                    lineWidth: isHovering ? 1 : 0.5
                )
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .accessibilityElement(children: .contain)
    }

    private func endpointHost(_ value: String) -> String {
        URL(string: value)?.host ?? value
    }
}

private struct LaunchProfileCard: View {
    let profile: LaunchProfile
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.callout.weight(.semibold))
                    Text(AppLocalization.keyCount(profile.credentialNames.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button(
                        AppLocalization.text("action.edit", "Edit"),
                        systemImage: "pencil",
                        action: onEdit
                    )
                    Divider()
                    Button(
                        AppLocalization.text("action.delete", "Delete"),
                        systemImage: "trash",
                        role: .destructive,
                        action: onDelete
                    )
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .accessibilityLabel(
                    AppLocalization.text(
                        "vault.group.actions",
                        "Actions for key group \(profile.name)"
                    )
                )
            }

            Text(profile.credentialNames.map(\.rawValue).joined(separator: "  ·  "))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button(
                AppLocalization.text("vault.group.edit", "Edit group"),
                action: onEdit
            )
                .buttonStyle(.link)
                .font(.caption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
    }
}

private struct AgentSetupDisclosure: View {
    @Binding var isExpanded: Bool
    let sharedStatus: AgentPairingStatus
    let pairedHosts: [PairedHost]
    let setupPrompt: String
    @Binding var copiedContent: String?
    let errorMessage: String?
    let onRefresh: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if pairedHosts.isEmpty {
                    Label(
                        AppLocalization.text(
                            "vault.agentSetup.empty",
                            "No named agents or hosts have paired yet."
                        ),
                        systemImage: "person.crop.circle.badge.questionmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(pairedHosts) { host in
                                PairedHostRow(host: host, sharedStatus: sharedStatus)
                                if host.id != pairedHosts.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 112)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(
                            AppLocalization.text(
                                "vault.agentSetup.promptTitle",
                                "Setup prompt"
                            )
                        )
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button(action: copyPrompt) {
                            Label(
                                copiedContent == setupPrompt
                                    ? AppLocalization.text(
                                        "vault.agentSetup.copied",
                                        "Copied"
                                    )
                                    : AppLocalization.text(
                                        "vault.agentSetup.copyPrompt",
                                        "Copy setup prompt"
                                    ),
                                systemImage: copiedContent == setupPrompt ? "checkmark" : "doc.on.doc"
                            )
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .accessibilityHint(
                            AppLocalization.text(
                                "vault.agentSetup.copyPrompt.hint",
                                "Copies pairing, doctor, help, and launch instructions with no secret values"
                            )
                        )
                    }

                    ScrollView {
                        Text(setupPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                    }
                    .frame(maxHeight: 126)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    }
                }

                Button(action: onRefresh) {
                    Label(
                        AppLocalization.text(
                            "vault.agentSetup.refresh",
                            "Refresh paired hosts"
                        ),
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 10) {
                Label(
                    AppLocalization.text(
                        "vault.agentSetup.title",
                        "Agent setup"
                    ),
                    systemImage: "person.2.badge.gearshape"
                )
                    .font(.headline)
                Spacer()
                Label(summary, systemImage: sharedStatus == .paired ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(sharedStatus == .paired ? Color.secondary : Color.orange)
            }
        }
        .accessibilityHint(
            AppLocalization.text(
                "vault.agentSetup.expand.hint",
                "Expands named paired-host status and the reusable setup prompt"
            )
        )
    }

    private var summary: String {
        guard sharedStatus == .paired else {
            return AppLocalization.text(
                "vault.agentSetup.needsRepair",
                "Shared setup needs repair"
            )
        }
        return AppLocalization.pairedHostCount(pairedHosts.count)
    }

    private func copyPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(setupPrompt, forType: .string)
        copiedContent = setupPrompt
    }
}

private struct PairedHostRow: View {
    let host: PairedHost
    let sharedStatus: AgentPairingStatus

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: sharedStatus == .paired ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(sharedStatus == .paired ? Color.green : Color.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(host.name)
                    .font(.callout.weight(.medium))
                Text(
                    sharedStatus == .paired
                        ? AppLocalization.text(
                            "vault.agentSetup.hostReady",
                            "Ready"
                        )
                        : AppLocalization.text(
                            "vault.agentSetup.hostNeedsRepair",
                            "Paired name saved · shared setup needs repair"
                        )
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(host.pairedAt, format: .dateTime.year().month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}

private struct KeyEditorState: Identifiable {
    let id = UUID()
    let existingName: CredentialName?
    let profile: EndpointProfile?
}

private struct LaunchProfileEditorState: Identifiable {
    let id = UUID()
    let profile: LaunchProfile?
}

private struct LaunchProfileEditorSheet: View {
    let availableCredentials: [CredentialName]
    let existingProfile: LaunchProfile?
    let onSave: (LaunchProfile) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedCredentials: Set<CredentialName>
    @State private var attemptedSave = false
    @FocusState private var nameFocused: Bool

    init(
        availableCredentials: [CredentialName],
        existingProfile: LaunchProfile?,
        onSave: @escaping (LaunchProfile) -> Bool
    ) {
        self.availableCredentials = availableCredentials
        self.existingProfile = existingProfile
        self.onSave = onSave
        _name = State(initialValue: existingProfile?.name ?? "")
        _selectedCredentials = State(initialValue: Set(existingProfile?.credentialNames ?? []))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(
                    existingProfile == nil
                        ? AppLocalization.text(
                            "groupEditor.title.new",
                            "New key group"
                        )
                        : AppLocalization.text(
                            "groupEditor.title.edit",
                            "Edit key group"
                        )
                )
                    .font(.title3.weight(.semibold))
                Text(
                    AppLocalization.text(
                        "groupEditor.detail",
                        "Select exactly the keys this command or backend needs. Values stay hidden in Keychain."
                    )
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(AppLocalization.text("groupEditor.name", "Group name"))
                    .font(.callout.weight(.medium))
                TextField(
                    AppLocalization.text("groupEditor.name.placeholder", "Backend"),
                    text: $name
                )
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .disabled(existingProfile != nil)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(
                    AppLocalization.text(
                        "groupEditor.availableKeys",
                        "Available keys"
                    )
                )
                    .font(.callout.weight(.medium))
                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(availableCredentials, id: \.rawValue) { credential in
                            Toggle(
                                credential.rawValue,
                                isOn: Binding(
                                    get: { selectedCredentials.contains(credential) },
                                    set: { selected in
                                        if selected {
                                            selectedCredentials.insert(credential)
                                        } else {
                                            selectedCredentials.remove(credential)
                                        }
                                    }
                                )
                            )
                            .font(.system(.body, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 220)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
            }

            if attemptedSave, let validationError {
                Text(validationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(AppLocalization.text("action.cancel", "Cancel"), role: .cancel) {
                    dismiss()
                }
                    .keyboardShortcut(.cancelAction)
                Button(
                    AppLocalization.text(
                        "groupEditor.save",
                        "Save Group"
                    )
                ) {
                    attemptedSave = true
                    guard let profile = try? makeProfile(), validationError == nil else { return }
                    if onSave(profile) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .controlAccentColor))
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 472)
        .padding(24)
        .onAppear { nameFocused = existingProfile == nil }
    }

    private var validationError: String? {
        do {
            _ = try makeProfile()
            return nil
        } catch {
            return AppLocalization.message(for: error)
        }
    }

    private func makeProfile() throws -> LaunchProfile {
        let ordered = availableCredentials.filter(selectedCredentials.contains)
        return try LaunchProfile(name: name, credentialNames: ordered)
    }
}

private struct KeyEditorSheet: View {
    let existingName: CredentialName?
    let existingProfile: EndpointProfile?
    let onSave: (String, String, EndpointProfile?) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var rawName: String
    @State private var value = ""
    @State private var attemptedSave = false
    @State private var configureEndpoint: Bool
    @State private var providerName: String
    @State private var contract: APIContract
    @State private var baseURL: String
    @State private var credentialEnvironmentName: String
    @State private var selectedPresetID: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case value
    }

    init(
        existingName: CredentialName?,
        existingProfile: EndpointProfile?,
        onSave: @escaping (String, String, EndpointProfile?) -> Bool
    ) {
        self.existingName = existingName
        self.existingProfile = existingProfile
        self.onSave = onSave
        _rawName = State(initialValue: existingName?.rawValue ?? "")
        _configureEndpoint = State(initialValue: existingProfile != nil)
        _providerName = State(initialValue: existingProfile?.providerName ?? "")
        _contract = State(initialValue: existingProfile?.contract ?? .anthropic)
        _baseURL = State(initialValue: existingProfile?.baseURL ?? "")
        _credentialEnvironmentName = State(
            initialValue: existingProfile?.credentialEnvironmentName.rawValue
                ?? APIContract.anthropic.defaultCredentialEnvironmentName
        )
        _selectedPresetID = State(
            initialValue: existingName.flatMap {
                ProviderPreset.matching(credential: $0, endpoint: existingProfile)?.id
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(
                    existingName == nil
                        ? AppLocalization.text(
                            "keyEditor.title.add",
                            "Add API key"
                        )
                        : AppLocalization.text(
                            "keyEditor.title.edit",
                            "Edit API key"
                        )
                )
                    .font(.title3.weight(.semibold))
                Text(
                    AppLocalization.text(
                        "keyEditor.detail",
                        "The secret stays in your default Keychain. Endpoint settings never contain its value."
                    )
                )
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if existingName == nil {
                VStack(alignment: .leading, spacing: 9) {
                    Text(
                        AppLocalization.text(
                            "keyEditor.provider.title",
                            "Start with a provider"
                        )
                    )
                        .font(.callout.weight(.medium))
                    Text(
                        AppLocalization.text(
                            "keyEditor.provider.detail",
                            "Pick a preset to fill the environment name, API contract, and base URL. Everything remains editable."
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        ForEach(ProviderPreset.catalog) { preset in
                            ProviderPresetButton(
                                preset: preset,
                                isSelected: selectedPresetID == preset.id,
                                action: { apply(preset) }
                            )
                        }

                        Button {
                            selectedPresetID = nil
                            configureEndpoint = false
                        } label: {
                            HStack(spacing: 8) {
                                ProviderMark(
                                    presentation: ProviderPresentation(
                                        name: AppLocalization.text(
                                            "keyEditor.provider.custom",
                                            "Custom"
                                        ),
                                        iconAssetName: nil,
                                        usesOriginalIconColor: false,
                                        fallbackSymbolName: "slider.horizontal.3",
                                        color: .secondary
                                    ),
                                    size: 30
                                )
                                Text(
                                    AppLocalization.text(
                                        "keyEditor.provider.custom",
                                        "Custom"
                                    )
                                )
                                    .font(.callout.weight(.medium))
                                Spacer(minLength: 0)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedPresetID == nil
                                    ? Color.accentColor.opacity(0.09)
                                    : Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(
                                        selectedPresetID == nil
                                            ? Color.accentColor.opacity(0.7)
                                            : Color(nsColor: .separatorColor),
                                        lineWidth: selectedPresetID == nil ? 1 : 0.5
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(
                    AppLocalization.text(
                        "keyEditor.environmentName",
                        "Environment name"
                    )
                )
                    .font(.callout.weight(.medium))
                TextField("OPENAI_API_KEY", text: $rawName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($focusedField, equals: .name)
                    .disabled(existingName != nil)
                    .onChange(of: rawName) { newValue in
                        if existingName == nil {
                            rawName = newValue.uppercased()
                        }
                    }
                    .accessibilityHint(
                        AppLocalization.text(
                            "keyEditor.environmentName.hint",
                            "Uppercase credential name such as OPENAI_API_KEY"
                        )
                    )
                Text(nameGuidance)
                    .font(.caption)
                    .foregroundStyle(nameError == nil ? Color.secondary : Color.red)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(
                    existingName == nil
                        ? AppLocalization.text(
                            "keyEditor.value",
                            "Value"
                        )
                        : AppLocalization.text(
                            "keyEditor.value.optional",
                            "New value (optional)"
                        )
                )
                    .font(.callout.weight(.medium))
                SecureField(
                    AppLocalization.text(
                        "keyEditor.value.placeholder",
                        "Paste the key"
                    ),
                    text: $value
                )
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .value)
                    .accessibilityHint(
                        AppLocalization.text(
                            "keyEditor.value.hint",
                            "Secret value; characters are hidden"
                        )
                    )
                Text(
                    existingName == nil
                        ? AppLocalization.text(
                            "keyEditor.value.newDetail",
                            "Saved directly to Keychain."
                        )
                        : AppLocalization.text(
                            "keyEditor.value.editDetail",
                            "Leave blank to keep the current Keychain value."
                        )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if attemptedSave, let valueError {
                    Text(valueError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Toggle(
                    AppLocalization.text(
                        "keyEditor.endpoint.toggle",
                        "Configure endpoint profile"
                    ),
                    isOn: $configureEndpoint
                )
                    .font(.callout.weight(.medium))
                    .onChange(of: configureEndpoint) { isEnabled in
                        if !isEnabled {
                            selectedPresetID = nil
                        }
                    }

                if configureEndpoint {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                AppLocalization.text(
                                    "keyEditor.endpoint.provider",
                                    "Provider / profile"
                                )
                            )
                                .font(.caption.weight(.medium))
                            TextField("MiniMax China", text: $providerName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                AppLocalization.text(
                                    "keyEditor.endpoint.contract",
                                    "API contract"
                                )
                            )
                                .font(.caption.weight(.medium))
                            Picker(
                                AppLocalization.text(
                                    "keyEditor.endpoint.contract",
                                    "API contract"
                                ),
                                selection: $contract
                            ) {
                                ForEach(APIContract.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .onChange(of: contract) { newContract in
                                let knownDefaults = Set(
                                    APIContract.allCases.map(\.defaultCredentialEnvironmentName)
                                )
                                if credentialEnvironmentName.isEmpty
                                    || knownDefaults.contains(credentialEnvironmentName) {
                                    credentialEnvironmentName = newContract.defaultCredentialEnvironmentName
                                }
                            }
                        }
                        .frame(width: 190)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(
                            AppLocalization.text(
                                "keyEditor.endpoint.baseURL",
                                "API base URL"
                            )
                        )
                            .font(.caption.weight(.medium))
                        TextField("https://api.example.com", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(
                            AppLocalization.text(
                                "keyEditor.endpoint.exposeAs",
                                "Expose this key as"
                            )
                        )
                            .font(.caption.weight(.medium))
                        TextField(contract.defaultCredentialEnvironmentName, text: $credentialEnvironmentName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: credentialEnvironmentName) { newValue in
                                credentialEnvironmentName = newValue.uppercased()
                            }
                        Text(
                            AppLocalization.text(
                                "keyEditor.endpoint.bindingDetail",
                                "Agents use the same `run --using` command; this binding adapts the key to the target client."
                            )
                        )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if attemptedSave, let profileError {
                        Text(profileError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                Spacer()
                Button(AppLocalization.text("action.cancel", "Cancel"), role: .cancel) {
                    dismiss()
                }
                    .keyboardShortcut(.cancelAction)
                Button(
                    existingName == nil
                        ? AppLocalization.text(
                            "keyEditor.save.new",
                            "Save Key"
                        )
                        : AppLocalization.text(
                            "keyEditor.save.edit",
                            "Save Changes"
                        )
                ) {
                    attemptedSave = true
                    guard nameError == nil, valueError == nil, profileError == nil else { return }
                    let profile = configureEndpoint ? try? makeProfile() : nil
                    if onSave(rawName, value, profile) {
                        value = ""
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .controlAccentColor))
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 572)
        .padding(24)
        .onAppear {
            focusedField = existingName == nil ? .name : .value
        }
    }

    private var nameError: String? {
        if rawName.isEmpty {
            return attemptedSave
                ? AppLocalization.text(
                    "keyEditor.error.emptyName",
                    "Enter an environment name."
                )
                : nil
        }
        do {
            _ = try CredentialName(validating: rawName)
            return nil
        } catch {
            return AppLocalization.message(for: error)
        }
    }

    private var valueError: String? {
        if existingName != nil, value.isEmpty {
            return nil
        }
        do {
            try CredentialName.validateValue(value)
            return nil
        } catch {
            return AppLocalization.message(for: error)
        }
    }

    private var nameGuidance: String {
        nameError
            ?? AppLocalization.text(
                "keyEditor.nameGuidance",
                "Credential names end in API_KEY, TOKEN, SECRET, PASSWORD, ACCESS_KEY, PRIVATE_KEY, or CREDENTIAL."
            )
    }

    private var profileError: String? {
        guard configureEndpoint else { return nil }
        do {
            _ = try makeProfile()
            return nil
        } catch {
            return AppLocalization.message(for: error)
        }
    }

    private func makeProfile() throws -> EndpointProfile {
        try EndpointProfile(
            providerName: providerName,
            credentialName: CredentialName(validating: rawName),
            contract: contract,
            baseURL: baseURL,
            credentialEnvironmentName: CredentialName(validating: credentialEnvironmentName)
        )
    }

    private func apply(_ preset: ProviderPreset) {
        selectedPresetID = preset.id
        rawName = preset.suggestedCredentialName
        configureEndpoint = true
        providerName = preset.displayName
        contract = preset.contract
        baseURL = preset.baseURL
        credentialEnvironmentName = preset.exposedCredentialName
        focusedField = .value
    }
}

private struct ProviderPresetButton: View {
    let preset: ProviderPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let presentation = ProviderPresentation.presentation(for: preset)

        Button(action: action) {
            HStack(spacing: 8) {
                ProviderMark(presentation: presentation, size: 30)
                Text(preset.displayName)
                    .font(.callout.weight(.medium))
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? presentation.color.opacity(0.09)
                    : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(
                        isSelected
                            ? presentation.color.opacity(0.7)
                            : Color(nsColor: .separatorColor),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            AppLocalization.text(
                "keyEditor.providerPreset.accessibilityLabel",
                "\(preset.displayName) provider preset"
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

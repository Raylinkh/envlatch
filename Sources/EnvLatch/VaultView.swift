import EnvLatchCore
import AppKit
import SwiftUI

struct VaultView: View {
    @StateObject private var model = VaultViewModel()
    @State private var editor: KeyEditorState?
    @State private var pendingDeletion: CredentialName?
    @State private var launchProfileEditor: LaunchProfileEditorState?
    @State private var pendingLaunchProfileDeletion: LaunchProfile?
    @State private var keyGroupsExpanded = false
    @State private var copiedCommand: String?
    @State private var setupExpanded = true
    @State private var pairedHosts: [PairedHost] = []
    @State private var pairingError: String?

    private let inspector = InstallationInspector.current()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            keyContent
            Divider()
            launchSection
        }
        .frame(minWidth: 680, minHeight: 640)
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
            "Delete \(pendingDeletion?.rawValue ?? "key")?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { name in
            Button("Delete", role: .destructive) {
                model.delete(name)
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: { _ in
            Text("This permanently removes the value from your default Keychain.")
        }
        .alert(
            "Delete key group \(pendingLaunchProfileDeletion?.name ?? "group")?",
            isPresented: Binding(
                get: { pendingLaunchProfileDeletion != nil },
                set: { if !$0 { pendingLaunchProfileDeletion = nil } }
            ),
            presenting: pendingLaunchProfileDeletion
        ) { profile in
            Button("Delete", role: .destructive) {
                model.deleteLaunchProfile(profile)
                pendingLaunchProfileDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingLaunchProfileDeletion = nil
            }
        } message: { _ in
            Text("Saved keys remain in Keychain.")
        }
        .alert(
            "EnvLatch couldn't complete that action",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
            Button("Retry") { model.refresh() }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
        .onAppear(perform: refreshPairingStatus)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("EnvLatch")
                    .font(.title2.weight(.semibold))
                Text("API keys in macOS Keychain, released only when you launch a command.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                editor = KeyEditorState(existingName: nil, profile: nil)
            } label: {
                Label("Add Key", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityHint("Opens a secure form for a new credential")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    @ViewBuilder
    private var keyContent: some View {
        if model.isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Reading Keychain…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.names.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("No agent keys saved")
                    .font(.headline)
                Text("Add an API key once. EnvLatch keeps the value out of project files and terminal history.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 440)
                Button("Add your first key") {
                    editor = KeyEditorState(existingName: nil, profile: nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section("Saved keys") {
                    ForEach(model.names, id: \.rawValue) { name in
                        KeyRow(
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

                if model.showsKeyGroups {
                    Section {
                        DisclosureGroup(isExpanded: $keyGroupsExpanded) {
                            Text("Combine keys only when one command needs more than one.")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            ForEach(model.launchProfiles) { profile in
                                LaunchProfileRow(
                                    profile: profile,
                                    onEdit: {
                                        launchProfileEditor = LaunchProfileEditorState(profile: profile)
                                    },
                                    onDelete: { pendingLaunchProfileDeletion = profile }
                                )
                            }

                            Button {
                                launchProfileEditor = LaunchProfileEditorState(profile: nil)
                            } label: {
                                Label("New Key Group", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Creates an optional named set of saved keys")
                        } label: {
                            HStack {
                                Text("Key groups")
                                Text("Optional")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if !model.launchProfiles.isEmpty {
                                    Text("\(model.launchProfiles.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .accessibilityLabel("Saved API keys")
        }
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            AgentSetupDisclosure(
                isExpanded: $setupExpanded,
                sharedStatus: inspector.pairingStatus(),
                pairedHosts: pairedHosts,
                setupPrompt: inspector.setupPrompt,
                copiedContent: $copiedCommand,
                errorMessage: pairingError,
                onRefresh: refreshPairingStatus
            )

            Label(
                "Use any saved key directly with `--using KEY_NAME`. Key groups are only for commands that need several keys.",
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
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
    }

    private func refreshPairingStatus() {
        do {
            pairedHosts = try PairedHostStore.current().list()
            pairingError = nil
        } catch {
            pairingError = error.localizedDescription
        }
    }
}

private struct KeyRow: View {
    let name: CredentialName
    let profile: EndpointProfile?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.rawValue)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                if let profile {
                    Text("\(profile.providerName) · \(profile.contract.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.baseURL)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else {
                    Text("Value hidden · No endpoint profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Edit", action: onEdit)
                .buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(name.rawValue)")
        }
        .padding(.vertical, 6)
    }
}

private struct LaunchProfileRow: View {
    let profile: LaunchProfile
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "switch.2")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.body.weight(.medium))
                Text(profile.credentialNames.map(\.rawValue).joined(separator: ", "))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Edit", action: onEdit)
                .buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete key group \(profile.name)")
        }
        .padding(.vertical, 6)
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
                        "No named agents or hosts have paired yet.",
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
                        Text("Setup prompt")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button(action: copyPrompt) {
                            Label(
                                copiedContent == setupPrompt ? "Copied" : "Copy setup prompt",
                                systemImage: copiedContent == setupPrompt ? "checkmark" : "doc.on.doc"
                            )
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .accessibilityHint("Copies pairing, doctor, help, and launch instructions with no secret values")
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
                    Label("Refresh paired hosts", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 10) {
                Label("Agent setup", systemImage: "person.2.badge.gearshape")
                    .font(.headline)
                Spacer()
                Label(summary, systemImage: sharedStatus == .paired ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(sharedStatus == .paired ? Color.secondary : Color.orange)
            }
        }
        .accessibilityHint("Expands named paired-host status and the reusable setup prompt")
    }

    private var summary: String {
        guard sharedStatus == .paired else { return "Shared setup needs repair" }
        return "\(pairedHosts.count) named \(pairedHosts.count == 1 ? "host" : "hosts") paired"
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
                Text(sharedStatus == .paired ? "Ready" : "Paired name saved · shared setup needs repair")
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
                Text(existingProfile == nil ? "New key group" : "Edit key group")
                    .font(.title3.weight(.semibold))
                Text("Select exactly the keys this command or backend needs. Values stay hidden in Keychain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Group name")
                    .font(.callout.weight(.medium))
                TextField("Backend", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .disabled(existingProfile != nil)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Available keys")
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
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Group") {
                    attemptedSave = true
                    guard let profile = try? makeProfile(), validationError == nil else { return }
                    if onSave(profile) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear { nameFocused = existingProfile == nil }
    }

    private var validationError: String? {
        do {
            _ = try makeProfile()
            return nil
        } catch {
            return error.localizedDescription
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(existingName == nil ? "Add API key" : "Edit API key")
                    .font(.title3.weight(.semibold))
                Text("The secret stays in your default Keychain. Endpoint settings never contain its value.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Environment name")
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
                    .accessibilityHint("Uppercase credential name such as OPENAI_API_KEY")
                Text(nameGuidance)
                    .font(.caption)
                    .foregroundStyle(nameError == nil ? Color.secondary : Color.red)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(existingName == nil ? "Value" : "New value (optional)")
                    .font(.callout.weight(.medium))
                SecureField("Paste the key", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .value)
                    .accessibilityHint("Secret value; characters are hidden")
                Text(existingName == nil ? "Saved directly to Keychain." : "Leave blank to keep the current Keychain value.")
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
                Toggle("Configure endpoint profile", isOn: $configureEndpoint)
                    .font(.callout.weight(.medium))

                if configureEndpoint {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Provider / profile")
                                .font(.caption.weight(.medium))
                            TextField("MiniMax China", text: $providerName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("API contract")
                                .font(.caption.weight(.medium))
                            Picker("API contract", selection: $contract) {
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
                        Text("API base URL")
                            .font(.caption.weight(.medium))
                        TextField("https://api.example.com", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Expose this key as")
                            .font(.caption.weight(.medium))
                        TextField(contract.defaultCredentialEnvironmentName, text: $credentialEnvironmentName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: credentialEnvironmentName) { newValue in
                                credentialEnvironmentName = newValue.uppercased()
                            }
                        Text("Agents use the same `run --using` command; this binding adapts the key to the target client.")
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
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existingName == nil ? "Save Key" : "Save Changes") {
                    attemptedSave = true
                    guard nameError == nil, valueError == nil, profileError == nil else { return }
                    let profile = configureEndpoint ? try? makeProfile() : nil
                    if onSave(rawName, value, profile) {
                        value = ""
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540)
        .onAppear {
            focusedField = existingName == nil ? .name : .value
        }
    }

    private var nameError: String? {
        if rawName.isEmpty {
            return attemptedSave ? "Enter an environment name." : nil
        }
        do {
            _ = try CredentialName(validating: rawName)
            return nil
        } catch {
            return error.localizedDescription
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
            return error.localizedDescription
        }
    }

    private var nameGuidance: String {
        nameError ?? "Credential names end in API_KEY, TOKEN, SECRET, PASSWORD, ACCESS_KEY, PRIVATE_KEY, or CREDENTIAL."
    }

    private var profileError: String? {
        guard configureEndpoint else { return nil }
        do {
            _ = try makeProfile()
            return nil
        } catch {
            return error.localizedDescription
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
}

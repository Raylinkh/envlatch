import AgentKeyringCore
import AppKit
import SwiftUI

struct VaultView: View {
    @StateObject private var model = VaultViewModel()
    @State private var editor: KeyEditorState?
    @State private var pendingDeletion: CredentialName?
    @State private var copiedCommand: String?

    private let inspector = InstallationInspector.current()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            keyContent
            Divider()
            launchSection
        }
        .frame(minWidth: 620, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editor) { state in
            KeyEditorSheet(
                existingName: state.existingName,
                onSave: { name, value in model.save(rawName: name, value: value) }
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
            Text("This permanently removes the value from your login Keychain.")
        }
        .alert(
            "AgentKeyring couldn't complete that action",
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
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("AgentKeyring")
                    .font(.title2.weight(.semibold))
                Text("API keys in macOS Keychain, released only when you launch a command.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                editor = KeyEditorState(existingName: nil)
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
                Text("Add an API key once. AgentKeyring keeps the value out of project files and terminal history.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 440)
                Button("Add your first key") {
                    editor = KeyEditorState(existingName: nil)
                }
                .buttonStyle(.bordered)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(model.names, id: \.rawValue) { name in
                KeyRow(
                    name: name,
                    onReplace: { editor = KeyEditorState(existingName: name) },
                    onDelete: { pendingDeletion = name }
                )
            }
            .listStyle(.inset)
            .accessibilityLabel("Saved API keys")
        }
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Use from any agent")
                        .font(.headline)
                    Text("Pair once, then use the same command for Codex, Claude, Gemini, or any local tool.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PairingStatusView(
                    status: inspector.pairingStatus(),
                    pairCommand: inspector.pairCommand
                )
            }

            UniversalCommandButton(
                command: "agent-keyring run -- <command> [args…]",
                copiedCommand: $copiedCommand
            )

            Label(
                "Every saved key is available to the launched process and its children.",
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
}

private struct KeyRow: View {
    let name: CredentialName
    let onReplace: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.rawValue)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                Text("Value hidden · macOS Keychain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Replace", action: onReplace)
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

private struct UniversalCommandButton: View {
    let command: String
    @Binding var copiedCommand: String?

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            copiedCommand = command
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(command)
                        .font(.system(.callout, design: .monospaced, weight: .medium))
                    Text(copiedCommand == command ? "Copied" : "Replace <command> with any executable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: copiedCommand == command ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Copy universal AgentKeyring command")
        .accessibilityHint("Copies a command containing no secret values")
    }
}

private struct PairingStatusView: View {
    let status: AgentPairingStatus
    let pairCommand: String

    var body: some View {
        switch status {
        case .paired:
            Label("Agents paired", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .incomplete:
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(pairCommand, forType: .string)
            } label: {
                Label("Copy pair-once command", systemImage: "link.badge.plus")
            }
            .buttonStyle(.link)
            .font(.caption)
            .accessibilityHint("Copies the local setup command; it contains no secret values")
        }
    }
}

private struct KeyEditorState: Identifiable {
    let id = UUID()
    let existingName: CredentialName?
}

private struct KeyEditorSheet: View {
    let existingName: CredentialName?
    let onSave: (String, String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var rawName: String
    @State private var value = ""
    @State private var attemptedSave = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case value
    }

    init(existingName: CredentialName?, onSave: @escaping (String, String) -> Bool) {
        self.existingName = existingName
        self.onSave = onSave
        _rawName = State(initialValue: existingName?.rawValue ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(existingName == nil ? "Add API key" : "Replace API key")
                    .font(.title3.weight(.semibold))
                Text("The value goes directly to your login Keychain and is never shown again.")
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
                Text("New value")
                    .font(.callout.weight(.medium))
                SecureField("Paste the key", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .value)
                    .accessibilityHint("Secret value; characters are hidden")
                if attemptedSave, let valueError {
                    Text(valueError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existingName == nil ? "Save Key" : "Replace Key") {
                    attemptedSave = true
                    guard nameError == nil, valueError == nil else { return }
                    if onSave(rawName, value) {
                        value = ""
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
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
}

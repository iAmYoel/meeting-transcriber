import AppKit
import SwiftUI

struct ObsidianSettingsSection: View {
    @Bindable var settings: AppSettings
    @State private var errorMessage = ""
    @State private var showRemoteConsent = false

    var body: some View {
        Section("Obsidian meeting notes") {
            Picker("Summary execution", selection: $settings.summaryExecutionMode) {
                ForEach(SummaryExecutionMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            Text("Manual mode saves the transcript without calling or loading Ollama. Pending summaries are available in the menu bar.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(settings.vaultRoot?.lastPathComponent ?? "No vault selected")
                Spacer()
                Button("Choose vault…", action: chooseVault)
            }
            Text("Uses AI/Meeting notes, AI/Transcriptions/Pending and Archive. Existing files and your external prompt are preserved.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Open meeting-summary prompt", action: openPrompt)
                .disabled(settings.vaultBookmark == nil)
            Text("Meeting notes are generated in Swedish using the OpenAI-compatible provider. Choose a model installed in Ollama below.")
                .font(.caption).foregroundStyle(.secondary)
            Stepper("Archive retention: \(settings.transcriptRetentionDays) days", value: $settings.transcriptRetentionDays, in: 1 ... 3650)
            Text("Only processed raw transcripts with an existing meeting note can be removed. Meeting notes and audio are kept.")
                .font(.caption).foregroundStyle(.secondary)
            if let endpoint = URL(string: settings.openAIEndpoint), !SummaryEndpointPolicy.isLoopback(endpoint) {
                Text("Remote endpoint: transcript and selected calendar metadata will leave this Mac.")
                    .foregroundStyle(.orange)
                if settings.approvedRemoteSummaryEndpoint != settings.openAIEndpoint {
                    Button("Review remote transmission…") { showRemoteConsent = true }
                } else {
                    Button("Revoke remote transmission consent") { settings.approvedRemoteSummaryEndpoint = "" }
                }
            }
            if !errorMessage.isEmpty { Text(errorMessage).foregroundStyle(.orange) }
        }
        .confirmationDialog("Send meeting data to this remote endpoint?", isPresented: $showRemoteConsent) {
            Button("Allow transmission") { settings.approvedRemoteSummaryEndpoint = settings.openAIEndpoint }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Summarizing will send the transcript and selected calendar title, times and attendees to \(settings.openAIEndpoint).")
        }
    }

    private func openPrompt() {
        guard let root = settings.vaultRoot else { return }
        let scoped = root.startAccessingSecurityScopedResource()
        defer { if scoped { root.stopAccessingSecurityScopedResource() } }
        do {
            let service = ObsidianVaultService(root: root)
            if let url = Bundle.module.url(forResource: "Meeting-Summary", withExtension: "md") {
                try service.installPromptIfAbsent(String(contentsOf: url, encoding: .utf8))
            }
            try NSWorkspace.shared.open(service.checkedURL("AI/System/Prompts/Meeting-Summary.md"))
        } catch { errorMessage = "The prompt could not be opened. Existing files were preserved." }
    }

    private func chooseVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose the root of your Obsidian vault."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try settings.setVaultRoot(url)
            errorMessage = ""
        } catch { errorMessage = "The selected vault could not be bookmarked. Previous choice retained." }
    }
}

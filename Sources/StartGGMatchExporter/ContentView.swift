import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainPanel
        }
        .frame(minWidth: 940, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            modePanel
            sourcePanel
            Spacer(minLength: 16)
            actionPanel
        }
        .padding(24)
        .frame(width: 370)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryPanel
            statusPanel
            logPanel
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("StartGG Match Exporter")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Structured tournament data export for macOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("Connection")
            HStack(spacing: 10) {
                Image(systemName: viewModel.apiMode == .authenticatedFast ? "bolt.fill" : "tortoise.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(viewModel.apiMode == .authenticatedFast ? .green : .blue)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.apiMode.title)
                        .font(.headline)
                    Text(viewModel.apiMode.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help(viewModel.apiMode.helpText)
        }
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelTitle("Source")

            VStack(alignment: .leading, spacing: 6) {
                Text("Event URL")
                    .font(.subheadline.weight(.medium))
                TextField("https://www.start.gg/tournament/.../event/street-fighter-6", text: $viewModel.eventURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Paste a start.gg event URL or bracket URL. The app will normalize it to the event slug.")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("API Token")
                        .font(.subheadline.weight(.medium))
                    Text("Optional")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                SecureField("Paste token for Fast Mode", text: $viewModel.token)
                    .textFieldStyle(.roundedBorder)
                    .help("Leave this blank for Public Safe Mode. Paste a start.gg API token to use Fast Mode.")
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.saveToken()
                } label: {
                    Label("Save", systemImage: "key")
                }
                .help("Save the current token in the macOS Keychain. Saving an empty field clears the saved token.")

                Button {
                    viewModel.clearToken()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .help("Remove the saved token and return to Public Safe Mode.")
            }
            .controlSize(.small)
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                viewModel.fetch()
            } label: {
                Label("Fetch Data", systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!viewModel.canStart)
            .help("Fetch entrants, standings, phases, and sets. Token input automatically enables Fast Mode.")

            HStack(spacing: 8) {
                Button {
                    viewModel.saveJSON()
                } label: {
                    Label("Save JSON", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.lastDocument == nil || viewModel.isWorking)
                .help("Save the fetched export document as formatted JSON.")

                if viewModel.isWorking {
                    Button(role: .cancel) {
                        viewModel.cancel()
                    } label: {
                        Label("Cancel", systemImage: "stop.circle")
                    }
                    .help("Cancel the current export.")
                }
            }
        }
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelTitle("Summary")
            HStack(spacing: 12) {
                metric("Entrants", value: viewModel.entrantCount)
                metric("Sets", value: viewModel.totalSetCount)
                metric("Complete", value: viewModel.completedSetCount)
                metric("Pending", value: viewModel.pendingSetCount)
            }
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("Status")
            HStack(spacing: 10) {
                if viewModel.isWorking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: viewModel.lastDocument == nil ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(viewModel.lastDocument == nil ? Color.secondary : Color.green)
                }
                Text(viewModel.progressMessage)
                    .foregroundStyle(viewModel.isWorking ? .primary : .secondary)
                    .lineLimit(2)
            }

            if let outputURL = viewModel.lastOutputURL {
                Text(outputURL.path)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .help(outputURL.path)
            }
        }
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelTitle("Activity")
            TextEditor(text: $viewModel.logText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .frame(maxHeight: .infinity)
        }
    }

    private func panelTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func metric(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help("\(label): \(value.formatted())")
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            form
            actions
            status
            log
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("StartGG Match Exporter")
                .font(.system(size: 26, weight: .semibold))
            Text("Export event entrants, standings, phases, and currently available sets as JSON.")
                .foregroundStyle(.secondary)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Event URL")
                    .font(.headline)
                TextField("https://www.start.gg/tournament/.../event/street-fighter-6", text: $viewModel.eventURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("start.gg API Token")
                    .font(.headline)
                SecureField("Bearer token from start.gg Developer Settings", text: $viewModel.token)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Save Token") {
                viewModel.saveToken()
            }
            Button("Fetch Data") {
                viewModel.fetch()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!viewModel.canStart)

            Button("Save JSON") {
                viewModel.saveJSON()
            }
            .disabled(viewModel.lastDocument == nil || viewModel.isWorking)

            if viewModel.isWorking {
                Button("Cancel") {
                    viewModel.cancel()
                }
            }
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isWorking {
                ProgressView()
            }
            Text(viewModel.progressMessage)
                .foregroundStyle(viewModel.isWorking ? .primary : .secondary)
            if let outputURL = viewModel.lastOutputURL {
                Text(outputURL.path)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var log: some View {
        TextEditor(text: $viewModel.logText)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 180)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
    }
}

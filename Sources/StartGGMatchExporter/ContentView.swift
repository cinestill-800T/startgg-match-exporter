import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainPanel
        }
        .frame(minWidth: 1080, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            viewModel.startBackgroundSync()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            sourcePanel
            watchlistPanel
            Spacer(minLength: 16)
            actionPanel
        }
        .padding(24)
        .frame(width: 430)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            matchProgressPanel
            backgroundSyncPanel
            statusPanel
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("StartGG Match Exporter")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Watchlist-focused tournament reports for macOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("Connection")
            HStack(spacing: 10) {
                Image(systemName: viewModel.apiMode == .authenticatedFast ? "lock.shield.fill" : "tortoise.fill")
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
                HStack {
                    Text("Event URL")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    statusPill(
                        viewModel.eventURLStatusText,
                        color: viewModel.hasValidEventURL ? .green : (viewModel.eventURL.isEmpty ? .secondary : .red)
                    )
                }
                TextField("https://www.start.gg/tournament/.../event/street-fighter-6", text: $viewModel.eventURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Paste a start.gg event URL or bracket URL. The app will normalize it to the event slug.")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("API Token")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    statusPill(viewModel.apiTokenStatusText, color: viewModel.hasAPIToken ? .green : .blue)
                }
                SecureField("Paste token for authenticated mode", text: $viewModel.token)
                    .textFieldStyle(.roundedBorder)
                    .help("Leave this blank for Public Safe Mode. Paste a start.gg API token to use the official API.")
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

            HStack(spacing: 8) {
                Spacer()

                Button {
                    viewModel.revealConfig()
                } label: {
                    Label("Config", systemImage: "slider.horizontal.3")
                }
                .controlSize(.small)
                .help("Open the generated config.json. Use it to tune request pacing, page sizes, concurrency, and retry waits.")
            }
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("Optional Output")
            Picker("Mode", selection: $viewModel.aiExportMode) {
                ForEach(AIExportMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                        .help(mode.helpText)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .help(viewModel.aiExportModeHelpText)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                    .help(viewModel.aiExportModeHelpText)
                Text(viewModel.aiExportMode.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(viewModel.aiExportModeHelpText)
            }
            .animation(.easeOut(duration: 0.2), value: viewModel.aiExportMode)

            if viewModel.aiExportMode == .watchlistFocus &&
                viewModel.watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Add names to the Watchlist to save this mode.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(AIExportMode.watchlistFocus.helpText)
                    .transition(.opacity)
            }

            Divider()
                .padding(.vertical, 2)

            VStack(spacing: 8) {
                Button {
                    viewModel.fetch()
                } label: {
                    Label("Fetch", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!viewModel.canStart)
                .help("Fetch entrants, standings, phases, and sets. Complete local cache may be used as a base for completed phases.")

                Button {
                    viewModel.fetch(forceRefresh: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(!viewModel.canStart)
                .help("Ignore local cache and fetch fresh data from start.gg.")

                Button {
                    viewModel.saveAnalysisPacket()
                } label: {
                    Label("Save Analysis Pack", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(!viewModel.canSaveAnalysisPacket)
                .help(viewModel.aiExportModeHelpText)

                if viewModel.isWorking {
                    Button(role: .cancel) {
                        viewModel.cancel()
                    } label: {
                        Label("Cancel", systemImage: "stop.circle")
                    }
                    .help("Cancel the current export. Only previously completed exports are kept in the local cache.")
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.aiExportMode)
    }

    private var matchProgressPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelTitle("Match Progress")
            HStack(spacing: 12) {
                metric("Entrants", value: viewModel.entrantCount)
                metric("Total Sets", value: viewModel.totalSetCount)
                metric("Completed", value: viewModel.completedSetCount)
                metric("Remaining", value: viewModel.pendingSetCount)
            }

            ProgressView(value: matchProgressValue, total: 1)
                .progressViewStyle(.linear)
                .help("Completed sets divided by total sets.")

            HStack(spacing: 8) {
                statusDot(viewModel.lastDocument == nil ? .secondary : .green)
                Text(viewModel.lastDocument == nil ? "No event data loaded yet." : "\(viewModel.watchlistPreview.relatedSetCount) related watchlist sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let bracketSummaryText = viewModel.bracketSummaryText,
               !bracketSummaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(bracketSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var backgroundSyncPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                panelTitle("Background Sync")
                Spacer()
                statusPill(
                    viewModel.autoRefreshEnabled ? (viewModel.isBackgroundSyncing ? "Syncing" : "Active") : "Off",
                    color: viewModel.autoRefreshEnabled ? .green : .secondary
                )
            }

            Toggle("Auto-fetch on launch and periodic refresh", isOn: $viewModel.autoRefreshEnabled)
                .toggleStyle(.switch)
                .help("Keep the current event fresh while the app is open. Requests use the existing throttled queue.")

            HStack(spacing: 12) {
                syncMetric("Every", value: viewModel.backgroundRefreshIntervalText)
                syncMetric("Last", value: viewModel.lastBackgroundSyncText)
                syncMetric("Next", value: viewModel.nextBackgroundSyncText)
            }

            HStack(spacing: 8) {
                if viewModel.isBackgroundSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    statusDot(viewModel.autoRefreshEnabled ? .green : .secondary)
                }
                Text(viewModel.backgroundSyncMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !viewModel.backgroundSyncEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent Updates")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.backgroundSyncEvents, id: \.self) { event in
                        Text(event)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

        }
    }

    private var watchlistPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTitle("Watchlist")
            watchlistTextEditor(
                title: "Teams or players to track",
                text: $viewModel.watchlistText,
                placeholder: "SZ\nZETA\nacola\nMiya",
                help: "Paste one team or player name per line. Matching uses entrant names, gamer tags, and common prefix forms."
            )

            watchlistTextEditor(
                title: "Exclude",
                text: $viewModel.excludedWatchlistText,
                placeholder: "doubles\nside event",
                help: "Entries matching these words are removed from Watchlist matches. Use one word per line."
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Filters")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(alignment: .top, spacing: 18) {
                    watchlistFilterGroup(
                        title: "Status",
                        firstLabel: "Active",
                        firstBinding: $viewModel.watchlistIncludeLiving,
                        secondLabel: "Eliminated",
                        secondBinding: $viewModel.watchlistIncludeEliminated
                    )
                    watchlistFilterGroup(
                        title: "Bracket",
                        firstLabel: "Winners",
                        firstBinding: $viewModel.watchlistIncludeWinners,
                        secondLabel: "Losers",
                        secondBinding: $viewModel.watchlistIncludeLosers
                    )
                }
            }

            if let prompt = viewModel.watchlistExportPromptText {
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(viewModel.watchlistPreview.summaryText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .help("Summary updates from the latest fetched data and the pasted watchlist.")

            Button {
                viewModel.saveWatchlistMarkdown()
            } label: {
                Label("Save Markdown Report", systemImage: "doc.plaintext")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canSaveWatchlistScope)
            .help("Save a compact watchlist report as Markdown.")
        }
    }

    private func watchlistFilterGroup(
        title: String,
        firstLabel: String,
        firstBinding: Binding<Bool>,
        secondLabel: String,
        secondBinding: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Toggle(firstLabel, isOn: firstBinding)
                    .toggleStyle(.checkbox)
                Toggle(secondLabel, isOn: secondBinding)
                    .toggleStyle(.checkbox)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func watchlistTextEditor(
        title: String,
        text: Binding<String>,
        placeholder: String,
        help: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
                    .help(help)

                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.65))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 96)
        }
    }

    private func panelTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var matchProgressValue: Double {
        guard viewModel.totalSetCount > 0 else {
            return 0
        }
        return Double(viewModel.completedSetCount) / Double(viewModel.totalSetCount)
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            statusDot(color)
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
    }

    private func statusDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func syncMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)

            mainPanel
                .frame(minWidth: 560, idealWidth: 820, maxWidth: .infinity)
        }
        .frame(minWidth: 1080, idealWidth: 1260, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsView(viewModel: viewModel)
        }
        .task {
            viewModel.startBackgroundSync()
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                modePanel
                sourcePanel
                manualFetchPanel
                configPanel
            }
            .padding(20)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var mainPanel: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        watchlistPanel
                        outputPanel
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 16) {
                        matchProgressPanel
                        backgroundSyncPanel
                        statusPanel
                    }
                    .frame(width: 340, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 16) {
                    watchlistPanel
                    outputPanel
                    matchProgressPanel
                    backgroundSyncPanel
                    statusPanel
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("StartGG Match Exporter")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Watchlist-focused tournament reports for macOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modePanel: some View {
        sectionSurface {
            panelTitle("Connection")
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: viewModel.apiMode == .authenticatedFast ? "lock.shield.fill" : "tortoise.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(viewModel.apiMode == .authenticatedFast ? .green : .blue)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.apiMode.title)
                        .font(.headline)
                    Text(viewModel.apiMode.shortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .help(viewModel.apiMode.helpText)
        }
    }

    private var sourcePanel: some View {
        sectionSurface {
            panelTitle("Source")

            VStack(alignment: .leading, spacing: 8) {
                Text("Event URL")
                    .font(.subheadline.weight(.medium))
                TextField("https://www.start.gg/tournament/.../event/street-fighter-6", text: $viewModel.eventURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Paste a start.gg event URL or bracket URL. The app will normalize it to the event slug.")
                statusPill(
                    viewModel.eventURLStatusText,
                    color: viewModel.hasValidEventURL ? .green : (viewModel.eventURL.isEmpty ? .secondary : .red)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Token")
                    .font(.subheadline.weight(.medium))
                SecureField("Paste token for authenticated mode", text: $viewModel.token)
                    .textFieldStyle(.roundedBorder)
                    .help("Leave this blank for Public Safe Mode. Paste a start.gg API token to use the official API.")
                statusPill(viewModel.apiTokenStatusText, color: viewModel.hasAPIToken ? .green : .blue)
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.saveToken()
                } label: {
                    Label("Save Token", systemImage: "key")
                }
                .help("Save the current token in the macOS Keychain. Saving an empty field clears the saved token.")

                Button {
                    viewModel.clearToken()
                } label: {
                    Label("Clear Token", systemImage: "xmark.circle")
                }
                .help("Remove the saved token and return to Public Safe Mode.")
            }
            .controlSize(.small)
        }
    }

    private var configPanel: some View {
        sectionSurface {
            panelTitle("Settings")

            Button {
                viewModel.openSettings()
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .help("Open app settings for auto-fetch, request pacing, concurrency, and page sizes.")
        }
    }

    private var manualFetchPanel: some View {
        sectionSurface {
            panelTitle("Manual Fetch")

            HStack(spacing: 8) {
                Button {
                    viewModel.fetch()
                } label: {
                    Label("Fetch", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!viewModel.canStart)
                .help("Fetch entrants, standings, phases, and sets. Complete local cache may be used as a base for completed phases.")

                Button {
                    viewModel.fetch(forceRefresh: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.canStart)
                .help("Ignore local cache and fetch fresh data from start.gg.")
            }

            if viewModel.isWorking {
                Button(role: .cancel) {
                    viewModel.cancel()
                } label: {
                    Label("Cancel", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .help("Cancel the current export. Only previously completed exports are kept in the local cache.")
            }
        }
    }

    private var outputPanel: some View {
        sectionSurface {
            panelTitle("Output")

            HStack(spacing: 10) {
                Button {
                    viewModel.saveWatchlistMarkdown()
                } label: {
                    Label("Save Markdown Report", systemImage: "doc.plaintext")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSaveWatchlistScope)
                .help("Save a compact watchlist report as Markdown.")

                Button {
                    viewModel.saveAnalysisPacket()
                } label: {
                    Label("Save JSON Pack", systemImage: "curlybraces.square")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.canSaveAnalysisPacket)
                .help("Save analysis.json, matches.jsonl, summary.md, and optional raw.json.")
            }

            Divider()

            panelTitle("Auto Markdown")
            HStack(spacing: 10) {
                Toggle("Auto-overwrite Markdown Report", isOn: $viewModel.autoSaveWatchlistMarkdownEnabled)
                    .toggleStyle(.switch)
                    .help("Write the watchlist Markdown report to the same Downloads file after every successful fetch, refresh, or background sync.")

                Spacer()

                if viewModel.isAutoSavingWatchlistMarkdown {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    statusDot(viewModel.autoSaveWatchlistMarkdownEnabled ? .green : .secondary)
                }
            }

            Text(viewModel.autoWatchlistMarkdownDestinationText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(viewModel.autoWatchlistMarkdownDestinationText)

            Text(viewModel.autoWatchlistMarkdownStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Divider()

            panelTitle("JSON Pack Mode")
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
                Image(systemName: "info.circle")
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
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.aiExportMode)
    }

    private var matchProgressPanel: some View {
        sectionSurface {
            panelTitle("Match Progress")
            VStack(spacing: 10) {
                metric("Total Sets", value: viewModel.totalSetCount)
                metric("Completed", value: viewModel.completedSetCount)
                metric("Remaining", value: viewModel.pendingSetCount)
            }

            ProgressView(value: matchProgressValue, total: 1)
                .progressViewStyle(.linear)
                .help("Completed sets divided by total sets.")

            HStack(spacing: 8) {
                statusDot(viewModel.lastDocument == nil ? .secondary : .green)
                Text(viewModel.watchlistRelatedSetStatusText)
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
        sectionSurface {
            HStack {
                panelTitle("Background Sync")
                Spacer()
                statusPill(
                    viewModel.autoRefreshEnabled ? (viewModel.isBackgroundSyncing ? "Syncing" : "Active") : "Off",
                    color: viewModel.autoRefreshEnabled ? .green : .secondary
                )
            }

            Toggle("Auto-fetch on launch and every \(viewModel.backgroundRefreshIntervalText)", isOn: $viewModel.autoRefreshEnabled)
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
    }

    private var statusPanel: some View {
        sectionSurface {
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
        sectionSurface {
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
            .frame(height: title == "Exclude" ? 76 : 138)
        }
    }

    private func panelTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func sectionSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
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
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.formatted())
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help("\(label): \(value.formatted())")
    }
}

private struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text("Adjust the settings that affect ongoing fetches. Advanced retry timing remains in config.json for compatibility.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], 22)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper(value: $viewModel.settingsDraft.autoFetchIntervalMinutes, in: 1...60, step: 1) {
                                settingRow(
                                    title: "Auto-fetch interval",
                                    value: "\(viewModel.settingsDraft.autoFetchIntervalMinutes) min",
                                    description: "Used when background sync is enabled."
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Label("Background Sync", systemImage: "arrow.clockwise")
                    }

                    TabView {
                        apiSettingsSection(
                            modeTitle: "Authenticated Safe Mode",
                            modeDescription: "Used when an API token is saved.",
                            settings: $viewModel.settingsDraft.officialAPI
                        )
                        .tabItem {
                            Text("Authenticated")
                        }

                        apiSettingsSection(
                            modeTitle: "Public Safe Mode",
                            modeDescription: "Used when no API token is available.",
                            settings: $viewModel.settingsDraft.publicAPI
                        )
                        .tabItem {
                            Text("Public")
                        }
                    }
                    .frame(minHeight: 310)

                    if !viewModel.settingsMessage.isEmpty {
                        Text(viewModel.settingsMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(22)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    viewModel.resetSettingsDraft()
                } label: {
                    Label("Defaults", systemImage: "arrow.counterclockwise")
                }
                .help("Restore recommended defaults in this form. Save to apply them.")

                Button {
                    viewModel.revealConfig()
                } label: {
                    Label("Show Config File", systemImage: "doc.text.magnifyingglass")
                }
                .help("Reveal config.json for advanced settings that are not shown here.")

                Spacer()

                Button("Cancel") {
                    viewModel.isSettingsPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    viewModel.saveSettings()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 620, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func apiSettingsSection(
        modeTitle: String,
        modeDescription: String,
        settings: Binding<APISettingsDraft>
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modeTitle)
                        .font(.headline)
                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Stepper(value: settings.minimumRequestIntervalSeconds, in: 0.2...30, step: 0.05) {
                        settingRow(
                            title: "Request interval",
                            value: String(format: "%.2f sec", settings.wrappedValue.minimumRequestIntervalSeconds),
                            description: "Minimum wait between start.gg requests. Raise this if 429 errors appear."
                        )
                    }

                    Stepper(value: settings.concurrentRequests, in: 1...4, step: 1) {
                        settingRow(
                            title: "Concurrent page requests",
                            value: "\(settings.wrappedValue.concurrentRequests)",
                            description: "Higher values can fetch faster but increase rate-limit risk."
                        )
                    }

                    Divider()

                    pageSizeStepper(
                        title: "Set page size",
                        value: settings.setPageSize,
                        range: 1...100,
                        description: "Number of matches requested per page."
                    )

                    pageSizeStepper(
                        title: "Entrant page size",
                        value: settings.entrantPageSize,
                        range: 1...200,
                        description: "Number of entrants requested per page."
                    )

                    pageSizeStepper(
                        title: "Standing page size",
                        value: settings.standingPageSize,
                        range: 1...200,
                        description: "Number of standings rows requested per page."
                    )
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Fetch Tuning", systemImage: "speedometer")
        }
    }

    private func pageSizeStepper(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        description: String
    ) -> some View {
        Stepper(value: value, in: range, step: 5) {
            settingRow(
                title: title,
                value: "\(value.wrappedValue)",
                description: description
            )
        }
    }

    private func settingRow(title: String, value: String, description: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 78, alignment: .trailing)
        }
    }
}

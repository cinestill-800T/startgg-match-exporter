import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var token: String = ""
    @Published var eventURL: String = "" {
        didSet {
            UserDefaults.standard.set(eventURL, forKey: Self.lastEventURLDefaultsKey)
        }
    }
    @Published var isWorking = false
    @Published var progressMessage = "Ready"
    @Published private var logLines: [String] = []
    @Published var lastDocument: ExportDocument?
    @Published var lastOutputURL: URL?
    @Published var completedSetCount = 0
    @Published var pendingSetCount = 0
    @Published var totalSetCount = 0
    @Published var entrantCount = 0
    @Published private(set) var bracketSummaryText: String?
    @Published var watchlistText = "" {
        didSet {
            UserDefaults.standard.set(watchlistText, forKey: Self.lastWatchlistTextDefaultsKey)
        }
    }
    @Published var excludedWatchlistText = "" {
        didSet {
            UserDefaults.standard.set(excludedWatchlistText, forKey: Self.lastExcludedWatchlistTextDefaultsKey)
        }
    }
    @Published var aiExportMode: AIExportMode = .full {
        didSet {
            UserDefaults.standard.set(aiExportMode.rawValue, forKey: Self.aiExportModeDefaultsKey)
        }
    }

    private var currentTask: Task<Void, Never>?
    private static let lastEventURLDefaultsKey = "lastEventURL"
    private static let lastWatchlistTextDefaultsKey = "lastWatchlistText"
    private static let lastExcludedWatchlistTextDefaultsKey = "lastExcludedWatchlistText"
    private static let aiExportModeDefaultsKey = "aiExportMode"

    init() {
        token = (try? KeychainTokenStore.load()) ?? ""
        eventURL = UserDefaults.standard.string(forKey: Self.lastEventURLDefaultsKey) ?? ""
        watchlistText = UserDefaults.standard.string(forKey: Self.lastWatchlistTextDefaultsKey) ?? ""
        excludedWatchlistText = UserDefaults.standard.string(forKey: Self.lastExcludedWatchlistTextDefaultsKey) ?? ""
        if let rawMode = UserDefaults.standard.string(forKey: Self.aiExportModeDefaultsKey),
           let mode = AIExportMode(rawValue: rawMode) {
            aiExportMode = mode
        }
    }

    var canStart: Bool {
        !isWorking &&
            !eventURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var logText: String {
        logLines.joined(separator: "\n")
    }

    var apiMode: StartGGAPIMode {
        StartGGAPIMode.resolved(for: token)
    }

    var watchlistPreview: WatchlistPreview {
        WatchlistScopeBuilder.preview(for: watchlistText, excludedText: excludedWatchlistText, document: lastDocument)
    }

    var canSaveWatchlistScope: Bool {
        lastDocument != nil &&
            !watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !isWorking
    }

    var canSaveAnalysisPacket: Bool {
        guard lastDocument != nil, !isWorking else {
            return false
        }
        if aiExportMode == .watchlistFocus {
            return !watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var aiExportModeHelpText: String {
        aiExportMode.helpText
    }

    func saveToken() {
        do {
            try KeychainTokenStore.save(token)
            if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendLog("Token cleared. Public Safe Mode will be used.")
            } else {
                appendLog("Token saved to Keychain. Authenticated Safe Mode will be used.")
            }
        } catch {
            appendLog("Token save failed: \(error.localizedDescription)")
        }
    }

    func clearToken() {
        do {
            try KeychainTokenStore.delete()
            token = ""
            appendLog("Token cleared. Public Safe Mode will be used.")
        } catch {
            appendLog("Token clear failed: \(error.localizedDescription)")
        }
    }

    func fetch(forceRefresh: Bool = false) {
        guard canStart else {
            appendLog("Enter a start.gg event URL first.")
            return
        }

        if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveToken()
        }
        isWorking = true
        clearDisplayedDocument()
        progressMessage = "Starting \(apiMode.title)"
        logLines.removeAll()
        if forceRefresh {
            appendLog("Refresh requested. Ignoring local cache.")
        }

        let inputURL = eventURL
        let inputToken = token
        let mode = apiMode

        currentTask = Task { [weak self] in
            guard let self else { return }
            let configurationResult = ExportConfigurationStore.loadOrCreate()
            let options = configurationResult.configuration.options(for: mode)
            await MainActor.run {
                if configurationResult.url != nil {
                    self.appendLog("Config loaded.")
                }
                if let warning = configurationResult.warning {
                    self.appendLog(warning)
                }
            }

            let cachedDocument: ExportDocument?
            if !forceRefresh {
                do {
                    let slug = try StartGGURLParser.eventSlug(from: inputURL)
                    cachedDocument = ExportCache.cachedDocument(for: slug, mode: mode)
                    if cachedDocument != nil {
                        await MainActor.run {
                            self.appendLog("Using cache as the base for incremental update.")
                        }
                    }
                } catch {
                    cachedDocument = nil
                    await MainActor.run {
                        self.appendLog("Cache lookup skipped: \(error.localizedDescription)")
                    }
                }
            } else {
                cachedDocument = nil
            }

            let service = ExportService(options: options) { [weak self] progress in
                await MainActor.run {
                    self?.progressMessage = progress.total.map {
                        "\(progress.stage): \(progress.detail) (\(progress.current)/\($0))"
                    } ?? "\(progress.stage): \(progress.detail)"
                }
            } partialDocumentHandler: { [weak self] partialDocument in
                await MainActor.run {
                    self?.appendLog("Fetched bracket progress: \(partialDocument.phases.count)/\(partialDocument.event.phases.count) phases.")
                }
            }

            do {
                let document = try await service.export(from: inputURL, token: inputToken, cachedDocument: cachedDocument)
                await MainActor.run {
                    let didSaveCache = ExportCache.save(document)
                    self.apply(document: document, mode: mode)
                    self.progressMessage = "Fetched \(document.summary.setCount) sets."
                    self.appendLog(didSaveCache ? "Saved cache." : "Cache save skipped. Export data is available in this session.")
                    if !self.watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let preview = WatchlistScopeBuilder.preview(for: self.watchlistText, excludedText: self.excludedWatchlistText, document: document)
                        self.appendLog("Watchlist: \(preview.summaryText)")
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    if let cachedDocument = self.cachedDocument(for: inputURL, mode: mode) {
                        self.apply(document: cachedDocument, mode: mode)
                        self.progressMessage = "Cancelled. Loaded complete cache."
                        self.appendLog("Export cancelled. Loaded the previous complete cache.")
                    } else {
                        self.clearDisplayedDocument()
                        self.isWorking = false
                        self.progressMessage = "Cancelled"
                        self.appendLog("Export cancelled. No complete cache was available.")
                    }
                }
            } catch {
                await MainActor.run {
                    if let cachedDocument {
                        self.apply(document: cachedDocument, mode: mode)
                        self.progressMessage = "Loaded cache after refresh failed."
                        self.appendLog("Export failed: \(error.localizedDescription)")
                        self.appendLog("Fell back to cached data.")
                    } else {
                        self.clearDisplayedDocument()
                        self.isWorking = false
                        self.progressMessage = "Failed"
                        self.appendLog("Export failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    func saveAnalysisPacket() {
        guard let lastDocument else {
            appendLog("Fetch data before saving an analysis pack.")
            return
        }
        if aiExportMode == .watchlistFocus,
           watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendLog("Watchlist Focus requires at least one player name in the Watchlist field.")
            return
        }

        guard let downloads = downloadsDirectory() else {
            appendLog("Downloads folder is unavailable.")
            return
        }

        do {
            let eventName = sanitizedFileName(lastDocument.event.name ?? "startgg-event")
            let timestamp = timestampForFolderName()
            let folderURL = uniqueFolderURL(
                baseURL: downloads.appendingPathComponent(
                    "\(eventName)-analysis-\(aiExportMode.folderNameComponent)-\(timestamp)",
                    isDirectory: true
                )
            )
            let options = AIExportOptions(mode: aiExportMode, watchlistText: watchlistText, excludedWatchlistText: excludedWatchlistText)
            let files = try AIExportBuilder.writePacket(document: lastDocument, to: folderURL, options: options)
            lastOutputURL = folderURL
            appendLog("Saved analysis pack.")
            appendLog("AI output mode: \(aiExportMode.title)")
            appendLog("Analysis files: \(files.count)")
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        } catch {
            appendLog("Analysis pack save failed: \(error.localizedDescription)")
        }
    }

    func saveWatchlistMarkdown() {
        guard let scope = makeWatchlistScope() else {
            appendLog("Fetch data and paste watchlist names before saving a focused report.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.directoryURL = downloadsDirectory()
        let name = sanitizedFileName(lastDocument?.event.name ?? "startgg-event")
        panel.nameFieldStringValue = "\(name)-watchlist.md"

        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("Watchlist Markdown save cancelled.")
            return
        }

        do {
            let markdown = WatchlistScopeBuilder.markdown(from: scope)
            try Data(markdown.utf8).write(to: url, options: .atomic)
            appendLog("Saved watchlist Markdown.")
        } catch {
            appendLog("Watchlist Markdown save failed: \(error.localizedDescription)")
        }
    }

    func fetchAndSave() {
        fetch()
    }

    func revealConfig() {
        let result = ExportConfigurationStore.loadOrCreate()
        if let warning = result.warning {
            appendLog(warning)
        }
        guard let url = result.url else {
            appendLog("config.json を利用できません。")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        appendLog("Config opened.")
    }

    private func apply(document: ExportDocument, mode: StartGGAPIMode) {
        lastDocument = document
        isWorking = false
        completedSetCount = document.summary.completedSetCount
        pendingSetCount = document.summary.pendingSetCount
        totalSetCount = document.summary.setCount
        entrantCount = document.summary.entrantCount
        updateBracketSummary(from: document)
        appendLog("Event: \(document.event.name ?? document.event.id.value)")
        appendLog("Mode: \(mode.title)")
        appendLog("Entrants: \(document.summary.entrantCount)")
        appendLog("Standings: \(document.summary.standingCount)")
        appendLog("Sets: \(document.summary.setCount)")
        appendLog("Completed sets: \(document.summary.completedSetCount)")
        appendLog("Pending sets: \(document.summary.pendingSetCount)")
        appendLog("Started/called sets: \(document.summary.startedSetCount)")
    }

    private func clearDisplayedDocument() {
        lastDocument = nil
        lastOutputURL = nil
        completedSetCount = 0
        pendingSetCount = 0
        totalSetCount = 0
        entrantCount = 0
        bracketSummaryText = nil
    }

    private func makeWatchlistScope() -> WatchlistExportDocument? {
        guard let lastDocument, !watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return WatchlistScopeBuilder.build(from: lastDocument, watchlistText: watchlistText, excludedText: excludedWatchlistText)
    }

    private func cachedDocument(for inputURL: String, mode: StartGGAPIMode) -> ExportDocument? {
        guard let slug = try? StartGGURLParser.eventSlug(from: inputURL) else {
            return nil
        }
        return ExportCache.cachedDocument(for: slug, mode: mode)
    }

    private func updateBracketSummary(from document: ExportDocument) {
        bracketSummaryText = Self.bracketSummaryText(for: document)
    }

    private static func bracketSummaryText(for document: ExportDocument) -> String? {
        let eventPhases = document.event.phases
        guard !eventPhases.isEmpty else {
            return "No bracket phases were returned by start.gg for this event."
        }

        let fetchedPhaseCount = document.phases.count
        let totalPhaseCount = eventPhases.count
        let setSummary = document.summary.setCount > 0
            ? "\(document.summary.completedSetCount)/\(document.summary.setCount) sets"
            : nil
        let phaseSummary = "\(fetchedPhaseCount)/\(totalPhaseCount) phases"

        guard fetchedPhaseCount > 0 else {
            let firstPhaseName = phaseDisplayName(from: eventPhases[0])
            var text = "Current phase progress: waiting for \(firstPhaseName)"
            let details = [setSummary, phaseSummary].compactMap { $0 }
            if !details.isEmpty {
                text += " (\(details.joined(separator: ", ")))"
            }
            return text
        }

        let currentIndex = min(fetchedPhaseCount - 1, totalPhaseCount - 1)
        let currentPhase = document.phases[min(currentIndex, document.phases.count - 1)]
        let currentPhaseName = phaseDisplayName(from: currentPhase, fallback: eventPhases[currentIndex])
        let status = bracketPhaseStatus(for: currentPhase)
        var text = "Current phase progress: \(currentPhaseName) \(status)"
        let percentSummary = currentPhase.percentComplete.map { value -> String in
            "\(value)%"
        }
        let details = [percentSummary, setSummary, phaseSummary].compactMap { $0 }
        if !details.isEmpty {
            text += " (\(details.joined(separator: ", ")))"
        }
        if let nextPhaseName = nextBracketPhaseName(
            currentPhase: currentPhase,
            currentIndex: currentIndex,
            eventPhases: eventPhases
        ) {
            text += "; next \(nextPhaseName)"
        }
        return text
    }

    private static func bracketPhaseStatus(for phase: PhaseExport) -> String {
        let completedSetCount = phase.sets.filter { StartGGSetState.isCompleted($0.state) }.count
        let hasActiveSet = phase.sets.contains { StartGGSetState.isActive($0.state) }
        let hasPendingSet = phase.sets.contains { StartGGSetState.isPending($0.state) }

        if let percentComplete = phase.percentComplete {
            if percentComplete >= 100 || (!hasActiveSet && !hasPendingSet && !phase.sets.isEmpty && completedSetCount == phase.sets.count) {
                return "complete"
            }
            if percentComplete > 0 || hasActiveSet || hasPendingSet || completedSetCount > 0 {
                return "in progress"
            }
            return "pending"
        }

        if !phase.sets.isEmpty {
            if !hasActiveSet && !hasPendingSet && completedSetCount == phase.sets.count {
                return "complete"
            }
            return "in progress"
        }

        return "pending"
    }

    private static func nextBracketPhaseName(
        currentPhase: PhaseExport,
        currentIndex: Int,
        eventPhases: [PhaseSummary]
    ) -> String? {
        if let destination = currentPhase.destPhases?.first {
            let name = phaseDisplayName(from: destination)
            if !name.isEmpty {
                return name
            }
        }

        let nextIndex = currentIndex + 1
        guard nextIndex < eventPhases.count else {
            return nil
        }
        return phaseDisplayName(from: eventPhases[nextIndex])
    }

    private static func phaseDisplayName(from phase: PhaseSummary) -> String {
        phaseDisplayName(from: phase.name, fallback: phase.id.value)
    }

    private static func phaseDisplayName(from phase: DestinationPhase) -> String {
        phaseDisplayName(from: phase.name, fallback: phase.id.value)
    }

    private static func phaseDisplayName(from phase: PhaseExport, fallback: PhaseSummary) -> String {
        phaseDisplayName(from: phase.name, fallback: fallback.name ?? fallback.id.value)
    }

    private static func phaseDisplayName(from value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return fallback
    }

    private func downloadsDirectory() -> URL? {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }

    private func uniqueFolderURL(baseURL: URL) -> URL {
        var candidate = baseURL
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = baseURL.deletingLastPathComponent()
                .appendingPathComponent("\(baseURL.lastPathComponent)-\(index)", isDirectory: true)
            index += 1
        }
        return candidate
    }

    private func timestampForFolderName() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 500 {
            logLines.removeFirst(logLines.count - 500)
        }
    }

    private func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return name
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()
    }
}

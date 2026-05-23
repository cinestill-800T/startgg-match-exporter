import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var token: String = ""
    @Published var eventURL: String = ""
    @Published var isWorking = false
    @Published var progressMessage = "Ready"
    @Published var logText = ""
    @Published var lastDocument: ExportDocument?
    @Published var lastOutputURL: URL?
    @Published var completedSetCount = 0
    @Published var pendingSetCount = 0
    @Published var totalSetCount = 0
    @Published var entrantCount = 0
    @Published var watchlistText = ""

    private var currentTask: Task<Void, Never>?

    init() {
        token = (try? KeychainTokenStore.load()) ?? ""
    }

    var canStart: Bool {
        !isWorking &&
            !eventURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var apiMode: StartGGAPIMode {
        StartGGAPIMode.resolved(for: token)
    }

    var watchlistPreview: WatchlistPreview {
        WatchlistScopeBuilder.preview(for: watchlistText, document: lastDocument)
    }

    var canSaveWatchlistScope: Bool {
        lastDocument != nil &&
            !watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !isWorking
    }

    func saveToken() {
        do {
            try KeychainTokenStore.save(token)
            if token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendLog("Token cleared. Public Safe Mode will be used.")
            } else {
                appendLog("Token saved to Keychain. Fast Mode will be used.")
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

    func fetch() {
        guard canStart else {
            appendLog("Enter a start.gg event URL first.")
            return
        }

        if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveToken()
        }
        isWorking = true
        lastDocument = nil
        lastOutputURL = nil
        completedSetCount = 0
        pendingSetCount = 0
        totalSetCount = 0
        entrantCount = 0
        progressMessage = "Starting \(apiMode.title)"
        logText = ""

        let inputURL = eventURL
        let inputToken = token
        let mode = apiMode

        currentTask = Task { [weak self] in
            guard let self else { return }
            let service = ExportService(options: ExportOptions.defaults(for: mode)) { [weak self] progress in
                await MainActor.run {
                    self?.progressMessage = progress.total.map {
                        "\(progress.stage): \(progress.detail) (\(progress.current)/\($0))"
                    } ?? "\(progress.stage): \(progress.detail)"
                }
            }

            do {
                let document = try await service.export(from: inputURL, token: inputToken)
                await MainActor.run {
                    self.lastDocument = document
                    self.isWorking = false
                    self.progressMessage = "Fetched \(document.summary.setCount) sets."
                    self.completedSetCount = document.summary.completedSetCount
                    self.pendingSetCount = document.summary.pendingSetCount
                    self.totalSetCount = document.summary.setCount
                    self.entrantCount = document.summary.entrantCount
                    self.appendLog("Fetched event: \(document.event.name ?? document.event.id.value)")
                    self.appendLog("Mode: \(mode.title)")
                    self.appendLog("Entrants: \(document.summary.entrantCount)")
                    self.appendLog("Standings: \(document.summary.standingCount)")
                    self.appendLog("Sets: \(document.summary.setCount)")
                    self.appendLog("Completed sets: \(document.summary.completedSetCount)")
                    self.appendLog("Pending sets: \(document.summary.pendingSetCount)")
                    self.appendLog("Started/called sets: \(document.summary.startedSetCount)")
                    if !self.watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let preview = WatchlistScopeBuilder.preview(for: self.watchlistText, document: document)
                        self.appendLog("Watchlist: \(preview.summaryText)")
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isWorking = false
                    self.progressMessage = "Cancelled"
                    self.appendLog("Export cancelled.")
                }
            } catch {
                await MainActor.run {
                    self.isWorking = false
                    self.progressMessage = "Failed"
                    self.appendLog("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    func saveJSON() {
        guard let lastDocument else {
            appendLog("Fetch data before saving JSON.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        let name = sanitizedFileName(lastDocument.event.name ?? "startgg-event")
        panel.nameFieldStringValue = "\(name)-matches.json"

        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("Save cancelled.")
            return
        }

        do {
            let data = try ExportService().encode(lastDocument)
            try data.write(to: url, options: .atomic)
            lastOutputURL = url
            appendLog("Saved JSON: \(url.path)")
        } catch {
            appendLog("Save failed: \(error.localizedDescription)")
        }
    }

    func saveWatchlistJSON() {
        guard let scope = makeWatchlistScope() else {
            appendLog("Fetch data and paste watchlist names before saving a focused JSON.")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        let name = sanitizedFileName(lastDocument?.event.name ?? "startgg-event")
        panel.nameFieldStringValue = "\(name)-watchlist.json"

        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("Watchlist JSON save cancelled.")
            return
        }

        do {
            let data = try WatchlistScopeBuilder.encodeJSON(scope)
            try data.write(to: url, options: .atomic)
            appendLog("Saved watchlist JSON: \(url.path)")
        } catch {
            appendLog("Watchlist JSON save failed: \(error.localizedDescription)")
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
        let name = sanitizedFileName(lastDocument?.event.name ?? "startgg-event")
        panel.nameFieldStringValue = "\(name)-watchlist.md"

        guard panel.runModal() == .OK, let url = panel.url else {
            appendLog("Watchlist Markdown save cancelled.")
            return
        }

        do {
            let markdown = WatchlistScopeBuilder.markdown(from: scope)
            try Data(markdown.utf8).write(to: url, options: .atomic)
            appendLog("Saved watchlist Markdown: \(url.path)")
        } catch {
            appendLog("Watchlist Markdown save failed: \(error.localizedDescription)")
        }
    }

    func fetchAndSave() {
        fetch()
    }

    private func makeWatchlistScope() -> WatchlistExportDocument? {
        guard let lastDocument, !watchlistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return WatchlistScopeBuilder.build(from: lastDocument, watchlistText: watchlistText)
    }

    private func appendLog(_ line: String) {
        if logText.isEmpty {
            logText = line
        } else {
            logText += "\n\(line)"
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

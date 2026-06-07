import Foundation

enum AIExportMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case full
    case liveFocus
    case compact
    case watchlistFocus

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .full:
            return "Full"
        case .liveFocus:
            return "Live Focus"
        case .compact:
            return "Compact"
        case .watchlistFocus:
            return "Watchlist Focus"
        }
    }

    var folderNameComponent: String {
        switch self {
        case .full:
            return "full"
        case .liveFocus:
            return "live-focus"
        case .compact:
            return "compact"
        case .watchlistFocus:
            return "watchlist-focus"
        }
    }

    var shortDescription: String {
        switch self {
        case .full:
            return "Includes every match plus raw.json for complete review and later re-analysis."
        case .liveFocus:
            return "Keeps pending and active matches, related players, and recent results for ongoing event tracking."
        case .compact:
            return "Omits unrelated history and keeps the current bracket context small."
        case .watchlistFocus:
            return "Focuses the saved files on the teams or players entered in the Watchlist."
        }
    }

    var helpText: String {
        switch self {
        case .full:
            return "Full: includes raw.json and the complete matches.jsonl. Use this when you want the most complete archive."
        case .liveFocus:
            return "Live Focus: omits raw.json and scopes files to unfinished or active matches, related players, and recent completed sets for active entrants."
        case .compact:
            return "Compact: omits raw.json, completed match detail rows, unrelated players, and the broad search index."
        case .watchlistFocus:
            return "Watchlist Focus: saves only the watchlist entrants, their unfinished matches, and their recent completed matches."
        }
    }

    var defaultRecentCompletedMatchLimit: Int {
        switch self {
        case .full:
            return Int.max
        case .liveFocus:
            return 3
        case .compact:
            return 0
        case .watchlistFocus:
            return 5
        }
    }
}

struct AIExportOptions: Codable, Hashable, Sendable {
    var mode: AIExportMode
    var watchlistText: String
    var excludedWatchlistText: String
    var recentCompletedMatchLimit: Int

    init(
        mode: AIExportMode = .full,
        watchlistText: String = "",
        excludedWatchlistText: String = "",
        recentCompletedMatchLimit: Int? = nil
    ) {
        self.mode = mode
        self.watchlistText = watchlistText
        self.excludedWatchlistText = excludedWatchlistText
        self.recentCompletedMatchLimit = recentCompletedMatchLimit ?? mode.defaultRecentCompletedMatchLimit
    }
}

struct AIExportPacket: Codable, Hashable, Sendable {
    var metadata: AIExportMetadata
    var usageGuide: AIUsageGuide
    var entrantIndex: AIEntrantIndex
    var matchIndex: AIMatchIndex
    var frontier: AIFrontier
    var compressedHistory: AICompressedHistory
    var entrants: [AIEntrantRow]
    var standings: [AIStandingRow]
    var players: [AIPlayerRow]
    var phaseGroups: [AIPhaseGroupRow]
    var routes: [AIPlayerRouteRow]
}

struct AIExportMetadata: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var generatedAt: String
    var source: ExportSource
    var exportMode: String
    var exportModeDescription: String
    var eventName: String?
    var tournamentName: String?
    var videogameName: String?
    var summary: ExportSummary
    var notes: [String]
}

struct AIExportManifestFile: Codable, Hashable, Sendable {
    var path: String
    var description: String
    var records: Int?
}

struct AIUsageGuide: Codable, Hashable, Sendable {
    var purpose: String
    var targetPlayerWorkflow: [String]
    var filePriority: [String]
    var caveats: [String]
}

struct AIEntrantIndex: Codable, Hashable, Sendable {
    var byId: [String: Int]
    var nameSearch: [AINameSearchRow]
}

struct AINameSearchRow: Codable, Hashable, Sendable {
    var entrantId: FlexibleID
    var name: String?
    var normalizedName: String
    var aliases: [String]
    var tokens: [String]
    var seed: Int?
    var standingPlacement: Int?
}

struct AIMatchIndex: Codable, Hashable, Sendable {
    var byId: [String: AIMatchIndexRow]
    var byEntrantId: [String: [FlexibleID]]
    var pendingByEntrantId: [String: [FlexibleID]]
    var completedByEntrantId: [String: [FlexibleID]]
}

struct AIMatchIndexRow: Codable, Hashable, Sendable {
    var setId: FlexibleID
    var phaseName: String?
    var phaseGroupLabel: String?
    var roundText: String?
    var stateLabel: String
    var entrantIds: [FlexibleID]
    var winnerId: FlexibleID?
}

struct AIFrontier: Codable, Hashable, Sendable {
    var activeEntrantIds: [FlexibleID]
    var pendingMatchIds: [FlexibleID]
    var activeMatchIds: [FlexibleID]
    var phaseGroupsWithPending: [AIPhaseGroupFrontier]
}

struct AIPhaseGroupFrontier: Codable, Hashable, Sendable {
    var phaseId: FlexibleID
    var phaseName: String?
    var phaseGroupId: FlexibleID
    var phaseGroupLabel: String?
    var pendingSetIds: [FlexibleID]
    var entrantIds: [FlexibleID]
}

struct AICompressedHistory: Codable, Hashable, Sendable {
    var byEntrantId: [String: AIPlayerHistorySummary]
}

struct AIPlayerHistorySummary: Codable, Hashable, Sendable {
    var entrantId: FlexibleID
    var wins: Int
    var losses: Int
    var completedSetCount: Int
    var lastCompletedSetId: FlexibleID?
    var lastCompletedPhaseName: String?
    var lastCompletedRoundText: String?
    var recentCompletedMatches: [AIPlayerMatchRef]
}

struct AIEntrantRow: Codable, Hashable, Sendable {
    var entrantId: FlexibleID
    var name: String?
    var seed: Int?
    var participantTags: [String]
    var prefixes: [String]
    var standingPlacement: Int?
}

struct AIStandingRow: Codable, Hashable, Sendable {
    var placement: Int?
    var entrantId: FlexibleID?
    var entrantName: String?
    var seed: Int?
}

struct AIMatchRow: Codable, Hashable, Sendable {
    var setId: FlexibleID
    var phaseId: FlexibleID
    var phaseName: String?
    var phaseIndex: Int
    var phaseGroupId: FlexibleID?
    var phaseGroupLabel: String?
    var setIdentifier: String?
    var round: Int?
    var roundText: String?
    var state: Int?
    var stateLabel: String
    var displayScore: String?
    var winnerId: FlexibleID?
    var winnerName: String?
    var loserId: FlexibleID?
    var loserName: String?
    var completedAt: Int?
    var startedAt: Int?
    var updatedAt: Int?
    var player1: AIMatchSlot?
    var player2: AIMatchSlot?
    var slots: [AIMatchSlot]
}

struct AIMatchSlot: Codable, Hashable, Sendable {
    var slotIndex: Int
    var entrantId: FlexibleID?
    var entrantName: String?
    var seed: Int?
    var score: Double?
    var placement: Int?
    var result: String
}

struct AIPlayerRow: Codable, Hashable, Sendable {
    var entrantId: FlexibleID
    var name: String?
    var seed: Int?
    var participantTags: [String]
    var standingPlacement: Int?
    var status: String
    var statusNote: String
    var wins: Int
    var losses: Int
    var completedSetCount: Int
    var pendingSetCount: Int
    var activeSetCount: Int
    var latestPhaseName: String?
    var latestPhaseGroupLabel: String?
    var latestRoundText: String?
    var pendingMatches: [AIPlayerMatchRef]
    var completedMatches: [AIPlayerMatchRef]
}

struct AIPlayerMatchRef: Codable, Hashable, Sendable {
    var setId: FlexibleID
    var phaseName: String?
    var phaseGroupLabel: String?
    var roundText: String?
    var stateLabel: String
    var result: String
    var opponentIds: [FlexibleID]
    var opponentNames: [String]
    var displayScore: String?
}

struct AIPhaseGroupRow: Codable, Hashable, Sendable {
    var phaseId: FlexibleID
    var phaseName: String?
    var phaseIndex: Int
    var phaseGroupId: FlexibleID
    var phaseGroupLabel: String?
    var setCount: Int
    var completedSetCount: Int
    var pendingSetCount: Int
    var activeSetCount: Int
    var entrantCount: Int
    var entrantIds: [FlexibleID]
    var pendingSetIds: [FlexibleID]
}

struct AIPlayerRouteRow: Codable, Hashable, Sendable {
    var entrantId: FlexibleID
    var name: String?
    var seed: Int?
    var status: String
    var currentPhaseName: String?
    var currentPhaseGroupLabel: String?
    var currentRoundText: String?
    var currentSetId: FlexibleID?
    var pendingMatchIds: [FlexibleID]
    var knownPendingOpponents: [AIEntrantRef]
    var groupOpponentCandidates: [AIEntrantRef]
    var omittedGroupOpponentCandidateCount: Int
    var routeConfidence: String
    var routeNote: String
}

struct AIEntrantRef: Codable, Hashable, Sendable {
    var entrantId: FlexibleID
    var name: String?
    var seed: Int?
}

enum AIExportBuilder {
    static func build(from document: ExportDocument) -> AIExportPacket {
        buildResult(from: document).packet
    }

    static func build(from document: ExportDocument, options: AIExportOptions) -> AIExportPacket {
        buildResult(from: document, options: options).packet
    }

    static func normalizedMatches(from document: ExportDocument) -> [AIMatchRow] {
        matchRows(from: document)
    }

    static func normalizedMatches(from document: ExportDocument, options: AIExportOptions) -> [AIMatchRow] {
        buildResult(from: document, options: options).matches
    }

    private static func buildResult(
        from document: ExportDocument,
        options: AIExportOptions = AIExportOptions()
    ) -> (packet: AIExportPacket, matches: [AIMatchRow]) {
        let entrants = mergedEntrants(from: document)
        let standingsByEntrantId = standingsMap(from: document)
        let allEntrantRows = entrants.map { entrant in
            AIEntrantRow(
                entrantId: entrant.id,
                name: entrant.name,
                seed: entrant.initialSeedNum,
                participantTags: participantTags(for: entrant),
                prefixes: prefixes(for: entrant),
                standingPlacement: standingsByEntrantId[entrant.id]
            )
        }
        .sorted { sortEntrants($0, $1) }

        let allStandingRows = document.standings.map { standing in
            AIStandingRow(
                placement: standing.placement,
                entrantId: standing.entrant?.id,
                entrantName: standing.entrant?.name,
                seed: standing.entrant?.initialSeedNum
            )
        }
        .sorted { ($0.placement ?? Int.max) < ($1.placement ?? Int.max) }

        let allMatchRows = matchRows(from: document)
        let allPlayerRows = playerRows(entrants: entrants, standingsByEntrantId: standingsByEntrantId, matches: allMatchRows)
        let watchlistDocument = makeWatchlistDocument(from: document, options: options)
        let matchRows = filteredMatches(allMatchRows, players: allPlayerRows, options: options, watchlistDocument: watchlistDocument)
        let outputEntrantIds = includedEntrantIds(
            mode: options.mode,
            matches: matchRows,
            players: allPlayerRows,
            watchlistDocument: watchlistDocument
        )
        let entrantRows = filteredEntrants(allEntrantRows, includedIds: outputEntrantIds)
        let standingRows = filteredStandings(allStandingRows, includedIds: outputEntrantIds)
        let playerRows = filteredPlayers(allPlayerRows, options: options, includedIds: outputEntrantIds)
        let phaseGroupRows = filteredPhaseGroups(
            phaseGroupRows(from: document),
            matches: matchRows,
            mode: options.mode,
            includedIds: outputEntrantIds
        )
        let routes = routeRows(players: playerRows, phaseGroups: phaseGroupRows)
        let packet = AIExportPacket(
            metadata: metadata(from: document, options: options, watchlistDocument: watchlistDocument),
            usageGuide: usageGuide(options: options),
            entrantIndex: entrantIndex(entrants: entrantRows),
            matchIndex: matchIndex(matches: matchRows),
            frontier: frontier(players: playerRows, matches: matchRows, phaseGroups: phaseGroupRows),
            compressedHistory: compressedHistory(players: allPlayerRows, options: options, includedIds: outputEntrantIds),
            entrants: entrantRows,
            standings: standingRows,
            players: playerRows,
            phaseGroups: phaseGroupRows,
            routes: routes
        )

        return (packet, matchRows)
    }

    @discardableResult
    static func writePacket(
        document: ExportDocument,
        to folderURL: URL,
        options: AIExportOptions = AIExportOptions()
    ) throws -> [URL] {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let result = buildResult(from: document, options: options)
        let packet = result.packet
        var written: [URL] = []

        func write(_ data: Data, named filename: String) throws {
            let url = folderURL.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            written.append(url)
        }

        if options.mode == .full {
            try write(ExportService().encode(document), named: "raw.json")
        }
        try write(encodePacket(packet, options: options), named: "analysis.json")
        try write(encodeJSONLines(result.matches), named: "matches.jsonl")
        try write(Data(summaryMarkdown(from: packet).utf8), named: "summary.md")
        try write(Data(analysisPrompt(from: packet).utf8), named: "analysis-prompt.md")

        return written
    }

    static func encodePretty<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func encodeCompact<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func encodePacket(_ packet: AIExportPacket, options: AIExportOptions) throws -> Data {
        if options.mode == .full {
            return try encodePretty(packet)
        }
        return try encodeCompact(packet)
    }

    static func encodeJSONLines<T: Encodable>(_ values: [T]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let lines = try values.map { value -> String in
            let data = try encoder.encode(value)
            return String(decoding: data, as: UTF8.self)
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    static func summaryMarkdown(from packet: AIExportPacket) -> String {
        var lines: [String] = []
        lines.append("# \(packet.metadata.eventName ?? "start.gg Event") Analysis Summary")
        lines.append("")
        lines.append("- Generated: \(packet.metadata.generatedAt)")
        lines.append("- Source: \(packet.metadata.source.inputURL)")
        lines.append("- Output mode: \(packet.metadata.exportMode)")
        lines.append("- Entrants: \(packet.entrants.count)")
        lines.append("- Match rows in output: \(packet.matchIndex.byId.count)")
        lines.append("- Source matches: \(packet.metadata.summary.setCount)")
        lines.append("- Completed matches: \(packet.metadata.summary.completedSetCount)")
        lines.append("- Pending matches: \(packet.metadata.summary.pendingSetCount)")
        lines.append("- Frontier active entrants: \(packet.frontier.activeEntrantIds.count)")
        lines.append("")
        lines.append("## Files")
        lines.append("")
        for file in fileGuide(from: packet, matchRecordCount: packet.matchIndex.byId.count) {
            let count = file.records.map { " (\($0) records)" } ?? ""
            lines.append("- `\(file.path)`\(count): \(file.description)")
        }
        lines.append("")
        lines.append("## Active Players With Known Pending Matches")
        lines.append("")
        lines.append("| Player | Seed | Current Group | Pending | Known Opponents |")
        lines.append("|---|---:|---|---:|---|")
        for player in packet.players.filter({ !$0.pendingMatches.isEmpty }).prefix(40) {
            let route = packet.routes.first { $0.entrantId == player.entrantId }
            let opponents = route?.knownPendingOpponents.compactMap(\.name).joined(separator: ", ") ?? ""
            lines.append("| \(markdownCell(player.name ?? player.entrantId.value)) | \(player.seed.map(String.init) ?? "") | \(markdownCell(player.latestPhaseGroupLabel ?? "")) | \(player.pendingSetCount) | \(markdownCell(opponents)) |")
        }
        lines.append("")
        lines.append("For a target player, start with `entrantIndex.nameSearch`, then `players`, `matchIndex`, `frontier`, and `routes`. Use `matches.jsonl` only for detailed match rows.")
        return lines.joined(separator: "\n")
    }

    static func analysisPrompt(from packet: AIExportPacket) -> String {
        """
        You are analyzing a start.gg tournament export.

        Primary rule:
        Do not scan every match first. Resolve the requested player to entrantId, then follow the indices in analysis.json.

        Target-player workflow:
        1. Normalize the requested name by lowercasing, trimming spaces, folding width/diacritics, and removing punctuation if needed.
        2. Search analysis.json.entrantIndex.nameSearch. Prefer exact normalizedName or alias matches; if multiple plausible entrants remain, mention the ambiguity.
        3. Use the entrantId to read analysis.json.players for current status, wins/losses, pendingMatches, completedMatches, and latest phase/group.
        4. Use analysis.json.matchIndex.pendingByEntrantId[entrantId] for known next or active matches. Use matchIndex.byId for the compact match context.
        5. Use analysis.json.routes for route hints. Treat knownPendingOpponents as stronger than groupOpponentCandidates.
        6. Use analysis.json.frontier to understand what remains live in the tournament without reading unrelated completed matches.
        7. Use analysis.json.compressedHistory.byEntrantId[entrantId] for past results unless the user asks for detailed history.
        8. Open matches.jsonl only when you need full normalized match rows for specific setIds.
        9. Open raw.json only as a last resort when normalized data is insufficient.

        Important caveats:
        - Do not assume nationality from this export alone. If the user asks for Japanese players, use the user-provided list or explicitly state that nationality is inferred externally.
        - routeConfidence is usually partial because this export may not include start.gg prerequisite-slot graph edges.
        - For confirmed results, trust completedMatches in players or matches.jsonl rows where stateLabel is completed.
        - For future opponents, distinguish known pending opponents from broader groupOpponentCandidates.
        - Unrelated completed matches are intentionally compressed. Do not expand them unless the user asks.
        - raw.json is included only in Full mode. In lightweight modes, do not assume raw fallback is available.

        Event: \(packet.metadata.eventName ?? "unknown")
        Output mode: \(packet.metadata.exportMode)
        Output mode note: \(packet.metadata.exportModeDescription)
        Source: \(packet.metadata.source.inputURL)
        Generated: \(packet.metadata.generatedAt)
        """
    }

    private static func fileGuide(from packet: AIExportPacket, matchRecordCount: Int) -> [AIExportManifestFile] {
        var files = [
            AIExportManifestFile(path: "analysis.json", description: "Primary analysis packet with lookup indices, frontier, compressed history, players, phase groups, and routes.", records: nil),
            AIExportManifestFile(path: "matches.jsonl", description: "One normalized match per line for set-level drill-down. In lightweight modes this file is intentionally filtered.", records: matchRecordCount),
            AIExportManifestFile(path: "summary.md", description: "Human-readable overview for quick review.", records: nil),
            AIExportManifestFile(path: "analysis-prompt.md", description: "Optional guidance for structured review or follow-up analysis.", records: nil)
        ]
        if packet.metadata.exportMode == AIExportMode.full.title {
            files.append(AIExportManifestFile(path: "raw.json", description: "Original comprehensive export for fallback inspection.", records: nil))
        }
        return files
    }

    private static func metadata(
        from document: ExportDocument,
        options: AIExportOptions,
        watchlistDocument: WatchlistExportDocument?
    ) -> AIExportMetadata {
        var notes = [
            "analysis.json is optimized for target-player lookup. Use entrantIndex and matchIndex before scanning matches.jsonl.",
            "Full match rows are stored in matches.jsonl, not duplicated inside analysis.json.",
            "Routes are partial bracket-context hints. They do not include start.gg prerequisite-slot graph edges unless those are present in raw data.",
            "Player nationality is not inferred by this app."
        ]
        if options.mode != .full {
            notes.append("This lightweight export intentionally omits raw.json and scopes entrants, players, standings, routes, phase groups, and match details to the current output mode.")
        }
        if options.mode == .watchlistFocus {
            let matched = watchlistDocument?.summary.matchedEntrantCount ?? 0
            notes.append("Watchlist Focus matched \(matched) entrants from the current Watchlist text.")
        }

        return AIExportMetadata(
            schemaVersion: 3,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            source: document.source,
            exportMode: options.mode.title,
            exportModeDescription: options.mode.shortDescription,
            eventName: document.event.name,
            tournamentName: document.event.tournament?.name,
            videogameName: document.event.videogame?.name,
            summary: document.summary,
            notes: notes
        )
    }

    private static func usageGuide(options: AIExportOptions) -> AIUsageGuide {
        var filePriority = ["analysis.json", "matches.jsonl", "summary.md"]
        if options.mode == .full {
            filePriority.append("raw.json")
        }
        var workflow = [
            "Find the entrantId via entrantIndex.nameSearch.",
            "Read players for current status, record, latest location, and compact match references.",
            "Use matchIndex.pendingByEntrantId and matchIndex.completedByEntrantId to jump to relevant setIds.",
            "Use routes for known pending opponents and broader same-group candidates.",
            "Use frontier for live tournament context.",
            "Use compressedHistory for past results unless detailed per-set history is requested.",
            "Use matches.jsonl for specific setIds."
        ]
        if options.mode == .full {
            workflow.append("Use raw.json only as fallback.")
        }

        return AIUsageGuide(
            purpose: "Answer player-status and route questions without scanning unrelated completed matches first.",
            targetPlayerWorkflow: workflow,
            filePriority: filePriority,
            caveats: [
                "Nationality is not inferred.",
                "groupOpponentCandidates are not confirmed future opponents.",
                "routeConfidence is partial unless explicit bracket graph edges are available.",
                "raw.json is present only in Full mode."
            ]
        )
    }

    private static func entrantIndex(entrants: [AIEntrantRow]) -> AIEntrantIndex {
        var byId: [String: Int] = [:]
        var nameRows: [AINameSearchRow] = []
        for (index, entrant) in entrants.enumerated() {
            byId[entrant.entrantId.value] = index
            let aliases = Array(Set(([entrant.name].compactMap { $0 } + entrant.participantTags + entrant.prefixes))).sorted()
            let searchText = aliases.joined(separator: " ")
            nameRows.append(
                AINameSearchRow(
                    entrantId: entrant.entrantId,
                    name: entrant.name,
                    normalizedName: normalize(entrant.name ?? entrant.entrantId.value),
                    aliases: aliases,
                    tokens: tokens(from: searchText),
                    seed: entrant.seed,
                    standingPlacement: entrant.standingPlacement
                )
            )
        }
        return AIEntrantIndex(byId: byId, nameSearch: nameRows)
    }

    private static func matchIndex(matches: [AIMatchRow]) -> AIMatchIndex {
        var byId: [String: AIMatchIndexRow] = [:]
        var byEntrantId: [String: [FlexibleID]] = [:]
        var pendingByEntrantId: [String: [FlexibleID]] = [:]
        var completedByEntrantId: [String: [FlexibleID]] = [:]

        for match in matches {
            let entrantIds = match.slots.compactMap(\.entrantId)
            byId[match.setId.value] = AIMatchIndexRow(
                setId: match.setId,
                phaseName: match.phaseName,
                phaseGroupLabel: match.phaseGroupLabel,
                roundText: match.roundText,
                stateLabel: match.stateLabel,
                entrantIds: entrantIds,
                winnerId: match.winnerId
            )
            for entrantId in entrantIds {
                byEntrantId[entrantId.value, default: []].append(match.setId)
                if match.stateLabel == "completed" {
                    completedByEntrantId[entrantId.value, default: []].append(match.setId)
                } else {
                    pendingByEntrantId[entrantId.value, default: []].append(match.setId)
                }
            }
        }

        return AIMatchIndex(
            byId: byId,
            byEntrantId: byEntrantId,
            pendingByEntrantId: pendingByEntrantId,
            completedByEntrantId: completedByEntrantId
        )
    }

    private static func frontier(
        players: [AIPlayerRow],
        matches: [AIMatchRow],
        phaseGroups: [AIPhaseGroupRow]
    ) -> AIFrontier {
        let activeEntrantIds = players
            .filter { $0.status == "active" }
            .map(\.entrantId)
        let pendingMatches = matches
            .filter { $0.stateLabel == "pending" }
            .map(\.setId)
        let activeMatches = matches
            .filter { $0.stateLabel == "started" || $0.stateLabel == "called" }
            .map(\.setId)
        let groups = phaseGroups
            .filter { !$0.pendingSetIds.isEmpty }
            .map {
                AIPhaseGroupFrontier(
                    phaseId: $0.phaseId,
                    phaseName: $0.phaseName,
                    phaseGroupId: $0.phaseGroupId,
                    phaseGroupLabel: $0.phaseGroupLabel,
                    pendingSetIds: $0.pendingSetIds,
                    entrantIds: $0.entrantIds
                )
            }

        return AIFrontier(
            activeEntrantIds: activeEntrantIds,
            pendingMatchIds: pendingMatches,
            activeMatchIds: activeMatches,
            phaseGroupsWithPending: groups
        )
    }

    private static func compressedHistory(
        players: [AIPlayerRow],
        options: AIExportOptions,
        includedIds: Set<FlexibleID>?
    ) -> AICompressedHistory {
        let scopedPlayers = players.filter { player in
            guard let includedIds else {
                return true
            }
            return includedIds.contains(player.entrantId)
        }
        let rows = scopedPlayers.map { player in
            let lastCompleted = player.completedMatches.last
            return (
                player.entrantId.value,
                AIPlayerHistorySummary(
                    entrantId: player.entrantId,
                    wins: player.wins,
                    losses: player.losses,
                    completedSetCount: player.completedSetCount,
                    lastCompletedSetId: lastCompleted?.setId,
                    lastCompletedPhaseName: lastCompleted?.phaseName,
                    lastCompletedRoundText: lastCompleted?.roundText,
                    recentCompletedMatches: recentCompletedMatches(for: player, limit: options.recentCompletedMatchLimit)
                )
            )
        }
        return AICompressedHistory(byEntrantId: Dictionary(uniqueKeysWithValues: rows))
    }

    private static func makeWatchlistDocument(
        from document: ExportDocument,
        options: AIExportOptions
    ) -> WatchlistExportDocument? {
        guard options.mode == .watchlistFocus else {
            return nil
        }
        let trimmed = options.watchlistText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return WatchlistScopeBuilder.build(from: document, watchlistText: trimmed, excludedText: options.excludedWatchlistText)
    }

    private static func filteredMatches(
        _ matches: [AIMatchRow],
        players: [AIPlayerRow],
        options: AIExportOptions,
        watchlistDocument: WatchlistExportDocument?
    ) -> [AIMatchRow] {
        switch options.mode {
        case .full:
            return matches
        case .liveFocus:
            let activeRecentIds = Set(
                players
                    .filter { $0.status == "active" }
                    .flatMap { recentCompletedMatches(for: $0, limit: options.recentCompletedMatchLimit).map(\.setId) }
            )
            return matches.filter { !isCompleted($0) || activeRecentIds.contains($0.setId) }
        case .compact:
            return matches.filter { !isCompleted($0) }
        case .watchlistFocus:
            let watchedIds = watchlistEntrantIds(from: watchlistDocument)
            guard !watchedIds.isEmpty else {
                return matches.filter { !isCompleted($0) }
            }
            let watchedRecentIds = Set(
                players
                    .filter { watchedIds.contains($0.entrantId) }
                    .flatMap { recentCompletedMatches(for: $0, limit: options.recentCompletedMatchLimit).map(\.setId) }
            )
            return matches.filter { match in
                let containsWatchedEntrant = match.slots.contains { slot in
                    slot.entrantId.map { watchedIds.contains($0) } ?? false
                }
                guard containsWatchedEntrant else {
                    return false
                }
                return !isCompleted(match) || watchedRecentIds.contains(match.setId)
            }
        }
    }

    private static func includedEntrantIds(
        mode: AIExportMode,
        matches: [AIMatchRow],
        players: [AIPlayerRow],
        watchlistDocument: WatchlistExportDocument?
    ) -> Set<FlexibleID>? {
        if mode == .full {
            return nil
        }

        var ids = Set(matches.flatMap { match in match.slots.compactMap(\.entrantId) })
        if mode == .watchlistFocus {
            ids.formUnion(watchlistEntrantIds(from: watchlistDocument))
        }
        if ids.isEmpty {
            ids.formUnion(players.filter { $0.status == "active" }.map(\.entrantId))
        }
        return ids
    }

    private static func filteredEntrants(
        _ entrants: [AIEntrantRow],
        includedIds: Set<FlexibleID>?
    ) -> [AIEntrantRow] {
        guard let includedIds else {
            return entrants
        }
        return entrants.filter { includedIds.contains($0.entrantId) }
    }

    private static func filteredStandings(
        _ standings: [AIStandingRow],
        includedIds: Set<FlexibleID>?
    ) -> [AIStandingRow] {
        guard let includedIds else {
            return standings
        }
        return standings.filter { row in
            row.entrantId.map { includedIds.contains($0) } ?? false
        }
    }

    private static func filteredPlayers(
        _ players: [AIPlayerRow],
        options: AIExportOptions,
        includedIds: Set<FlexibleID>?
    ) -> [AIPlayerRow] {
        players.compactMap { player in
            if let includedIds, !includedIds.contains(player.entrantId) {
                return nil
            }
            var output = player
            switch options.mode {
            case .full:
                break
            case .liveFocus:
                output.completedMatches = player.status == "active"
                    ? recentCompletedMatches(for: player, limit: options.recentCompletedMatchLimit)
                    : []
            case .compact:
                output.completedMatches = []
            case .watchlistFocus:
                output.completedMatches = recentCompletedMatches(for: player, limit: options.recentCompletedMatchLimit)
            }
            return output
        }
    }

    private static func filteredPhaseGroups(
        _ phaseGroups: [AIPhaseGroupRow],
        matches: [AIMatchRow],
        mode: AIExportMode,
        includedIds: Set<FlexibleID>?
    ) -> [AIPhaseGroupRow] {
        guard mode != .full else {
            return phaseGroups
        }
        let includedMatchIds = Set(matches.map(\.setId))
        let keys = Set(matches.compactMap { match -> PhaseGroupKey? in
            guard let phaseGroupId = match.phaseGroupId else {
                return nil
            }
            return PhaseGroupKey(phaseId: match.phaseId, groupId: phaseGroupId, label: match.phaseGroupLabel)
        })
        return phaseGroups.compactMap { row in
            guard keys.contains(PhaseGroupKey(phaseId: row.phaseId, groupId: row.phaseGroupId, label: row.phaseGroupLabel)) else {
                return nil
            }
            var scoped = row
            if let includedIds {
                scoped.entrantIds = row.entrantIds.filter { includedIds.contains($0) }
                scoped.entrantCount = scoped.entrantIds.count
            }
            scoped.pendingSetIds = row.pendingSetIds.filter { includedMatchIds.contains($0) }
            return scoped
        }
    }

    private static func watchlistEntrantIds(from document: WatchlistExportDocument?) -> Set<FlexibleID> {
        guard let document else {
            return []
        }
        return Set(document.queries.flatMap { query in
            query.matches.map { $0.entrant.id }
        })
    }

    private static func recentCompletedMatches(for player: AIPlayerRow, limit: Int) -> [AIPlayerMatchRef] {
        guard limit > 0 else {
            return []
        }
        if limit == Int.max {
            return player.completedMatches
        }
        return Array(player.completedMatches.suffix(limit))
    }

    private static func isCompleted(_ match: AIMatchRow) -> Bool {
        match.stateLabel == "completed"
    }

    private static func matchRows(from document: ExportDocument) -> [AIMatchRow] {
        document.phases.enumerated().flatMap { phaseIndex, phase in
            phase.sets.map { set in
                let slots = set.slots.enumerated().map { index, slot in
                    AIMatchSlot(
                        slotIndex: index,
                        entrantId: slot.entrant?.id,
                        entrantName: slot.entrant?.name,
                        seed: slot.entrant?.initialSeedNum,
                        score: score(for: slot),
                        placement: slot.standing?.placement,
                        result: slotResult(slot: slot, set: set)
                    )
                }
                let winner = slots.first { $0.entrantId == set.winnerId }
                let loser = StartGGSetState.isCompleted(set.state) ? slots.first { $0.entrantId != nil && $0.entrantId != set.winnerId } : nil
                return AIMatchRow(
                    setId: set.id,
                    phaseId: phase.id,
                    phaseName: phase.name,
                    phaseIndex: phaseIndex,
                    phaseGroupId: set.phaseGroup?.id,
                    phaseGroupLabel: set.phaseGroup?.displayIdentifier,
                    setIdentifier: set.identifier,
                    round: set.round,
                    roundText: set.fullRoundText,
                    state: set.state,
                    stateLabel: set.stateLabel,
                    displayScore: set.displayScore,
                    winnerId: set.winnerId,
                    winnerName: winner?.entrantName,
                    loserId: loser?.entrantId,
                    loserName: loser?.entrantName,
                    completedAt: set.completedAt,
                    startedAt: set.startedAt,
                    updatedAt: set.updatedAt,
                    player1: slots.first,
                    player2: slots.dropFirst().first,
                    slots: slots
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.phaseIndex == rhs.phaseIndex {
                if (lhs.phaseGroupLabel ?? "") == (rhs.phaseGroupLabel ?? "") {
                    return (lhs.round ?? 0, lhs.setIdentifier ?? lhs.setId.value) < (rhs.round ?? 0, rhs.setIdentifier ?? rhs.setId.value)
                }
                return (lhs.phaseGroupLabel ?? "") < (rhs.phaseGroupLabel ?? "")
            }
            return lhs.phaseIndex < rhs.phaseIndex
        }
    }

    private static func playerRows(
        entrants: [Entrant],
        standingsByEntrantId: [FlexibleID: Int],
        matches: [AIMatchRow]
    ) -> [AIPlayerRow] {
        entrants.map { entrant in
            let refs = matches.compactMap { match -> AIPlayerMatchRef? in
                guard match.slots.contains(where: { $0.entrantId == entrant.id }) else {
                    return nil
                }
                return playerMatchRef(for: entrant.id, match: match)
            }
            let completed = refs.filter { $0.stateLabel == "completed" }
            let pending = refs.filter { $0.stateLabel != "completed" }
            let wins = completed.filter { $0.result == "win" }.count
            let losses = completed.filter { $0.result == "loss" }.count
            let active = refs.filter { $0.stateLabel == "started" || $0.stateLabel == "called" }.count
            let latest = refs.last
            let status: String
            let note: String
            if !pending.isEmpty || active > 0 {
                status = "active"
                note = "Has pending or active matches in fetched data."
            } else if !completed.isEmpty, standingsByEntrantId[entrant.id] != nil || losses > 0 {
                status = "eliminated_or_finished"
                note = "No pending match was found; this can mean eliminated, finished, or not yet represented in fetched pending data."
            } else {
                status = "unknown"
                note = "No reliable active/eliminated signal was found."
            }

            return AIPlayerRow(
                entrantId: entrant.id,
                name: entrant.name,
                seed: entrant.initialSeedNum,
                participantTags: participantTags(for: entrant),
                standingPlacement: standingsByEntrantId[entrant.id],
                status: status,
                statusNote: note,
                wins: wins,
                losses: losses,
                completedSetCount: completed.count,
                pendingSetCount: pending.filter { $0.stateLabel == "pending" }.count,
                activeSetCount: active,
                latestPhaseName: latest?.phaseName,
                latestPhaseGroupLabel: latest?.phaseGroupLabel,
                latestRoundText: latest?.roundText,
                pendingMatches: pending,
                completedMatches: completed
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.seed, rhs.seed) {
            case let (.some(lhsSeed), .some(rhsSeed)):
                return lhsSeed < rhsSeed
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return (lhs.name ?? lhs.entrantId.value) < (rhs.name ?? rhs.entrantId.value)
            }
        }
    }

    private static func playerMatchRef(for entrantId: FlexibleID, match: AIMatchRow) -> AIPlayerMatchRef {
        let slot = match.slots.first { $0.entrantId == entrantId }
        let opponents = match.slots.filter { $0.entrantId != nil && $0.entrantId != entrantId }
        return AIPlayerMatchRef(
            setId: match.setId,
            phaseName: match.phaseName,
            phaseGroupLabel: match.phaseGroupLabel,
            roundText: match.roundText,
            stateLabel: match.stateLabel,
            result: slot?.result ?? "unknown",
            opponentIds: opponents.compactMap(\.entrantId),
            opponentNames: opponents.compactMap(\.entrantName),
            displayScore: match.displayScore
        )
    }

    private static func phaseGroupRows(from document: ExportDocument) -> [AIPhaseGroupRow] {
        var groups: [PhaseGroupKey: [ExportSet]] = [:]
        var phaseLookup: [FlexibleID: (Int, PhaseExport)] = [:]

        for (phaseIndex, phase) in document.phases.enumerated() {
            phaseLookup[phase.id] = (phaseIndex, phase)
            for set in phase.sets {
                guard let group = set.phaseGroup else {
                    continue
                }
                groups[PhaseGroupKey(phaseId: phase.id, groupId: group.id, label: group.displayIdentifier), default: []].append(set)
            }
        }

        return groups.map { key, sets in
            let phase = phaseLookup[key.phaseId]
            let entrantIds = Set(sets.flatMap { set in set.slots.compactMap { $0.entrant?.id } })
            return AIPhaseGroupRow(
                phaseId: key.phaseId,
                phaseName: phase?.1.name,
                phaseIndex: phase?.0 ?? 0,
                phaseGroupId: key.groupId,
                phaseGroupLabel: key.label,
                setCount: sets.count,
                completedSetCount: sets.filter { StartGGSetState.isCompleted($0.state) }.count,
                pendingSetCount: sets.filter { StartGGSetState.isPending($0.state) }.count,
                activeSetCount: sets.filter { StartGGSetState.isActive($0.state) }.count,
                entrantCount: entrantIds.count,
                entrantIds: entrantIds.sorted { $0.value < $1.value },
                pendingSetIds: sets.filter { !StartGGSetState.isCompleted($0.state) }.map(\.id)
            )
        }
        .sorted { lhs, rhs in
            if lhs.phaseIndex == rhs.phaseIndex {
                return (lhs.phaseGroupLabel ?? lhs.phaseGroupId.value) < (rhs.phaseGroupLabel ?? rhs.phaseGroupId.value)
            }
            return lhs.phaseIndex < rhs.phaseIndex
        }
    }

    private static func routeRows(players: [AIPlayerRow], phaseGroups: [AIPhaseGroupRow]) -> [AIPlayerRouteRow] {
        let playerLookup = Dictionary(uniqueKeysWithValues: players.map { ($0.entrantId, $0) })
        return players.map { player in
            let current = player.pendingMatches.first ?? player.completedMatches.last
            let currentGroup = phaseGroups.first {
                $0.phaseGroupLabel == current?.phaseGroupLabel && $0.phaseName == current?.phaseName
            }
            let groupCandidates = currentGroup?.entrantIds
                .filter { $0 != player.entrantId }
                .compactMap { playerLookup[$0] }
                .sorted { lhs, rhs in (lhs.seed ?? Int.max, lhs.name ?? "") < (rhs.seed ?? Int.max, rhs.name ?? "") }
                .map { AIEntrantRef(entrantId: $0.entrantId, name: $0.name, seed: $0.seed) } ?? []
            let knownOpponents = player.pendingMatches.flatMap { match in
                zip(match.opponentIds, match.opponentNames).map { id, name in
                    AIEntrantRef(entrantId: id, name: name, seed: playerLookup[id]?.seed)
                }
            }
            let confidence = player.pendingMatches.isEmpty ? "low" : "partial"
            let note = player.pendingMatches.isEmpty
                ? "No known pending set contains this player in fetched data."
                : "Known pending opponents come from set slots. Broader candidates are same phase group entrants, not guaranteed bracket-path opponents."

            return AIPlayerRouteRow(
                entrantId: player.entrantId,
                name: player.name,
                seed: player.seed,
                status: player.status,
                currentPhaseName: current?.phaseName,
                currentPhaseGroupLabel: current?.phaseGroupLabel,
                currentRoundText: current?.roundText,
                currentSetId: current?.setId,
                pendingMatchIds: player.pendingMatches.map(\.setId),
                knownPendingOpponents: Array(knownOpponents.prefix(8)),
                groupOpponentCandidates: Array(groupCandidates.prefix(16)),
                omittedGroupOpponentCandidateCount: max(0, groupCandidates.count - 16),
                routeConfidence: confidence,
                routeNote: note
            )
        }
    }

    private static func mergedEntrants(from document: ExportDocument) -> [Entrant] {
        var byId: [FlexibleID: Entrant] = [:]
        for entrant in document.entrants {
            byId[entrant.id] = merge(existing: byId[entrant.id], incoming: entrant)
        }
        for standing in document.standings {
            if let entrant = standing.entrant {
                byId[entrant.id] = merge(existing: byId[entrant.id], incoming: entrant)
            }
        }
        for phase in document.phases {
            for set in phase.sets {
                for slot in set.slots {
                    if let entrant = slot.entrant {
                        byId[entrant.id] = merge(existing: byId[entrant.id], incoming: entrant)
                    }
                }
            }
        }
        return Array(byId.values)
    }

    private static func merge(existing: Entrant?, incoming: Entrant) -> Entrant {
        guard let existing else {
            return incoming
        }
        return existing.mergingMissingFields(from: incoming)
    }

    private static func standingsMap(from document: ExportDocument) -> [FlexibleID: Int] {
        Dictionary(uniqueKeysWithValues: document.standings.compactMap { standing in
            guard let entrantId = standing.entrant?.id, let placement = standing.placement else {
                return nil
            }
            return (entrantId, placement)
        })
    }

    private static func slotResult(slot: SetSlot, set: ExportSet) -> String {
        guard let entrantId = slot.entrant?.id else {
            return "empty"
        }
        if StartGGSetState.isCompleted(set.state), let winnerId = set.winnerId {
            return winnerId == entrantId ? "win" : "loss"
        }
        if StartGGSetState.isPending(set.state) {
            return "pending"
        }
        if StartGGSetState.isActive(set.state) {
            return "active"
        }
        return "unknown"
    }

    private static func score(for slot: SetSlot) -> Double? {
        slot.standing?.stats?.score?.value?.value
    }

    private static func participantTags(for entrant: Entrant) -> [String] {
        let tags = (entrant.participants ?? []).flatMap { participant -> [String] in
            [participant.gamerTag, participant.player?.gamerTag].compactMap { $0 }
        }
        return Array(Set(tags)).sorted()
    }

    private static func prefixes(for entrant: Entrant) -> [String] {
        let prefixes = (entrant.participants ?? []).flatMap { participant -> [String] in
            [participant.prefix, participant.player?.prefix].compactMap { $0 }.filter { !$0.isEmpty }
        }
        return Array(Set(prefixes)).sorted()
    }

    private static func sortEntrants(_ lhs: AIEntrantRow, _ rhs: AIEntrantRow) -> Bool {
        switch (lhs.seed, rhs.seed) {
        case let (.some(lhsSeed), .some(rhsSeed)):
            return lhsSeed < rhsSeed
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return (lhs.name ?? lhs.entrantId.value) < (rhs.name ?? rhs.entrantId.value)
        }
    }

    private static func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func tokens(from value: String) -> [String] {
        let normalized = normalize(value)
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = normalized
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(tokens)).sorted()
    }
}

private struct PhaseGroupKey: Hashable {
    var phaseId: FlexibleID
    var groupId: FlexibleID
    var label: String?
}

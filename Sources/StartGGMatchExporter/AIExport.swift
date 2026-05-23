import Foundation

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

    static func normalizedMatches(from document: ExportDocument) -> [AIMatchRow] {
        matchRows(from: document)
    }

    private static func buildResult(from document: ExportDocument) -> (packet: AIExportPacket, matches: [AIMatchRow]) {
        let entrants = mergedEntrants(from: document)
        let standingsByEntrantId = standingsMap(from: document)
        let entrantRows = entrants.map { entrant in
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

        let standingRows = document.standings.map { standing in
            AIStandingRow(
                placement: standing.placement,
                entrantId: standing.entrant?.id,
                entrantName: standing.entrant?.name,
                seed: standing.entrant?.initialSeedNum
            )
        }
        .sorted { ($0.placement ?? Int.max) < ($1.placement ?? Int.max) }

        let matchRows = matchRows(from: document)
        let playerRows = playerRows(entrants: entrants, standingsByEntrantId: standingsByEntrantId, matches: matchRows)
        let phaseGroupRows = phaseGroupRows(from: document)
        let routes = routeRows(players: playerRows, phaseGroups: phaseGroupRows)
        let packet = AIExportPacket(
            metadata: metadata(from: document),
            usageGuide: usageGuide(),
            entrantIndex: entrantIndex(entrants: entrantRows),
            matchIndex: matchIndex(matches: matchRows),
            frontier: frontier(players: playerRows, matches: matchRows, phaseGroups: phaseGroupRows),
            compressedHistory: compressedHistory(players: playerRows),
            entrants: entrantRows,
            standings: standingRows,
            players: playerRows,
            phaseGroups: phaseGroupRows,
            routes: routes
        )

        return (packet, matchRows)
    }

    @discardableResult
    static func writePacket(document: ExportDocument, to folderURL: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let result = buildResult(from: document)
        let packet = result.packet
        var written: [URL] = []

        func write(_ data: Data, named filename: String) throws {
            let url = folderURL.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            written.append(url)
        }

        try write(ExportService().encode(document), named: "raw.json")
        try write(encodePretty(packet), named: "analysis.json")
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
        lines.append("- Entrants: \(packet.entrants.count)")
        lines.append("- Matches: \(packet.metadata.summary.setCount)")
        lines.append("- Completed matches: \(packet.metadata.summary.completedSetCount)")
        lines.append("- Pending matches: \(packet.metadata.summary.pendingSetCount)")
        lines.append("- Frontier active entrants: \(packet.frontier.activeEntrantIds.count)")
        lines.append("")
        lines.append("## Files")
        lines.append("")
        for file in fileGuide(from: packet) {
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
        - raw.json is included as a fallback for missing fields, not as the primary analysis surface.

        Event: \(packet.metadata.eventName ?? "unknown")
        Source: \(packet.metadata.source.inputURL)
        Generated: \(packet.metadata.generatedAt)
        """
    }

    private static func fileGuide(from packet: AIExportPacket) -> [AIExportManifestFile] {
        [
            AIExportManifestFile(path: "analysis.json", description: "Primary target-agnostic analysis packet with lookup indices, frontier, compressed history, players, phase groups, and routes.", records: nil),
            AIExportManifestFile(path: "matches.jsonl", description: "One normalized match per line for set-level drill-down.", records: packet.metadata.summary.setCount),
            AIExportManifestFile(path: "summary.md", description: "Human-readable overview for quick review.", records: nil),
            AIExportManifestFile(path: "analysis-prompt.md", description: "Prompt guidance for an external AI assistant.", records: nil),
            AIExportManifestFile(path: "raw.json", description: "Original comprehensive export for fallback inspection.", records: nil)
        ]
    }

    private static func metadata(from document: ExportDocument) -> AIExportMetadata {
        AIExportMetadata(
            schemaVersion: 2,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            source: document.source,
            eventName: document.event.name,
            tournamentName: document.event.tournament?.name,
            videogameName: document.event.videogame?.name,
            summary: document.summary,
            notes: [
                "analysis.json is optimized for arbitrary target-player lookup. Use entrantIndex and matchIndex before scanning matches.jsonl.",
                "Full match rows are stored in matches.jsonl, not duplicated inside analysis.json.",
                "Routes are partial bracket-context hints. They do not include start.gg prerequisite-slot graph edges unless those are present in raw data.",
                "Player nationality is not inferred by this app."
            ]
        )
    }

    private static func usageGuide() -> AIUsageGuide {
        AIUsageGuide(
            purpose: "Help an external AI answer arbitrary player-status and route questions without scanning unrelated completed matches first.",
            targetPlayerWorkflow: [
                "Find the entrantId via entrantIndex.nameSearch.",
                "Read players for current status, record, latest location, and compact match references.",
                "Use matchIndex.pendingByEntrantId and matchIndex.completedByEntrantId to jump to relevant setIds.",
                "Use routes for known pending opponents and broader same-group candidates.",
                "Use frontier for live tournament context.",
                "Use compressedHistory for past results unless detailed per-set history is requested.",
                "Use matches.jsonl for specific setIds and raw.json only as fallback."
            ],
            filePriority: ["analysis.json", "matches.jsonl", "summary.md", "raw.json"],
            caveats: [
                "Nationality is not inferred.",
                "groupOpponentCandidates are not confirmed future opponents.",
                "routeConfidence is partial unless explicit bracket graph edges are available."
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

    private static func compressedHistory(players: [AIPlayerRow]) -> AICompressedHistory {
        let rows = players.map { player in
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
                    recentCompletedMatches: Array(player.completedMatches.suffix(3))
                )
            )
        }
        return AICompressedHistory(byEntrantId: Dictionary(uniqueKeysWithValues: rows))
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
                let loser = set.state == 3 ? slots.first { $0.entrantId != nil && $0.entrantId != set.winnerId } : nil
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
                completedSetCount: sets.filter { $0.state == 3 }.count,
                pendingSetCount: sets.filter { $0.state == 1 }.count,
                activeSetCount: sets.filter { $0.state == 2 || $0.state == 6 }.count,
                entrantCount: entrantIds.count,
                entrantIds: entrantIds.sorted { $0.value < $1.value },
                pendingSetIds: sets.filter { $0.state != 3 }.map(\.id)
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
        return Entrant(
            id: existing.id,
            name: existing.name ?? incoming.name,
            initialSeedNum: existing.initialSeedNum ?? incoming.initialSeedNum,
            participants: existing.participants?.isEmpty == false ? existing.participants : incoming.participants
        )
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
        if set.state == 3, let winnerId = set.winnerId {
            return winnerId == entrantId ? "win" : "loss"
        }
        if set.state == 1 {
            return "pending"
        }
        if set.state == 2 || set.state == 6 {
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

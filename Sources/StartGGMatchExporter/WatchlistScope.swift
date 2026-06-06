import Foundation

struct WatchlistPreview: Equatable {
    var queryCount: Int
    var matchedQueryCount: Int
    var matchedEntrantCount: Int
    var relatedSetCount: Int

    static let empty = WatchlistPreview(queryCount: 0, matchedQueryCount: 0, matchedEntrantCount: 0, relatedSetCount: 0)

    var summaryText: String {
        if queryCount == 0 {
            return "Paste one player name per line."
        }
        return "\(matchedQueryCount)/\(queryCount) matched, \(matchedEntrantCount) entrants, \(relatedSetCount) related sets"
    }
}

struct WatchlistExportDocument: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var generatedAt: String
    var source: ExportSource
    var event: EventSummary
    var summary: WatchlistSummary
    var queries: [WatchlistQueryResult]
}

struct WatchlistSummary: Codable, Hashable, Sendable {
    var queryCount: Int
    var matchedQueryCount: Int
    var unmatchedQueryCount: Int
    var matchedEntrantCount: Int
    var relatedSetCount: Int
    var completedRelatedSetCount: Int
    var pendingRelatedSetCount: Int
}

struct WatchlistQueryResult: Codable, Hashable, Sendable {
    var query: String
    var normalizedQuery: String
    var matches: [WatchlistEntrantReport]
}

struct WatchlistEntrantReport: Codable, Hashable, Sendable {
    var entrant: Entrant
    var matchReason: String
    var matchedValue: String
    var score: Int
    var standingPlacement: Int?
    var setCount: Int
    var completedSetCount: Int
    var wins: Int
    var losses: Int
    var pendingSetCount: Int
    var latestPhaseName: String?
    var latestPhaseGroup: PhaseGroupRef?
    var sets: [WatchlistSetContext]
}

struct WatchlistSetContext: Codable, Hashable, Sendable {
    var phaseId: FlexibleID
    var phaseName: String?
    var phaseIndex: Int
    var phaseGroup: PhaseGroupRef?
    var set: ExportSet
    var watchedEntrantId: FlexibleID
    var result: String
    var watchedScore: Double?
    var opponentScore: Double?
    var opponents: [Entrant]
}

enum WatchlistScopeBuilder {
    static func parseQueries(_ text: String) -> [String] {
        var seen = Set<String>()
        return text
            .components(separatedBy: .newlines)
            .flatMap { line in
                line.split(separator: ",").map(String.init)
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .filter { query in
                let normalized = normalize(query)
                guard !seen.contains(normalized) else {
                    return false
                }
                seen.insert(normalized)
                return true
            }
    }

    static func preview(for watchlistText: String, document: ExportDocument?) -> WatchlistPreview {
        let queries = parseQueries(watchlistText)
        guard let document, !queries.isEmpty else {
            return WatchlistPreview(queryCount: queries.count, matchedQueryCount: 0, matchedEntrantCount: 0, relatedSetCount: 0)
        }
        let export = build(from: document, watchlistText: watchlistText)
        return WatchlistPreview(
            queryCount: export.summary.queryCount,
            matchedQueryCount: export.summary.matchedQueryCount,
            matchedEntrantCount: export.summary.matchedEntrantCount,
            relatedSetCount: export.summary.relatedSetCount
        )
    }

    static func build(from document: ExportDocument, watchlistText: String) -> WatchlistExportDocument {
        let queries = parseQueries(watchlistText)
        let allEntrants = entrants(from: document)
        var standingsByEntrantId: [FlexibleID: Int] = [:]
        for standing in document.standings {
            if let entrantId = standing.entrant?.id {
                standingsByEntrantId[entrantId] = standing.placement
            }
        }

        let phaseContexts = document.phases.enumerated().map { index, phase in
            PhaseContext(index: index, phase: phase)
        }

        let results = queries.map { query -> WatchlistQueryResult in
            let matches = bestMatches(for: query, entrants: allEntrants)
            let reports = matches.map { match in
                report(
                    for: match,
                    phaseContexts: phaseContexts,
                    standingPlacement: standingsByEntrantId[match.entrant.id]
                )
            }
            return WatchlistQueryResult(query: query, normalizedQuery: normalize(query), matches: reports)
        }

        let uniqueEntrantIds = Set(results.flatMap { $0.matches.map(\.entrant.id) })
        let uniqueSets = Dictionary(
            grouping: results.flatMap { $0.matches.flatMap(\.sets) },
            by: { $0.set.id }
        )
        let uniqueSetContexts = uniqueSets.compactMap { $0.value.first }
        let matchedQueryCount = results.filter { !$0.matches.isEmpty }.count

        return WatchlistExportDocument(
            schemaVersion: 1,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            source: document.source,
            event: document.event,
            summary: WatchlistSummary(
                queryCount: queries.count,
                matchedQueryCount: matchedQueryCount,
                unmatchedQueryCount: queries.count - matchedQueryCount,
                matchedEntrantCount: uniqueEntrantIds.count,
                relatedSetCount: uniqueSetContexts.count,
                completedRelatedSetCount: uniqueSetContexts.filter { StartGGSetState.isCompleted($0.set.state) }.count,
                pendingRelatedSetCount: uniqueSetContexts.filter { !StartGGSetState.isCompleted($0.set.state) }.count
            ),
            queries: results
        )
    }

    static func encodeJSON(_ document: WatchlistExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    static func markdown(from document: WatchlistExportDocument) -> String {
        var lines: [String] = []
        lines.append("# \(document.event.name ?? "start.gg Event") Watchlist")
        lines.append("")
        lines.append("- Generated: \(document.generatedAt)")
        lines.append("- Source: \(document.source.inputURL)")
        lines.append("- Mode: \(document.source.apiMode)")
        lines.append("- Queries: \(document.summary.matchedQueryCount)/\(document.summary.queryCount) matched")
        lines.append("- Entrants: \(document.summary.matchedEntrantCount)")
        lines.append("- Related sets: \(document.summary.relatedSetCount)")
        lines.append("")

        for query in document.queries {
            lines.append("## \(query.query)")
            if query.matches.isEmpty {
                lines.append("")
                lines.append("No entrant matched.")
                lines.append("")
                continue
            }

            for report in query.matches {
                let name = report.entrant.name ?? report.entrant.id.value
                lines.append("")
                lines.append("### \(name)")
                lines.append("")
                lines.append("- Match: \(report.matchReason) (`\(report.matchedValue)`)")
                if let seed = report.entrant.initialSeedNum {
                    lines.append("- Seed: \(seed)")
                }
                if let placement = report.standingPlacement, placement > 0 {
                    lines.append("- Standing placement: \(placement)")
                }
                lines.append("- Record in fetched sets: \(report.wins)-\(report.losses)")
                lines.append("- Pending/active sets: \(report.pendingSetCount)")
                if let latestPhaseName = report.latestPhaseName {
                    let group = report.latestPhaseGroup?.displayIdentifier.map { " / \($0)" } ?? ""
                    lines.append("- Latest context: \(latestPhaseName)\(group)")
                }
                lines.append("")
                lines.append("| Phase | Group | Round | State | Result | Score | Opponent | Display |")
                lines.append("|---|---|---|---|---|---|---|---|")

                for context in report.sets {
                    let phase = markdownCell(context.phaseName ?? context.phaseId.value)
                    let group = markdownCell(context.phaseGroup?.displayIdentifier ?? "")
                    let round = markdownCell(context.set.fullRoundText ?? context.set.identifier ?? "")
                    let state = markdownCell(context.set.stateLabel)
                    let result = markdownCell(context.result)
                    let score = markdownCell(scoreText(watched: context.watchedScore, opponent: context.opponentScore))
                    let opponents = markdownCell(context.opponents.compactMap(\.name).joined(separator: ", "))
                    let display = markdownCell(context.set.displayScore ?? "")
                    lines.append("| \(phase) | \(group) | \(round) | \(state) | \(result) | \(score) | \(opponents) | \(display) |")
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func compact(_ value: String) -> String {
        normalize(value)
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func entrants(from document: ExportDocument) -> [Entrant] {
        var byId: [FlexibleID: Entrant] = [:]
        for entrant in document.entrants {
            byId[entrant.id] = entrant
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
        for standing in document.standings {
            if let entrant = standing.entrant {
                byId[entrant.id] = entrant
            }
        }
        return byId.values.sorted { ($0.name ?? $0.id.value) < ($1.name ?? $1.id.value) }
    }

    private static func merge(existing: Entrant?, incoming: Entrant) -> Entrant {
        guard let existing else {
            return incoming
        }
        if existing.participants?.isEmpty == false {
            return existing
        }
        return incoming.participants?.isEmpty == false ? incoming : existing
    }

    private static func bestMatches(for query: String, entrants: [Entrant]) -> [EntrantMatch] {
        let scored = entrants.compactMap { entrant -> EntrantMatch? in
            bestMatch(for: query, entrant: entrant)
        }
        let bestScore = scored.map(\.score).max() ?? 0
        let threshold = bestScore >= 95 ? 95 : 80
        return scored
            .filter { $0.score >= threshold }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return (lhs.entrant.name ?? lhs.entrant.id.value) < (rhs.entrant.name ?? rhs.entrant.id.value)
                }
                return lhs.score > rhs.score
            }
    }

    private static func bestMatch(for query: String, entrant: Entrant) -> EntrantMatch? {
        let normalizedQuery = normalize(query)
        let compactQuery = compact(query)
        guard !normalizedQuery.isEmpty else {
            return nil
        }

        let candidates = candidateValues(for: entrant)
        var best: EntrantMatch?

        for candidate in candidates {
            let normalizedCandidate = normalize(candidate)
            let compactCandidate = compact(candidate)
            let score: Int
            let reason: String

            if normalizedCandidate == normalizedQuery {
                score = 100
                reason = "exact"
            } else if compactCandidate == compactQuery {
                score = 98
                reason = "compact exact"
            } else if normalizedQuery.count > 3, normalizedCandidate.contains(normalizedQuery) {
                score = 86
                reason = "contains"
            } else if compactQuery.count > 3, compactCandidate.contains(compactQuery) {
                score = 84
                reason = "compact contains"
            } else {
                continue
            }

            let match = EntrantMatch(entrant: entrant, score: score, reason: reason, matchedValue: candidate)
            if best == nil || score > best!.score {
                best = match
            }
        }

        return best
    }

    private static func candidateValues(for entrant: Entrant) -> [String] {
        var values: [String] = []
        if let name = entrant.name {
            values.append(name)
            values.append(contentsOf: prefixCandidates(from: name))
        }
        for participant in entrant.participants ?? [] {
            if let gamerTag = participant.gamerTag {
                values.append(gamerTag)
                if let prefix = participant.prefix, !prefix.isEmpty {
                    values.append(prefix)
                    values.append("\(prefix) \(gamerTag)")
                    values.append("\(prefix) | \(gamerTag)")
                }
            }
            if let player = participant.player {
                if let gamerTag = player.gamerTag {
                    values.append(gamerTag)
                    if let prefix = player.prefix, !prefix.isEmpty {
                        values.append(prefix)
                        values.append("\(prefix) \(gamerTag)")
                        values.append("\(prefix) | \(gamerTag)")
                    }
                }
            }
        }
        return Array(Set(values))
    }

    private static func prefixCandidates(from name: String) -> [String] {
        for separator in [" | ", "｜"] {
            let parts = name.components(separatedBy: separator)
            if parts.count > 1 {
                let prefix = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                return prefix.isEmpty ? [] : [prefix]
            }
        }
        return []
    }

    private static func report(
        for match: EntrantMatch,
        phaseContexts: [PhaseContext],
        standingPlacement: Int?
    ) -> WatchlistEntrantReport {
        let setContexts = phaseContexts.flatMap { phaseContext in
            phaseContext.phase.sets.compactMap { set -> WatchlistSetContext? in
                guard set.slots.contains(where: { $0.entrant?.id == match.entrant.id }) else {
                    return nil
                }
                return context(for: match.entrant, set: set, phaseContext: phaseContext)
            }
        }

        let wins = setContexts.filter { $0.result == "win" }.count
        let losses = setContexts.filter { $0.result == "loss" }.count
        let pending = setContexts.filter { !StartGGSetState.isCompleted($0.set.state) }.count
        let latest = setContexts.sorted { lhs, rhs in
            if lhs.phaseIndex == rhs.phaseIndex {
                return (lhs.set.updatedAt ?? lhs.set.completedAt ?? lhs.set.startedAt ?? 0) < (rhs.set.updatedAt ?? rhs.set.completedAt ?? rhs.set.startedAt ?? 0)
            }
            return lhs.phaseIndex < rhs.phaseIndex
        }.last

        return WatchlistEntrantReport(
            entrant: match.entrant,
            matchReason: match.reason,
            matchedValue: match.matchedValue,
            score: match.score,
            standingPlacement: standingPlacement,
            setCount: setContexts.count,
            completedSetCount: setContexts.filter { StartGGSetState.isCompleted($0.set.state) }.count,
            wins: wins,
            losses: losses,
            pendingSetCount: pending,
            latestPhaseName: latest?.phaseName,
            latestPhaseGroup: latest?.phaseGroup,
            sets: setContexts
        )
    }

    private static func context(for entrant: Entrant, set: ExportSet, phaseContext: PhaseContext) -> WatchlistSetContext {
        let watchedSlot = set.slots.first { $0.entrant?.id == entrant.id }
        let opponentSlots = set.slots.filter { $0.entrant?.id != nil && $0.entrant?.id != entrant.id }
        let watchedScore = watchedSlot?.standing?.stats?.score?.value?.value
        let opponentScore = opponentSlots.compactMap { $0.standing?.stats?.score?.value?.value }.max()
        let result: String

        if StartGGSetState.isCompleted(set.state), let winnerId = set.winnerId {
            result = winnerId == entrant.id ? "win" : "loss"
        } else if StartGGSetState.isPending(set.state) {
            result = "pending"
        } else if StartGGSetState.isActive(set.state) {
            result = "active"
        } else {
            result = "unknown"
        }

        return WatchlistSetContext(
            phaseId: phaseContext.phase.id,
            phaseName: phaseContext.phase.name,
            phaseIndex: phaseContext.index,
            phaseGroup: set.phaseGroup,
            set: set,
            watchedEntrantId: entrant.id,
            result: result,
            watchedScore: watchedScore,
            opponentScore: opponentScore,
            opponents: opponentSlots.compactMap(\.entrant)
        )
    }

    private static func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func scoreText(watched: Double?, opponent: Double?) -> String {
        guard watched != nil || opponent != nil else {
            return ""
        }
        return "\(formatScore(watched))-\(formatScore(opponent))"
    }

    private static func formatScore(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }
}

private struct EntrantMatch: Hashable {
    var entrant: Entrant
    var score: Int
    var reason: String
    var matchedValue: String
}

private struct PhaseContext {
    var index: Int
    var phase: PhaseExport
}

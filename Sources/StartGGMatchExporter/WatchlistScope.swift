import Foundation

struct WatchlistPreview: Equatable, Sendable {
    var queryCount: Int
    var matchedQueryCount: Int
    var matchedEntrantCount: Int
    var relatedSetCount: Int
    var isResolved: Bool

    static let empty = WatchlistPreview(
        queryCount: 0,
        matchedQueryCount: 0,
        matchedEntrantCount: 0,
        relatedSetCount: 0,
        isResolved: false
    )

    static func draft(queryCount: Int) -> WatchlistPreview {
        WatchlistPreview(
            queryCount: queryCount,
            matchedQueryCount: 0,
            matchedEntrantCount: 0,
            relatedSetCount: 0,
            isResolved: false
        )
    }

    static func resolved(from document: WatchlistExportDocument) -> WatchlistPreview {
        WatchlistPreview(
            queryCount: document.summary.queryCount,
            matchedQueryCount: document.summary.matchedQueryCount,
            matchedEntrantCount: document.summary.matchedEntrantCount,
            relatedSetCount: document.summary.relatedSetCount,
            isResolved: true
        )
    }

    var summaryText: String {
        if queryCount == 0 {
            return "Paste one player name per line."
        }
        if !isResolved {
            let label = queryCount == 1 ? "entry" : "entries"
            return "\(queryCount) watchlist \(label) ready. Full counts update after fetch or save."
        }
        return "\(matchedQueryCount)/\(queryCount) matched, \(matchedEntrantCount) entrants, \(relatedSetCount) related sets"
    }
}

struct WatchlistOutputFilter: Codable, Hashable, Sendable {
    var includeLiving: Bool = true
    var includeEliminated: Bool = true
    var includeWinners: Bool = true
    var includeLosers: Bool = true

    var isEnabled: Bool {
        includeLiving || includeEliminated || includeWinners || includeLosers
    }

    static let allEnabled = WatchlistOutputFilter()
}

struct WatchlistExportDocument: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var generatedAt: String
    var source: ExportSource
    var event: EventSummary
    var summary: WatchlistSummary
    var exclusionQueries: [String]
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

    static func preview(
        for watchlistText: String,
        excludedText: String = "",
        document: ExportDocument?,
        filter: WatchlistOutputFilter = .allEnabled
    ) -> WatchlistPreview {
        let queries = parseQueries(watchlistText)
        guard let document, !queries.isEmpty else {
            return WatchlistPreview.draft(queryCount: queries.count)
        }
        let export = build(from: document, watchlistText: watchlistText, excludedText: excludedText, filter: filter)
        return WatchlistPreview.resolved(from: export)
    }

    static func draftPreview(for watchlistText: String) -> WatchlistPreview {
        WatchlistPreview.draft(queryCount: parseQueries(watchlistText).count)
    }

    static func build(
        from document: ExportDocument,
        watchlistText: String,
        excludedText: String = "",
        filter: WatchlistOutputFilter = .allEnabled
    ) -> WatchlistExportDocument {
        let queries = parseQueries(watchlistText)
        let exclusionQueries = parseQueries(excludedText)
        let allEntrants = entrants(from: document)
            .filter { !isExcluded($0, by: exclusionQueries) }
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

        let filteredResults = results.map { queryResult in
            WatchlistQueryResult(
                query: queryResult.query,
                normalizedQuery: queryResult.normalizedQuery,
                matches: queryResult.matches.filter { matchesFilter($0, using: filter) }
            )
        }

        let uniqueEntrantIds = Set(filteredResults.flatMap { $0.matches.map(\.entrant.id) })
        let uniqueSets = Dictionary(
            grouping: filteredResults.flatMap { $0.matches.flatMap(\.sets) },
            by: { $0.set.id }
        )
        let uniqueSetContexts = uniqueSets.compactMap { $0.value.first }
        let matchedQueryCount = filteredResults.filter { !$0.matches.isEmpty }.count

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
            exclusionQueries: exclusionQueries,
            queries: filteredResults
        )
    }

    static func encodeJSON(_ document: WatchlistExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    static func markdown(from document: WatchlistExportDocument) -> String {
        var lines: [String] = []
        lines.append("# \(document.event.name ?? "start.gg Event") 選手ウォッチレポート")
        lines.append("")
        appendTableOfContents(for: document, to: &lines)
        lines.append("")
        appendRecentCompletedMatchSummary(for: document, to: &lines)
        lines.append("")
        appendCurrentStatusSummary(for: document, to: &lines)
        lines.append("")
        lines.append("## 概要")
        lines.append("")
        lines.append("- 作成日時: \(document.generatedAt)")
        lines.append("- 対象URL: \(document.source.inputURL)")
        lines.append("- 取得モード: \(document.source.apiMode)")
        lines.append("- 検索一致: \(document.summary.matchedQueryCount)/\(document.summary.queryCount) 件")
        if !document.exclusionQueries.isEmpty {
            lines.append("- 除外ワード: \(document.exclusionQueries.joined(separator: ", "))")
        }
        lines.append("- 対象選手: \(document.summary.matchedEntrantCount) 名")
        lines.append("- 関連試合: \(document.summary.relatedSetCount) 件（終了 \(document.summary.completedRelatedSetCount) / 未完了 \(document.summary.pendingRelatedSetCount)）")
        lines.append("")

        for query in document.queries {
            lines.append("## 検索: \(query.query)")
            if query.matches.isEmpty {
                lines.append("")
                lines.append("一致する選手が見つかりませんでした。")
                lines.append("")
                continue
            }

            for report in query.matches {
                let name = report.entrant.name ?? report.entrant.id.value
                lines.append("")
                lines.append("### \(name)")
                lines.append("")
                lines.append(statusBadgesLine(for: report))
                lines.append("")
                lines.append("- 一致理由: \(localizedMatchReason(report.matchReason))（`\(report.matchedValue)`）")
                if let seed = report.entrant.initialSeedNum {
                    lines.append("- シード: \(seed)")
                }
                if let placement = report.standingPlacement, placement > 0 {
                    lines.append("- 現在順位: \(placement)位")
                }
                lines.append("- 取得済み戦績: \(report.wins)勝\(report.losses)敗")
                lines.append("- 未完了・進行中: \(report.pendingSetCount)件")
                if let latestPhaseName = report.latestPhaseName {
                    let group = report.latestPhaseGroup?.displayIdentifier.map { " / \($0)" } ?? ""
                    lines.append("- 直近の場所: \(latestPhaseName)\(group)")
                }
                lines.append("")

                let pendingOrActiveSets = report.sets.filter { !StartGGSetState.isCompleted($0.set.state) }
                let completedSets = report.sets.filter { StartGGSetState.isCompleted($0.set.state) }.reversed()

                if !pendingOrActiveSets.isEmpty {
                    lines.append("#### 次の試合・進行中")
                    lines.append("")
                    appendMatchTable(Array(pendingOrActiveSets), to: &lines)
                    lines.append("")
                }

                if !completedSets.isEmpty {
                    lines.append("#### 取得済みの試合結果")
                    lines.append("")
                    appendMatchTable(Array(completedSets), to: &lines)
                    lines.append("")
                }

                if report.sets.isEmpty {
                    lines.append("取得済みデータ内に関連試合はありません。")
                    lines.append("")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func appendRecentCompletedMatchSummary(for document: WatchlistExportDocument, to lines: inout [String]) {
        let recentMatches = recentCompletedMatchSummaries(from: document)

        lines.append("## ウォッチ対象者の直近完了試合")
        lines.append("")

        guard !recentMatches.isEmpty else {
            lines.append("ウォッチ対象者に関連する完了済み試合はまだありません。")
            return
        }

        lines.append("- ウォッチ対象者に関連する完了済み試合の直近10件です。")
        lines.append("")
        lines.append("| 対象者 | 勝敗 | 相手 | スコア | 文脈 |")
        lines.append("|---|---|---|---|---|")

        for match in recentMatches.prefix(10) {
            let targetText = markdownCell(match.watchedEntrants.map(\.name).joined(separator: " / "))
            let resultText = markdownCell(match.resultText)
            let opponentText = markdownCell(match.opponentText)
            let scoreText = markdownCell(match.scoreText)
            let contextText = markdownCell(match.contextText)
            lines.append("| \(targetText) | \(resultText) | \(opponentText) | \(scoreText) | \(contextText) |")
        }
    }

    private static func appendCurrentStatusSummary(for document: WatchlistExportDocument, to lines: inout [String]) {
        let reports = currentStatusReports(from: document)

        lines.append("## ウォッチ対象者の現在状況")
        lines.append("")

        guard !reports.isEmpty else {
            lines.append("ウォッチ対象者の現在状況はありません。")
            return
        }

        let columnPairCount = 3
        let headerCells = (0..<columnPairCount).flatMap { _ in ["選手", "状況"] }
        let dividerCells = Array(repeating: "---", count: headerCells.count)
        lines.append(markdownTableRow(headerCells))
        lines.append(markdownTableRow(dividerCells))

        for startIndex in stride(from: 0, to: reports.count, by: columnPairCount) {
            var cells: [String] = []
            for offset in 0..<columnPairCount {
                let index = startIndex + offset
                if reports.indices.contains(index) {
                    let report = reports[index]
                    cells.append(markdownCell(report.entrant.name ?? report.entrant.id.value))
                    cells.append(statusBadgesLine(for: report))
                } else {
                    cells.append("")
                    cells.append("")
                }
            }
            lines.append(markdownTableRow(cells))
        }
    }

    private static func currentStatusReports(from document: WatchlistExportDocument) -> [WatchlistEntrantReport] {
        var reports: [WatchlistEntrantReport] = []
        var seenEntrantIds = Set<FlexibleID>()

        for query in document.queries {
            for report in query.matches where !seenEntrantIds.contains(report.entrant.id) {
                seenEntrantIds.insert(report.entrant.id)
                reports.append(report)
            }
        }

        return reports
    }

    private static func appendTableOfContents(for document: WatchlistExportDocument, to lines: inout [String]) {
        lines.append("## 目次")
        lines.append("")
        let recentSummaryHeading = "ウォッチ対象者の直近完了試合"
        let currentStatusHeading = "ウォッチ対象者の現在状況"
        lines.append("- [\(markdownLinkText(recentSummaryHeading))](#\(markdownHeadingAnchor(recentSummaryHeading)))")
        lines.append("- [\(markdownLinkText(currentStatusHeading))](#\(markdownHeadingAnchor(currentStatusHeading)))")
        lines.append("- [概要](#概要)")

        for query in document.queries {
            let queryHeading = "検索: \(query.query)"
            lines.append("- [\(markdownLinkText(queryHeading))](#\(markdownHeadingAnchor(queryHeading)))")
            for report in query.matches {
                let name = report.entrant.name ?? report.entrant.id.value
                lines.append("  - [\(markdownLinkText(name))](#\(markdownHeadingAnchor(name)))")
            }
        }
    }

    private static func markdownLinkText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func markdownHeadingAnchor(_ value: String) -> String {
        normalize(value)
            .unicodeScalars
            .filter { scalar in
                CharacterSet.alphanumerics.contains(scalar) ||
                    CharacterSet.letters.contains(scalar) ||
                    CharacterSet.decimalDigits.contains(scalar) ||
                    scalar == " " ||
                    scalar == "-"
            }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func statusBadgesLine(for report: WatchlistEntrantReport) -> String {
        let survival = survivalStatus(for: report)
        let bracket = bracketSide(for: report)
        return [
            markdownBadge(label: "状態", message: survival.label, color: survival.color),
            markdownBadge(label: "ブラケット", message: bracket.label, color: bracket.color)
        ].joined(separator: " ")
    }

    private static func matchesFilter(_ report: WatchlistEntrantReport, using filter: WatchlistOutputFilter) -> Bool {
        guard filter.isEnabled else {
            return false
        }

        let survival = survivalStatus(for: report).label
        let bracket = bracketSide(for: report).label

        let survivalAllowed: Bool
        switch (filter.includeLiving, filter.includeEliminated) {
        case (false, false), (true, true):
            survivalAllowed = true
        case (true, false):
            survivalAllowed = survival == "生存中"
        case (false, true):
            survivalAllowed = survival == "敗退済み"
        }

        let bracketAllowed: Bool
        switch (filter.includeWinners, filter.includeLosers) {
        case (false, false), (true, true):
            bracketAllowed = true
        case (true, false):
            bracketAllowed = bracket == "Winners"
        case (false, true):
            bracketAllowed = bracket == "Losers"
        }

        return survivalAllowed && bracketAllowed
    }

    private static func survivalStatus(for report: WatchlistEntrantReport) -> BadgeValue {
        if let latestUnfinished = latestRelevantSetContext(for: report, preferUnfinished: true),
           !StartGGSetState.isCompleted(latestUnfinished.set.state) {
            return BadgeValue(label: "生存中", color: "brightgreen")
        }

        guard let latestCompleted = latestRelevantSetContext(for: report, preferUnfinished: false),
              StartGGSetState.isCompleted(latestCompleted.set.state) else {
            return BadgeValue(label: "不明", color: "lightgrey")
        }

        switch latestCompleted.result {
        case "loss":
            return BadgeValue(label: "敗退済み", color: "red")
        case "win":
            return BadgeValue(label: "生存中", color: "brightgreen")
        default:
            return BadgeValue(label: "不明", color: "lightgrey")
        }
    }

    private static func bracketSide(for report: WatchlistEntrantReport) -> BadgeValue {
        guard let preferredSet = latestRelevantSetContext(for: report, preferUnfinished: true) else {
            return BadgeValue(label: "不明", color: "lightgrey")
        }

        guard let roundText = preferredSet.set.fullRoundText?.lowercased() else {
            return BadgeValue(label: "不明", color: "lightgrey")
        }

        if roundText.contains("winners") {
            return BadgeValue(label: "Winners", color: "blue")
        }
        if roundText.contains("losers") {
            return BadgeValue(label: "Losers", color: "orange")
        }
        return BadgeValue(label: "不明", color: "lightgrey")
    }

    private static func latestRelevantSetContext(for report: WatchlistEntrantReport, preferUnfinished: Bool) -> WatchlistSetContext? {
        let rankedSets = report.sets.sorted(by: compareSetContextsForRecency)
        let newestFirst = rankedSets.reversed()

        if preferUnfinished, let latestUnfinished = newestFirst.first(where: { !StartGGSetState.isCompleted($0.set.state) }) {
            return latestUnfinished
        }

        return newestFirst.first(where: { StartGGSetState.isCompleted($0.set.state) })
    }

    private static func compareSetContextsForRecency(_ lhs: WatchlistSetContext, _ rhs: WatchlistSetContext) -> Bool {
        if lhs.phaseIndex == rhs.phaseIndex {
            return setTimestamp(lhs.set) < setTimestamp(rhs.set)
        }
        return lhs.phaseIndex < rhs.phaseIndex
    }

    private static func setTimestamp(_ set: ExportSet) -> Int {
        set.updatedAt ?? set.completedAt ?? set.startedAt ?? 0
    }

    private static func markdownBadge(label: String, message: String, color: String) -> String {
        "![\(label): \(message)](\(shieldsBadgeURL(label: label, message: message, color: color)))"
    }

    private static func shieldsBadgeURL(label: String, message: String, color: String) -> String {
        "https://img.shields.io/badge/\(percentEncodedBadgeComponent(label))-\(percentEncodedBadgeComponent(message))-\(color)"
    }

    private static func percentEncodedBadgeComponent(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func recentCompletedMatchSummaries(from document: WatchlistExportDocument) -> [RecentCompletedMatchSummary] {
        var summaries: [FlexibleID: RecentCompletedMatchSummary] = [:]

        for query in document.queries {
            for report in query.matches {
                for context in report.sets where StartGGSetState.isCompleted(context.set.state) {
                    let watchedName = entrantName(from: context.watchedEntrantId, in: context.set)
                    let watchedResult = localizedResult(context.result)
                    let opponentNames = context.set.slots
                        .compactMap { slot -> String? in
                            guard let entrant = slot.entrant, entrant.id != context.watchedEntrantId else {
                                return nil
                            }
                            return entrant.name ?? entrant.id.value
                        }
                    let summary = summaries[context.set.id] ?? RecentCompletedMatchSummary(
                        setId: context.set.id,
                        sortTimestamp: context.set.completedAt ?? context.set.updatedAt ?? context.set.startedAt ?? 0,
                        phaseIndex: context.phaseIndex,
                        round: context.set.round ?? 0,
                        phaseName: context.phaseName,
                        phaseGroup: context.phaseGroup,
                        watchedEntrants: [],
                        opponentNames: [],
                        scoreText: context.set.displayScore ?? scoreText(watched: context.watchedScore, opponent: context.opponentScore)
                    )

                    summaries[context.set.id] = summary.merging(
                        watchedEntrant: RecentCompletedMatchParticipant(name: watchedName, result: watchedResult),
                        opponentNames: opponentNames,
                        context: context
                    )
                }
            }
        }

        return summaries.values.sorted { lhs, rhs in
            if lhs.sortTimestamp == rhs.sortTimestamp {
                if lhs.phaseIndex == rhs.phaseIndex {
                    if lhs.round == rhs.round {
                        return lhs.setId.value > rhs.setId.value
                    }
                    return lhs.round > rhs.round
                }
                return lhs.phaseIndex > rhs.phaseIndex
            }
            return lhs.sortTimestamp > rhs.sortTimestamp
        }
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
                byId[entrant.id] = merge(existing: byId[entrant.id], incoming: entrant)
            }
        }
        return byId.values.sorted { ($0.name ?? $0.id.value) < ($1.name ?? $1.id.value) }
    }

    private static func merge(existing: Entrant?, incoming: Entrant) -> Entrant {
        guard let existing else {
            return incoming
        }
        return existing.mergingMissingFields(from: incoming)
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

    private static func isExcluded(_ entrant: Entrant, by exclusionQueries: [String]) -> Bool {
        exclusionQueries.contains { query in
            bestMatch(for: query, entrant: entrant) != nil
        }
    }

    private static func bestMatch(for query: String, entrant: Entrant) -> EntrantMatch? {
        let normalizedQuery = normalize(query)
        let compactQuery = compact(query)
        guard !normalizedQuery.isEmpty else {
            return nil
        }
        let canUseCompactQuery = !compactQuery.isEmpty
        let canUsePartialMatch = compactQuery.count >= 3

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
            } else if canUseCompactQuery && compactCandidate == compactQuery {
                score = 98
                reason = "compact exact"
            } else if canUsePartialMatch && normalizedCandidate.contains(normalizedQuery) {
                score = 86
                reason = "contains"
            } else if canUsePartialMatch && compactCandidate.contains(compactQuery) {
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
            values.append(contentsOf: spellingVariantCandidates(from: name))
            values.append(contentsOf: prefixCandidates(from: name))
        }
        for participant in entrant.participants ?? [] {
            appendCandidateValues(prefix: participant.prefix, gamerTag: participant.gamerTag, to: &values)
            if let player = participant.player {
                appendCandidateValues(prefix: player.prefix, gamerTag: player.gamerTag, to: &values)
            }
        }
        return Array(Set(values))
    }

    private static func appendCandidateValues(prefix: String?, gamerTag: String?, to values: inout [String]) {
        let trimmedPrefix = prefix?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGamerTag = gamerTag?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedGamerTag, !trimmedGamerTag.isEmpty {
            values.append(trimmedGamerTag)
            values.append(contentsOf: spellingVariantCandidates(from: trimmedGamerTag))
        }

        guard let trimmedPrefix, !trimmedPrefix.isEmpty else {
            return
        }

        values.append(trimmedPrefix)
        values.append(contentsOf: splitPrefixCandidates(from: trimmedPrefix))
        values.append(contentsOf: prefixTokenCandidates(from: trimmedPrefix))
        values.append(contentsOf: splitPrefixCandidates(from: trimmedPrefix).flatMap(prefixTokenCandidates))

        if let trimmedGamerTag, !trimmedGamerTag.isEmpty {
            values.append("\(trimmedPrefix) \(trimmedGamerTag)")
            values.append("\(trimmedPrefix) | \(trimmedGamerTag)")
        }
    }

    private static func prefixCandidates(from name: String) -> [String] {
        var candidates: [String] = []
        for separator in ["|", "｜"] {
            let parts = name.components(separatedBy: separator)
            if parts.count > 1 {
                let prefix = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefix.isEmpty {
                    candidates.append(prefix)
                    candidates.append(contentsOf: splitPrefixCandidates(from: prefix))
                    candidates.append(contentsOf: prefixTokenCandidates(from: prefix))
                    candidates.append(contentsOf: splitPrefixCandidates(from: prefix).flatMap(prefixTokenCandidates))
                }
                candidates.append(contentsOf: postSeparatorPrefixCandidates(from: parts.dropFirst().joined(separator: separator)))
            }
        }
        return candidates
    }

    private static func splitPrefixCandidates(from prefix: String) -> [String] {
        prefix
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func prefixTokenCandidates(from prefix: String) -> [String] {
        prefix
            .split(whereSeparator: { $0.isWhitespace || $0 == "/" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }

    private static func spellingVariantCandidates(from value: String) -> [String] {
        let acquaVariant = value.replacingOccurrences(
            of: "acqua",
            with: "AQUA",
            options: [.caseInsensitive, .diacriticInsensitive]
        )
        guard acquaVariant != value else {
            return []
        }
        return [acquaVariant]
    }

    private static func postSeparatorPrefixCandidates(from value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }
        let tokens = trimmed.split(whereSeparator: { $0.isWhitespace || $0 == "/" })
        guard let firstToken = tokens.first.map(String.init), firstToken.count >= 2 else {
            return []
        }
        return [firstToken, trimmed]
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

    private static func markdownTableRow(_ cells: [String]) -> String {
        "| \(cells.joined(separator: " | ")) |"
    }

    private static func appendMatchTable(_ contexts: [WatchlistSetContext], to lines: inout [String]) {
        lines.append("| 状況 | 場所 | ラウンド | 選手 | スコア | 相手 | 勝敗 |")
        lines.append("|---|---|---|---|---|---|---|")

        for context in contexts {
            let state = markdownCell(localizedStateLabel(context.set.stateLabel))
            let location = markdownCell(locationText(for: context))
            let round = markdownCell(context.set.fullRoundText ?? context.set.identifier ?? "")
            let matchup = matchupColumns(for: context)
            let player = markdownCell(matchup.player)
            let score = markdownCell(matchup.score)
            let opponent = markdownCell(matchup.opponent)
            let result = markdownCell(localizedResult(context.result))
            lines.append("| \(state) | \(location) | \(round) | \(player) | \(score) | \(opponent) | \(result) |")
        }
    }

    private static func localizedMatchReason(_ reason: String) -> String {
        switch reason {
        case "exact":
            return "完全一致"
        case "compact exact":
            return "記号・空白を除いた完全一致"
        case "contains":
            return "部分一致"
        case "compact contains":
            return "記号・空白を除いた部分一致"
        default:
            return reason
        }
    }

    private static func localizedStateLabel(_ state: String) -> String {
        switch state {
        case "completed":
            return "終了"
        case "pending":
            return "未開始"
        case "active":
            return "進行中"
        default:
            return "不明"
        }
    }

    private static func localizedResult(_ result: String) -> String {
        switch result {
        case "win":
            return "勝ち"
        case "loss":
            return "負け"
        case "pending":
            return "予定"
        case "active":
            return "進行中"
        default:
            return "不明"
        }
    }

    private static func locationText(for context: WatchlistSetContext) -> String {
        let phase = context.phaseName ?? context.phaseId.value
        guard let group = context.phaseGroup?.displayIdentifier, !group.isEmpty else {
            return phase
        }
        return "\(phase) / \(group)"
    }

    private static func scoreText(watched: Double?, opponent: Double?) -> String {
        guard let watched, watched >= 0, let opponent, opponent >= 0 else {
            return "未記録"
        }
        return "\(formatScore(watched)) - \(formatScore(opponent))"
    }

    private static func formatScore(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private static func matchupColumns(for context: WatchlistSetContext) -> MatchupColumns {
        let watchedName = entrantName(from: context.watchedEntrantId, in: context.set)
        let opponentSlots = context.set.slots.filter { $0.entrant?.id != context.watchedEntrantId }
        let opponents = opponentSlots.map { $0.entrant?.name ?? $0.entrant?.id.value ?? "未定" }
        let opponentText = opponents.isEmpty ? "未定" : opponents.joined(separator: ", ")
        let score = StartGGSetState.isCompleted(context.set.state)
            ? scoreText(watched: context.watchedScore, opponent: context.opponentScore)
            : ""

        return MatchupColumns(player: watchedName, score: score, opponent: opponentText)
    }

    private static func entrantName(from entrantId: FlexibleID, in set: ExportSet) -> String {
        set.slots.first { $0.entrant?.id == entrantId }?.entrant?.name ?? entrantId.value
    }
}

private struct BadgeValue {
    var label: String
    var color: String
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

private struct MatchupColumns {
    var player: String
    var score: String
    var opponent: String
}

private struct RecentCompletedMatchSummary {
    var setId: FlexibleID
    var sortTimestamp: Int
    var phaseIndex: Int
    var round: Int
    var phaseName: String?
    var phaseGroup: PhaseGroupRef?
    var watchedEntrants: [RecentCompletedMatchParticipant]
    var opponentNames: [String]
    var scoreText: String

    var resultText: String {
        watchedEntrants.isEmpty
            ? "不明"
            : watchedEntrants.map { "\($0.name)（\($0.result)）" }.joined(separator: " / ")
    }

    var contextText: String {
        let phase = phaseName ?? setId.value
        let group = phaseGroup?.displayIdentifier.map { " / \($0)" } ?? ""
        let roundText = round > 0 ? " / R\(round)" : ""
        return "\(phase)\(group)\(roundText)"
    }

    var opponentText: String {
        let unique = Array(Set(opponentNames)).sorted()
        let watchedNames = Set(watchedEntrants.map(\.name))
        if unique.isEmpty || unique.allSatisfy(watchedNames.contains) {
            return "対象者同士"
        }
        return unique.joined(separator: ", ")
    }

    func merging(watchedEntrant: RecentCompletedMatchParticipant, opponentNames: [String], context: WatchlistSetContext) -> RecentCompletedMatchSummary {
        var merged = self
        if !merged.watchedEntrants.contains(watchedEntrant) {
            merged.watchedEntrants.append(watchedEntrant)
        }
        merged.watchedEntrants.sort { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.result < rhs.result
            }
            return lhs.name < rhs.name
        }
        merged.opponentNames.append(contentsOf: opponentNames)
        merged.sortTimestamp = max(merged.sortTimestamp, context.set.completedAt ?? context.set.updatedAt ?? context.set.startedAt ?? 0)
        return merged
    }
}

private struct RecentCompletedMatchParticipant: Hashable {
    var name: String
    var result: String
}

import Foundation
import Testing
@testable import StartGGMatchExporter

@Suite("Watchlist scope")
struct WatchlistScopeTests {
    @Test("Parses unique watchlist queries")
    func parsesQueries() {
        let queries = WatchlistScopeBuilder.parseQueries("""
        Tokido
        MenaRD, Kakeru
        # comment
        tokido
        """)

        #expect(queries == ["Tokido", "MenaRD", "Kakeru"])
    }

    @Test("Builds focused export for matched players")
    func buildsFocusedExport() {
        let document = sampleDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido\nKakeru\nMissing")

        #expect(scope.summary.queryCount == 3)
        #expect(scope.summary.matchedQueryCount == 2)
        #expect(scope.summary.unmatchedQueryCount == 1)
        #expect(scope.summary.matchedEntrantCount == 2)
        #expect(scope.summary.relatedSetCount == 2)

        let tokido = scope.queries.first { $0.query == "Tokido" }?.matches.first
        #expect(tokido?.wins == 1)
        #expect(tokido?.losses == 0)
        #expect(tokido?.pendingSetCount == 1)
    }

    @Test("Filters watchlist output by status and bracket groups")
    func filtersWatchlistOutputByStatusAndBracketGroups() {
        let document = mixedBracketDocument()
        let watchlistText = "Tokido\nKakeru"

        let allEnabled = WatchlistScopeBuilder.build(from: document, watchlistText: watchlistText)
        let statusOnly = WatchlistScopeBuilder.build(
            from: document,
            watchlistText: watchlistText,
            filter: WatchlistOutputFilter(includeLiving: true, includeEliminated: true, includeWinners: false, includeLosers: false)
        )
        let winnersOnly = WatchlistScopeBuilder.build(
            from: document,
            watchlistText: watchlistText,
            filter: WatchlistOutputFilter(includeLiving: false, includeEliminated: false, includeWinners: true, includeLosers: false)
        )
        let livingWinnersOnly = WatchlistScopeBuilder.build(
            from: document,
            watchlistText: watchlistText,
            filter: WatchlistOutputFilter(includeLiving: true, includeEliminated: false, includeWinners: true, includeLosers: false)
        )
        let allOff = WatchlistScopeBuilder.build(
            from: document,
            watchlistText: watchlistText,
            filter: WatchlistOutputFilter(includeLiving: false, includeEliminated: false, includeWinners: false, includeLosers: false)
        )

        #expect(allEnabled.summary.matchedEntrantCount == 2)
        #expect(statusOnly.summary.matchedEntrantCount == 2)
        #expect(winnersOnly.summary.matchedEntrantCount == 1)
        #expect(winnersOnly.queries.first { $0.query == "Kakeru" }?.matches.isEmpty == true)
        #expect(livingWinnersOnly.summary.matchedEntrantCount == 1)
        #expect(livingWinnersOnly.summary.relatedSetCount == 1)
        #expect(allOff.summary.matchedEntrantCount == 0)
        #expect(allOff.summary.relatedSetCount == 0)
        #expect(allOff.queries.allSatisfy { $0.matches.isEmpty })

        let filteredPreview = WatchlistScopeBuilder.preview(
            for: watchlistText,
            document: document,
            filter: WatchlistOutputFilter(includeLiving: false, includeEliminated: false, includeWinners: true, includeLosers: false)
        )
        #expect(filteredPreview.matchedEntrantCount == 1)
    }

    @Test("Matches team prefix queries")
    func matchesTeamPrefixQueries() {
        let document = sampleDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "DFM")

        let match = scope.queries.first { $0.query == "DFM" }?.matches.first
        #expect(scope.summary.matchedQueryCount == 1)
        #expect(match?.entrant.name == "DFM | Itabashi Zangief")
        #expect(match?.matchReason == "exact")
        #expect(match?.matchedValue == "DFM")
    }

    @Test("Matches team token after sponsor prefix")
    func matchesTeamTokenAfterSponsorPrefix() {
        let document = sponsorPrefixDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "CR")
        let names = scope.queries.first { $0.query == "CR" }?.matches.compactMap(\.entrant.name) ?? []

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(scope.summary.matchedEntrantCount == 2)
        #expect(names.contains("CR | Dogura"))
        #expect(names.contains("Red Bull | CR Bonchan"))
    }

    @Test("Matches team token inside slash-separated prefix")
    func matchesTeamTokenInsideSlashSeparatedPrefix() {
        let document = slashSeparatedSponsorPrefixDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "REJECT")
        let match = scope.queries.first { $0.query == "REJECT" }?.matches.first

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(scope.summary.matchedEntrantCount == 1)
        #expect(match?.entrant.name == "REJECT/RC | ウメハラ/Daigo")
        #expect(match?.matchReason == "exact")
        #expect(match?.matchedValue == "REJECT")
    }

    @Test("Matches team token inside slash-delimited multi word prefix")
    func matchesTeamTokenInsideSlashDelimitedMultiWordPrefix() {
        let document = slashDelimitedMultiWordPrefixDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "iXA")
        let names = scope.queries.first { $0.query == "iXA" }?.matches.compactMap(\.entrant.name) ?? []
        let acqua = scope.queries.first?.matches.first { $0.entrant.name == "広島TEAM iXA/HT | ACQUA" }

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(scope.summary.matchedEntrantCount == 2)
        #expect(names.contains("広島TEAM iXA/HT | ACQUA"))
        #expect(names.contains("iXA | Other"))
        #expect(acqua?.matchReason == "exact")
        #expect(acqua?.matchedValue == "iXA")
    }

    @Test("Matches ACQUA with AQUA spelling")
    func matchesACQUAWithAQUASpelling() {
        let document = slashDelimitedMultiWordPrefixDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "AQUA")
        let match = scope.queries.first { $0.query == "AQUA" }?.matches.first

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(scope.summary.matchedEntrantCount == 1)
        #expect(match?.entrant.name == "広島TEAM iXA/HT | ACQUA")
        #expect(match?.matchReason == "exact")
        #expect(match?.matchedValue == "AQUA")
    }

    @Test("Matches team token inside multi word prefix")
    func matchesTeamTokenInsideMultiWordPrefix() {
        let document = multiWordSponsorPrefixDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "REJECT")
        let names = scope.queries.first { $0.query == "REJECT" }?.matches.compactMap(\.entrant.name) ?? []

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(scope.summary.matchedEntrantCount == 2)
        #expect(names.contains("REJECT | Fuudo"))
        #expect(names.contains("REJECT Beast | DAIGO"))
        #expect(scope.queries.first?.matches.first { $0.entrant.name == "REJECT Beast | DAIGO" }?.matchReason == "exact")
        #expect(scope.queries.first?.matches.first { $0.entrant.name == "REJECT Beast | DAIGO" }?.matchedValue == "REJECT")
    }

    @Test("Matches prefix with pipe spacing variants")
    func matchesPrefixWithPipeSpacingVariants() {
        let document = pipeSpacingDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "CR\nREJECT")

        let crNames = scope.queries.first { $0.query == "CR" }?.matches.compactMap(\.entrant.name) ?? []
        let rejectNames = scope.queries.first { $0.query == "REJECT" }?.matches.compactMap(\.entrant.name) ?? []

        #expect(scope.summary.matchedQueryCount == 2)
        #expect(crNames.contains("CR|Dogura"))
        #expect(rejectNames.contains("REJECT ｜ RC | ウメハラ/Daigo"))
    }

    @Test("Matches participant prefix when gamer tag is missing")
    func matchesParticipantPrefixWithoutGamerTag() {
        let document = prefixOnlyParticipantDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "CR")
        let match = scope.queries.first { $0.query == "CR" }?.matches.first

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(match?.entrant.name == "Dogura")
        #expect(match?.matchReason == "exact")
        #expect(match?.matchedValue == "CR")
    }

    @Test("Limits two character queries to exact candidate matches")
    func limitsTwoCharacterQueriesToExactCandidateMatches() {
        let document = shortQueryDocument()
        let crScope = WatchlistScopeBuilder.build(from: document, watchlistText: "CR")
        let rcScope = WatchlistScopeBuilder.build(from: document, watchlistText: "RC")
        let reScope = WatchlistScopeBuilder.build(from: document, watchlistText: "Re")

        #expect(crScope.summary.matchedEntrantCount == 1)
        #expect(crScope.queries.first?.matches.first?.entrant.name == "Red Bull | CR Bonchan")
        #expect(rcScope.summary.matchedEntrantCount == 1)
        #expect(rcScope.queries.first?.matches.first?.entrant.name == "REJECT/RC | ウメハラ/Daigo")
        #expect(reScope.summary.matchedEntrantCount == 0)
    }

    @Test("Ignores punctuation only queries")
    func ignoresPunctuationOnlyQueries() {
        let document = sampleDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "!!!")

        #expect(scope.summary.matchedQueryCount == 0)
        #expect(scope.summary.matchedEntrantCount == 0)
    }

    @Test("Matches short partial queries")
    func matchesShortPartialQueries() {
        let document = shortPrefixDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "G8S")

        let match = scope.queries.first { $0.query == "G8S" }?.matches.first
        #expect(scope.summary.matchedQueryCount == 1)
        #expect(match?.entrant.name == "G8S/PWS | Alpha")
        #expect(match?.matchReason == "exact")
    }

    @Test("Matches compact-only short queries")
    func matchesCompactOnlyShortQueries() {
        var document = shortPrefixDocument()
        document.entrants[0].name = "G-8-S / PWS | Alpha"

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "G8S")
        let match = scope.queries.first { $0.query == "G8S" }?.matches.first

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(match?.entrant.name == "G-8-S / PWS | Alpha")
        #expect(match?.matchReason == "compact exact")
    }

    @Test("Excludes watchlist matches by excluded words")
    func excludesWatchlistMatchesByExcludedWords() {
        let document = sampleDocument()
        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "DFM\nTokido", excludedText: "Itabashi")
        let dfm = scope.queries.first { $0.query == "DFM" }
        let tokido = scope.queries.first { $0.query == "Tokido" }
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(scope.exclusionQueries == ["Itabashi"])
        #expect(scope.summary.queryCount == 2)
        #expect(scope.summary.matchedQueryCount == 1)
        #expect(dfm?.matches.isEmpty == true)
        #expect(tokido?.matches.first?.entrant.name == "ROHTO Z! Tokido")
        #expect(markdown.contains("- 除外ワード: Itabashi"))
        #expect(!markdown.contains("### DFM | Itabashi Zangief"))
    }

    @Test("Merges sparse standings entrants without losing watchlist candidates")
    func mergesSparseStandingsEntrantsWithoutLosingWatchlistCandidates() {
        var document = sampleDocument()
        document.standings = [
            Standing(
                id: FlexibleID("st-sparse"),
                placement: 1,
                entrant: Entrant(
                    id: FlexibleID("1"),
                    name: nil,
                    initialSeedNum: nil,
                    participants: nil
                )
            )
        ]

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let match = scope.queries.first?.matches.first

        #expect(scope.summary.matchedQueryCount == 1)
        #expect(match?.entrant.name == "ROHTO Z! Tokido")
        #expect(match?.entrant.initialSeedNum == 1)
        #expect(match?.standingPlacement == 1)
        #expect(match?.setCount == 2)
    }

    @Test("Creates markdown report")
    func createsMarkdown() {
        let scope = WatchlistScopeBuilder.build(from: sampleDocument(), watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("# Street Fighter 6 選手ウォッチレポート"))
        #expect(markdown.contains("## 目次"))
        #expect(markdown.contains("## ウォッチ対象者の直近完了試合"))
        #expect(markdown.contains("## ウォッチ対象者の現在状況"))
        #expect(markdown.contains("- [ウォッチ対象者の直近完了試合](#ウォッチ対象者の直近完了試合)"))
        #expect(markdown.contains("- [ウォッチ対象者の現在状況](#ウォッチ対象者の現在状況)"))
        #expect(markdown.contains("- [概要](#概要)"))
        #expect(markdown.contains("- [検索: Tokido](#検索-tokido)"))
        #expect(markdown.contains("  - [ROHTO Z! Tokido](#rohto-z-tokido)"))
        #expect(!markdown.contains("<a id="))
        #expect(markdown.contains("### ROHTO Z! Tokido\n\n![状態: 生存中](https://img.shields.io/badge/%E7%8A%B6%E6%85%8B-%E7%94%9F%E5%AD%98%E4%B8%AD-brightgreen) ![ブラケット: Winners](https://img.shields.io/badge/%E3%83%96%E3%83%A9%E3%82%B1%E3%83%83%E3%83%88-Winners-blue)"))
        #expect(markdown.contains("| 対象者 | 勝敗 | 相手 | スコア | 文脈 |"))
        #expect(markdown.contains("| 選手 | 状況 | 選手 | 状況 | 選手 | 状況 |"))
        #expect(markdown.contains("| ROHTO Z! Tokido | ![状態: 生存中](https://img.shields.io/badge/%E7%8A%B6%E6%85%8B-%E7%94%9F%E5%AD%98%E4%B8%AD-brightgreen) ![ブラケット: Winners](https://img.shields.io/badge/%E3%83%96%E3%83%A9%E3%82%B1%E3%83%83%E3%83%88-Winners-blue) |  |  |  |  |"))
        #expect(markdown.contains("| 状況 | 場所 | ラウンド | 選手 | スコア | 相手 | 勝敗 |"))
        #expect(markdown.contains("| 未開始 | Round 1 / A101 | Winners Round 2 | ROHTO Z! Tokido |  | IBUSHIGIN \\| Kakeru | 予定 |"))
        #expect(markdown.contains("| 終了 | Round 1 / A101 | Winners Round 1 | ROHTO Z! Tokido | 2 - 0 | Punk | 勝ち |"))
    }

    @Test("Shows current status summary with escaped entrant names")
    func showsCurrentStatusSummaryWithEscapedEntrantNames() {
        let scope = WatchlistScopeBuilder.build(from: sampleDocument(), watchlistText: "Tokido\nKakeru")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)
        let statusSection = markdown.section(named: "ウォッチ対象者の現在状況")
        let dataRow = statusSection
            .split(separator: "\n")
            .map(String.init)
            .first { $0.contains("ROHTO Z! Tokido") } ?? ""

        #expect(statusSection.contains("| 選手 | 状況 | 選手 | 状況 | 選手 | 状況 |"))
        #expect(dataRow.contains("| ROHTO Z! Tokido | ![状態: 生存中]"))
        #expect(dataRow.contains("| IBUSHIGIN \\| Kakeru | ![状態: 生存中]"))
        #expect(dataRow.contains("![ブラケット: Winners]"))
    }

    @Test("Shows badges for losers-side active matches")
    func showsBadgesForLosersSideActiveMatches() {
        var document = sampleDocument()
        document.phases[0].sets[1].fullRoundText = "Losers Round 2"

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("![状態: 生存中](https://img.shields.io/badge/%E7%8A%B6%E6%85%8B-%E7%94%9F%E5%AD%98%E4%B8%AD-brightgreen)"))
        #expect(markdown.contains("![ブラケット: Losers](https://img.shields.io/badge/%E3%83%96%E3%83%A9%E3%82%B1%E3%83%83%E3%83%88-Losers-orange)"))
    }

    @Test("Prefers the newest unfinished set when multiple unfinished sets exist")
    func prefersNewestUnfinishedSetForBracketSide() {
        var document = sampleDocument()
        document.phases[0].sets.append(
            ExportSet(
                SetNode(
                    id: FlexibleID("s3"),
                    identifier: "C",
                    state: 1,
                    round: 3,
                    fullRoundText: "Losers Round 3",
                    displayScore: nil,
                    winnerId: nil,
                    completedAt: nil,
                    startedAt: nil,
                    updatedAt: 3,
                    phaseGroup: PhaseGroupRef(id: FlexibleID("pg1"), displayIdentifier: "A101"),
                    slots: [
                        slot(entrant: document.entrants.first { $0.id.value == "1" }, score: nil, placement: nil),
                        slot(entrant: document.entrants.first { $0.id.value == "4" }, score: nil, placement: nil)
                    ]
                )
            )
        )

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("![ブラケット: Losers](https://img.shields.io/badge/%E3%83%96%E3%83%A9%E3%82%B1%E3%83%83%E3%83%88-Losers-orange)"))
    }

    @Test("Shows badges for elimination state with no unfinished matches")
    func showsBadgesForEliminationStateWithNoUnfinishedMatches() {
        let scope = WatchlistScopeBuilder.build(from: eliminationDocument(), watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("![状態: 敗退済み](https://img.shields.io/badge/%E7%8A%B6%E6%85%8B-%E6%95%97%E9%80%80%E6%B8%88%E3%81%BF-red)"))
        #expect(markdown.contains("![ブラケット: Losers](https://img.shields.io/badge/%E3%83%96%E3%83%A9%E3%82%B1%E3%83%83%E3%83%88-Losers-orange)"))
    }

    @Test("Shows unknown badge when round text cannot be classified")
    func showsUnknownBadgeWhenRoundTextCannotBeClassified() {
        var document = sampleDocument()
        document.phases[0].sets[1].fullRoundText = "Championship Qualifier"

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("![ブラケット: 不明](https://img.shields.io/badge/%E3%83%96%E3%83%A9%E3%82%B1%E3%83%83%E3%83%88-%E4%B8%8D%E6%98%8E-lightgrey)"))
    }

    @Test("Uses the newest completed set when only completed sets exist")
    func usesNewestCompletedSetWhenOnlyCompletedSetsExist() {
        var document = sampleDocument()
        document.phases[0].sets = [
            document.phases[0].sets[0],
            ExportSet(
                SetNode(
                    id: FlexibleID("s4"),
                    identifier: "D",
                    state: 3,
                    round: 4,
                    fullRoundText: "Losers Round 4",
                    displayScore: "IBUSHIGIN | Kakeru 2 - ROHTO Z! Tokido 0",
                    winnerId: FlexibleID("2"),
                    completedAt: 4,
                    startedAt: nil,
                    updatedAt: 4,
                    phaseGroup: PhaseGroupRef(id: FlexibleID("pg1"), displayIdentifier: "A101"),
                    slots: [
                        slot(entrant: document.entrants.first { $0.id.value == "1" }, score: 0, placement: 2),
                        slot(entrant: document.entrants.first { $0.id.value == "2" }, score: 2, placement: 1)
                    ]
                )
            )
        ]

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("![ブラケット: Losers](https://img.shields.io/badge/%E3%83%96%E3%83%A9%E3%82%B1%E3%83%83%E3%83%88-Losers-orange)"))
    }

    @Test("Shows the 10 most recent completed watchlist matches without duplicate sets")
    func showsRecentCompletedMatchesSummary() {
        let scope = WatchlistScopeBuilder.build(from: recentMatchesDocument(), watchlistText: "Tokido\nKakeru")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)
        let summarySection = markdown.section(named: "ウォッチ対象者の直近完了試合")
        let summaryLines = summarySection.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let dataRows = summaryLines.filter { $0.hasPrefix("| ") && !$0.contains("対象者 |") }

        #expect(markdown.contains("## ウォッチ対象者の直近完了試合"))
        #expect(dataRows.count == 10)
        #expect(dataRows.first?.contains("Round 11 / A101 / R11") == true)
        #expect(dataRows.contains { $0.contains("対象者同士") })
        #expect(!summarySection.contains("Round 1 / A101 / R1"))
    }

    @Test("Shows 未記録 for invalid completed scores in markdown")
    func showsNotRecordedForInvalidCompletedScoresInMarkdown() {
        var document = sampleDocument()
        let punk = document.entrants.first { $0.id.value == "3" }
        document.phases[0].sets[0].slots[1] = slot(entrant: punk, score: -1, placement: 2)

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(!markdown.contains("2 - -1"))
        #expect(!markdown.contains("- -1"))
        #expect(markdown.contains("| 終了 | Round 1 / A101 | Winners Round 1 | ROHTO Z! Tokido | 未記録 | Punk | 勝ち |"))
    }

    @Test("Shows 未記録 for completed scores with missing values in markdown")
    func showsNotRecordedForMissingCompletedScoresInMarkdown() {
        var document = sampleDocument()
        let punk = document.entrants.first { $0.id.value == "3" }
        document.phases[0].sets[0].slots[1] = slot(entrant: punk, score: nil, placement: 2)

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("| 終了 | Round 1 / A101 | Winners Round 1 | ROHTO Z! Tokido | 未記録 | Punk | 勝ち |"))
    }

    @Test("Shows undecided opponent in pending match markdown")
    func showsUndecidedOpponentInPendingMatchMarkdown() {
        var document = sampleDocument()
        document.phases[0].sets[1].slots[1] = slot(entrant: nil, score: nil, placement: nil)

        let scope = WatchlistScopeBuilder.build(from: document, watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("| 未開始 | Round 1 / A101 | Winners Round 2 | ROHTO Z! Tokido |  | 未定 | 予定 |"))
    }

    @Test("Disables watchlist export when all filter checkboxes are off")
    @MainActor
    func disablesWatchlistExportWhenAllFilterCheckboxesAreOff() {
        let viewModel = AppViewModel()
        viewModel.lastDocument = mixedBracketDocument()
        viewModel.watchlistText = "Tokido"
        viewModel.watchlistIncludeLiving = false
        viewModel.watchlistIncludeEliminated = false
        viewModel.watchlistIncludeWinners = false
        viewModel.watchlistIncludeLosers = false

        #expect(viewModel.canSaveWatchlistScope == false)
        #expect(viewModel.watchlistExportPromptText == "Select at least one output filter.")
    }

    private func sampleDocument() -> ExportDocument {
        let tokido = entrant(id: "1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
        let kakeru = entrant(id: "2", name: "IBUSHIGIN | Kakeru", tag: "Kakeru", seed: 2)
        let punk = entrant(id: "3", name: "Punk", tag: "Punk", seed: 3)
        let itabashi = entrant(id: "4", name: "DFM | Itabashi Zangief", tag: "Itabashi Zangief", seed: 4)

        let completed = ExportSet(
            SetNode(
                id: FlexibleID("s1"),
                identifier: "A",
                state: 3,
                round: 1,
                fullRoundText: "Winners Round 1",
                displayScore: "ROHTO Z! Tokido 2 - Punk 0",
                winnerId: tokido.id,
                completedAt: 1,
                startedAt: nil,
                updatedAt: 1,
                phaseGroup: PhaseGroupRef(id: FlexibleID("pg1"), displayIdentifier: "A101"),
                slots: [
                    slot(entrant: tokido, score: 2, placement: 1),
                    slot(entrant: punk, score: 0, placement: 2)
                ]
            )
        )

        let pending = ExportSet(
            SetNode(
                id: FlexibleID("s2"),
                identifier: "B",
                state: 1,
                round: 2,
                fullRoundText: "Winners Round 2",
                displayScore: nil,
                winnerId: nil,
                completedAt: nil,
                startedAt: nil,
                updatedAt: 2,
                phaseGroup: PhaseGroupRef(id: FlexibleID("pg1"), displayIdentifier: "A101"),
                slots: [
                    slot(entrant: tokido, score: nil, placement: nil),
                    slot(entrant: kakeru, score: nil, placement: nil)
                ]
            )
        )

        let event = EventSummary(
            id: FlexibleID("e1"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 4,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t1"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(phaseCount: 1, entrantCount: 4, standingCount: 0, setCount: 2, completedSetCount: 1, pendingSetCount: 1, startedSetCount: 0),
            event: event,
            entrants: [tokido, kakeru, punk, itabashi],
            standings: [
                Standing(id: FlexibleID("st1"), placement: 1, entrant: tokido)
            ],
            phases: [
                PhaseExport(
                    id: FlexibleID("p1"),
                    name: "Round 1",
                    state: "ACTIVE",
                    groupCount: 1,
                    bracketType: "DOUBLE_ELIMINATION",
                    numSeeds: 3,
                    percentComplete: 50,
                    destPhases: [],
                    phaseGroups: [],
                    sets: [completed, pending]
                )
            ]
        )
    }

    private func mixedBracketDocument() -> ExportDocument {
        let tokido = entrant(id: "1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
        let kakeru = entrant(id: "2", name: "IBUSHIGIN | Kakeru", tag: "Kakeru", seed: 2)
        let punk = entrant(id: "3", name: "Punk", tag: "Punk", seed: 3)

        let winnersMatch = ExportSet(
            SetNode(
                id: FlexibleID("s-winners"),
                identifier: "A",
                state: 3,
                round: 1,
                fullRoundText: "Winners Round 1",
                displayScore: "ROHTO Z! Tokido 2 - Punk 0",
                winnerId: tokido.id,
                completedAt: 1,
                startedAt: nil,
                updatedAt: 1,
                phaseGroup: PhaseGroupRef(id: FlexibleID("pg1"), displayIdentifier: "A101"),
                slots: [
                    slot(entrant: tokido, score: 2, placement: 1),
                    slot(entrant: punk, score: 0, placement: 2)
                ]
            )
        )

        let losersMatch = ExportSet(
            SetNode(
                id: FlexibleID("s-losers"),
                identifier: "B",
                state: 3,
                round: 2,
                fullRoundText: "Losers Round 2",
                displayScore: "Punk 2 - IBUSHIGIN | Kakeru 0",
                winnerId: punk.id,
                completedAt: 2,
                startedAt: nil,
                updatedAt: 2,
                phaseGroup: PhaseGroupRef(id: FlexibleID("pg2"), displayIdentifier: "B202"),
                slots: [
                    slot(entrant: kakeru, score: 0, placement: 2),
                    slot(entrant: punk, score: 2, placement: 1)
                ]
            )
        )

        let event = EventSummary(
            id: FlexibleID("e-filter"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 3,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t-filter"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(
                phaseCount: 2,
                entrantCount: 3,
                standingCount: 0,
                setCount: 2,
                completedSetCount: 2,
                pendingSetCount: 0,
                startedSetCount: 0
            ),
            event: event,
            entrants: [tokido, kakeru, punk],
            standings: [],
            phases: [
                PhaseExport(
                    id: FlexibleID("p1"),
                    name: "Round 1",
                    state: "COMPLETED",
                    groupCount: 1,
                    bracketType: "DOUBLE_ELIMINATION",
                    numSeeds: 3,
                    percentComplete: 100,
                    destPhases: [],
                    phaseGroups: [],
                    sets: [winnersMatch]
                ),
                PhaseExport(
                    id: FlexibleID("p2"),
                    name: "Round 2",
                    state: "COMPLETED",
                    groupCount: 1,
                    bracketType: "DOUBLE_ELIMINATION",
                    numSeeds: 3,
                    percentComplete: 100,
                    destPhases: [],
                    phaseGroups: [],
                    sets: [losersMatch]
                )
            ]
        )
    }

    private func recentMatchesDocument() -> ExportDocument {
        let tokido = entrant(id: "1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
        let kakeru = entrant(id: "2", name: "IBUSHIGIN | Kakeru", tag: "Kakeru", seed: 2)
        let punk = entrant(id: "3", name: "Punk", tag: "Punk", seed: 3)

        let completedSets = (1...11).map { index -> ExportSet in
            let winnerIsTokido = index % 2 == 1
            let opponent = index == 11 ? kakeru : punk
            let winner = winnerIsTokido ? tokido : opponent
            return ExportSet(
                SetNode(
                    id: FlexibleID("s\(index)"),
                    identifier: String(index),
                    state: 3,
                    round: index,
                    fullRoundText: "Winners Round \(index)",
                    displayScore: winnerIsTokido ? "ROHTO Z! Tokido 2 - \(opponent.name ?? opponent.id.value) 0" : "\(opponent.name ?? opponent.id.value) 2 - ROHTO Z! Tokido 0",
                    winnerId: winner.id,
                    completedAt: index,
                    startedAt: nil,
                    updatedAt: index,
                    phaseGroup: PhaseGroupRef(id: FlexibleID("pg1"), displayIdentifier: "A101"),
                    slots: [
                        slot(entrant: tokido, score: winnerIsTokido ? 2 : 0, placement: winnerIsTokido ? 1 : 2),
                        slot(entrant: opponent, score: winnerIsTokido ? 0 : 2, placement: winnerIsTokido ? 2 : 1)
                    ]
                )
            )
        }

        let event = EventSummary(
            id: FlexibleID("e1"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 3,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t1"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(phaseCount: 1, entrantCount: 3, standingCount: 0, setCount: 11, completedSetCount: 11, pendingSetCount: 0, startedSetCount: 0),
            event: event,
            entrants: [tokido, kakeru, punk],
            standings: [],
            phases: [
                PhaseExport(
                    id: FlexibleID("p1"),
                    name: "Round 11",
                    state: "COMPLETED",
                    groupCount: 1,
                    bracketType: "DOUBLE_ELIMINATION",
                    numSeeds: 3,
                    percentComplete: 100,
                    destPhases: [],
                    phaseGroups: [],
                    sets: completedSets
                )
            ]
        )
    }

    private func eliminationDocument() -> ExportDocument {
        let tokido = entrant(id: "1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
        let kakeru = entrant(id: "2", name: "IBUSHIGIN | Kakeru", tag: "Kakeru", seed: 2)

        let eliminated = ExportSet(
            SetNode(
                id: FlexibleID("s-elim"),
                identifier: "C",
                state: 3,
                round: 2,
                fullRoundText: "Losers Round 2",
                displayScore: "IBUSHIGIN | Kakeru 2 - ROHTO Z! Tokido 0",
                winnerId: kakeru.id,
                completedAt: 2,
                startedAt: nil,
                updatedAt: 2,
                phaseGroup: PhaseGroupRef(id: FlexibleID("pg1"), displayIdentifier: "A101"),
                slots: [
                    slot(entrant: tokido, score: 0, placement: 2),
                    slot(entrant: kakeru, score: 2, placement: 1)
                ]
            )
        )

        let event = EventSummary(
            id: FlexibleID("e1"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 2,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t1"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(phaseCount: 1, entrantCount: 2, standingCount: 0, setCount: 1, completedSetCount: 1, pendingSetCount: 0, startedSetCount: 0),
            event: event,
            entrants: [tokido, kakeru],
            standings: [],
            phases: [
                PhaseExport(
                    id: FlexibleID("p1"),
                    name: "Round 1",
                    state: "COMPLETED",
                    groupCount: 1,
                    bracketType: "DOUBLE_ELIMINATION",
                    numSeeds: 2,
                    percentComplete: 100,
                    destPhases: [],
                    phaseGroups: [],
                    sets: [eliminated]
                )
            ]
        )
    }

    private func shortPrefixDocument() -> ExportDocument {
        let g8s = entrant(id: "1", name: "G8S/PWS | Alpha", tag: "Alpha", seed: 1)

        let event = EventSummary(
            id: FlexibleID("e-short-prefix"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 1,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t-short-prefix"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(
                phaseCount: 0,
                entrantCount: 1,
                standingCount: 0,
                setCount: 0,
                completedSetCount: 0,
                pendingSetCount: 0,
                startedSetCount: 0
            ),
            event: event,
            entrants: [g8s],
            standings: [],
            phases: []
        )
    }

    private func sponsorPrefixDocument() -> ExportDocument {
        let dogura = entrant(id: "1", name: "CR | Dogura", tag: "Dogura", seed: 1)
        let bonchan = entrant(id: "2", name: "Red Bull | CR Bonchan", tag: "Bonchan", seed: 2)

        let event = EventSummary(
            id: FlexibleID("e-sponsor-prefix"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 2,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t-sponsor-prefix"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(
                phaseCount: 0,
                entrantCount: 2,
                standingCount: 0,
                setCount: 0,
                completedSetCount: 0,
                pendingSetCount: 0,
                startedSetCount: 0
            ),
            event: event,
            entrants: [dogura, bonchan],
            standings: [],
            phases: []
        )
    }

    private func slashSeparatedSponsorPrefixDocument() -> ExportDocument {
        let daigo = entrant(id: "1", name: "REJECT/RC | ウメハラ/Daigo", tag: "ウメハラ/Daigo", seed: 1)

        let event = EventSummary(
            id: FlexibleID("e-slash-sponsor-prefix"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 1,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t-slash-sponsor-prefix"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(
                phaseCount: 0,
                entrantCount: 1,
                standingCount: 0,
                setCount: 0,
                completedSetCount: 0,
                pendingSetCount: 0,
                startedSetCount: 0
            ),
            event: event,
            entrants: [daigo],
            standings: [],
            phases: []
        )
    }

    private func slashDelimitedMultiWordPrefixDocument() -> ExportDocument {
        let acqua = entrant(id: "1", name: "広島TEAM iXA/HT | ACQUA", tag: "ACQUA", seed: 1)
        let other = entrant(id: "2", name: "iXA | Other", tag: "Other", seed: 2)
        return entrantOnlyDocument(
            id: "slash-delimited-multi-word-prefix",
            entrants: [acqua, other]
        )
    }

    private func multiWordSponsorPrefixDocument() -> ExportDocument {
        let fuudo = entrant(id: "1", name: "REJECT | Fuudo", tag: "Fuudo", seed: 1)
        let daigo = entrant(id: "2", name: "REJECT Beast | DAIGO", tag: "DAIGO", seed: 2)
        return entrantOnlyDocument(
            id: "multi-word-sponsor-prefix",
            entrants: [fuudo, daigo]
        )
    }

    private func pipeSpacingDocument() -> ExportDocument {
        let dogura = entrant(id: "1", name: "CR|Dogura", tag: "Dogura", seed: 1)
        let daigo = entrant(id: "2", name: "REJECT ｜ RC | ウメハラ/Daigo", tag: "ウメハラ/Daigo", seed: 2)
        return entrantOnlyDocument(
            id: "pipe-spacing",
            entrants: [dogura, daigo]
        )
    }

    private func prefixOnlyParticipantDocument() -> ExportDocument {
        let entrant = Entrant(
            id: FlexibleID("prefix-only"),
            name: "Dogura",
            initialSeedNum: 1,
            participants: [
                Participant(
                    id: FlexibleID("participant-prefix-only"),
                    gamerTag: nil,
                    prefix: "CR",
                    player: nil
                )
            ]
        )
        return entrantOnlyDocument(id: "prefix-only", entrants: [entrant])
    }

    private func shortQueryDocument() -> ExportDocument {
        let bonchan = entrant(id: "1", name: "Red Bull | CR Bonchan", tag: "Bonchan", seed: 1)
        let daigo = entrant(id: "2", name: "REJECT/RC | ウメハラ/Daigo", tag: "ウメハラ/Daigo", seed: 2)
        let redacted = entrant(id: "3", name: "Redacted", tag: "Redacted", seed: 3)
        return entrantOnlyDocument(id: "short-query", entrants: [bonchan, daigo, redacted])
    }

    private func entrantOnlyDocument(id: String, entrants: [Entrant]) -> ExportDocument {
        let event = EventSummary(
            id: FlexibleID("e-\(id)"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: entrants.count,
            type: 1,
            videogame: nil,
            tournament: TournamentSummary(id: FlexibleID("t-\(id)"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )

        return ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(
                phaseCount: 0,
                entrantCount: entrants.count,
                standingCount: 0,
                setCount: 0,
                completedSetCount: 0,
                pendingSetCount: 0,
                startedSetCount: 0
            ),
            event: event,
            entrants: entrants,
            standings: [],
            phases: []
        )
    }

    private func entrant(id: String, name: String, tag: String, seed: Int) -> Entrant {
        Entrant(
            id: FlexibleID(id),
            name: name,
            initialSeedNum: seed,
            participants: [
                Participant(
                    id: FlexibleID("participant-\(id)"),
                    gamerTag: tag,
                    prefix: nil,
                    player: Player(id: FlexibleID("player-\(id)"), gamerTag: tag, prefix: nil)
                )
            ]
        )
    }

    private func slot(entrant: Entrant?, score: Double?, placement: Int?) -> SetSlot {
        SetSlot(
            id: FlexibleID("slot-\(entrant?.id.value ?? "empty")"),
            entrant: entrant,
            standing: SlotStanding(
                placement: placement,
                stats: SlotStats(score: ScoreValue(value: FlexibleDouble(score)))
            )
        )
    }
}

private extension String {
    func section(named heading: String) -> String {
        let marker = "## \(heading)"
        guard let startRange = range(of: marker) else {
            return ""
        }
        if let nextRange = self[startRange.upperBound...].range(of: "\n## ") {
            return String(self[startRange.lowerBound..<nextRange.lowerBound])
        }
        return String(self[startRange.lowerBound...])
    }
}

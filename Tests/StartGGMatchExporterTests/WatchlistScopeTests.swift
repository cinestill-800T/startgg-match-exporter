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

    @Test("Creates markdown report")
    func createsMarkdown() {
        let scope = WatchlistScopeBuilder.build(from: sampleDocument(), watchlistText: "Tokido")
        let markdown = WatchlistScopeBuilder.markdown(from: scope)

        #expect(markdown.contains("# Street Fighter 6 Watchlist"))
        #expect(markdown.contains("### ROHTO Z! Tokido"))
        #expect(markdown.contains("| Phase | Group | Round | State | Result | Score | Opponent | Display |"))
    }

    private func sampleDocument() -> ExportDocument {
        let tokido = entrant(id: "1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
        let kakeru = entrant(id: "2", name: "IBUSHIGIN | Kakeru", tag: "Kakeru", seed: 2)
        let punk = entrant(id: "3", name: "Punk", tag: "Punk", seed: 3)

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
            summary: ExportSummary(phaseCount: 1, entrantCount: 3, standingCount: 0, setCount: 2, completedSetCount: 1, pendingSetCount: 1, startedSetCount: 0),
            event: event,
            entrants: [tokido, kakeru, punk],
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

    private func slot(entrant: Entrant, score: Double?, placement: Int?) -> SetSlot {
        SetSlot(
            id: FlexibleID("slot-\(entrant.id.value)"),
            entrant: entrant,
            standing: SlotStanding(
                placement: placement,
                stats: SlotStats(score: ScoreValue(value: FlexibleDouble(score)))
            )
        )
    }
}

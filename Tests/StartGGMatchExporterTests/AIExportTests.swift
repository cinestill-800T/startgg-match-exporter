import Foundation
import Testing
@testable import StartGGMatchExporter

@Suite("AI export")
struct AIExportTests {
    @Test("Builds normalized AI packet")
    func buildsNormalizedPacket() throws {
        let packet = AIExportBuilder.build(from: sampleDocument())

        #expect(packet.entrants.count == 3)
        #expect(packet.matches.count == 2)
        #expect(packet.players.count == 3)
        #expect(packet.phaseGroups.count == 1)

        let tokido = packet.players.first { $0.name == "ROHTO Z! Tokido" }
        #expect(tokido?.wins == 1)
        #expect(tokido?.losses == 0)
        #expect(tokido?.pendingSetCount == 1)
        #expect(tokido?.status == "active")

        let route = packet.routes.first { $0.name == "ROHTO Z! Tokido" }
        #expect(route?.knownPendingOpponents.map(\.name).contains("IBUSHIGIN | Kakeru") == true)
        #expect(route?.routeConfidence == "partial")
    }

    @Test("Encodes matches as JSON lines")
    func encodesMatchesAsJSONLines() throws {
        let packet = AIExportBuilder.build(from: sampleDocument())
        let data = try AIExportBuilder.encodeJSONLines(packet.matches)
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")

        #expect(lines.count == 2)
        #expect(lines.first?.contains("\"setId\":\"s1\"") == true)
        #expect(lines.first?.contains("\"winnerName\":\"ROHTO Z! Tokido\"") == true)
    }

    @Test("Writes analysis packet files")
    func writesAnalysisPacketFiles() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("StartGGMatchExporterTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: folder)
        }

        let files = try AIExportBuilder.writePacket(document: sampleDocument(), to: folder)
        let names = Set(files.map(\.lastPathComponent))

        #expect(names.count == 5)
        #expect(names.contains("raw.json"))
        #expect(names.contains("analysis.json"))
        #expect(names.contains("matches.jsonl"))
        #expect(names.contains("summary.md"))
        #expect(names.contains("analysis-prompt.md"))

        let analysis = try String(contentsOf: folder.appendingPathComponent("analysis.json"), encoding: .utf8)
        #expect(analysis.contains("\"players\""))
        #expect(analysis.contains("\"routes\""))
        let prompt = try String(contentsOf: folder.appendingPathComponent("analysis-prompt.md"), encoding: .utf8)
        #expect(prompt.contains("Prefer these normalized files"))
        #expect(prompt.contains("Do not assume nationality"))
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
            videogame: VideoGame(id: FlexibleID("43868"), name: "Street Fighter 6"),
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
            summary: ExportSummary(phaseCount: 1, entrantCount: 3, standingCount: 1, setCount: 2, completedSetCount: 1, pendingSetCount: 1, startedSetCount: 0),
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

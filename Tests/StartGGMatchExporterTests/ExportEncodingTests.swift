import Foundation
import Testing
@testable import StartGGMatchExporter

@Suite("Export encoding")
struct ExportEncodingTests {
    @Test("Maps set states")
    func mapsSetStates() {
        #expect(StartGGSetState.label(for: 1) == "pending")
        #expect(StartGGSetState.label(for: 2) == "started")
        #expect(StartGGSetState.label(for: 3) == "completed")
        #expect(StartGGSetState.label(for: 6) == "called")
        #expect(StartGGSetState.label(for: 99) == "unknown_99")
    }

    @Test("Encodes GraphQL variables")
    func encodesGraphQLVariables() throws {
        let body = GraphQLRequestBody(
            query: "query Test { id }",
            operationName: "Test",
            variables: ["phaseId": .string("123"), "page": .int(1), "public": .bool(true)]
        )
        let data = try JSONEncoder().encode(body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let variables = object?["variables"] as? [String: Any]
        #expect(variables?["phaseId"] as? String == "123")
        #expect(variables?["page"] as? Int == 1)
        #expect(variables?["public"] as? Bool == true)
    }

    @Test("Encodes stable export document")
    func encodesDocument() throws {
        let event = EventSummary(
            id: FlexibleID("1"),
            name: "Street Fighter 6",
            slug: "tournament/test/event/street-fighter-6",
            numEntrants: 2,
            type: 1,
            videogame: VideoGame(id: FlexibleID("43868"), name: "Street Fighter 6"),
            tournament: TournamentSummary(id: FlexibleID("9"), name: "Test", slug: "tournament/test", timezone: "UTC"),
            phases: []
        )
        let document = ExportDocument(
            schemaVersion: 1,
            fetchedAt: "2026-05-23T00:00:00Z",
            source: ExportSource(
                inputURL: "https://www.start.gg/tournament/test/event/street-fighter-6",
                eventSlug: "tournament/test/event/street-fighter-6",
                apiEndpoint: "https://api.start.gg/gql/alpha",
                apiMode: StartGGAPIMode.authenticatedFast.rawValue
            ),
            summary: ExportSummary(phaseCount: 0, entrantCount: 0, standingCount: 0, setCount: 0, completedSetCount: 0, pendingSetCount: 0, startedSetCount: 0),
            event: event,
            entrants: [],
            standings: [],
            phases: []
        )
        let data = try ExportService().encode(document)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"schemaVersion\" : 1"))
        #expect(json.contains("\"Street Fighter 6\""))
    }

    @Test("Selects API mode from token")
    func selectsAPIMode() {
        #expect(StartGGAPIMode.resolved(for: "") == .publicSafe)
        #expect(StartGGAPIMode.resolved(for: "   ") == .publicSafe)
        #expect(StartGGAPIMode.resolved(for: "abc123") == .authenticatedFast)
    }

    @Test("Uses distinct mode defaults")
    func usesModeDefaults() {
        let fast = ExportOptions.defaults(for: .authenticatedFast)
        let safe = ExportOptions.defaults(for: .publicSafe)

        #expect(fast.concurrentPageRequests > safe.concurrentPageRequests)
        #expect(fast.setPageSize > safe.setPageSize)
        #expect(fast.minimumRequestIntervalSeconds < safe.minimumRequestIntervalSeconds)
    }
}

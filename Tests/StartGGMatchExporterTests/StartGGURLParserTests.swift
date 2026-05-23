import Testing
@testable import StartGGMatchExporter

@Suite("StartGGURLParser")
struct StartGGURLParserTests {
    @Test("Parses full bracket URL")
    func parsesFullBracketURL() throws {
        let slug = try StartGGURLParser.eventSlug(
            from: "https://www.start.gg/tournament/combo-breaker-2026/event/street-fighter-6/brackets?filter=x"
        )
        #expect(slug == "tournament/combo-breaker-2026/event/street-fighter-6")
    }

    @Test("Accepts already normalized slug")
    func acceptsSlug() throws {
        let slug = try StartGGURLParser.eventSlug(from: "tournament/foo/event/street-fighter-6/brackets/123/456")
        #expect(slug == "tournament/foo/event/street-fighter-6")
    }

    @Test("Rejects non start.gg URL")
    func rejectsNonStartGG() {
        #expect(throws: StartGGURLParserError.missingEventSlug) {
            _ = try StartGGURLParser.eventSlug(from: "https://example.com/tournament/foo/event/bar")
        }
    }
}

import Foundation
import Testing
@testable import StartGGMatchExporter

@Suite("Flexible scalars")
struct FlexibleScalarTests {
    @Test("Decodes string or integer IDs")
    func decodesIDs() throws {
        struct Box: Decodable {
            var id: FlexibleID
        }

        let stringID = try JSONDecoder().decode(Box.self, from: Data(#"{"id":"123"}"#.utf8))
        let intID = try JSONDecoder().decode(Box.self, from: Data(#"{"id":123}"#.utf8))

        #expect(stringID.id.value == "123")
        #expect(intID.id.value == "123")
    }

    @Test("Decodes flexible score values")
    func decodesScores() throws {
        struct Box: Decodable {
            var score: FlexibleDouble
        }

        let intScore = try JSONDecoder().decode(Box.self, from: Data(#"{"score":2}"#.utf8))
        let stringScore = try JSONDecoder().decode(Box.self, from: Data(#"{"score":"2.5"}"#.utf8))

        #expect(intScore.score.value == 2)
        #expect(stringScore.score.value == 2.5)
    }
}

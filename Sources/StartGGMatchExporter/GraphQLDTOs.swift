import Foundation

struct GraphQLRequestBody: Encodable {
    var query: String
    var operationName: String
    var variables: [String: GraphQLValue]
}

struct GraphQLResponse<T: Decodable>: Decodable {
    var data: T?
    var errors: [GraphQLError]?
}

struct GraphQLError: Decodable, Error, CustomStringConvertible {
    var message: String

    var description: String {
        message
    }
}

struct EventSummaryData: Decodable {
    var event: EventSummary?
}

struct EventEntrantsData: Decodable {
    var event: EntrantsEvent?
}

struct EntrantsEvent: Decodable {
    var id: FlexibleID
    var entrants: EntrantConnection
}

struct EntrantConnection: Decodable {
    var pageInfo: PageInfo
    var nodes: [Entrant]
}

struct EventStandingsData: Decodable {
    var event: StandingsEvent?
}

struct StandingsEvent: Decodable {
    var id: FlexibleID
    var standings: StandingConnection
}

struct StandingConnection: Decodable {
    var pageInfo: PageInfo
    var nodes: [Standing]
}

struct PhaseSetsData: Decodable {
    var phase: PhaseSetsPhase?
}

struct PhaseSetsPhase: Decodable {
    var id: FlexibleID
    var name: String?
    var sets: SetConnection
}

struct SetConnection: Decodable {
    var pageInfo: PageInfo
    var nodes: [SetNode]
}

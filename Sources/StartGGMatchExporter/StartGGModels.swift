import Foundation

struct PageInfo: Codable, Hashable, Sendable {
    var total: Int?
    var totalPages: Int?
    var page: Int?
    var perPage: Int?

    func resolvedTotalPages(defaultPerPage: Int) -> Int {
        if let totalPages, totalPages > 0 {
            return totalPages
        }
        guard let total, total > 0 else {
            return 1
        }
        let perPageValue = perPage ?? defaultPerPage
        return max(1, Int(ceil(Double(total) / Double(max(1, perPageValue)))))
    }
}

struct VideoGame: Codable, Hashable, Sendable {
    var id: FlexibleID?
    var name: String?
}

struct TournamentSummary: Codable, Hashable, Sendable {
    var id: FlexibleID
    var name: String?
    var slug: String?
    var timezone: String?
}

struct ProgressionData: Codable, Hashable, Sendable {
    var origin: FlexibleID?
    var numProgressing: Int?
}

struct DestinationPhase: Codable, Hashable, Sendable {
    var id: FlexibleID
    var name: String?
    var progressionData: [ProgressionData]?
}

struct PhaseSummary: Codable, Hashable, Sendable {
    var id: FlexibleID
    var name: String?
    var state: String?
    var groupCount: Int?
    var bracketType: String?
    var numSeeds: Int?
    var percentComplete: Int?
    var destPhases: [DestinationPhase]?
}

struct EventSummary: Codable, Hashable, Sendable {
    var id: FlexibleID
    var name: String?
    var slug: String?
    var numEntrants: Int?
    var type: Int?
    var videogame: VideoGame?
    var tournament: TournamentSummary?
    var phases: [PhaseSummary]
}

struct Player: Codable, Hashable, Sendable {
    var id: FlexibleID?
    var gamerTag: String?
    var prefix: String?
}

struct Participant: Codable, Hashable, Sendable {
    var id: FlexibleID
    var gamerTag: String?
    var prefix: String?
    var player: Player?
}

struct Entrant: Codable, Hashable, Sendable {
    var id: FlexibleID
    var name: String?
    var initialSeedNum: Int?
    var participants: [Participant]?
}

struct Standing: Codable, Hashable, Sendable {
    var id: FlexibleID?
    var placement: Int?
    var entrant: Entrant?
}

struct PhaseGroupRef: Codable, Hashable, Sendable {
    var id: FlexibleID
    var displayIdentifier: String?
}

struct ScoreValue: Codable, Hashable, Sendable {
    var value: FlexibleDouble?
}

struct SlotStats: Codable, Hashable, Sendable {
    var score: ScoreValue?
}

struct SlotStanding: Codable, Hashable, Sendable {
    var placement: Int?
    var stats: SlotStats?
}

struct SetSlot: Codable, Hashable, Sendable {
    var id: FlexibleID?
    var entrant: Entrant?
    var standing: SlotStanding?
}

struct SetNode: Codable, Hashable, Sendable {
    var id: FlexibleID
    var identifier: String?
    var state: Int?
    var round: Int?
    var fullRoundText: String?
    var displayScore: String?
    var winnerId: FlexibleID?
    var completedAt: Int?
    var startedAt: Int?
    var updatedAt: Int?
    var phaseGroup: PhaseGroupRef?
    var slots: [SetSlot]
}

struct ExportSet: Codable, Hashable, Sendable {
    var id: FlexibleID
    var identifier: String?
    var state: Int?
    var stateLabel: String
    var round: Int?
    var fullRoundText: String?
    var displayScore: String?
    var winnerId: FlexibleID?
    var completedAt: Int?
    var startedAt: Int?
    var updatedAt: Int?
    var phaseGroup: PhaseGroupRef?
    var slots: [SetSlot]

    init(_ set: SetNode) {
        id = set.id
        identifier = set.identifier
        state = set.state
        stateLabel = StartGGSetState.label(for: set.state)
        round = set.round
        fullRoundText = set.fullRoundText
        displayScore = set.displayScore
        winnerId = set.winnerId
        completedAt = set.completedAt
        startedAt = set.startedAt
        updatedAt = set.updatedAt
        phaseGroup = set.phaseGroup
        slots = set.slots
    }
}

struct PhaseGroupSummary: Codable, Hashable, Sendable {
    var id: FlexibleID
    var displayIdentifier: String?
    var setCount: Int
    var completedSetCount: Int
    var pendingSetCount: Int
    var startedSetCount: Int
}

struct PhaseExport: Codable, Hashable, Sendable {
    var id: FlexibleID
    var name: String?
    var state: String?
    var groupCount: Int?
    var bracketType: String?
    var numSeeds: Int?
    var percentComplete: Int?
    var destPhases: [DestinationPhase]?
    var phaseGroups: [PhaseGroupSummary]
    var sets: [ExportSet]
}

struct ExportSource: Codable, Hashable, Sendable {
    var inputURL: String
    var eventSlug: String
    var apiEndpoint: String
    var apiMode: String
}

struct ExportSummary: Codable, Hashable, Sendable {
    var phaseCount: Int
    var entrantCount: Int
    var standingCount: Int
    var setCount: Int
    var completedSetCount: Int
    var pendingSetCount: Int
    var startedSetCount: Int
}

struct ExportDocument: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var fetchedAt: String
    var source: ExportSource
    var summary: ExportSummary
    var event: EventSummary
    var entrants: [Entrant]
    var standings: [Standing]
    var phases: [PhaseExport]
}

enum StartGGSetState {
    static func label(for state: Int?) -> String {
        switch state {
        case 1:
            return "pending"
        case 2:
            return "started"
        case 3:
            return "completed"
        case 6:
            return "called"
        case .some(let value):
            return "unknown_\(value)"
        case .none:
            return "unknown"
        }
    }
}

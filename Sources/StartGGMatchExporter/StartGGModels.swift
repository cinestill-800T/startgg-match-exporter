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
    var isDisqualified: Bool? = nil
}

extension Entrant {
    func mergingMissingFields(from incoming: Entrant) -> Entrant {
        Entrant(
            id: id,
            name: Self.firstNonBlank(name, incoming.name),
            initialSeedNum: initialSeedNum ?? incoming.initialSeedNum,
            participants: Self.mergedParticipants(participants, incoming.participants),
            isDisqualified: isDisqualified ?? incoming.isDisqualified
        )
    }

    private static func firstNonBlank(_ values: String?...) -> String? {
        values.first { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        } ?? nil
    }

    private static func mergedParticipants(_ existing: [Participant]?, _ incoming: [Participant]?) -> [Participant]? {
        var byId: [FlexibleID: Participant] = [:]
        var orderedIds: [FlexibleID] = []

        func upsert(_ participant: Participant) {
            if byId[participant.id] == nil {
                orderedIds.append(participant.id)
            }
            byId[participant.id] = merge(existing: byId[participant.id], incoming: participant)
        }

        existing?.forEach(upsert)
        incoming?.forEach(upsert)

        let merged = orderedIds.compactMap { byId[$0] }
        return merged.isEmpty ? nil : merged
    }

    private static func merge(existing: Participant?, incoming: Participant) -> Participant {
        guard let existing else {
            return incoming
        }
        return Participant(
            id: existing.id,
            gamerTag: firstNonBlank(existing.gamerTag, incoming.gamerTag),
            prefix: firstNonBlank(existing.prefix, incoming.prefix),
            player: merge(existing: existing.player, incoming: incoming.player)
        )
    }

    private static func merge(existing: Player?, incoming: Player?) -> Player? {
        guard existing != nil || incoming != nil else {
            return nil
        }
        return Player(
            id: existing?.id ?? incoming?.id,
            gamerTag: firstNonBlank(existing?.gamerTag, incoming?.gamerTag),
            prefix: firstNonBlank(existing?.prefix, incoming?.prefix)
        )
    }
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

    init(
        id: FlexibleID,
        identifier: String?,
        state: Int?,
        round: Int?,
        fullRoundText: String?,
        displayScore: String?,
        winnerId: FlexibleID?,
        completedAt: Int?,
        startedAt: Int?,
        updatedAt: Int?,
        phaseGroup: PhaseGroupRef?,
        slots: [SetSlot]
    ) {
        self.id = id
        self.identifier = identifier
        self.state = state
        self.round = round
        self.fullRoundText = fullRoundText
        self.displayScore = displayScore
        self.winnerId = winnerId
        self.completedAt = completedAt
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.phaseGroup = phaseGroup
        self.slots = slots
    }

    init(_ exportSet: ExportSet) {
        id = exportSet.id
        identifier = exportSet.identifier
        state = exportSet.state
        round = exportSet.round
        fullRoundText = exportSet.fullRoundText
        displayScore = exportSet.displayScore
        winnerId = exportSet.winnerId
        completedAt = exportSet.completedAt
        startedAt = exportSet.startedAt
        updatedAt = exportSet.updatedAt
        phaseGroup = exportSet.phaseGroup
        slots = exportSet.slots
    }
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

    var isCompleteExport: Bool {
        guard schemaVersion == 1,
              !source.eventSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !source.apiMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              summary.phaseCount == event.phases.count,
              phases.map(\.id) == event.phases.map(\.id) else {
            return false
        }

        let sets = phases.flatMap(\.sets)
        return summary.entrantCount == entrants.count &&
            summary.standingCount == standings.count &&
            summary.setCount == sets.count &&
            summary.completedSetCount == sets.filter { StartGGSetState.isCompleted($0.state) }.count &&
            summary.pendingSetCount == sets.filter { StartGGSetState.isPending($0.state) }.count &&
            summary.startedSetCount == sets.filter { StartGGSetState.isActive($0.state) }.count
    }
}

enum StartGGSetState: Int, Sendable {
    case pending = 1
    case started = 2
    case completed = 3
    case called = 6

    static func matches(_ state: Int?, _ expected: StartGGSetState) -> Bool {
        state == expected.rawValue
    }

    static func isCompleted(_ state: Int?) -> Bool {
        matches(state, .completed)
    }

    static func isPending(_ state: Int?) -> Bool {
        matches(state, .pending)
    }

    static func isActive(_ state: Int?) -> Bool {
        matches(state, .started) || matches(state, .called)
    }

    static func label(for state: Int?) -> String {
        guard let state else {
            return "unknown"
        }

        guard let setState = StartGGSetState(rawValue: state) else {
            return "unknown_\(state)"
        }

        switch setState {
        case .pending:
            return "pending"
        case .started:
            return "started"
        case .completed:
            return "completed"
        case .called:
            return "called"
        }
    }
}

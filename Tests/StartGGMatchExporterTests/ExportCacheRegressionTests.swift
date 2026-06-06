import Foundation
import Testing
@testable import StartGGMatchExporter

@Suite("Export cache regressions")
struct ExportCacheRegressionTests {
    @Test("Filters incomplete cache files and keeps complete ones loadable")
    func filtersIncompleteCacheFilesAndKeepsCompleteOnesLoadable() throws {
        let eventSlug = "tournament/test/event/cache-regression"
        let mode = StartGGAPIMode.publicSafe

        ExportCache.clear(eventSlug: eventSlug, mode: mode)
        defer {
            ExportCache.clear(eventSlug: eventSlug, mode: mode)
        }

        let completeDocument = makeCacheDocument(
            eventSlug: eventSlug,
            eventPhaseCount: 2,
            cachedPhaseCount: 2
        )

        let incompleteDocument = makeCacheDocument(
            eventSlug: eventSlug,
            eventPhaseCount: 2,
            cachedPhaseCount: 1
        )

        let cacheURL = cacheURL(for: eventSlug, mode: mode)

        #expect(ExportCache.save(incompleteDocument) == false)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)
        #expect(ExportCache.cachedDocument(for: eventSlug, mode: mode) == nil)

        try writeDocument(incompleteDocument, to: cacheURL)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path))
        #expect(ExportCache.cachedDocument(for: eventSlug, mode: mode) == nil)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)

        #expect(ExportCache.save(completeDocument))
        let loadedDocument = try #require(ExportCache.cachedDocument(for: eventSlug, mode: mode))
        #expect(loadedDocument == completeDocument)
        #expect(loadedDocument.isCompleteExport)
        #expect(loadedDocument.phases.count == loadedDocument.event.phases.count)
    }

    @Test("Keeps complete zero-phase cache loadable")
    func keepsCompleteZeroPhaseCacheLoadable() throws {
        let eventSlug = "tournament/test/event/zero-phase-cache"
        let mode = StartGGAPIMode.publicSafe

        ExportCache.clear(eventSlug: eventSlug, mode: mode)
        defer {
            ExportCache.clear(eventSlug: eventSlug, mode: mode)
        }

        let document = makeCacheDocument(
            eventSlug: eventSlug,
            eventPhaseCount: 0,
            cachedPhaseCount: 0
        )

        #expect(document.isCompleteExport)
        #expect(ExportCache.save(document))

        let loadedDocument = try #require(ExportCache.cachedDocument(for: eventSlug, mode: mode))
        #expect(loadedDocument == document)
        #expect(loadedDocument.phases.isEmpty)
        #expect(loadedDocument.event.phases.isEmpty)
    }

    @Test("Rejects complete-looking cache with mismatched phase IDs")
    func rejectsCompleteLookingCacheWithMismatchedPhaseIDs() throws {
        let eventSlug = "tournament/test/event/cache-phase-mismatch"
        let mode = StartGGAPIMode.publicSafe

        ExportCache.clear(eventSlug: eventSlug, mode: mode)
        defer {
            ExportCache.clear(eventSlug: eventSlug, mode: mode)
        }

        var mismatchedDocument = makeCacheDocument(
            eventSlug: eventSlug,
            eventPhaseCount: 2,
            cachedPhaseCount: 2
        )
        mismatchedDocument.phases[1].id = FlexibleID("unexpected-phase")
        let cacheURL = cacheURL(for: eventSlug, mode: mode)

        #expect(mismatchedDocument.isCompleteExport == false)
        #expect(ExportCache.save(mismatchedDocument) == false)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)

        try writeDocument(mismatchedDocument, to: cacheURL)
        #expect(ExportCache.cachedDocument(for: eventSlug, mode: mode) == nil)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)
    }

    @Test("Removes corrupt cache files")
    func removesCorruptCacheFiles() throws {
        let eventSlug = "tournament/test/event/corrupt-cache"
        let mode = StartGGAPIMode.publicSafe
        let cacheURL = cacheURL(for: eventSlug, mode: mode)

        ExportCache.clear(eventSlug: eventSlug, mode: mode)
        defer {
            ExportCache.clear(eventSlug: eventSlug, mode: mode)
        }

        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: cacheURL, options: .atomic)

        #expect(FileManager.default.fileExists(atPath: cacheURL.path))
        #expect(ExportCache.cachedDocument(for: eventSlug, mode: mode) == nil)
        #expect(FileManager.default.fileExists(atPath: cacheURL.path) == false)
    }

}

private final class MockStartGGURLProtocol: URLProtocol {
    enum ResponsePlan {
        case immediate(MockResponse)
        case delayed(MockResponse)
    }

    typealias RequestPlan = @Sendable (URLRequest) -> ResponsePlan

    private static let state = StateBox()

    static var requestPlan: RequestPlan? {
        get { state.requestPlan }
        set { state.requestPlan = newValue }
    }

    static var recordedOperationNames: [String] {
        state.lock.withLock { state.requestNames }
    }

    static func install() {
        state.lock.withLock {
            state.requestNames = []
            state.delayedResponse = nil
            state.delayedResponseReady = false
            requestPlan = nil
        }
        URLProtocol.registerClass(Self.self)
    }

    static func uninstall() {
        URLProtocol.unregisterClass(Self.self)
        state.lock.withLock {
            requestPlan = nil
            state.requestNames = []
            state.delayedResponse = nil
            state.delayedResponseReady = false
        }
    }

    static func fulfillDelayedResponse() {
        var semaphore: DispatchSemaphore?
        state.lock.withLock {
            state.delayedResponseReady = true
            semaphore = state.delayedSemaphore
        }
        semaphore?.signal()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else {
            return false
        }
        return ["api.start.gg", "www.start.gg", "start.gg"].contains(host) && request.url?.path.contains("/gql") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let responseClient = client
        let responseURL = request.url
        guard let plan = Self.requestPlan?(request) else {
            responseClient?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        if let operationName = operationName(from: request) {
            Self.state.lock.withLock {
                Self.state.requestNames.append(operationName)
            }
        }

        switch plan {
        case .immediate(let response):
            Self.deliver(response, to: responseClient, requestURL: responseURL, protocolInstance: self)
        case .delayed(let response):
            let shouldWait = Self.state.lock.withLock {
                Self.state.delayedResponse = response
                Self.state.delayedSemaphore = DispatchSemaphore(value: 0)
                return !Self.state.delayedResponseReady
            }
            if shouldWait {
                let semaphore = Self.state.lock.withLock {
                    Self.state.delayedSemaphore
                }
                semaphore?.wait()
            }
            let delayedResponse = Self.state.lock.withLock {
                let queuedResponse = Self.state.delayedResponse ?? response
                Self.state.delayedResponse = nil
                Self.state.delayedResponseReady = false
                Self.state.delayedSemaphore = nil
                return queuedResponse
            }
            Self.deliver(delayedResponse, to: responseClient, requestURL: responseURL, protocolInstance: self)
        }
    }

    override func stopLoading() {}

    private static func deliver(
        _ response: MockResponse,
        to client: URLProtocolClient?,
        requestURL: URL?,
        protocolInstance: URLProtocol
    ) {
        guard let client else {
            return
        }

        let httpResponse = HTTPURLResponse(
            url: requestURL ?? URL(string: "https://www.start.gg")!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client.urlProtocol(protocolInstance, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(protocolInstance, didLoad: response.body)
        client.urlProtocolDidFinishLoading(protocolInstance)
    }

}

private final class StateBox: @unchecked Sendable {
    let lock = NSLock()
    var requestPlan: MockStartGGURLProtocol.RequestPlan?
    var delayedResponse: MockResponse?
    var delayedResponseReady = false
    var delayedSemaphore: DispatchSemaphore?
    var requestNames: [String] = []
}

private struct MockResponse {
    var statusCode: Int
    var body: Data
}

private func mockResponse(statusCode: Int = 200, body: String) -> MockResponse {
    MockResponse(statusCode: statusCode, body: Data(body.utf8))
}

private func operationName(from request: URLRequest) -> String? {
    guard let body = requestBodyData(from: request),
          let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        return nil
    }
    return object["operationName"] as? String
}

private func requestBodyData(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 4_096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read < 0 {
            return nil
        }
        if read == 0 {
            break
        }
        data.append(buffer, count: read)
    }

    return data
}

private func makeEventSummaryResponse(eventSlug: String, phasePercentComplete: Int) -> String {
    """
    {
      "data": {
        "event": {
          "id": "event-1",
          "name": "Bracket Regression",
          "slug": "\(eventSlug)",
          "numEntrants": 1,
          "type": 1,
          "videogame": { "id": "43868", "name": "Street Fighter 6" },
          "tournament": {
            "id": "tournament-1",
            "name": "Test Tournament",
            "slug": "tournament/test",
            "timezone": "UTC"
          },
          "phases": [
            {
              "id": "phase-1",
              "name": "Top 8",
              "state": "ACTIVE",
              "groupCount": 1,
              "bracketType": "DOUBLE_ELIMINATION",
              "numSeeds": 8,
              "percentComplete": \(phasePercentComplete),
              "destPhases": []
            }
          ]
        }
      }
    }
    """
}

private func makeEventEntrantsResponse() -> String {
    """
    {
      "data": {
        "event": {
          "id": "event-1",
          "entrants": {
            "pageInfo": { "totalPages": 1, "page": 1, "perPage": 100 },
            "nodes": [
              {
                "id": "entrant-1",
                "name": "ROHTO Z! Tokido",
                "initialSeedNum": 1,
                "participants": [
                  {
                    "id": "participant-1",
                    "gamerTag": "Tokido",
                    "prefix": null,
                    "player": {
                      "id": "player-1",
                      "gamerTag": "Tokido",
                      "prefix": null
                    }
                  }
                ]
              }
            ]
          }
        }
      }
    }
    """
}

private func makeEventStandingsResponse() -> String {
    """
    {
      "data": {
        "event": {
          "id": "event-1",
          "standings": {
            "pageInfo": { "totalPages": 1, "page": 1, "perPage": 100 },
            "nodes": [
              {
                "id": "standing-1",
                "placement": 1,
                "entrant": {
                  "id": "entrant-1",
                  "name": "ROHTO Z! Tokido",
                  "initialSeedNum": 1,
                  "participants": [
                    {
                      "id": "participant-1",
                      "gamerTag": "Tokido",
                      "prefix": null,
                      "player": {
                        "id": "player-1",
                        "gamerTag": "Tokido",
                        "prefix": null
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      }
    }
    """
}

private func makePhaseSetsResponse(setId: String, state: Int, winnerId: String?, completedAt: Int?) -> String {
    let winnerIdJSON = winnerId.map { "\"\($0)\"" } ?? "null"
    let completedAtJSON = completedAt.map(String.init) ?? "null"
    return """
    {
      "data": {
        "phase": {
          "id": "phase-1",
          "name": "Top 8",
          "sets": {
            "pageInfo": { "totalPages": 1, "page": 1, "perPage": 50 },
            "nodes": [
              {
                "id": "\(setId)",
                "identifier": "A",
                "state": \(state),
                "round": 1,
                "fullRoundText": "Winners Round 1",
                "displayScore": "ROHTO Z! Tokido 2 - Opponent 0",
                "winnerId": \(winnerIdJSON),
                "completedAt": \(completedAtJSON),
                "startedAt": null,
                "updatedAt": 1234,
                "phaseGroup": { "id": "phase-group-1", "displayIdentifier": "A101" },
                "slots": [
                  {
                    "id": "slot-entrant-1",
                    "entrant": {
                      "id": "entrant-1",
                      "name": "ROHTO Z! Tokido",
                      "initialSeedNum": 1,
                      "participants": [
                        {
                          "id": "participant-1",
                          "gamerTag": "Tokido",
                          "prefix": null,
                          "player": {
                            "id": "player-1",
                            "gamerTag": "Tokido",
                            "prefix": null
                          }
                        }
                      ]
                    },
                    "standing": {
                      "placement": 1,
                      "stats": { "score": { "value": 2 } }
                    }
                  },
                  {
                    "id": "slot-entrant-2",
                    "entrant": {
                      "id": "entrant-2",
                      "name": "Opponent",
                      "initialSeedNum": 2,
                      "participants": [
                        {
                          "id": "participant-2",
                          "gamerTag": "Opponent",
                          "prefix": null,
                          "player": {
                            "id": "player-2",
                            "gamerTag": "Opponent",
                            "prefix": null
                          }
                        }
                      ]
                    },
                    "standing": {
                      "placement": 2,
                      "stats": { "score": { "value": 0 } }
                    }
                  }
                ]
              }
            ]
          }
        }
      }
    }
    """
}

private func makeDocument(
    eventSlug: String,
    phaseSets: [ExportSet],
    phasePercentComplete: Int
) -> ExportDocument {
    let tokido = makeEntrant(id: "entrant-1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
    let event = EventSummary(
        id: FlexibleID("event-1"),
        name: "Bracket Regression",
        slug: eventSlug,
        numEntrants: 1,
        type: 1,
        videogame: VideoGame(id: FlexibleID("43868"), name: "Street Fighter 6"),
        tournament: TournamentSummary(id: FlexibleID("tournament-1"), name: "Test Tournament", slug: "tournament/test", timezone: "UTC"),
        phases: [
            PhaseSummary(
                id: FlexibleID("phase-1"),
                name: "Top 8",
                state: "ACTIVE",
                groupCount: 1,
                bracketType: "DOUBLE_ELIMINATION",
                numSeeds: 8,
                percentComplete: phasePercentComplete,
                destPhases: []
            )
        ]
    )

    return ExportDocument(
        schemaVersion: 1,
        fetchedAt: "2026-05-23T00:00:00Z",
        source: ExportSource(
            inputURL: "https://www.start.gg/\(eventSlug)",
            eventSlug: eventSlug,
            apiEndpoint: StartGGAPIMode.publicSafe.endpoint.absoluteString,
            apiMode: StartGGAPIMode.publicSafe.rawValue
        ),
        summary: ExportSummary(
            phaseCount: 1,
            entrantCount: 1,
            standingCount: 1,
            setCount: phaseSets.count,
            completedSetCount: phaseSets.filter { StartGGSetState.isCompleted($0.state) }.count,
            pendingSetCount: phaseSets.filter { StartGGSetState.isPending($0.state) }.count,
            startedSetCount: phaseSets.filter { StartGGSetState.isActive($0.state) }.count
        ),
        event: event,
        entrants: [tokido],
        standings: [
            Standing(id: FlexibleID("standing-1"), placement: 1, entrant: tokido)
        ],
        phases: [
            PhaseExport(
                id: FlexibleID("phase-1"),
                name: "Top 8",
                state: "ACTIVE",
                groupCount: 1,
                bracketType: "DOUBLE_ELIMINATION",
                numSeeds: 8,
                percentComplete: phasePercentComplete,
                destPhases: [],
                phaseGroups: [
                    PhaseGroupSummary(
                        id: FlexibleID("phase-group-1"),
                        displayIdentifier: "A101",
                        setCount: phaseSets.count,
                        completedSetCount: phaseSets.filter { StartGGSetState.isCompleted($0.state) }.count,
                        pendingSetCount: phaseSets.filter { StartGGSetState.isPending($0.state) }.count,
                        startedSetCount: phaseSets.filter { StartGGSetState.isActive($0.state) }.count
                    )
                ],
                sets: phaseSets
            )
        ]
    )
}

private func makeCacheDocument(
    eventSlug: String,
    eventPhaseCount: Int,
    cachedPhaseCount: Int
) -> ExportDocument {
    let phases: [PhaseSummary]
    if eventPhaseCount > 0 {
        phases = (1...eventPhaseCount).map { index in
            PhaseSummary(
                id: FlexibleID("phase-\(index)"),
                name: "Phase \(index)",
                state: "ACTIVE",
                groupCount: 1,
                bracketType: "DOUBLE_ELIMINATION",
                numSeeds: 8,
                percentComplete: index <= cachedPhaseCount ? 100 : 0,
                destPhases: []
            )
        }
    } else {
        phases = []
    }

    let exportedPhases = phases.prefix(cachedPhaseCount).enumerated().map { index, phase in
        let setSuffix = index + 1
        let phaseGroupID = "phase-group-\(setSuffix)"
        let exportSet = makeExportSet(
            id: "set-\(setSuffix)",
            state: 3,
            winnerId: FlexibleID("entrant-1"),
            completedAt: 1234
        )
        return PhaseExport(
            id: phase.id,
            name: phase.name,
            state: phase.state,
            groupCount: phase.groupCount,
            bracketType: phase.bracketType,
            numSeeds: phase.numSeeds,
            percentComplete: phase.percentComplete,
            destPhases: phase.destPhases,
            phaseGroups: [
                PhaseGroupSummary(
                    id: FlexibleID(phaseGroupID),
                    displayIdentifier: "A\(setSuffix)01",
                    setCount: 1,
                    completedSetCount: 1,
                    pendingSetCount: 0,
                    startedSetCount: 0
                )
            ],
            sets: [exportSet]
        )
    }

    return ExportDocument(
        schemaVersion: 1,
        fetchedAt: "2026-05-23T00:00:00Z",
        source: ExportSource(
            inputURL: "https://www.start.gg/\(eventSlug)",
            eventSlug: eventSlug,
            apiEndpoint: StartGGAPIMode.publicSafe.endpoint.absoluteString,
            apiMode: StartGGAPIMode.publicSafe.rawValue
        ),
        summary: ExportSummary(
            phaseCount: eventPhaseCount,
            entrantCount: 1,
            standingCount: 1,
            setCount: cachedPhaseCount,
            completedSetCount: cachedPhaseCount,
            pendingSetCount: 0,
            startedSetCount: 0
        ),
        event: EventSummary(
            id: FlexibleID("event-1"),
            name: "Bracket Regression",
            slug: eventSlug,
            numEntrants: 1,
            type: 1,
            videogame: VideoGame(id: FlexibleID("43868"), name: "Street Fighter 6"),
            tournament: TournamentSummary(
                id: FlexibleID("tournament-1"),
                name: "Test Tournament",
                slug: "tournament/test",
                timezone: "UTC"
            ),
            phases: phases
        ),
        entrants: [
            makeEntrant(id: "entrant-1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
        ],
        standings: [
            Standing(
                id: FlexibleID("standing-1"),
                placement: 1,
                entrant: makeEntrant(id: "entrant-1", name: "ROHTO Z! Tokido", tag: "Tokido", seed: 1)
            )
        ],
        phases: Array(exportedPhases)
    )
}

private func writeDocument(_ document: ExportDocument, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try ExportService().encode(document)
    try data.write(to: url, options: .atomic)
}

private func cacheURL(for eventSlug: String, mode: StartGGAPIMode) -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let filename = "\(safeFilename(eventSlug))-\(mode.rawValue).json"
    return support.appendingPathComponent("StartGGMatchExporter", isDirectory: true).appendingPathComponent(filename)
}

private func safeFilename(_ value: String) -> String {
    value
        .unicodeScalars
        .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
        .joined()
        .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        .lowercased()
}

private func makeExportSet(
    id: String,
    state: Int,
    winnerId: FlexibleID?,
    completedAt: Int?
) -> ExportSet {
    ExportSet(
        SetNode(
            id: FlexibleID(id),
            identifier: "A",
            state: state,
            round: 1,
            fullRoundText: "Winners Round 1",
            displayScore: "ROHTO Z! Tokido 2 - Opponent 0",
            winnerId: winnerId,
            completedAt: completedAt,
            startedAt: nil,
            updatedAt: 1234,
            phaseGroup: PhaseGroupRef(id: FlexibleID("phase-group-1"), displayIdentifier: "A101"),
            slots: [
                makeSlot(
                    id: "slot-entrant-1",
                    entrantID: "entrant-1",
                    gamerTag: "Tokido",
                    seed: 1,
                    score: 2,
                    placement: 1
                ),
                makeSlot(
                    id: "slot-entrant-2",
                    entrantID: "entrant-2",
                    gamerTag: "Opponent",
                    seed: 2,
                    score: 0,
                    placement: 2
                )
            ]
        )
    )
}

private func makeEntrant(id: String, name: String, tag: String, seed: Int) -> Entrant {
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

private func makeSlot(
    id: String,
    entrantID: String,
    gamerTag: String,
    seed: Int,
    score: Double,
    placement: Int
) -> SetSlot {
    SetSlot(
        id: FlexibleID(id),
        entrant: makeEntrant(id: entrantID, name: gamerTag == "Tokido" ? "ROHTO Z! Tokido" : "Opponent", tag: gamerTag, seed: seed),
        standing: SlotStanding(
            placement: placement,
            stats: SlotStats(score: ScoreValue(value: FlexibleDouble(score)))
        )
    )
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

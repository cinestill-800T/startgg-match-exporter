import Testing
@testable import StartGGMatchExporter

@Suite("Export configuration")
struct ExportConfigurationTests {
    @Test("Default config contains user-facing notes")
    func defaultConfigContainsNotes() {
        let config = ExportConfiguration.defaultConfiguration

        #expect(!config._notes.isEmpty)
        #expect(!config.officialAPI._notes.isEmpty)
        #expect(!config.publicAPI._notes.isEmpty)
    }

    @Test("Default official configuration stays below the documented average rate")
    func defaultOfficialConfigurationStaysBelowRateLimit() {
        let options = ExportConfiguration.defaultConfiguration.options(for: .authenticatedFast)

        #expect(options.minimumRequestIntervalSeconds >= 0.8)
        #expect(options.concurrentPageRequests == 1)
        #expect(options.setPageSize <= 10)
        #expect(options.standingPageSize <= 10)
    }

    @Test("Config clamps unsafe values")
    func configClampsUnsafeValues() {
        let apiConfig = ExportAPIConfiguration(
            _notes: [],
            setPageSize: 1_000,
            entrantPageSize: 1_000,
            standingPageSize: 1_000,
            minimumRequestIntervalSeconds: 0,
            concurrentRequests: 99,
            maxRetries: 99,
            rateLimitInitialPauseSeconds: 1,
            rateLimitPauseIncrementSeconds: 1,
            rateLimitMaxPauseSeconds: 1_000,
            serverErrorInitialPauseSeconds: 0,
            serverErrorMaxPauseSeconds: 1_000
        )

        let options = apiConfig.options()

        #expect(options.setPageSize == 100)
        #expect(options.entrantPageSize == 200)
        #expect(options.standingPageSize == 200)
        #expect(options.minimumRequestIntervalSeconds == 0.2)
        #expect(options.concurrentPageRequests == 4)
        #expect(options.retryPolicy.maxRetries == 20)
    }
}

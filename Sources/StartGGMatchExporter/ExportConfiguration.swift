import Foundation

struct ExportConfiguration: Codable, Sendable, Equatable {
    var _notes: [String]
    var officialAPI: ExportAPIConfiguration
    var publicAPI: ExportAPIConfiguration

    static let defaultConfiguration = ExportConfiguration(
        _notes: [
            "StartGG Match Exporter は Fetch Data を開始するたびにこの config.json を読み込みます。アプリの再起動は不要です。",
            "初期値は速度優先です。start.gg が公開している平均レート制限 80 requests/min の直前を狙っています。",
            "HTTP 429 が出る場合は minimumRequestIntervalSeconds を大きくするか concurrentRequests を小さくしてください。その後、Use local cache を有効にしたまま Fetch Data を実行すると、取得済み部分を再利用できます。",
            "Refresh はローカルキャッシュを無視して start.gg から取り直したい場合だけ使ってください。大会進行に合わせた通常更新では Fetch Data の利用を推奨します。",
            "Page size は GraphQL の複雑度に強く影響します。リクエスト間隔が十分でも、page size を上げすぎると 1000 objects 制限で失敗することがあります。",
            "この初期値で 429 や 1000 objects 制限が出る場合は、minimumRequestIntervalSeconds を 0.9 から 1.2 へ上げる、または setPageSize / standingPageSize を 30 以下へ下げてください。"
        ],
        officialAPI: ExportAPIConfiguration(
            _notes: [
                "API Token が入力されている場合に使われる設定です。公式 start.gg GraphQL API に Authorization ヘッダー付きでアクセスします。",
                "setPageSize は試合データの 1 ページあたり取得件数です。45 は 1000 objects 制限の手前を狙う攻めた値です。失敗する場合は 30、20、10 の順に下げてください。",
                "entrantPageSize は参加者一覧の 1 ページあたり取得件数です。SF6 のような 1 人参加イベントでは 150 まで上げても比較的通りやすい想定です。",
                "standingPageSize は順位表の 1 ページあたり取得件数です。45 は速度優先の値です。1000 objects 制限が出る場合はここも 30 以下へ下げてください。",
                "minimumRequestIntervalSeconds は速度調整の中心です。0.76 秒は約 79 requests/min で、公開されている平均制限 80 requests/min の直前です。",
                "concurrentRequests は同時に取得するページ数です。2 にすると通信待ちを重ねられるため速くなりますが、429 が出る場合は 1 に戻してください。",
                "maxRetries は 429 や 5xx が返ったときに何回まで待って再試行するかです。増やすほど失敗しにくくなりますが、429 中は完了まで長く待つ可能性があります。",
                "rateLimitInitialPauseSeconds / rateLimitPauseIncrementSeconds / rateLimitMaxPauseSeconds は HTTP 429 の待機時間です。429 が頻発する場合は request interval を上げる方が根本対策になります。",
                "serverErrorInitialPauseSeconds / serverErrorMaxPauseSeconds は start.gg 側の一時的な 5xx エラーに対する待機時間です。通常は変更不要です。"
            ],
            setPageSize: 45,
            entrantPageSize: 150,
            standingPageSize: 45,
            minimumRequestIntervalSeconds: 0.76,
            concurrentRequests: 2,
            maxRetries: 8,
            rateLimitInitialPauseSeconds: 45,
            rateLimitPauseIncrementSeconds: 30,
            rateLimitMaxPauseSeconds: 180,
            serverErrorInitialPauseSeconds: 1.5,
            serverErrorMaxPauseSeconds: 30
        ),
        publicAPI: ExportAPIConfiguration(
            _notes: [
                "API Token 欄が空の場合に使われる設定です。start.gg の公開 Web 用 GraphQL エンドポイントを利用します。",
                "Public Safe Mode はトークン不要で便利ですが、大型大会を継続的に取得する用途では公式 API Token ありの Authenticated Safe Mode を推奨します。",
                "Public Safe Mode の初期値も速度寄りですが、公開エンドポイントは公式 API より不安定です。失敗する場合は minimumRequestIntervalSeconds を 1.2 以上へ上げてください。",
                "concurrentRequests は 1 のままです。公開エンドポイントでは同時実行を増やすメリットより失敗リスクが大きくなります。",
                "公開エンドポイントが遅い、または失敗する場合は数分待つか、API Token を入力して Authenticated Safe Mode に切り替えてください。",
                "Public Safe Mode でも cache は有効です。大会進行に合わせた再取得では Use local cache をオンにしたまま Fetch Data を使ってください。"
            ],
            setPageSize: 75,
            entrantPageSize: 200,
            standingPageSize: 100,
            minimumRequestIntervalSeconds: 0.76,
            concurrentRequests: 1,
            maxRetries: 6,
            rateLimitInitialPauseSeconds: 60,
            rateLimitPauseIncrementSeconds: 45,
            rateLimitMaxPauseSeconds: 240,
            serverErrorInitialPauseSeconds: 2,
            serverErrorMaxPauseSeconds: 45
        )
    )

    private static let previousBalancedOfficialAPI = ExportAPIConfiguration(
        _notes: [],
        setPageSize: 10,
        entrantPageSize: 25,
        standingPageSize: 10,
        minimumRequestIntervalSeconds: 1.2,
        concurrentRequests: 1,
        maxRetries: 8,
        rateLimitInitialPauseSeconds: 45,
        rateLimitPauseIncrementSeconds: 30,
        rateLimitMaxPauseSeconds: 180,
        serverErrorInitialPauseSeconds: 1.5,
        serverErrorMaxPauseSeconds: 30
    )

    private static let previousBalancedPublicAPI = ExportAPIConfiguration(
        _notes: [],
        setPageSize: 50,
        entrantPageSize: 100,
        standingPageSize: 100,
        minimumRequestIntervalSeconds: 0.8,
        concurrentRequests: 1,
        maxRetries: 6,
        rateLimitInitialPauseSeconds: 60,
        rateLimitPauseIncrementSeconds: 45,
        rateLimitMaxPauseSeconds: 240,
        serverErrorInitialPauseSeconds: 2,
        serverErrorMaxPauseSeconds: 45
    )

    func options(for mode: StartGGAPIMode) -> ExportOptions {
        switch mode {
        case .authenticatedFast:
            officialAPI.options()
        case .publicSafe:
            publicAPI.options()
        }
    }

    func refreshingNotes() -> ExportConfiguration {
        var configuration = self
        if officialAPI.hasSameTuning(as: Self.previousBalancedOfficialAPI) {
            configuration.officialAPI = Self.defaultConfiguration.officialAPI
        }
        if publicAPI.hasSameTuning(as: Self.previousBalancedPublicAPI) {
            configuration.publicAPI = Self.defaultConfiguration.publicAPI
        }
        configuration._notes = Self.defaultConfiguration._notes
        configuration.officialAPI._notes = Self.defaultConfiguration.officialAPI._notes
        configuration.publicAPI._notes = Self.defaultConfiguration.publicAPI._notes
        return configuration
    }
}

struct ExportAPIConfiguration: Codable, Sendable, Equatable {
    var _notes: [String]
    var setPageSize: Int
    var entrantPageSize: Int
    var standingPageSize: Int
    var minimumRequestIntervalSeconds: TimeInterval
    var concurrentRequests: Int
    var maxRetries: Int
    var rateLimitInitialPauseSeconds: TimeInterval
    var rateLimitPauseIncrementSeconds: TimeInterval
    var rateLimitMaxPauseSeconds: TimeInterval
    var serverErrorInitialPauseSeconds: TimeInterval
    var serverErrorMaxPauseSeconds: TimeInterval

    func options() -> ExportOptions {
        ExportOptions(
            setPageSize: clamp(setPageSize, min: 1, max: 100),
            entrantPageSize: clamp(entrantPageSize, min: 1, max: 200),
            standingPageSize: clamp(standingPageSize, min: 1, max: 200),
            minimumRequestIntervalSeconds: max(0.2, min(minimumRequestIntervalSeconds, 30)),
            concurrentPageRequests: clamp(concurrentRequests, min: 1, max: 4),
            retryPolicy: StartGGRetryPolicy(
                maxRetries: maxRetries,
                rateLimitInitialPauseSeconds: rateLimitInitialPauseSeconds,
                rateLimitPauseIncrementSeconds: rateLimitPauseIncrementSeconds,
                rateLimitMaxPauseSeconds: rateLimitMaxPauseSeconds,
                serverErrorInitialPauseSeconds: serverErrorInitialPauseSeconds,
                serverErrorMaxPauseSeconds: serverErrorMaxPauseSeconds
            ).clamped()
        )
    }

    private func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.max(minimum, Swift.min(value, maximum))
    }

    fileprivate func hasSameTuning(as other: ExportAPIConfiguration) -> Bool {
        setPageSize == other.setPageSize &&
            entrantPageSize == other.entrantPageSize &&
            standingPageSize == other.standingPageSize &&
            minimumRequestIntervalSeconds == other.minimumRequestIntervalSeconds &&
            concurrentRequests == other.concurrentRequests &&
            maxRetries == other.maxRetries &&
            rateLimitInitialPauseSeconds == other.rateLimitInitialPauseSeconds &&
            rateLimitPauseIncrementSeconds == other.rateLimitPauseIncrementSeconds &&
            rateLimitMaxPauseSeconds == other.rateLimitMaxPauseSeconds &&
            serverErrorInitialPauseSeconds == other.serverErrorInitialPauseSeconds &&
            serverErrorMaxPauseSeconds == other.serverErrorMaxPauseSeconds
    }
}

enum ExportConfigurationStore {
    struct LoadResult: Sendable {
        var configuration: ExportConfiguration
        var url: URL?
        var warning: String?
    }

    private static let folderName = "StartGGMatchExporter"
    private static let filename = "config.json"

    static func loadOrCreate() -> LoadResult {
        guard let url = configURL else {
            return LoadResult(
                configuration: .defaultConfiguration,
                url: nil,
                warning: "Application Support フォルダを利用できないため、内蔵の初期値を使います。"
            )
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try writeDefault(to: url)
            } catch {
                return LoadResult(
                    configuration: .defaultConfiguration,
                    url: url,
                    warning: "config.json を作成できませんでした: \(error.localizedDescription)"
                )
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let configuration = try JSONDecoder().decode(ExportConfiguration.self, from: data)
            let refreshedConfiguration = configuration.refreshingNotes()
            if refreshedConfiguration != configuration {
                try? write(refreshedConfiguration, to: url)
            }
            return LoadResult(configuration: refreshedConfiguration, url: url, warning: nil)
        } catch {
            return LoadResult(
                configuration: .defaultConfiguration,
                url: url,
                warning: "config.json を読み込めませんでした。JSON を修正または削除するまで、内蔵の初期値を使います。\(error.localizedDescription)"
            )
        }
    }

    static var configURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return support.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(filename)
    }

    private static func writeDefault(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try write(.defaultConfiguration, to: url)
    }

    private static func write(_ configuration: ExportConfiguration, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(configuration)
        try data.write(to: url, options: .atomic)
    }
}

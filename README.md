# StartGG Match Exporter

[![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![Release](https://img.shields.io/badge/release-v2.5.3-green.svg)](https://github.com/cinestill-800T/startgg-match-exporter/releases/tag/v2.5.3)
[![start.gg API](https://img.shields.io/badge/start.gg-GraphQL%20API-ff6694.svg)](https://developer.start.gg/docs/intro/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

StartGG Match Exporter is a small macOS SwiftUI app that exports a start.gg event into JSON for downstream analysis.

It does not infer player nationality, predict matches, or call external services beyond start.gg. It focuses on collecting comprehensive structured data:

- event metadata
- phases and progression metadata
- entrants
- standings
- all currently available sets, including completed and pending sets
- set slots, scores, winner IDs, phase group IDs, and display scores

## Requirements

- macOS 13 or later
- Xcode 26.5 or compatible Swift 6 toolchain
- optional start.gg API token

Create a token in start.gg Developer Settings and paste it into the app to enable authenticated official API access. The token is stored in the macOS Keychain.

## Usage

1. Download `StartGGMatchExporter-macOS-release.zip` from the GitHub Releases page.
2. Unzip it and open `StartGGMatchExporter.app`.
3. Paste a start.gg event URL, for example `https://www.start.gg/tournament/.../event/street-fighter-6`.
4. Paste your start.gg API token for authenticated official API access, or leave it blank for Public Safe Mode.
5. Click `Fetch`, or `Refresh` when you want to ignore local cache and fetch fresh data.
6. Paste Watchlist names, then click `Save Markdown Report` or enable `Auto-overwrite Markdown Report`.

The exporter accepts normal event URLs and bracket URLs. It normalizes them to a start.gg event slug internally.

## Connection Modes

The app chooses the mode automatically:

- `Authenticated Safe Mode`: enabled when an API token is present. Uses the official API, small page sizes, sequential reads, request throttling, and longer retry waits for rate limits.
- `Public Safe Mode`: enabled when the token field is blank. Uses public web data with conservative pacing. This is convenient for quick checks, but the official API is preferred for sustained exports.

## Watchlist Export

After fetching an event, paste player names into the Watchlist search field. The app matches those names against entrant names, gamer tags, and common prefix forms, then exports only the related sets. Add optional exclusion words in the lower Watchlist field to remove matching entrants from the focused export.

Watchlist outputs:

- focused JSON for structured processing
- Markdown report for quick reading

Enable `Auto-overwrite Markdown Report` to write the watchlist Markdown automatically after every successful manual fetch, manual refresh, or background sync. The file is overwritten at:

```text
~/Downloads/<event-name>-watchlist.md
```

Matching is mechanical and transparent. The app does not infer nationality, team affiliation, or tournament outcomes beyond the set data returned by start.gg.

The Markdown status badge distinguishes entrants as follows:

- `開始待ち`: the entrant has a pending first set and no completed sets yet
- `生存中`: the entrant is active, waiting after a completed set, or most recently won
- `DQ`: start.gg marks the entrant or the entrant's latest lost set as disqualified
- `敗退済み`: the entrant's latest completed result is a loss and no unfinished set remains

Badge colors use separate visual families so player status and bracket side remain easy to distinguish:

- Status: `開始待ち` is purple, `生存中` is green, `DQ` is dark red, and `敗退済み` is slate
- Bracket: `Winners` is blue and `Losers` is burnt orange
- Unknown values use neutral gray

## Analysis Pack

After fetching an event, choose a JSON Pack mode and click `Save JSON Pack` to create a folder in Downloads. Hover the output mode selector or the help icon in the app to read the explanation for each mode.

Modes:

- `Full（全件）`: writes the complete compatibility pack, including `raw.json` and all match rows.
- `Live Focus（進行中中心）`: omits `raw.json`, keeps unfinished/active matches, and adds recent completed context for active players.
- `Compact（軽量）`: omits `raw.json` and completed match detail rows, keeping compact history summaries plus current unfinished matches.
- `Watchlist Focus（指定選手）`: requires Watchlist names and writes only those players' current/recent match context.

Full mode creates five files:

- `raw.json`: the complete original export
- `analysis.json`: the primary normalized packet, including metadata, entrants, standings, matches, players, phase groups, and routes
- `matches.jsonl`: one normalized match per line
- `summary.md`: compact human-readable overview
- `analysis-prompt.md`: guidance for external AI analysis

`Save JSON Pack` is the analysis-pack action. `raw.json` keeps the complete raw export in Full mode, while `analysis.json` and `matches.jsonl` provide the AI-friendly normalized view. Lightweight modes intentionally do not write `raw.json`, so uploading the output folder to an AI assistant does not accidentally include the full tournament dump. Route data is intentionally marked as partial because start.gg set data does not always include explicit prerequisite-slot graph edges. Use it as a prediction aid, not as a confirmed bracket path.

## Local Cache

The app caches complete exports in Application Support and reuses them for the same event URL and connection mode. Normal `Fetch` uses a valid complete cache as a base, skips phases whose cached sets are all completed, and updates the remaining phases. Incomplete or corrupted cache files are ignored and removed so stale partial data cannot be displayed or exported.

Use `Refresh` to ignore the cache and fetch fresh data from start.gg.

## Configuration

The first fetch creates a local configuration file:

```text
~/Library/Application Support/StartGGMatchExporter/config.json
```

The `Config` button reveals this file in Finder. It includes explanatory `_notes` fields and can tune:

- set, entrant, and standing page sizes
- minimum request interval
- concurrent page requests
- retry count
- HTTP 429 and 5xx retry waits

For authenticated mode, the default request interval is `0.76` seconds, roughly 79 requests per minute. This is intentionally close to start.gg's documented average limit of 80 requests per minute. The default page sizes are also speed-oriented: `setPageSize` 45, `entrantPageSize` 150, and `standingPageSize` 45. If HTTP 429 appears, increase the interval to `0.9` or `1.2`, or return `concurrentRequests` to `1`. If a 1000 object complexity error appears, lower `setPageSize` and `standingPageSize`.

The generated `_notes` text is written in Japanese. If an older English config file already exists, the app refreshes only the explanatory `_notes` while preserving your numeric tuning values.

The app also remembers the last event URL, Watchlist search text, and Watchlist exclusion text you entered and restores them on the next launch. Save dialogs default to the macOS Downloads folder.

## JSON Shape

The output root contains:

- `schemaVersion`
- `fetchedAt`
- `source`
- `summary`
- `event`
- `entrants`
- `standings`
- `phases`

Each phase contains its set list and a phase group summary derived from the set data.

## Development

Run tests:

```bash
swift test
```

Build app bundles:

```bash
Scripts/build_app.sh all
```

The script places built artifacts directly under:

- `debug/`
- `release/`

Built app bundles and zip files are ignored by Git. When a GitHub Release is published, GitHub Actions builds the release app and uploads `StartGGMatchExporter-macOS-release.zip` to that release automatically. The same workflow can be rerun manually with `workflow_dispatch` by entering an existing release tag.

## API Notes

This app uses the official start.gg GraphQL API endpoint:

```text
https://api.start.gg/gql/alpha
```

start.gg documents an average rate limit of 80 requests per 60 seconds and a 1000 object maximum per request. The app throttles requests, uses conservative page sizes, and writes complete local cache files so repeated tournament updates avoid re-fetching completed phases.

## License

MIT

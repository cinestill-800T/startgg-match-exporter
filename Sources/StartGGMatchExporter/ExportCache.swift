import Foundation

enum ExportCache {
    private static let folderName = "StartGGMatchExporter"

    static func cachedDocument(for eventSlug: String, mode: StartGGAPIMode) -> ExportDocument? {
        guard let url = cacheURL(for: eventSlug, mode: mode), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let document = try JSONDecoder().decode(ExportDocument.self, from: data)
            guard document.isCompleteExport else {
                removeCache(at: url)
                return nil
            }
            return document
        } catch {
            removeCache(at: url)
            return nil
        }
    }

    @discardableResult
    static func save(_ document: ExportDocument) -> Bool {
        guard document.isCompleteExport else {
            return false
        }
        guard let url = cacheURL(for: document.source.eventSlug, mode: StartGGAPIMode(rawValue: document.source.apiMode) ?? .publicSafe) else {
            return false
        }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try ExportService().encode(document)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func clear(eventSlug: String, mode: StartGGAPIMode) {
        guard let url = cacheURL(for: eventSlug, mode: mode) else {
            return
        }
        removeCache(at: url)
    }

    private static func removeCache(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func cacheURL(for eventSlug: String, mode: StartGGAPIMode) -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let filename = "\(safeFilename(eventSlug))-\(mode.rawValue).json"
        return support.appendingPathComponent(folderName, isDirectory: true).appendingPathComponent(filename)
    }

    private static func safeFilename(_ value: String) -> String {
        value
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
            .joined()
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()
    }
}

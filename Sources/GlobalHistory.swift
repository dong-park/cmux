import Foundation

// MARK: - Global History

/// App-wide, append-only history that persists to ~/Documents/cmux/history.json.
/// Survives app deletion, workspace closure, and session resets.
/// Used by dev-flow skills to accumulate patterns across features and projects.
enum GlobalHistory {

    // MARK: - Model

    struct Entry: Codable, Equatable, Identifiable {
        let id: UUID
        let type: String            // "decision", "task", "feedback", "pattern", "phase", "note"
        let phase: String?          // "spec", "plan", "build", "test", "review", "ship", "feedback"
        let summary: String
        let detail: String?
        let tags: [String]
        let cwd: String?            // project directory for filtering
        let workspaceName: String?
        let timestamp: Date

        init(
            type: String,
            phase: String? = nil,
            summary: String,
            detail: String? = nil,
            tags: [String] = [],
            cwd: String? = nil,
            workspaceName: String? = nil,
            timestamp: Date = Date()
        ) {
            self.id = UUID()
            self.type = type
            self.phase = phase
            self.summary = summary
            self.detail = detail
            self.tags = tags
            self.cwd = cwd
            self.workspaceName = workspaceName
            self.timestamp = timestamp
        }
    }

    struct Store: Codable {
        var version: Int = 1
        var entries: [Entry]

        init(entries: [Entry] = []) {
            self.entries = entries
        }
    }

    // MARK: - File I/O

    static let maxEntries = 2000

    static func defaultDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("cmux", isDirectory: true)
    }

    static func defaultFileURL() -> URL {
        defaultDirectory().appendingPathComponent("history.json", isDirectory: false)
    }

    static func load(fileURL: URL? = nil) -> Store {
        let url = fileURL ?? defaultFileURL()
        guard let data = try? Data(contentsOf: url) else { return Store() }
        guard let store = try? JSONDecoder().decode(Store.self, from: data) else { return Store() }
        return store
    }

    @discardableResult
    static func save(_ store: Store, fileURL: URL? = nil) -> Bool {
        let url = fileURL ?? defaultFileURL()
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(store)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Operations

    @discardableResult
    static func add(_ entry: Entry, fileURL: URL? = nil) -> Bool {
        var store = load(fileURL: fileURL)
        store.entries.append(entry)
        if store.entries.count > maxEntries {
            store.entries.removeFirst(store.entries.count - maxEntries)
        }
        return save(store, fileURL: fileURL)
    }

    static func list(
        type: String? = nil,
        phase: String? = nil,
        tag: String? = nil,
        cwd: String? = nil,
        since: Date? = nil,
        limit: Int? = nil,
        fileURL: URL? = nil
    ) -> [Entry] {
        let store = load(fileURL: fileURL)
        var results = store.entries

        if let type { results = results.filter { $0.type == type } }
        if let phase { results = results.filter { $0.phase == phase } }
        if let tag { results = results.filter { $0.tags.contains(tag) } }
        if let cwd { results = results.filter { $0.cwd == cwd } }
        if let since { results = results.filter { $0.timestamp >= since } }

        // Most recent first
        results.reverse()

        if let limit { results = Array(results.prefix(limit)) }
        return results
    }

    static func summary(fileURL: URL? = nil) -> String {
        let store = load(fileURL: fileURL)
        let entries = store.entries

        let types = Dictionary(grouping: entries, by: { $0.type })
        let phases = Dictionary(grouping: entries.filter { $0.type == "phase" }, by: { $0.summary.contains("✅") ? "done" : "active" })

        var parts: [String] = []
        parts.append("total: \(entries.count)")
        for (type, items) in types.sorted(by: { $0.key < $1.key }) {
            parts.append("\(type): \(items.count)")
        }
        if let donePhases = phases["done"] {
            parts.append("phases_done: \(donePhases.count)")
        }

        return parts.joined(separator: " | ")
    }

    @discardableResult
    static func clear(fileURL: URL? = nil) -> Bool {
        save(Store(), fileURL: fileURL)
    }
}

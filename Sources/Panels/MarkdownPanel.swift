import Foundation
import Combine

/// A panel that renders a markdown file with live file-watching.
/// When the file changes on disk, the content is automatically reloaded.
@MainActor
final class MarkdownPanel: Panel, ObservableObject {
    let id: UUID
    let panelType: PanelType = .markdown

    /// Absolute path to the markdown file being displayed.
    let filePath: String

    /// The workspace this panel belongs to.
    private(set) var workspaceId: UUID

    /// Current markdown content read from the file.
    @Published private(set) var content: String = ""

    /// Title shown in the tab bar (filename).
    @Published private(set) var displayTitle: String = ""

    /// SF Symbol icon for the tab bar.
    var displayIcon: String? { "doc.richtext" }

    /// Whether the file has been deleted or is unreadable.
    @Published private(set) var isFileUnavailable: Bool = false

    /// Token incremented to trigger focus flash animation.
    @Published private(set) var focusFlashToken: Int = 0

    // MARK: - File watching

    // nonisolated(unsafe) because deinit is not guaranteed to run on the
    // main actor, but DispatchSource.cancel() is thread-safe.
    private nonisolated(unsafe) var fileWatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var isClosed: Bool = false
    private let watchQueue = DispatchQueue(label: "com.cmux.markdown-file-watch", qos: .utility)

    /// Maximum number of reattach attempts after a file delete/rename event.
    private static let maxReattachAttempts = 6
    /// Delay between reattach attempts (total window: attempts * delay = 3s).
    private static let reattachDelay: TimeInterval = 0.5

    // MARK: - Init

    init(workspaceId: UUID, filePath: String) {
        self.id = UUID()
        self.workspaceId = workspaceId
        self.filePath = filePath
        self.displayTitle = (filePath as NSString).lastPathComponent

        loadFileContent()
        startFileWatcher()
        if isFileUnavailable && fileWatchSource == nil {
            // Session restore can create a panel before the file is recreated.
            // Retry briefly so atomic-rename recreations can reconnect.
            scheduleReattach(attempt: 1)
        }
    }

    // MARK: - Panel protocol

    func focus() {
        // Markdown panel is read-only; no first responder to manage.
    }

    func unfocus() {
        // No-op for read-only panel.
    }

    func close() {
        isClosed = true
        stopFileWatcher()
    }

    func triggerFlash(reason: WorkspaceAttentionFlashReason) {
        _ = reason
        guard NotificationPaneFlashSettings.isEnabled() else { return }
        focusFlashToken += 1
    }

    // MARK: - File I/O

    private func loadFileContent() {
        do {
            let newContent = try String(contentsOfFile: filePath, encoding: .utf8)
            content = newContent
            isFileUnavailable = false
        } catch {
            // Fallback: try ISO Latin-1, which accepts all 256 byte values,
            // covering legacy encodings like Windows-1252.
            if let data = FileManager.default.contents(atPath: filePath),
               let decoded = String(data: data, encoding: .isoLatin1) {
                content = decoded
                isFileUnavailable = false
            } else {
                isFileUnavailable = true
            }
        }
    }

    // MARK: - File watcher via DispatchSource

    private func startFileWatcher() {
        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: watchQueue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // File was deleted or renamed. The old file descriptor points to
                // a stale inode, so we must always stop and reattach the watcher
                // even if the new file is already readable (atomic save case).
                DispatchQueue.main.async {
                    self.stopFileWatcher()
                    self.loadFileContent()
                    if self.isFileUnavailable {
                        // File not yet replaced — retry until it reappears.
                        self.scheduleReattach(attempt: 1)
                    } else {
                        // File already replaced — reattach to the new inode immediately.
                        self.startFileWatcher()
                    }
                }
            } else {
                // Content changed — reload.
                DispatchQueue.main.async {
                    self.loadFileContent()
                }
            }
        }

        source.setCancelHandler {
            Darwin.close(fd)
        }

        source.resume()
        fileWatchSource = source
    }

    /// Retry reattaching the file watcher up to `maxReattachAttempts` times.
    /// Each attempt checks if the file has reappeared. Bails out early if
    /// the panel has been closed.
    private func scheduleReattach(attempt: Int) {
        guard attempt <= Self.maxReattachAttempts else { return }
        watchQueue.asyncAfter(deadline: .now() + Self.reattachDelay) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                guard !self.isClosed else { return }
                if FileManager.default.fileExists(atPath: self.filePath) {
                    self.isFileUnavailable = false
                    self.loadFileContent()
                    self.startFileWatcher()
                } else {
                    self.scheduleReattach(attempt: attempt + 1)
                }
            }
        }
    }

    private func stopFileWatcher() {
        if let source = fileWatchSource {
            source.cancel()
            fileWatchSource = nil
        }
        // File descriptor is closed by the cancel handler.
        fileDescriptor = -1
    }

    deinit {
        // DispatchSource cancel is safe from any thread.
        fileWatchSource?.cancel()
    }
}

@MainActor
final class MemoPanel: Panel, ObservableObject {
    let id: UUID
    let panelType: PanelType = .memo

    @Published private(set) var displayTitle: String
    @Published private(set) var content: String
    @Published private(set) var updatedAt: Date?
    @Published private(set) var focusFlashToken: Int = 0
    @Published var focusRequestToken: UInt64 = 0

    private(set) var workspaceId: UUID
    private weak var workspace: Workspace?
    private var workspaceSubscription: AnyCancellable?
    private var isEditing = false

    var displayIcon: String? { "note.text" }

    init(workspace: Workspace) {
        self.id = UUID()
        self.workspaceId = workspace.id
        self.workspace = workspace
        self.displayTitle = String(localized: "workspace.memo.panelTitle", defaultValue: "Memo")
        self.content = workspace.memo ?? ""
        self.updatedAt = workspace.memoUpdatedAt
        bind(to: workspace)
    }

    func updateWorkspace(_ workspace: Workspace) {
        workspaceId = workspace.id
        self.workspace = workspace
        bind(to: workspace)
    }

    func focus() {
        focusRequestToken &+= 1
    }

    func unfocus() {
        endEditing()
    }

    func close() {
        persistContent()
    }

    func triggerFlash(reason: WorkspaceAttentionFlashReason) {
        _ = reason
        guard NotificationPaneFlashSettings.isEnabled() else { return }
        focusFlashToken += 1
    }

    func beginEditing() {
        isEditing = true
    }

    func endEditing() {
        isEditing = false
        persistContent()
    }

    func updateContentFromEditor(_ newContent: String) {
        guard content != newContent else { return }
        content = newContent
    }

    private func bind(to workspace: Workspace) {
        workspaceSubscription = Publishers.CombineLatest(
            workspace.$memo.removeDuplicates(),
            workspace.$memoUpdatedAt.removeDuplicates()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] memo, updatedAt in
            guard let self else { return }
            self.updatedAt = updatedAt
            guard !self.isEditing else { return }
            let nextContent = memo ?? ""
            if self.content != nextContent {
                self.content = nextContent
            }
        }
    }

    private func persistContent() {
        guard let workspace else { return }
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if workspace.memo != nil {
                workspace.clearMemo()
            }
        } else if workspace.memo != content {
            workspace.setMemo(content)
        }
        updatedAt = workspace.memoUpdatedAt
    }
}

@MainActor
final class HistoryPanel: Panel, ObservableObject {
    let id: UUID
    let panelType: PanelType = .history

    @Published private(set) var displayTitle: String
    @Published private(set) var entries: [GlobalHistory.Entry] = []
    @Published private(set) var focusFlashToken: Int = 0
    @Published var focusRequestToken: UInt64 = 0

    @Published var filterType: String?
    @Published var filterPhase: String?
    @Published var filterTag: String?

    var displayIcon: String? { "clock.arrow.circlepath" }

    private var refreshTimer: Timer?

    init() {
        self.id = UUID()
        self.displayTitle = String(localized: "history.panelTitle", defaultValue: "History")
        reload()
    }

    func focus() {
        focusRequestToken &+= 1
        reload()
    }

    func unfocus() {}

    func close() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func triggerFlash(reason: WorkspaceAttentionFlashReason) {
        _ = reason
        guard NotificationPaneFlashSettings.isEnabled() else { return }
        focusFlashToken += 1
    }

    func reload() {
        entries = GlobalHistory.list(
            type: filterType,
            phase: filterPhase,
            tag: filterTag,
            limit: 200
        )
    }

    func applyFilter(type: String?, phase: String?, tag: String?) {
        filterType = type
        filterPhase = phase
        filterTag = tag
        reload()
    }

    func clearFilter() {
        filterType = nil
        filterPhase = nil
        filterTag = nil
        reload()
    }
}

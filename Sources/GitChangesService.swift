import Foundation
import Combine

enum GitFileStatus: String, Sendable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case untracked = "?"

    init(porcelainCode: Character) {
        switch porcelainCode {
        case "M": self = .modified
        case "A": self = .added
        case "D": self = .deleted
        case "R": self = .renamed
        case "?": self = .untracked
        default: self = .modified
        }
    }
}

struct GitChangedFile: Identifiable, Sendable {
    let id: String // file path
    let status: GitFileStatus
    let path: String

    var fileName: String {
        (path as NSString).lastPathComponent
    }
}

struct GitChangesSnapshot: Sendable {
    var files: [GitChangedFile]
    var isGitRepo: Bool
    var directory: String

    static let empty = GitChangesSnapshot(files: [], isGitRepo: false, directory: "")
}

@MainActor
final class GitChangesService: ObservableObject {
    @Published var snapshot = GitChangesSnapshot.empty
    @Published var selectedFileDiff: String?
    @Published var selectedFilePath: String?
    @Published var isLoading = false

    private var refreshTask: Task<Void, Never>?
    private var diffTask: Task<Void, Never>?
    private var lastRefreshDate = Date.distantPast
    private static let debounceInterval: TimeInterval = 2.0
    private static let processTimeout: TimeInterval = 5.0
    private static let maxDiffLines = 10_000

    func refresh(directory: String) {
        let now = Date()
        if now.timeIntervalSince(lastRefreshDate) < Self.debounceInterval {
            return
        }
        lastRefreshDate = now

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }

            let result = await Self.runGitStatus(in: directory)
            guard !Task.isCancelled else { return }
            self.snapshot = result
            self.selectedFileDiff = nil
            self.selectedFilePath = nil
        }
    }

    func forceRefresh(directory: String) {
        lastRefreshDate = .distantPast
        refresh(directory: directory)
    }

    func selectFile(_ file: GitChangedFile, directory: String) {
        selectedFilePath = file.path
        diffTask?.cancel()
        diffTask = Task { [weak self] in
            guard let self else { return }
            let diff = await Self.runGitDiff(file: file.path, in: directory)
            guard !Task.isCancelled else { return }
            self.selectedFileDiff = diff
        }
    }

    // MARK: - Git Commands

    private static func runGitStatus(in directory: String) async -> GitChangesSnapshot {
        guard let output = await runGitCommand(["status", "--porcelain=v1"], in: directory) else {
            return GitChangesSnapshot(files: [], isGitRepo: false, directory: directory)
        }

        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        var files: [GitChangedFile] = []
        for line in lines {
            guard line.count >= 4 else { continue }
            let index = line.index(line.startIndex, offsetBy: 1)
            let workingTreeStatus = line[index]
            let statusChar: Character
            if workingTreeStatus != " " && workingTreeStatus != "?" {
                statusChar = workingTreeStatus
            } else {
                statusChar = line[line.startIndex]
            }
            let pathStart = line.index(line.startIndex, offsetBy: 3)
            let filePath = String(line[pathStart...])
            let status = GitFileStatus(porcelainCode: statusChar)
            files.append(GitChangedFile(id: filePath, status: status, path: filePath))
        }

        return GitChangesSnapshot(files: files, isGitRepo: true, directory: directory)
    }

    private static func runGitDiff(file: String, in directory: String) async -> String? {
        // Try staged + unstaged diff
        if let diff = await runGitCommand(["diff", "HEAD", "--", file], in: directory), !diff.isEmpty {
            return truncateDiff(diff)
        }
        // For untracked files, show file content
        if let content = await runGitCommand(["diff", "--no-index", "/dev/null", file], in: directory) {
            return truncateDiff(content)
        }
        return nil
    }

    private static func truncateDiff(_ diff: String) -> String {
        let lines = diff.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > maxDiffLines {
            let truncated = lines.prefix(maxDiffLines).joined(separator: "\n")
            return truncated + "\n... (\(lines.count - maxDiffLines) more lines truncated)"
        }
        return diff
    }

    private static func runGitCommand(_ arguments: [String], in directory: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = arguments
                process.currentDirectoryURL = URL(fileURLWithPath: directory)
                process.environment = [
                    "PATH": "/usr/bin:/usr/local/bin",
                    "GIT_TERMINAL_PROMPT": "0",
                    "LC_ALL": "C",
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                let timeoutItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + processTimeout, execute: timeoutItem)

                process.waitUntilExit()
                timeoutItem.cancel()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                continuation.resume(returning: output)
            }
        }
    }
}

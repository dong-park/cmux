import SwiftUI

struct GitChangesPanel: View {
    @EnvironmentObject private var rightPanelState: RightPanelState
    @ObservedObject var gitService: GitChangesService
    let directory: String?
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(String(localized: "gitChanges.title", defaultValue: "Git Changes"))
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if gitService.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help(String(localized: "gitChanges.refresh", defaultValue: "Refresh"))
            Button(action: { rightPanelState.toggle() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(String(localized: "gitChanges.close", defaultValue: "Close"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let directory, !directory.isEmpty {
            if !gitService.snapshot.isGitRepo && !gitService.isLoading {
                emptyState(String(localized: "gitChanges.notGitRepo", defaultValue: "Not a git repository"))
            } else if gitService.snapshot.files.isEmpty && !gitService.isLoading {
                emptyState(String(localized: "gitChanges.noChanges", defaultValue: "No changes"))
            } else {
                fileListAndDiff
            }
        } else {
            emptyState(String(localized: "gitChanges.noDirectory", defaultValue: "No directory"))
        }
    }

    private func emptyState(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - File List + Diff

    private var fileListAndDiff: some View {
        VStack(spacing: 0) {
            fileList
            if gitService.selectedFileDiff != nil {
                Divider()
                diffView
            }
        }
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(gitService.snapshot.files) { file in
                    fileRow(file)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: gitService.selectedFileDiff != nil ? 200 : .infinity)
    }

    private func fileRow(_ file: GitChangedFile) -> some View {
        let isSelected = gitService.selectedFilePath == file.path
        return Button(action: {
            if let directory {
                gitService.selectFile(file, directory: directory)
            }
        }) {
            HStack(spacing: 6) {
                Text(file.status.rawValue)
                    .font(.system(size: 11, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(statusColor(file.status))
                    .frame(width: 16, alignment: .center)
                VStack(alignment: .leading, spacing: 1) {
                    Text(file.fileName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                    if file.path != file.fileName {
                        Text(file.path)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusColor(_ status: GitFileStatus) -> Color {
        switch status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .untracked: return .secondary
        }
    }

    // MARK: - Diff View

    private var diffView: some View {
        ScrollView([.horizontal, .vertical]) {
            if let diff = gitService.selectedFileDiff {
                diffContent(diff)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func diffContent(_ diff: String) -> some View {
        let lines = diff.split(separator: "\n", omittingEmptySubsequences: false)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let lineStr = String(line)
                Text(lineStr)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(diffLineColor(lineStr))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("@@") {
            return .blue
        } else if line.hasPrefix("+") {
            return .green
        } else if line.hasPrefix("-") {
            return .red
        }
        return .primary
    }
}

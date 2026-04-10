import SwiftUI
import Foundation
import Bonsplit

struct PaneNumberBadgeView: View {
    let text: String
    let isFocused: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(Color.white.opacity(isFocused ? 0.95 : 0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isFocused ? cmuxAccentColor().opacity(0.92) : Color.black.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(isFocused ? 0.18 : 0.08), lineWidth: 1)
            )
            .padding(.top, 8)
            .padding(.leading, 8)
            .allowsHitTesting(false)
    }
}

/// View that renders the appropriate panel view based on panel type
struct PanelContentView: View {
    let panel: any Panel
    let paneId: PaneID
    let isFocused: Bool
    let isSelectedInPane: Bool
    let isVisibleInUI: Bool
    let portalPriority: Int
    let isSplit: Bool
    let appearance: PanelAppearance
    let hasUnreadNotification: Bool
    let paneBadgeText: String
    let showsPaneNumberBadge: Bool
    let onFocus: () -> Void
    let onRequestPanelFocus: () -> Void
    let onTriggerFlash: () -> Void

    var body: some View {
        Group {
            switch panel.panelType {
            case .terminal:
                if let terminalPanel = panel as? TerminalPanel {
                    TerminalPanelView(
                        panel: terminalPanel,
                        paneId: paneId,
                        isFocused: isFocused,
                        isVisibleInUI: isVisibleInUI,
                        portalPriority: portalPriority,
                        isSplit: isSplit,
                        appearance: appearance,
                        hasUnreadNotification: hasUnreadNotification,
                        paneBadgeText: paneBadgeText,
                        showsPaneNumberBadge: showsPaneNumberBadge,
                        onFocus: onFocus,
                        onTriggerFlash: onTriggerFlash
                    )
                }
            case .browser:
                if let browserPanel = panel as? BrowserPanel {
                    BrowserPanelView(
                        panel: browserPanel,
                        paneId: paneId,
                        isFocused: isFocused,
                        isVisibleInUI: isVisibleInUI,
                        portalPriority: portalPriority,
                        onRequestPanelFocus: onRequestPanelFocus
                    )
                }
            case .markdown:
                if let markdownPanel = panel as? MarkdownPanel {
                    MarkdownPanelView(
                        panel: markdownPanel,
                        isFocused: isFocused,
                        isVisibleInUI: isVisibleInUI,
                        portalPriority: portalPriority,
                        onRequestPanelFocus: onRequestPanelFocus
                    )
                }
            case .memo:
                if let memoPanel = panel as? MemoPanel {
                    MemoPanelView(
                        panel: memoPanel,
                        isFocused: isFocused,
                        isVisibleInUI: isVisibleInUI,
                        portalPriority: portalPriority,
                        onRequestPanelFocus: onRequestPanelFocus
                    )
                }
            case .history:
                if let historyPanel = panel as? HistoryPanel {
                    HistoryPanelView(
                        panel: historyPanel,
                        isFocused: isFocused,
                        isVisibleInUI: isVisibleInUI,
                        portalPriority: portalPriority,
                        onRequestPanelFocus: onRequestPanelFocus
                    )
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if showsPaneNumberBadge, panel.panelType != .terminal {
                PaneNumberBadgeView(text: paneBadgeText, isFocused: isFocused)
            }
        }
    }
}

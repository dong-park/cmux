import SwiftUI

@MainActor
final class RightPanelState: ObservableObject {
    @Published var isVisible: Bool
    @Published var persistedWidth: CGFloat

    init(isVisible: Bool = false, persistedWidth: CGFloat = CGFloat(SessionPersistencePolicy.defaultRightPanelWidth)) {
        self.isVisible = isVisible
        let sanitized = SessionPersistencePolicy.sanitizedRightPanelWidth(Double(persistedWidth))
        self.persistedWidth = CGFloat(sanitized)
    }

    func toggle() {
        isVisible.toggle()
    }
}

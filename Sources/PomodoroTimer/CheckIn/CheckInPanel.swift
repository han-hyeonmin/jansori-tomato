import AppKit

/// 체크인 캐릭터를 담는 창.
///
/// - 앱을 활성화하지 않고(non-activating) 항상 위에 떠 있으며
/// - 마우스 이벤트를 아래 창으로 흘려보낸다(클릭 통과).
/// - 모든 Space와 전체화면 위에서도 같은 자리에 머문다.
final class CheckInPanel: NSPanel {
    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true          // 클릭 통과
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

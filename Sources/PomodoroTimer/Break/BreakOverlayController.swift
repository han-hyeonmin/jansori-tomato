import SwiftUI
import AppKit
import CoreGraphics

/// 휴식 시간에 화면 전체를 덮는 오버레이를 총괄한다. (Flow 앱 방식)
///
/// - 집중이 끝나면 휴식이 자동 시작되고 전체화면 오버레이가 카운트다운을 보여준다.
/// - 사용자는 언제든 오버레이를 닫거나(휴식은 백그라운드로 계속) 바로 집중을 시작할 수 있다.
/// - 휴식이 끝나면 "집중 다시 시작" 프롬프트로 알아서 전환된다.
@MainActor
final class BreakOverlayController: ObservableObject {
    enum Mode {
        case resting   // 휴식 중: 카운트다운 + 쉬기 유도
        case ready     // 휴식 끝: "집중 다시 시작" 프롬프트
    }

    @Published private(set) var mode: Mode = .resting

    private let engine: TimerEngine
    private var windows: [NSWindow] = []
    private var presented = false

    init(engine: TimerEngine) {
        self.engine = engine
        engine.addSessionEndObserver { [weak self] finished, completedNormally in
            self?.handle(finished: finished, completedNormally: completedNormally)
        }

        // 디버그: BREAK_PREVIEW=1 → 휴식/재개 화면을 차례로 띄워 확인.
        if ProcessInfo.processInfo.environment["BREAK_PREVIEW"] == "1" {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 800_000_000)
                self?.present(mode: .resting)
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                self?.present(mode: .ready)
            }
        }
    }

    // MARK: 세션 전환 반응

    private func handle(finished: SessionType, completedNormally: Bool) {
        if finished == .focus {
            // 집중 종료 → 휴식 시작. 전체화면으로 작업을 가린다.
            present(mode: .resting)
        } else if completedNormally {
            // 휴식이 자연히 끝남 → 재개 프롬프트 자동 팝업.
            present(mode: .ready)
        } else {
            // 휴식을 건너뜀 → 그냥 닫는다.
            dismiss()
        }
    }

    // MARK: 사용자 액션

    /// resting: 휴식을 끝내고 바로 집중 시작.
    func startFocusFromRest() {
        engine.skip()          // break → focus(idle) (onSessionEnd(break,false)로 dismiss됨)
        engine.start()
    }

    /// ready: 다음 집중 세션 시작.
    func startFocus() {
        if engine.sessionType != .focus { engine.skip() }
        engine.start()
        dismiss()
    }

    /// 가리는 창만 닫기(휴식은 메뉴바에서 계속 카운트다운).
    func closeCover() {
        dismiss()
    }

    // MARK: 표시 / 숨김

    private func present(mode: Mode) {
        self.mode = mode
        if !presented {
            buildWindows()
            presented = true
        }
        for window in windows { window.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismiss() {
        guard presented else { return }
        presented = false
        let closing = windows
        windows.removeAll()
        // 버튼 액션 도중 창을 즉시 해제하지 않도록 다음 런루프에서 정리.
        Task { @MainActor in
            for window in closing { window.orderOut(nil) }
        }
    }

    private func buildWindows() {
        windows = NSScreen.screens.map { screen in
            let window = BreakOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.setFrame(screen.frame, display: true)
            window.contentView = NSHostingView(
                rootView: BreakOverlayView(engine: engine, controller: self)
            )
            return window
        }
    }
}

/// 키 입력(Esc)과 버튼 클릭을 받도록 key가 될 수 있는 보더리스 창.
final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 뒤 배경을 흐리게(frosted) 보여주는 시각 효과 뷰.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

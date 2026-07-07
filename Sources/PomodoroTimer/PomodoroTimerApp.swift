import SwiftUI

@main
struct PomodoroTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine: TimerEngine
    @StateObject private var checkIn: CheckInController
    @StateObject private var breakOverlay: BreakOverlayController
    @StateObject private var notifications: NotificationManager

    init() {
        let engine = TimerEngine()
        _engine = StateObject(wrappedValue: engine)
        _checkIn = StateObject(wrappedValue: CheckInController(engine: engine))
        _breakOverlay = StateObject(wrappedValue: BreakOverlayController(engine: engine))
        _notifications = StateObject(wrappedValue: NotificationManager(engine: engine))
    }

    var body: some Scene {
        MenuBarExtra {
            ControlPanelView(engine: engine, checkIn: checkIn)
        } label: {
            // 메뉴바 레이블은 텍스트만 안정적으로 렌더된다.
            Text(engine.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Dock 아이콘 없이 메뉴바 액세서리로만 동작시키기 위한 델리게이트.
/// (배포 번들에서는 Info.plist의 LSUIElement가, 개발 실행에서는 이 코드가 담당한다.)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

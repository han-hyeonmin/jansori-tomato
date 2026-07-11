import SwiftUI

@main
struct PomodoroTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine: TimerEngine
    @StateObject private var checkIn: CheckInController
    @StateObject private var breakOverlay: BreakOverlayController
    @StateObject private var notifications: NotificationManager
    @StateObject private var sound: SoundManager
    @StateObject private var sleepMonitor: SleepMonitor

    init() {
        let engine = TimerEngine()
        _engine = StateObject(wrappedValue: engine)
        _checkIn = StateObject(wrappedValue: CheckInController(engine: engine))
        _breakOverlay = StateObject(wrappedValue: BreakOverlayController(engine: engine))
        _notifications = StateObject(wrappedValue: NotificationManager(engine: engine))
        _sound = StateObject(wrappedValue: SoundManager(engine: engine))
        _sleepMonitor = StateObject(wrappedValue: SleepMonitor(engine: engine))

        // 디버그: AUTOSTART=1 → 실행 즉시 집중 세션 시작(메뉴바 카운트다운 스크린샷용).
        if ProcessInfo.processInfo.environment["AUTOSTART"] == "1" {
            engine.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ControlPanelView(engine: engine, checkIn: checkIn, sound: sound)
        } label: {
            // 메뉴바 레이블은 텍스트만 안정적으로 렌더된다.
            // monospacedDigit만으로는 숫자 글리프 폭만 같아질 뿐, MenuBarExtra가
            // tick마다 레이블 크기를 재측정하며 항목 폭이 미세하게 흔들린다.
            // 그래서 tick마다 변하지 않는 템플릿(숫자를 전부 0으로 고정)을 숨겨서
            // 깔아 레이아웃 폭을 확정하고, 실제 타이틀을 그 위에 겹쳐 그린다.
            // 이러면 항목 폭이 매 tick 완전히 동일해 좌우 흔들림이 사라진다.
            Text(engine.menuBarWidthTemplate)
                .monospacedDigit()
                .hidden()
                .overlay(alignment: .leading) {
                    Text(engine.menuBarTitle)
                        .monospacedDigit()
                        .fixedSize()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Dock 아이콘 없이 메뉴바 액세서리로만 동작시키기 위한 델리게이트.
/// (배포 번들에서는 Info.plist의 LSUIElement가, 개발 실행에서는 이 코드가 담당한다.)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // 새 버전 확인(백그라운드, 앱당 1회).
        UpdateChecker.shared.checkOnce()
    }
}

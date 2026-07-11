import SwiftUI
import AppKit
import Combine

@main
struct PomodoroTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 메뉴바 전용(LSUIElement) 앱이라 보이는 창 씬이 필요 없다.
        // 상태바 아이템·팝오버는 AppDelegate가 직접 관리한다(폭 고정을 위해
        // MenuBarExtra 대신 NSStatusItem을 쓴다 — 아래 주석 참고).
        //
        // App.body는 최소 하나의 Scene을 요구하므로 빈 Settings 씬을 자리채움으로
        // 둔다. 실제 설정은 팝오버 패널의 DisclosureGroup에 통합돼 있어 이 씬은
        // 열 일이 없다. 그런데 Settings 씬은 표준 "설정…"(⌘,) 메뉴 항목을 자동
        // 등록해 이 빈 창을 띄워버리므로, appSettings 커맨드 그룹을 비워 그 경로를
        // 제거한다. (reopen·상태복원 경로는 AppDelegate에서 함께 차단한다.)
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) { }
            }
    }
}

/// 상태바 아이템과 컨트롤 패널 팝오버를 직접 관리하는 델리게이트.
///
/// SwiftUI `MenuBarExtra`는 status item의 폭을 내용의 잉크 경계에 맞춰 잡아,
/// `monospacedDigit`을 써도 숫자 잉크 폭 차이만큼 항목이 미세하게 흔들린다.
/// 이를 없애려면 `NSStatusItem.length`를 직접 고정해야 하는데 MenuBarExtra는
/// 그 제어를 열어주지 않는다. 그래서 상태바 아이템을 손수 만들어,
/// 카운트다운 중에는 길이를 고정폭으로 못박는다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // 엔진과 부수 컨트롤러들(살아있는 동안 엔진을 관찰한다).
    private var engine: TimerEngine!
    private var checkIn: CheckInController!
    private var breakOverlay: BreakOverlayController!
    private var notifications: NotificationManager!
    private var sound: SoundManager!
    private var sleepMonitor: SleepMonitor!

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    /// 상태바 텍스트 폰트(시스템 메뉴바 폰트 크기에 tabular figures 적용).
    private var menuBarFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    /// 상태바 아이템 고정 폭(가장 넓은 "🍅 00:00" 기준, 한 번만 계산해 계속 고정).
    private var runningLength: CGFloat = NSStatusItem.variableLength

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 이전 세션에서 상태 복원으로 되살아난 빈 설정 창을 닫는다(아래 주석 참고).
        closeStraySettingsWindows()

        // 엔진·컨트롤러 구성.
        let engine = TimerEngine()
        self.engine = engine
        checkIn = CheckInController(engine: engine)
        breakOverlay = BreakOverlayController(engine: engine)
        notifications = NotificationManager(engine: engine)
        sound = SoundManager(engine: engine)
        sleepMonitor = SleepMonitor(engine: engine)

        // 디버그: AUTOSTART=1 → 실행 즉시 집중 세션 시작(메뉴바 카운트다운 확인용).
        if ProcessInfo.processInfo.environment["AUTOSTART"] == "1" {
            engine.start()
        }

        setUpStatusItem()
        setUpPopover()

        // 엔진이 바뀔 때마다(초당 tick 포함) 상태바 텍스트·폭을 갱신.
        // objectWillChange는 값 변경 "직전"에 오므로 한 런루프 뒤에 읽는다.
        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                MainActor.assumeIsolated { self?.updateStatusButton() }
            }
            .store(in: &cancellables)
        updateStatusButton()

        // 새 버전 확인(백그라운드, 앱당 1회).
        UpdateChecker.shared.checkOnce()
    }

    // MARK: 상태바 아이템

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            // 시스템 메뉴바 폰트 크기에 맞춰 tabular-digit 폰트를 만든다.
            let base = button.font ?? NSFont.menuBarFont(ofSize: 0)
            menuBarFont = NSFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: .regular)
            button.font = menuBarFont
            button.imagePosition = .noImage
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        // 가장 넓은 문자열의 폭을 재, 살짝 여유를 두고 항상 고정폭으로 쓴다.
        // idle 상태에서도 시계를 표시하므로 폭이 늘 일정하다 → 폭 변화로 인한
        // 흔들림도, 팝오버가 열린 채 리사이즈되며 화살표가 튀는 문제도 없다.
        let widest = NSAttributedString(string: "🍅 00:00", attributes: [.font: menuBarFont])
        runningLength = ceil(widest.size().width) + 8
        item.length = runningLength
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        button.attributedTitle = NSAttributedString(
            string: engine.menuBarTitle,
            attributes: [.font: menuBarFont, .foregroundColor: NSColor.labelColor]
        )
    }

    // MARK: 팝오버

    private func setUpPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: ControlPanelView(
                engine: engine,
                checkIn: checkIn,
                sound: sound,
                onRequestClose: { [weak self] in self?.popover.performClose(nil) }
            )
        )
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: 빈 설정 창 차단

    /// 메뉴바 앱이라 표준 창을 열지 않는다. 아이콘 재클릭·재실행(reopen) 시 SwiftUI가
    /// 유일한 씬인 빈 Settings 창을 열어버리는 것을 막는다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    /// 상태 복원이 이전 세션의 빈 설정 창을 되살릴 수 있어, 실행 직후 표준(제목 있는,
    /// 복원 대상) 창을 닫는다. 상태바 창은 borderless·비복원이라, 브레이크 오버레이는
    /// 실행 시점엔 아직 만들어지지 않아 여기 걸리지 않는다. 복원 타이밍을 놓치지 않도록
    /// 다음 런루프에서 한 번 더 확인한다.
    private func closeStraySettingsWindows() {
        closeTitledRestorableWindows()
        DispatchQueue.main.async { [weak self] in
            self?.closeTitledRestorableWindows()
        }
    }

    private func closeTitledRestorableWindows() {
        for window in NSApp.windows
        where window.isRestorable && window.styleMask.contains(.titled) {
            window.close()
        }
    }
}

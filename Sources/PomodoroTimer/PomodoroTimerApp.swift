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

extension Notification.Name {
    /// 컨트롤 패널이 닫혔음을 패널 뷰에 알린다(펼친 상태를 접기 위해).
    static let controlPanelDidClose = Notification.Name("JansoriTomato.controlPanelDidClose")
}

/// 상태바 아이템과 컨트롤 패널 팝오버를 직접 관리하는 델리게이트.
///
/// SwiftUI `MenuBarExtra`는 status item의 폭을 내용의 잉크 경계에 맞춰 잡아,
/// `monospacedDigit`을 써도 숫자 잉크 폭 차이만큼 항목이 미세하게 흔들린다.
/// 이를 없애려면 `NSStatusItem.length`를 직접 고정해야 하는데 MenuBarExtra는
/// 그 제어를 열어주지 않는다. 그래서 상태바 아이템을 손수 만들어,
/// 카운트다운 중에는 길이를 고정폭으로 못박는다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
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
    /// 상태바 아이콘 클릭 감시자(앱 수명 동안 유지).
    private var statusItemClickMonitor: Any?
    /// 팝오버 크기 변화 관찰자(열려 있는 동안만 유지).
    private var popoverResizeObserver: Any?
    /// 팝오버가 마지막으로 닫힌 시각(아이콘 클릭이 곧바로 다시 열지 않게 막는 데 쓴다).
    private var popoverClosedAt: Date?
    /// 팝오버가 열려 있는지. 열려 있는 동안 상태바 아이콘을 눌린 상태로 표시한다.
    private var isPanelOpen = false
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

        installStatusItemClickMonitor()

        // 가장 넓은 문자열의 폭을 재, 살짝 여유를 두고 항상 고정폭으로 쓴다.
        // idle 상태에서도 시계를 표시하므로 폭이 늘 일정하다 → 폭 변화로 인한
        // 흔들림도, 팝오버가 열린 채 리사이즈되며 화살표가 튀는 문제도 없다.
        let widest = NSAttributedString(string: "🍅 00:00", attributes: [.font: menuBarFont])
        runningLength = ceil(widest.size().width) + 8
        item.length = runningLength
    }

    /// 상태바 아이콘 클릭을 직접 받는다.
    ///
    /// 버튼의 target/action에 맡기면 `NSButton`의 추적 루프가 mouse-up에서 `highlight(_:)`로
    /// 넣은 눌린 표시를 지워 버린다. 지워진 뒤에 되돌리는 방식은 아무리 빨라도 한 프레임
    /// 깜빡이므로, mouse-down을 여기서 처리하고 이벤트를 소비해 추적 자체가 시작되지 않게
    /// 한다 — 지워지는 일이 없으니 깜빡임도 없다. 상태바 창의 이벤트가 아니면 그대로 흘려
    /// 보내므로, 감시자가 못 잡는 경우에도 기존 action 경로가 받아 준다.
    private func installStatusItemClickMonitor() {
        statusItemClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            // 창 비교는 Sendable한 창 번호로 한다(NSEvent·NSWindow를 isolation 경계로
            // 넘기지 않도록).
            let windowNumber = event.windowNumber
            var consumed = false
            MainActor.assumeIsolated {
                guard let self, let button = self.statusItem?.button,
                      button.window?.windowNumber == windowNumber
                else { return }
                self.togglePopover(button)
                consumed = true
            }
            return consumed ? nil : event
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        button.attributedTitle = NSAttributedString(
            string: engine.menuBarTitle,
            attributes: [.font: menuBarFont, .foregroundColor: NSColor.labelColor]
        )
        // 팝오버가 열려 있는 동안 아이콘을 눌린 상태로 둔다.
        //
        // 버튼 액션은 기본값인 mouse-up에 발동하게 남겨 둬야 한다. mouse-down으로 옮기면
        // AppKit이 추적을 끝내며(mouse-up) 이 표시를 지운 *뒤*에 복원이 들어가 한 프레임
        // 깜빡인다. 기본값이면 AppKit의 삭제와 이 복원이 같은 이벤트 처리 안에서 이어지고,
        // 누르는 동안에는 AppKit 자체 추적 하이라이트가 보여 빈틈이 없다.
        button.highlight(isPanelOpen)
    }

    // MARK: 팝오버

    private func setUpPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        // 화살표(꼬리)를 감춘다. 공개 API로는 크기를 조절할 수 없어, 비공개 KVC 키를
        // 쓴다 — 존재를 먼저 확인하므로 애플이 없애면 화살표만 되돌아오고 앱은 멀쩡하다.
        let hideAnchor = NSSelectorFromString("setShouldHideAnchor:")
        if popover.responds(to: hideAnchor) {
            popover.setValue(true, forKey: "shouldHideAnchor")
        }
        let hosting = NSHostingController(
            rootView: ControlPanelView(
                engine: engine,
                checkIn: checkIn,
                sound: sound,
                onRequestClose: { [weak self] in self?.popover.performClose(nil) }
            )
        )
        // 패널이 "더 보기"로 펼쳐지고 접힐 때 팝오버 크기가 내용을 따라가게 한다.
        // (이걸 켜지 않으면 첫 표시 때의 크기에 갇혀 펼친 내용이 잘린다.)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            stopObservingPopoverResize()
            popover.performClose(sender)
            return
        }
        // 아이콘 클릭으로 닫은 직후라면 열지 않는다.
        //
        // transient 팝오버는 "바깥 클릭"에 스스로 닫히고, 상태바 아이콘도 팝오버 바깥이다.
        // mouse-down에 팝오버가 먼저 닫히고 mouse-up에 이 액션이 오므로, 그대로 두면
        // isShown이 이미 false여서 곧바로 다시 열려 "닫히지 않는" 것처럼 보인다.
        // (카운트다운 중에는 매초 갱신 때문에 이 순서가 더 자주 발생한다.)
        if let closedAt = popoverClosedAt, Date().timeIntervalSince(closedAt) < 0.25 {
            popoverClosedAt = nil
            return
        }

        // 눌린 표시를 먼저 넣는다 — 팝오버를 띄운 뒤에 하면 그만큼 늦게 들어온다.
        isPanelOpen = true
        updateStatusButton()

        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        raisePopoverToMenuBar()
        observePopoverResize()
    }

    /// 팝오버가 닫히면(바깥 클릭 포함) 정리하고, 펼쳐져 있던 패널을 접게 알린다 —
    /// 다시 열면 접힌 상태로 시작한다.
    func popoverDidClose(_ notification: Notification) {
        popoverClosedAt = Date()
        isPanelOpen = false
        updateStatusButton()
        stopObservingPopoverResize()
        NotificationCenter.default.post(name: .controlPanelDidClose, object: nil)
    }

    /// 팝오버 창을 메뉴바에 붙게 끌어올린다.
    ///
    /// 화살표를 감춰도 팝오버는 화살표가 있던 만큼(약 7pt) 메뉴바에서 떨어져 자리를 잡고,
    /// `show(relativeTo:)`의 기준 사각형을 위로 밀어도 메뉴바를 넘지 않게 스스로 보정해
    /// 버린다. 그래서 창을 직접 옮긴다.
    ///
    /// 고정값을 더하지 않고 내용 뷰의 실제 상단을 읽어 메뉴바 경계에 맞춘다 — 창 프레임과
    /// 보이는 패널 사이의 그림자 여백을 몰라도 되고, 여러 번 불려도 같은 자리에 머문다.
    private func raisePopoverToMenuBar() {
        guard let view = popover.contentViewController?.view,
              let window = view.window,
              let screen = window.screen ?? NSScreen.main
        else { return }

        let contentTop = window.convertToScreen(view.convert(view.bounds, to: nil)).maxY
        let delta = screen.visibleFrame.maxY - contentTop
        guard abs(delta) > 0.5 else { return }
        window.setFrameOrigin(NSPoint(x: window.frame.minX, y: window.frame.origin.y + delta))
    }

    /// 팝오버는 내용 크기가 바뀌면("더 보기"/"간략히 보기") 앵커 기준으로 자리를 다시
    /// 잡아 끌어올린 위치를 잃는다. 크기·위치 변화를 관찰해 그때마다 다시 붙인다.
    ///
    /// 보정을 다음 런루프로 미루는 이유: 알림이 팝오버가 자리를 다시 잡기 *전에* 오는
    /// 경우가 있어(접을 때), 같은 패스에서 고치면 곧바로 되돌려진다.
    private func observePopoverResize() {
        guard let window = popover.contentViewController?.view.window else { return }
        stopObservingPopoverResize()
        let center = NotificationCenter.default
        popoverResizeObserver = [NSWindow.didResizeNotification, NSWindow.didMoveNotification]
            .map { name in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    // 약한 참조를 먼저 상수로 풀어둔다 — 중첩 클로저가 `weak self`
                    // 변수를 그대로 캡처하면 동시성 검사에서 거부된다.
                    guard let self else { return }
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { self.raisePopoverToMenuBar() }
                    }
                }
            }
    }

    private func stopObservingPopoverResize() {
        if let observers = popoverResizeObserver as? [Any] {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
        popoverResizeObserver = nil
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

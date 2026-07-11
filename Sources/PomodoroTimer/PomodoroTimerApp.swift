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
        Settings { EmptyView() }
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
    /// 카운트다운 중 고정할 아이템 폭(가장 넓은 "🍅 00:00" 기준, 한 번만 계산).
    private var runningLength: CGFloat = NSStatusItem.variableLength
    /// 팝오버가 열려 있는 동안 미뤄둔 길이 변경(닫힐 때 적용).
    private var pendingLength: CGFloat?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

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

        // 가장 넓은 카운트다운 문자열의 폭을 재, 살짝 여유를 두고 고정폭으로 쓴다.
        let widest = NSAttributedString(string: "🍅 00:00", attributes: [.font: menuBarFont])
        runningLength = ceil(widest.size().width) + 8
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        button.attributedTitle = NSAttributedString(
            string: engine.menuBarTitle,
            attributes: [.font: menuBarFont, .foregroundColor: NSColor.labelColor]
        )
        // 실행/일시정지 중에는 폭을 고정해 숫자 잉크 차이로 인한 흔들림을 없앤다.
        // 정지 상태(이모지만)에서는 내용에 맞춰 좁게 둔다.
        let desired: CGFloat = engine.runState == .idle ? NSStatusItem.variableLength : runningLength
        applyLength(desired)
    }

    /// 상태바 아이템 길이를 적용한다. 단, 팝오버가 열려 있는 동안 앵커(버튼)를
    /// 리사이즈하면 팝오버 화살표가 튀므로(예: 초기화 → idle 전환), 열려 있으면
    /// 닫힐 때까지 미룬다. 제목(숫자) 갱신은 고정폭 안에서 이뤄져 리사이즈가 없다.
    private func applyLength(_ desired: CGFloat) {
        if popover.isShown {
            pendingLength = desired
            return
        }
        if statusItem?.length != desired {
            statusItem?.length = desired
        }
    }

    // MARK: 팝오버

    private func setUpPopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
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
}

extension AppDelegate: NSPopoverDelegate {
    /// 팝오버가 닫힌 뒤, 열려 있는 동안 미뤄둔 상태바 길이 변경을 적용한다.
    func popoverDidClose(_ notification: Notification) {
        guard let pending = pendingLength else { return }
        pendingLength = nil
        if statusItem?.length != pending {
            statusItem?.length = pending
        }
    }
}

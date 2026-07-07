import SwiftUI
import AppKit

/// 감시 캐릭터의 등장 스케줄과 애니메이션을 총괄한다.
///
/// 집중 세션이 실행 중이고 체크인 주기가 켜져 있으면, 주기마다 캐릭터를
/// 화면 우하단에 잠깐 띄웠다가 숨긴다. 표시되는 동안 눈동자는 커서를 따라가고
/// 이따금 눈을 깜빡인다.
@MainActor
final class CheckInController: ObservableObject {
    private let engine: TimerEngine
    private let model = EyeModel()

    private let panelSize = NSSize(width: 220, height: 150)
    private let displayDuration: Double = 5.5
    private var messageIndex = 0

    private var panel: CheckInPanel?
    private var isVisible = false

    private var scheduleTask: Task<Void, Never>?
    private var visibilityTask: Task<Void, Never>?
    private var gazeTask: Task<Void, Never>?
    private var blinkTask: Task<Void, Never>?

    init(engine: TimerEngine) {
        self.engine = engine
        engine.onStateChange = { [weak self] in self?.refresh() }
        refresh()

        // 디버그: CHECKIN_PREVIEW=1 로 실행하면 시작 직후 캐릭터를 한 번 띄운다.
        if ProcessInfo.processInfo.environment["CHECKIN_PREVIEW"] == "1" {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                self?.previewNow(duration: 6)
            }
        }
    }

    // MARK: 공개

    /// 설정 화면의 "미리보기" 버튼 등에서 즉시 캐릭터를 띄운다.
    func previewNow(duration: Double = 4.5) {
        showCharacter(for: duration)
    }

    // MARK: 스케줄링

    private func refresh() {
        let interval = engine.settings.checkInIntervalMinutes
        let active = engine.sessionType == .focus
            && engine.runState == .running
            && interval > 0

        scheduleTask?.cancel()
        scheduleTask = nil

        if active {
            let base = Double(interval * 60)
            scheduleTask = Task { [weak self] in
                while !Task.isCancelled {
                    // N ± X, X는 균등분포 |X| < 0.5N → 실제 간격이 (0.5N, 1.5N)에서
                    // 흔들려 유저가 등장 시점을 예측하기 어렵다.
                    let jitter = Double.random(in: -0.5..<0.5) * base
                    let wait = max(5, base + jitter)
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    if Task.isCancelled { break }
                    self?.showCharacter(for: self?.displayDuration ?? 4.5)
                }
            }
        } else if isVisible {
            hideCharacter()
        }
    }

    // MARK: 표시 / 숨김

    private func showCharacter(for duration: Double) {
        ensurePanel()
        positionPanel()
        // 등장할 때마다 다음 문구로 순환(현재 언어로).
        model.message = CheckInMessages.message(at: messageIndex, LocalizationManager.shared)
        messageIndex += 1

        if !isVisible {
            isVisible = true
            model.isBlinking = false
            model.appeared = false
            panel?.alphaValue = 1              // 알파 페이드 없이 슬라이드만
            panel?.orderFrontRegardless()
            startGaze()
            startBlinking()
            // 다음 런루프에 등장시켜 슬라이드 애니메이션이 확실히 재생되게 한다.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000)
                if self?.isVisible == true { self?.model.appeared = true }
            }
        }

        // 표시 시간이 끝나면 숨김. 도중에 다시 호출되면 타이머만 갱신.
        visibilityTask?.cancel()
        visibilityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if Task.isCancelled { return }
            self?.hideCharacter()
        }
    }

    private func hideCharacter() {
        guard isVisible else { return }
        isVisible = false

        gazeTask?.cancel(); gazeTask = nil
        blinkTask?.cancel(); blinkTask = nil
        visibilityTask?.cancel(); visibilityTask = nil

        // 사라질 땐 반드시 눈을 뜬 채로, 메뉴바 뒤로 슬라이드해 들어간다.
        model.isBlinking = false
        model.appeared = false

        let closingPanel = panel
        Task { [weak self] in
            // 슬라이드가 끝난 뒤 창을 내린다(알파 페이드와 겹치지 않게).
            try? await Task.sleep(nanoseconds: 620_000_000)
            if self?.isVisible == false {
                closingPanel?.orderOut(nil)
            }
        }
    }

    // MARK: 눈동자 추적 / 깜빡임

    private func startGaze() {
        gazeTask?.cancel()
        gazeTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateGaze()
                try? await Task.sleep(nanoseconds: 33_000_000)  // ~30fps
            }
        }
    }

    private func updateGaze() {
        guard let frame = panel?.frame else { return }
        let mouse = NSEvent.mouseLocation                       // 화면 좌표(좌하단 원점)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = mouse.x - center.x
        let dy = mouse.y - center.y
        let distance = hypot(dx, dy)
        if distance < 1 {
            model.gaze = .zero
            return
        }
        let ease = min(1, distance / 70)                        // 커서가 가까우면 중앙으로
        // 화면 y는 위로, SwiftUI y는 아래로 → dy 부호 반전
        model.gaze = CGVector(dx: (dx / distance) * ease, dy: -(dy / distance) * ease)
    }

    private func startBlinking() {
        blinkTask?.cancel()
        blinkTask = Task { [weak self] in
            // 등장 직후 짧게 한 번 깜빡(인사), 그다음엔 가끔.
            try? await Task.sleep(nanoseconds: 500_000_000)
            while !Task.isCancelled {
                self?.model.isBlinking = true
                try? await Task.sleep(nanoseconds: 150_000_000)
                self?.model.isBlinking = false
                let wait = Double.random(in: 3.0...6.0)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                if Task.isCancelled { break }
            }
        }
    }

    // MARK: 패널

    private func ensurePanel() {
        guard panel == nil else { return }
        let created = CheckInPanel(size: panelSize)
        created.contentView = NSHostingView(rootView: CheckInCharacterView(model: model))
        panel = created
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let width = panelSize.width
        let height = panelSize.height

        // 메뉴바 아이콘 x에 맞춰 그 아래로. 못 찾으면 우측 상단으로 폴백.
        let anchorX = menuBarIconFrame()?.midX ?? (visible.maxX - width / 2 - 8)
        var originX = anchorX - width / 2
        originX = min(max(originX, visible.minX + 4), visible.maxX - width - 4)

        // 패널 top을 메뉴바 바로 아래에 붙인다(캐릭터가 메뉴바에서 튀어나오는 효과).
        let originY = visible.maxY - height
        panel.setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)
    }

    /// MenuBarExtra가 만든 상태바 아이템 창의 프레임을 최선으로 찾는다.
    /// 메뉴바(화면 최상단)의 오른쪽에 있는 작은 창만 인정한다. (엉뚱한 창에 붙지 않도록)
    private func menuBarIconFrame() -> NSRect? {
        guard let screen = NSScreen.main else { return nil }
        let topY = screen.frame.maxY
        let midX = screen.frame.midX
        for window in NSApp.windows {
            let name = String(describing: type(of: window))
            guard name.contains("StatusBar") || name.contains("MenuBarExtra") else { continue }
            let frame = window.frame
            guard frame.width > 0, frame.width < 220 else { continue }
            guard frame.maxY >= topY - 4, frame.midX > midX else { continue }
            return frame
        }
        return nil
    }
}

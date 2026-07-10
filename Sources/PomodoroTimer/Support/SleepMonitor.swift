import AppKit

/// 맥이 잠자기에 들어가거나 화면이 잠기면 타이머를 일시정지하고,
/// 깨어나거나 잠금이 풀리면 (자동 일시정지된 경우에 한해) 다시 재개한다.
///
/// RunLoop 타이머는 시스템 슬립 중에는 대체로 멈추지만, 화면 잠금(슬립 아님)
/// 상태에서는 계속 카운트다운된다. 자리를 비운 동안 시간이 흘러가지 않도록
/// 두 상황 모두에서 명시적으로 멈춘다.
@MainActor
final class SleepMonitor: ObservableObject {
    private let engine: TimerEngine
    /// 이 감시자가 자동으로 멈춘 경우에만 true — 사용자가 직접 멈춘 세션을
    /// 깨어날 때 멋대로 재개하지 않기 위한 플래그.
    private var autoPaused = false

    init(engine: TimerEngine) {
        self.engine = engine

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(handlePause),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(handleResume),
                              name: NSWorkspace.didWakeNotification, object: nil)

        // 화면 잠금/해제는 분산 알림으로만 전달된다.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(handlePause),
                                name: .init("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(handleResume),
                                name: .init("com.apple.screenIsUnlocked"), object: nil)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handlePause() {
        MainActor.assumeIsolated {
            guard engine.isRunning else { return }
            engine.pause()
            autoPaused = true
        }
    }

    @objc private func handleResume() {
        MainActor.assumeIsolated {
            guard autoPaused else { return }
            autoPaused = false
            engine.start()
        }
    }
}

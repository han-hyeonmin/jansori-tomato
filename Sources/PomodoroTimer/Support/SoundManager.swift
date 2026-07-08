import AppKit

/// 세션 완료 시 시스템 사운드를 직접 재생한다.
///
/// 알림(UNUserNotification)의 사운드는 알림 권한이 없으면 울리지 않는다(미서명 개발
/// 빌드에선 권한이 거부되기 일쑤). 그래서 알림과 무관하게 `NSSound`로 직접 재생해
/// 완료 사운드가 항상 울리도록 한다.
@MainActor
final class SoundManager: ObservableObject {
    private let engine: TimerEngine

    init(engine: TimerEngine) {
        self.engine = engine
        engine.addSessionEndObserver { [weak self] finished, completedNormally in
            self?.handle(finished: finished, completedNormally: completedNormally)
        }
    }

    private func handle(finished: SessionType, completedNormally: Bool) {
        guard completedNormally, engine.settings.soundEnabled else { return }
        // 집중 완료는 또렷한 소리, 휴식 완료는 부드러운 소리.
        let name = finished == .focus ? "Glass" : "Tink"
        NSSound(named: name)?.play()
    }
}

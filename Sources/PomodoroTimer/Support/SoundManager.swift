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
        play(named: name)
    }

    /// 설정의 음량 슬라이더에서 호출 — 현재 음량으로 완료음을 미리 들려준다.
    func previewCompletionSound() {
        play(named: "Glass")
    }

    private func play(named name: String) {
        guard let sound = NSSound(named: name) else { return }
        // 같은 NSSound가 재생 중이면 겹치지 않게 멈추고 처음부터.
        if sound.isPlaying { sound.stop() }
        sound.volume = Float(min(1, max(0, engine.settings.soundVolume)))
        sound.play()
    }
}

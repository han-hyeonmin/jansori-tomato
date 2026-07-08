import Foundation
import UserNotifications

/// 세션 전환 시 macOS 네이티브 알림을 띄운다. (M3)
///
/// 알림 권한은 최초 실행 때 요청한다. 스킵으로 넘어간 전환에는 알림을 띄우지 않고,
/// 정상 완료된 전환에만 알림 + (설정 시) 사운드를 낸다.
@MainActor
final class NotificationManager: ObservableObject {
    private let engine: TimerEngine
    private lazy var center = UNUserNotificationCenter.current()

    init(engine: TimerEngine) {
        self.engine = engine

        // 번들 밖(개발 raw 실행)에서는 UNUserNotificationCenter가 크래시하므로 건너뛴다.
        guard AppEnvironment.isBundledApp else {
            NSLog("[Notification] 앱 번들이 아니어서 알림을 건너뜁니다(개발 실행).")
            return
        }

        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error {
                NSLog("[Notification] 권한 요청 실패: \(error.localizedDescription)")
            }
        }
        engine.addSessionEndObserver { [weak self] finished, completedNormally in
            self?.handle(finished: finished, completedNormally: completedNormally)
        }
    }

    private func handle(finished: SessionType, completedNormally: Bool) {
        guard completedNormally else { return }

        let loc = LocalizationManager.shared
        let content = UNMutableNotificationContent()
        if finished == .focus {
            content.title = loc("집중 완료 🍅", "Focus done 🍅")
            content.body = loc(
                "\(engine.sessionType.title(loc)) 시간이에요. 잠깐 쉬어가요.",
                "Time for \(engine.sessionType.title(loc)). Take a breather."
            )
        } else {
            content.title = loc("휴식 끝 ☕️", "Break over ☕️")
            content.body = loc("다시 집중할 준비됐나요?", "Ready to focus again?")
        }
        // 사운드는 SoundManager가 NSSound로 직접 재생한다(알림 권한과 무관하게 보장).

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                NSLog("[Notification] 전송 실패: \(error.localizedDescription)")
            }
        }
    }
}

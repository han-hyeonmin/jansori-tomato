import ServiceManagement
import Foundation

/// 로그인 시 자동 실행 등록/해제. (macOS 13+ `SMAppService`)
///
/// 정상 동작하려면 앱이 제대로 서명·번들된 상태여야 한다. 개발 중 raw 실행 파일에서는
/// register가 실패할 수 있으며, 그 경우 조용히 로그만 남긴다.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        get {
            guard AppEnvironment.isBundledApp else { return false }
            return SMAppService.mainApp.status == .enabled
        }
        set {
            guard AppEnvironment.isBundledApp else { return }
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[LaunchAtLogin] 등록/해제 실패: \(error.localizedDescription)")
            }
        }
    }
}

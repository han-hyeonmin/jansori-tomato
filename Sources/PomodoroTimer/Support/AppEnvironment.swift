import Foundation

enum AppEnvironment {
    /// 제대로 된 .app 번들 안에서 실행 중인지.
    ///
    /// `UNUserNotificationCenter`·`SMAppService` 같은 API는 유효한 번들이 없으면
    /// 크래시하므로, raw 실행 파일로 개발 중일 땐 이 값으로 건너뛴다.
    static var isBundledApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}

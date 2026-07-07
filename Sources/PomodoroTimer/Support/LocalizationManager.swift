import Foundation
import Combine

/// 앱 내 언어(한국어/영어) 전환. 인앱 토글로 즉시 바뀌며 선택은 저장된다.
///
/// 문자열은 `loc("한국어문구", "English text")` 형태로 그 자리에서 두 언어를 함께 적는다.
/// 뷰는 이 객체를 관찰하므로 언어를 바꾸면 즉시 다시 그려진다.
@MainActor
final class LocalizationManager: ObservableObject {
    enum Language: String, CaseIterable, Identifiable {
        case ko, en
        var id: String { rawValue }
        var label: String { self == .ko ? "한국어" : "English" }
    }

    static let shared = LocalizationManager()

    @Published var language: Language {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
            // 시스템의 앱별 언어(다음 실행부터 반영)도 함께 맞춘다.
            UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    private static let key = "pomodoro.language"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let saved = Language(rawValue: raw) {
            language = saved
        } else {
            // 최초 실행: 시스템 언어가 한국어면 ko, 아니면 en.
            let system = Locale.current.language.languageCode?.identifier
            language = (system == "ko") ? .ko : .en
        }
    }

    /// 현재 언어에 맞는 문구를 고른다.
    func callAsFunction(_ ko: String, _ en: String) -> String {
        language == .ko ? ko : en
    }
}

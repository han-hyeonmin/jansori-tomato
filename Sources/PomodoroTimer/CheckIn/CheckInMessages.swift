import Foundation

/// 감시 캐릭터 말풍선에 번갈아 띄울 문구 템플릿(한/영).
/// 집중 여부를 귀엽게 확인하는 톤. 등장할 때마다 순서대로 하나씩 꺼낸다.
enum CheckInMessages {
    /// (한국어, 영어) 쌍.
    static let all: [(ko: String, en: String)] = [
        ("집중하고 있나요? 👀", "Still focused? 👀"),
        ("딴짓 중은 아니죠?", "Not slacking, right?"),
        ("잘하고 있어요, 계속!", "Doing great, keep going!"),
        ("화면 잘 보고 있어요", "I'm watching 👀"),
        ("혹시 유튜브...?", "Is that... YouTube?"),
        ("지켜보고 있어요 👀", "Eyes on you 👀"),
        ("오, 열심이네요!", "Ooh, nice hustle!"),
        ("조금만 더 힘내요", "A little more, you got this"),
        ("눈 안 떼고 있어요", "Not blinking away"),
        ("그 탭 맞나요? 👀", "Right tab? 👀")
    ]

    /// 순환 인덱스 + 현재 언어에 해당하는 문구.
    @MainActor
    static func message(at index: Int, _ loc: LocalizationManager) -> String {
        guard !all.isEmpty else { return "" }
        let pair = all[((index % all.count) + all.count) % all.count]
        return loc(pair.ko, pair.en)
    }
}

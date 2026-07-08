import Foundation

/// 감시 캐릭터 말풍선에 번갈아 띄울 문구 템플릿(한/영).
/// "잔소리 토마토" 컨셉 — 엄마의 잔소리처럼 재치있게(정겹게) 집중을 채근한다.
/// 말풍선 폭(약 220pt)에 맞도록 짧게 유지.
enum CheckInMessages {
    /// (한국어, 영어) 쌍.
    static let all: [(ko: String, en: String)] = [
        ("딴짓하지 말랬지? 👀", "No goofing off~ 👀"),
        ("다 보고 있다 👀", "I see everything 👀"),
        ("그거 일 맞아? 👀", "Is that... work? 👀"),
        ("핸드폰 그만 보고~", "Phone down, please~"),
        ("이러다 밤새운다", "You'll be up all night~"),
        ("허리 펴고 앉아", "Sit up straight now"),
        ("5분만 더 하자, 응?", "5 more minutes, hmm?"),
        ("눈 나빠진다, 집중!", "Focus—or ruin your eyes"),
        ("지금 노는 거 아니지?", "Not slacking, right?"),
        ("다 하고 쉬어", "Finish first, rest later"),
        ("한눈팔지 말고~", "Eyes on the task~"),
        ("눈 똑바로 뜨고 있다 👀", "Keeping an eye on you 👀")
    ]

    /// 순환 인덱스 + 현재 언어에 해당하는 문구.
    @MainActor
    static func message(at index: Int, _ loc: LocalizationManager) -> String {
        guard !all.isEmpty else { return "" }
        let pair = all[((index % all.count) + all.count) % all.count]
        return loc(pair.ko, pair.en)
    }
}

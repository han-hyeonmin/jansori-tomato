import Foundation

/// 타이머 동작을 결정하는 사용자 설정.
struct PomodoroSettings: Codable, Equatable {
    /// 집중 세션 길이(분).
    var focusMinutes: Int
    /// 짧은 휴식 길이(분).
    var shortBreakMinutes: Int
    /// 긴 휴식 길이(분).
    var longBreakMinutes: Int
    /// 긴 휴식이 등장하기까지 필요한 집중 세션 횟수.
    var longBreakInterval: Int
    /// 감시 캐릭터 체크인 주기(분). 0이면 끔.
    var checkInIntervalMinutes: Int
    /// 세션 완료 사운드 재생 여부.
    var soundEnabled: Bool
    /// 완료 사운드 음량(0.0 ~ 1.0).
    var soundVolume: Double
    /// 휴식 시 전체화면 오버레이 대신 알림음만 재생.
    var soundOnlyBreak: Bool

    static let `default` = PomodoroSettings(
        focusMinutes: 25,
        shortBreakMinutes: 5,
        longBreakMinutes: 15,
        longBreakInterval: 4,
        checkInIntervalMinutes: 5,
        soundEnabled: true,
        soundVolume: 0.8,
        soundOnlyBreak: false
    )

    /// 각 세션 종류의 길이를 초 단위로 반환.
    func duration(for type: SessionType) -> Int {
        switch type {
        case .focus: return max(1, focusMinutes) * 60
        case .shortBreak: return max(1, shortBreakMinutes) * 60
        case .longBreak: return max(1, longBreakMinutes) * 60
        }
    }
}

// MARK: - 내구성 있는 디코딩
//
// init(from:)을 확장에 두어 멤버와이즈 이니셜라이저(.default에서 사용)를 유지한다.
// 새 필드가 추가돼도 기존 저장값을 깨뜨리지 않도록 각 키를 decodeIfPresent로 읽고
// 없으면 기본값으로 채운다.
extension PomodoroSettings {
    private enum CodingKeys: String, CodingKey {
        case focusMinutes, shortBreakMinutes, longBreakMinutes
        case longBreakInterval, checkInIntervalMinutes, soundEnabled, soundVolume, soundOnlyBreak
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PomodoroSettings.default
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        longBreakInterval = try c.decodeIfPresent(Int.self, forKey: .longBreakInterval) ?? d.longBreakInterval
        checkInIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .checkInIntervalMinutes) ?? d.checkInIntervalMinutes
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        soundVolume = try c.decodeIfPresent(Double.self, forKey: .soundVolume) ?? d.soundVolume
        soundOnlyBreak = try c.decodeIfPresent(Bool.self, forKey: .soundOnlyBreak) ?? d.soundOnlyBreak
    }
}

// MARK: - UserDefaults 영속화

extension PomodoroSettings {
    private static let storageKey = "pomodoro.settings"

    /// 저장된 설정을 불러오거나 기본값을 반환.
    static func load(from defaults: UserDefaults = .standard) -> PomodoroSettings {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    /// 현재 설정을 저장.
    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

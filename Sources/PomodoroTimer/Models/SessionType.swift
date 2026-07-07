import SwiftUI

/// 뽀모도로 세션의 종류.
enum SessionType: String, CaseIterable, Codable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    /// 현재 언어에 맞는 세션 이름.
    @MainActor
    func title(_ loc: LocalizationManager) -> String {
        switch self {
        case .focus: return loc("집중", "Focus")
        case .shortBreak: return loc("짧은 휴식", "Short Break")
        case .longBreak: return loc("긴 휴식", "Long Break")
        }
    }

    /// 메뉴바에 곁들일 이모지.
    var emoji: String {
        switch self {
        case .focus: return "🍅"
        case .shortBreak: return "☕️"
        case .longBreak: return "🛋️"
        }
    }

    /// 세션별 강조 색.
    var accentColor: Color {
        switch self {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    /// 집중 세션 여부.
    var isBreak: Bool { self != .focus }
}

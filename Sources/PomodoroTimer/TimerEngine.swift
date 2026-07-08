import Foundation
import Combine

/// 타이머 실행 상태.
enum TimerRunState {
    case idle      // 정지 상태(시작 대기)
    case running   // 카운트다운 중
    case paused    // 일시정지
}

/// 뽀모도로 타이머의 핵심 상태 머신.
///
/// 세션 종류(집중 → 휴식) 전환, 남은 시간 카운트다운, 집중 세션 누적을 관리한다.
/// UI는 이 객체를 `ObservableObject`로 구독한다.
@MainActor
final class TimerEngine: ObservableObject {

    // MARK: 발행 상태

    @Published private(set) var sessionType: SessionType = .focus {
        didSet { onStateChange?() }
    }
    @Published private(set) var runState: TimerRunState = .idle {
        didSet { onStateChange?() }
    }
    @Published private(set) var remainingSeconds: Int
    /// 긴 휴식까지의 사이클 진행 카운터. 재시작해도 유지(영속).
    @Published private(set) var completedFocusSessions: Int = 0
    /// 오늘 완료한 집중 수. 자정(날짜 변경)에 자동으로 0으로.
    @Published private(set) var todayFocusCount: Int = 0

    /// 설정 변경 시, 정지 상태라면 남은 시간을 새 길이로 갱신한다.
    @Published var settings: PomodoroSettings {
        didSet {
            settings.save()
            if runState == .idle {
                resetRemaining()
            }
            onStateChange?()
        }
    }

    /// 세션이 끝났을 때 호출되는 옵저버들. 인자는 (끝난 세션, 정상 완료 여부).
    /// 휴식 오버레이·알림·사운드 등 여러 소비자가 각자 등록한다.
    private var sessionEndObservers: [@MainActor (_ finished: SessionType, _ completedNormally: Bool) -> Void] = []

    /// 세션 종료 옵저버 등록.
    func addSessionEndObserver(_ observer: @escaping @MainActor (_ finished: SessionType, _ completedNormally: Bool) -> Void) {
        sessionEndObservers.append(observer)
    }

    /// 세션 종류·실행 상태·설정이 바뀔 때 호출되는 훅. (체크인 스케줄 갱신용)
    var onStateChange: (@MainActor () -> Void)?

    // MARK: 내부

    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let cycleCount = "pomodoro.cycleCount"
        static let todayCount = "pomodoro.today.count"
        static let todayDate = "pomodoro.today.date"
    }

    // MARK: 초기화

    init(settings: PomodoroSettings = .load()) {
        self.settings = settings
        self.remainingSeconds = settings.duration(for: .focus)

        // 사이클 진행은 항상 이어받고, 오늘 카운트는 날짜가 같을 때만 이어받는다.
        completedFocusSessions = defaults.integer(forKey: Keys.cycleCount)
        if defaults.string(forKey: Keys.todayDate) == Self.todayString() {
            todayFocusCount = defaults.integer(forKey: Keys.todayCount)
        }
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: 파생 값

    var isRunning: Bool { runState == .running }

    var totalSeconds: Int { settings.duration(for: sessionType) }

    /// 0.0 ~ 1.0 진행률.
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = Double(totalSeconds - remainingSeconds)
        return min(1, max(0, elapsed / Double(totalSeconds)))
    }

    /// "MM:SS" 형식의 남은 시간.
    var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 메뉴바에 표시할 문자열. 정지 상태에서는 이모지만.
    var menuBarTitle: String {
        switch runState {
        case .idle:
            return sessionType.emoji
        case .running, .paused:
            return "\(sessionType.emoji) \(formattedRemaining)"
        }
    }

    // MARK: 조작

    func start() {
        guard runState != .running else { return }
        runState = .running
        scheduleTimer()
    }

    func pause() {
        guard runState == .running else { return }
        runState = .paused
        invalidateTimer()
    }

    /// 실행 중이면 일시정지, 아니면 시작.
    func toggle() {
        isRunning ? pause() : start()
    }

    /// 현재 세션을 처음 상태로 되돌린다(세션 종류는 유지).
    func reset() {
        invalidateTimer()
        runState = .idle
        resetRemaining()
    }

    /// 현재 세션을 건너뛰고 다음 세션으로 이동(완료로 치지 않음).
    func skip() {
        invalidateTimer()
        advanceToNextSession(completedNormally: false)
    }

    /// 4개 집중 사이클 전체를 초기화한다(사이클 진행 0, 집중 대기 상태로).
    /// "오늘 완료한 집중" 누적 카운트는 건드리지 않는다.
    func resetCycle() {
        invalidateTimer()
        completedFocusSessions = 0
        defaults.set(0, forKey: Keys.cycleCount)
        sessionType = .focus
        runState = .idle
        resetRemaining()
    }

    /// "오늘 완료한 집중" 통계를 0으로 초기화한다.
    func resetStats() {
        todayFocusCount = 0
        defaults.set(0, forKey: Keys.todayCount)
        defaults.set(Self.todayString(), forKey: Keys.todayDate)
    }

    // MARK: 타이머 루프

    private func scheduleTimer() {
        invalidateTimer()
        let newTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetRemaining() {
        remainingSeconds = settings.duration(for: sessionType)
    }

    /// 오늘 완료한 집중 수를 1 늘린다. 날짜가 바뀌었으면 0부터 다시 센다.
    private func incrementTodayCount() {
        let today = Self.todayString()
        if defaults.string(forKey: Keys.todayDate) != today {
            todayFocusCount = 0
            defaults.set(today, forKey: Keys.todayDate)
        }
        todayFocusCount += 1
        defaults.set(todayFocusCount, forKey: Keys.todayCount)
    }

    private func tick() {
        guard runState == .running else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }
        if remainingSeconds <= 0 {
            invalidateTimer()
            advanceToNextSession(completedNormally: true)
        }
    }

    // MARK: 세션 전환

    private func advanceToNextSession(completedNormally: Bool) {
        let finished = sessionType

        // 스킵도 한 세션 소화한 것으로 간주해 점을 채운다.
        // (완료/스킵 구분은 아래 onSessionEnd 훅으로 전달 — 알림/사운드용)
        if finished == .focus {
            completedFocusSessions += 1
            defaults.set(completedFocusSessions, forKey: Keys.cycleCount)
            incrementTodayCount()
        }

        let next: SessionType
        switch finished {
        case .focus:
            let interval = max(1, settings.longBreakInterval)
            let dueForLongBreak = completedFocusSessions > 0
                && completedFocusSessions % interval == 0
            next = dueForLongBreak ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            next = .focus
        }

        sessionType = next
        resetRemaining()

        if next.isBreak {
            // 휴식은 자동 시작 → 전체화면 오버레이가 곧바로 카운트다운.
            runState = .running
            scheduleTimer()
        } else {
            // 다음 집중은 사용자가 "재개"를 누를 때까지 대기(Flow 방식).
            runState = .idle
        }

        for observer in sessionEndObservers {
            observer(finished, completedNormally)
        }
    }
}

import SwiftUI

/// 메뉴바 아이콘을 클릭하면 나타나는 컨트롤 패널.
struct ControlPanelView: View {
    @ObservedObject var engine: TimerEngine
    let checkIn: CheckInController
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showSettings = false

    /// 팝오버 고정 높이(접힌 내용에 딱 맞춤 — 측정값 418 + 여유). nil이면 내용 크기에 맞춘다.
    var fixedHeight: CGFloat? = 419

    var body: some View {
        // 팝오버 창을 고정 크기로 두고 내용은 안에서 스크롤한다.
        // (설정 펼치기·언어 전환 등 내용 높이가 바뀌어도 창이 움직이지 않도록)
        if let fixedHeight {
            ScrollView { content }
                .frame(width: 268, height: fixedHeight)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            sessionHeader
            timerRing
            controlButtons
            sessionDots

            Divider()

            DisclosureGroup(loc("설정", "Settings"), isExpanded: $showSettings) {
                settingsSection
                    .padding(.top, 8)
            }
            .font(.subheadline)

            Divider()

            footer
        }
        .padding(20)
        .frame(width: 268)
    }

    // MARK: 헤더

    private var sessionHeader: some View {
        HStack(spacing: 6) {
            Text(engine.sessionType.emoji)
            Text(engine.sessionType.title(loc))
                .font(.headline)
                .foregroundStyle(engine.sessionType.accentColor)
        }
    }

    // MARK: 진행 링 + 남은 시간

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(engine.sessionType.accentColor.opacity(0.15), lineWidth: 10)

            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(
                    engine.sessionType.accentColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: engine.progress)

            Text(engine.formattedRemaining)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 150, height: 150)
        .padding(.vertical, 4)
    }

    // MARK: 조작 버튼

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: engine.reset) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 20, height: 20)
            }
            .help(loc("현재 세션 리셋", "Reset session"))

            Button(action: engine.toggle) {
                Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                    .frame(width: 28, height: 28)
                    .font(.title2)
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.sessionType.accentColor)
            .help(engine.isRunning ? loc("일시정지", "Pause") : loc("시작", "Start"))

            Button(action: engine.skip) {
                Image(systemName: "forward.fill")
                    .frame(width: 20, height: 20)
            }
            .help(loc("건너뛰기", "Skip"))
        }
    }

    // MARK: 집중 세션 진행 표시(토마토 점)

    private var sessionDots: some View {
        let interval = max(1, engine.settings.longBreakInterval)
        let filled = engine.completedFocusSessions % interval
        return HStack(spacing: 6) {
            ForEach(0..<interval, id: \.self) { index in
                Circle()
                    .fill(index < filled ? SessionType.focus.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .help(loc("긴 휴식까지 \(interval - filled)회 남음",
                  "\(interval - filled) to long break"))
    }

    // MARK: 설정

    private var settingsSection: some View {
        VStack(spacing: 10) {
            durationStepper(loc("집중", "Focus"), value: $engine.settings.focusMinutes, range: 1...90)
            durationStepper(loc("짧은 휴식", "Short break"), value: $engine.settings.shortBreakMinutes, range: 1...30)
            durationStepper(loc("긴 휴식", "Long break"), value: $engine.settings.longBreakMinutes, range: 1...60)
            durationStepper(loc("긴 휴식 주기", "Long break every"), value: $engine.settings.longBreakInterval,
                            range: 2...8, unit: loc("회", "×"))

            Divider()

            Picker(selection: $engine.settings.checkInIntervalMinutes) {
                Text(loc("끄기", "Off")).tag(0)
                Text(loc("3분", "3m")).tag(3)
                Text(loc("5분", "5m")).tag(5)
                Text(loc("10분", "10m")).tag(10)
            } label: {
                Text(loc("감시 캐릭터", "Watching eyes"))
            }
            .pickerStyle(.menu)
            .font(.subheadline)

            Button {
                checkIn.previewNow()
                dismissPopover()
            } label: {
                Label(loc("캐릭터 미리보기", "Preview character"), systemImage: "eye")
                    .frame(maxWidth: .infinity)
            }
            .font(.subheadline)

            Divider()

            Toggle(loc("완료 사운드", "Completion sound"), isOn: $engine.settings.soundEnabled)
                .font(.subheadline)

            Toggle(loc("로그인 시 자동 시작", "Launch at login"), isOn: Binding(
                get: { LaunchAtLogin.isEnabled },
                set: { LaunchAtLogin.isEnabled = $0 }
            ))
            .font(.subheadline)

            Picker(selection: $loc.language) {
                ForEach(LocalizationManager.Language.allCases) { lang in
                    Text(lang.label).tag(lang)
                }
            } label: {
                Text(loc("언어", "Language"))
            }
            .pickerStyle(.menu)
            .font(.subheadline)

            Divider()

            HStack(spacing: 8) {
                Button(loc("사이클 초기화", "Reset cycle")) {
                    engine.resetCycle()
                }
                .frame(maxWidth: .infinity)
                .help(loc("4개 집중 사이클 진행을 0으로 되돌립니다",
                          "Reset the 4-session cycle progress to zero"))

                Button(loc("통계 초기화", "Reset stats")) {
                    engine.resetStats()
                }
                .frame(maxWidth: .infinity)
                .help(loc("오늘 완료한 집중 수를 0으로 되돌립니다",
                          "Reset today's completed focus count to zero"))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func durationStepper(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String? = nil
    ) -> some View {
        let unitText = unit ?? loc("분", "m")
        return Stepper(value: value, in: range) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue)\(unitText)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
    }

    // MARK: 푸터

    private var footer: some View {
        HStack {
            Text(loc("오늘 집중: \(engine.todayFocusCount)", "Today: \(engine.todayFocusCount)"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button(loc("종료", "Quit")) {
                NSApplication.shared.terminate(nil)
            }
            .font(.caption)
        }
    }

    /// 메뉴바 팝오버(현재 key 창)를 닫는다. 미리보기 등장 시 창이 가리지 않도록.
    private func dismissPopover() {
        NSApp.keyWindow?.close()
    }
}

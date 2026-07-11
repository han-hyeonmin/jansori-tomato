import SwiftUI

/// 메뉴바 아이콘을 클릭하면 나타나는 컨트롤 패널.
struct ControlPanelView: View {
    @ObservedObject var engine: TimerEngine
    let checkIn: CheckInController
    let sound: SoundManager
    /// 컨트롤 패널 팝오버를 닫아달라고 요청하는 콜백(AppDelegate가 주입).
    var onRequestClose: (() -> Void)? = nil
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var showSettings = false
    @State private var updateCopied = false
    /// 범위를 벗어난 값을 입력한 필드에 잠깐 띄우는 경고 말풍선 정보.
    @State private var inputWarning: InputWarning?

    /// 어느 필드에서 어떤 경고를 보여줄지. `id`가 바뀌면 표시 타이머가 재시작된다.
    private struct InputWarning: Equatable {
        let field: String
        let text: String
        let id = UUID()
    }

    /// 팝오버 고정 높이(접힌 내용에 딱 맞춤 — 측정값 418 + 여유). nil이면 내용 크기에 맞춘다.
    var fixedHeight: CGFloat? = 419

    var body: some View {
        // 팝오버 창을 고정 크기로 두고 내용은 안에서 스크롤한다.
        // (설정 펼치기·언어 전환 등 내용 높이가 바뀌어도 창이 움직이지 않도록)
        if let fixedHeight {
            // 스크롤 인디케이터를 숨겨, "스크롤바 항상 표시" 설정에서도 스크롤바가
            // 가로 폭을 잠식해 내용이 왼쪽으로 밀리는 현상을 막는다.
            ScrollView { content }
                .scrollIndicators(.hidden)
                .frame(width: 268, height: fixedHeight)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            if let version = updates.availableUpdate {
                updateBanner(version)
            }
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

            if showSettings {
                Divider()
                resetButtons
            }

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

            Button {
                let wasRunning = engine.isRunning
                engine.toggle()
                // 방금 "시작"을 눌렀다면(일시정지가 아니라) 팝오버를 닫아 집중에 들어가게 한다.
                if !wasRunning { dismissPopover() }
            } label: {
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
            durationStepper(loc("집중", "Focus"), value: $engine.settings.focusMinutes, range: 1...59)
            durationStepper(loc("짧은 휴식", "Short break"), value: $engine.settings.shortBreakMinutes, range: 1...59)
            durationStepper(loc("긴 휴식", "Long break"), value: $engine.settings.longBreakMinutes, range: 1...59)
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

            if engine.settings.soundEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    // 슬라이더를 놓는 순간(editing 종료) 현재 음량으로 완료음을 미리 들려준다.
                    Slider(value: $engine.settings.soundVolume, in: 0...1) { editing in
                        if !editing { sound.previewCompletionSound() }
                    }
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .help(loc("완료 사운드 음량 (놓으면 미리듣기)", "Completion sound volume (release to preview)"))
            }

            Toggle(loc("휴식 전체화면 대신 알림음만", "Sound only (no full-screen break)"),
                   isOn: $engine.settings.soundOnlyBreak)
                .font(.subheadline)
                .help(loc("휴식 시 화면을 덮지 않고 알림음만 재생합니다",
                          "Play only a sound at break time instead of covering the screen"))

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

            Button {
                engine.resetSettings()
            } label: {
                Label(loc("기본값으로 초기화", "Reset to defaults"), systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.subheadline)
            .help(loc("시간·주기·감시·사운드 설정을 기본값으로 되돌립니다",
                      "Reset durations, interval, watching eyes, and sound to defaults"))
        }
        // 경고 말풍선은 잠깐 보였다가 사라진다(새 경고가 뜨면 타이머 재시작).
        .task(id: inputWarning?.id) {
            guard inputWarning != nil else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { withAnimation(.easeIn(duration: 0.2)) { inputWarning = nil } }
        }
    }

    /// 초기화 버튼들(설정 펼침 시 설정 아래에 표시).
    private var resetButtons: some View {
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

    /// 라벨 + 직접 입력 가능한 숫자 필드 + 스텝퍼. 값은 범위로 clamp되고,
    /// 범위를 벗어난 값을 입력하면 해당 필드에 경고 말풍선을 잠깐 띄운다.
    private func durationStepper(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unit: String? = nil
    ) -> some View {
        let unitText = unit ?? loc("분", "m")
        let bound = validated(value, range, unit: unitText, field: label)
        return HStack(spacing: 6) {
            Text(label)
            Spacer()
            TextField("", value: bound, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 42)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
            Text(unitText)
                .foregroundStyle(.secondary)
            Stepper("", value: bound, in: range)
                .labelsHidden()
        }
        .font(.subheadline)
        // 경고 말풍선은 이 행 "안"(필드 왼쪽 빈 공간)에 띄운다. 행 높이를 벗어나지
        // 않게 두어야 아래 행이 위에 그려지며 말풍선을 덮거나, 스크롤뷰에 잘리는 일이 없다.
        .overlay(alignment: .trailing) {
            if let warning = inputWarning, warning.field == label {
                WarningBubble(text: warning.text)
                    .padding(.trailing, 96)   // 필드 묶음(입력칸+단위+스텝퍼) 왼쪽에 자리잡기
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 범위를 벗어나지 않게 clamp하되, 벗어난 입력이 들어오면 경고를 띄우는 바인딩.
    private func validated(
        _ value: Binding<Int>,
        _ range: ClosedRange<Int>,
        unit: String,
        field: String
    ) -> Binding<Int> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
                if newValue != clampedValue {
                    withAnimation(.easeOut(duration: 0.15)) {
                        inputWarning = InputWarning(
                            field: field,
                            text: loc("\(range.lowerBound)~\(range.upperBound)\(unit)만 입력할 수 있어요",
                                      "Enter \(range.lowerBound)–\(range.upperBound) only")
                        )
                    }
                }
                value.wrappedValue = clampedValue
            }
        )
    }

    /// 새 버전 알림 배너. 클릭하면 `brew upgrade` 명령을 복사한다(Homebrew 업데이트).
    private func updateBanner(_ version: String) -> some View {
        Button {
            updates.copyUpgradeCommand()
            updateCopied = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                updateCopied = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: updateCopied ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                Text(updateCopied
                     ? loc("복사됨 · 터미널에 붙여넣기", "Copied · paste in Terminal")
                     : loc("새 버전 v\(version) · brew upgrade", "Update v\(version) · brew upgrade"))
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "doc.on.doc")
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .help(loc("클릭하면 brew upgrade 명령을 복사합니다", "Click to copy the brew upgrade command"))
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

    /// 메뉴바 팝오버를 닫는다. 버튼 이벤트가 끝난 뒤(next runloop) 닫아야 안정적이다.
    private func dismissPopover() {
        DispatchQueue.main.async {
            if let onRequestClose {
                onRequestClose()
                return
            }
            // 폴백: 콜백이 없으면 팝오버(또는 키 윈도우)를 직접 찾아 닫는다.
            if let key = NSApp.keyWindow {
                key.close()
                return
            }
            for window in NSApp.windows {
                let name = String(describing: type(of: window))
                if name.contains("Popover") {
                    window.close()
                }
            }
        }
    }
}

/// 입력 범위 안내용 경고 말풍선. 오른쪽 꼬리가 해당 입력 필드를 가리킨다.
private struct WarningBubble: View {
    let text: String

    var body: some View {
        HStack(spacing: -0.5) {
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 7))
            BubbleTail()
                .fill(Color.orange)
                .frame(width: 6, height: 12)
        }
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }
}

/// 말풍선 오른쪽 꼬리(오른쪽을 가리키는 삼각형).
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

import SwiftUI
import AppKit

/// 메뉴바 아이콘을 클릭하면 나타나는 컨트롤 패널.
///
/// 레이아웃은 macOS 메뉴바 유틸리티의 관용적인 구성을 따른다.
/// 상단에 현재 상태를 요약한 카드, 그 아래 얇은 상태 한 줄, 구분선으로 나눈
/// "라벨 왼쪽 · 컨트롤 오른쪽" 행 그룹, 마지막에 평문 메뉴 항목, 맨 아래 중앙에
/// 접기/펼치기 토글. 접힌 상태에서는 타이머 조작까지만 보이고, 설정과 메뉴
/// 항목은 "더 보기"로 펼친다.
struct ControlPanelView: View {
    @ObservedObject var engine: TimerEngine
    let checkIn: CheckInController
    let sound: SoundManager
    /// 컨트롤 패널 팝오버를 닫아달라고 요청하는 콜백(AppDelegate가 주입).
    var onRequestClose: (() -> Void)? = nil
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var updates = UpdateChecker.shared
    /// 설정·메뉴 항목까지 펼친 상태인지("더 보기" / "간략히 보기").
    @State private var expanded = false
    /// 펼친 내용의 실측 높이. 펼치는 첫 프레임에서 크기가 튀지 않도록 대략치로 시작해
    /// 실제 측정값으로 교정된다(언어·설정에 따라 내용 높이가 조금씩 달라진다).
    @State private var expandedContentHeight: CGFloat = 640
    @State private var updateCopied = false
    /// 범위를 벗어난 값을 입력한 필드에 잠깐 띄우는 경고 말풍선 정보.
    @State private var inputWarning: InputWarning?

    /// 어느 필드에서 어떤 경고를 보여줄지. `id`가 바뀌면 표시 타이머가 재시작된다.
    private struct InputWarning: Equatable {
        let field: String
        let text: String
        let id = UUID()
    }

    // MARK: 치수

    /// 패널 폭.
    private let panelWidth: CGFloat = 280
    /// 카드·구분선 안쪽에서 행이 추가로 들여쓰는 양(카드는 구분선보다 조금 넓다).
    private let rowInset: CGFloat = 7

    private var rowFont: Font { .system(size: 12.5) }
    private var captionFont: Font { .system(size: 11) }
    private var accent: Color { engine.sessionType.accentColor }

    /// 펼친 상태의 팝오버 높이. 내용 높이를 그대로 쓰되, 화면을 넘지 않게 자른다
    /// (잘리면 안에서 스크롤된다).
    private var expandedHeight: CGFloat {
        let available = (NSScreen.main?.visibleFrame.height ?? 900) - 40
        return min(expandedContentHeight, max(360, available))
    }

    var body: some View {
        // 접힌 상태는 내용 높이 그대로(팝오버가 딱 맞게 줄어든다).
        // 펼친 상태는 실측 높이 + 스크롤 — 스크롤 인디케이터를 숨겨 "스크롤바 항상
        // 표시" 설정에서도 가로 폭을 잠식하지 않게 한다.
        if expanded {
            ScrollView { content.measuringHeight() }
                .scrollIndicators(.hidden)
                .frame(width: panelWidth, height: expandedHeight)
                .onPreferenceChange(ContentHeightKey.self) { height in
                    if height > 0 { expandedContentHeight = height }
                }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let version = updates.availableUpdate {
                updateBanner(version)
            }

            heroCard
            statusLine.padding(.horizontal, rowInset)

            separator
            controlRow.padding(.horizontal, rowInset)

            if expanded {
                separator
                durationSection.padding(.horizontal, rowInset)

                separator
                behaviorSection.padding(.horizontal, rowInset)

                separator
                actionSection

                separator
                MenuRow(title: loc("Jansori Tomato 종료", "Quit Jansori Tomato"),
                        help: loc("앱을 종료합니다", "Quit the app")) {
                    NSApplication.shared.terminate(nil)
                }
            }

            separator
            expandToggle
        }
        .padding(.horizontal, rowInset)
        .padding(.top, 9)
        .padding(.bottom, 6)
        .frame(width: panelWidth)
    }

    /// 구분선. 카드보다 한 단계 안쪽에서 시작한다.
    private var separator: some View {
        Divider().padding(.horizontal, rowInset)
    }

    // MARK: 상태 요약 카드

    private var heroCard: some View {
        HStack(spacing: 12) {
            heroIcon
            VStack(alignment: .leading, spacing: 1) {
                Text(engine.formattedRemaining)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("\(engine.sessionType.title(loc)) · \(runStateText)")
                    .font(captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    /// 카드 왼쪽의 작은 진행 링(안에 세션 이모지).
    private var heroIcon: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.18), lineWidth: 3.5)

            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: engine.progress)

            Text(engine.sessionType.emoji)
                .font(.system(size: 15))
        }
        .frame(width: 38, height: 38)
    }

    private var runStateText: String {
        switch engine.runState {
        case .idle: return loc("시작 대기", "Ready")
        case .running: return loc("진행 중", "Running")
        case .paused: return loc("일시정지", "Paused")
        }
    }

    // MARK: 상태 한 줄(오늘 집중 + 사이클 점)

    private var statusLine: some View {
        let interval = max(1, engine.settings.longBreakInterval)
        let filled = engine.completedFocusSessions % interval
        return HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(loc("오늘 집중 \(engine.todayFocusCount)회", "\(engine.todayFocusCount) focused today"))
                .font(captionFont)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            HStack(spacing: 5) {
                ForEach(0..<interval, id: \.self) { index in
                    Circle()
                        .fill(index < filled ? SessionType.focus.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .help(loc("긴 휴식까지 \(interval - filled)회 남음",
                      "\(interval - filled) to long break"))
        }
    }

    // MARK: 타이머 조작

    private var controlRow: some View {
        HStack(spacing: 6) {
            Button {
                let wasRunning = engine.isRunning
                engine.toggle()
                // 방금 "시작"을 눌렀다면(일시정지가 아니라) 팝오버를 닫아 집중에 들어가게 한다.
                if !wasRunning { dismissPopover() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 10))
                    Text(engine.isRunning ? loc("일시정지", "Pause") : loc("시작", "Start"))
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .help(engine.isRunning ? loc("일시정지", "Pause") : loc("시작", "Start"))

            iconButton("arrow.counterclockwise", help: loc("현재 세션 리셋", "Reset session"),
                       action: engine.reset)
            iconButton("forward.fill", help: loc("건너뛰기", "Skip"),
                       action: engine.skip)
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .frame(width: 16, height: 15)
        }
        .buttonStyle(.bordered)
        .help(help)
    }

    // MARK: 세션 길이

    private var durationSection: some View {
        VStack(spacing: 7) {
            durationStepper(loc("집중", "Focus"), value: $engine.settings.focusMinutes, range: 1...59)
            durationStepper(loc("짧은 휴식", "Short break"), value: $engine.settings.shortBreakMinutes, range: 1...59)
            durationStepper(loc("긴 휴식", "Long break"), value: $engine.settings.longBreakMinutes, range: 1...59)
            durationStepper(loc("긴 휴식 주기", "Long break every"), value: $engine.settings.longBreakInterval,
                            range: 2...8, unit: loc("회", "×"))
        }
        // 경고 말풍선은 잠깐 보였다가 사라진다(새 경고가 뜨면 타이머 재시작).
        .task(id: inputWarning?.id) {
            guard inputWarning != nil else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { withAnimation(.easeIn(duration: 0.2)) { inputWarning = nil } }
        }
    }

    // MARK: 동작 설정

    // 팝업 메뉴에는 폭을 지정하지 않는다. 고정 폭을 주면 팝업 버튼이 그 안에서
    // 가운데 정렬돼, 항목 글자 폭에 따라(예: "10분" vs "English") 오른쪽 끝이
    // 제각각 안쪽으로 밀린다. fixedSize로 고유 폭을 쓰면 토글·스텝퍼와 오른쪽 끝이 맞는다.
    private var behaviorSection: some View {
        VStack(spacing: 7) {
            settingRow(loc("감시 캐릭터", "Watching eyes")) {
                Picker("", selection: $engine.settings.checkInIntervalMinutes) {
                    Text(loc("끄기", "Off")).tag(0)
                    Text(loc("3분", "3m")).tag(3)
                    Text(loc("5분", "5m")).tag(5)
                    Text(loc("10분", "10m")).tag(10)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .font(rowFont)
                .fixedSize()
            }

            settingRow(loc("완료 사운드", "Completion sound")) {
                switchToggle($engine.settings.soundEnabled)
            }

            if engine.settings.soundEnabled {
                volumeRow
            }

            settingRow(loc("휴식은 알림음만", "Sound-only break"),
                       help: loc("휴식 시 화면을 덮지 않고 알림음만 재생합니다",
                                 "Play only a sound at break time instead of covering the screen")) {
                switchToggle($engine.settings.soundOnlyBreak)
            }

            settingRow(loc("로그인 시 자동 시작", "Launch at login")) {
                switchToggle(Binding(
                    get: { LaunchAtLogin.isEnabled },
                    set: { LaunchAtLogin.isEnabled = $0 }
                ))
            }

            settingRow(loc("언어", "Language")) {
                Picker("", selection: $loc.language) {
                    ForEach(LocalizationManager.Language.allCases) { lang in
                        Text(lang.label).tag(lang)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .font(rowFont)
                .fixedSize()
            }
        }
    }

    /// 완료 사운드 음량. 슬라이더를 놓는 순간(editing 종료) 현재 음량으로 미리 들려준다.
    private var volumeRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 12)
            Slider(value: $engine.settings.soundVolume, in: 0...1) { editing in
                if !editing { sound.previewCompletionSound() }
            }
            .controlSize(.small)
            Text("\(Int((engine.settings.soundVolume * 100).rounded()))%")
                .font(captionFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .help(loc("완료 사운드 음량 (놓으면 미리듣기)", "Completion sound volume (release to preview)"))
    }

    // MARK: 메뉴 항목

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuRow(title: loc("캐릭터 미리보기…", "Preview character…"),
                    help: loc("감시 캐릭터가 지금 나타납니다", "Show the watching character right now")) {
                checkIn.previewNow()
                dismissPopover()
            }
            MenuRow(title: loc("사이클 초기화", "Reset cycle"),
                    help: loc("긴 휴식까지의 집중 사이클 진행을 0으로 되돌립니다",
                              "Reset the cycle progress toward the long break to zero")) {
                engine.resetCycle()
            }
            MenuRow(title: loc("통계 초기화", "Reset stats"),
                    help: loc("오늘 완료한 집중 수를 0으로 되돌립니다",
                              "Reset today's completed focus count to zero")) {
                engine.resetStats()
            }
            MenuRow(title: loc("설정 기본값으로 초기화", "Reset settings to defaults"),
                    help: loc("시간·주기·감시·사운드 설정을 기본값으로 되돌립니다",
                              "Reset durations, interval, watching eyes, and sound to defaults")) {
                engine.resetSettings()
            }
        }
    }

    // MARK: 접기 / 펼치기

    private var expandToggle: some View {
        Button {
            expanded.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                Text(expanded ? loc("간략히 보기", "Show less") : loc("더 보기", "Show more"))
                    .font(captionFont)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    // MARK: 행 구성 도우미

    /// 라벨(+선택적 ⓘ 도움말)을 왼쪽에, 컨트롤을 오른쪽에 두는 설정 행.
    private func settingRow<Control: View>(
        _ label: String,
        help: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 5) {
            Text(label).font(rowFont)
            if let help {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .help(help)
            }
            Spacer(minLength: 8)
            control()
        }
    }

    private func switchToggle(_ isOn: Binding<Bool>) -> some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(accent)
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
        return settingRow(label) {
            HStack(spacing: 5) {
                TextField("", value: bound, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(width: 40)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .font(rowFont)
                // 단위는 고정폭 열로 둔다. 폭을 주지 않으면 글자 폭 차이(영어 "m" vs
                // "×")만큼 오른쪽 정렬된 묶음이 밀려, 행마다 입력칸 위치가 어긋난다.
                Text(unitText)
                    .font(captionFont)
                    .foregroundStyle(.secondary)
                    .frame(width: 14, alignment: .leading)
                Stepper("", value: bound, in: range)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
        // 경고 말풍선은 이 행 "안"(필드 왼쪽 빈 공간)에 띄운다. 행 높이를 벗어나지
        // 않게 두어야 아래 행이 위에 그려지며 말풍선을 덮거나, 스크롤뷰에 잘리는 일이 없다.
        .overlay(alignment: .trailing) {
            if let warning = inputWarning, warning.field == label {
                WarningBubble(text: warning.text)
                    .padding(.trailing, 92)   // 필드 묶음(입력칸+단위+스텝퍼) 왼쪽에 자리잡기
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

/// 펼친 내용의 높이를 상위로 올려보내는 preference 키.
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    /// 자기 높이를 `ContentHeightKey`로 보고한다.
    func measuringHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
            }
        )
    }
}

/// 메뉴처럼 보이는 평문 항목 행. 호버하면 배경이 옅게 깔린다.
private struct MenuRow: View {
    let title: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 12.5))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hovering ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
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

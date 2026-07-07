import SwiftUI

/// 휴식 전체화면 오버레이. resting(쉬는 중) / ready(재개) 두 모드.
/// 캐릭터 없이 타이포그래피 중심의 잔잔한 화면.
struct BreakOverlayView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var controller: BreakOverlayController
    @ObservedObject private var loc = LocalizationManager.shared

    // 팔레트 — 어느 바탕화면 위에서도 읽히도록 프로스트 위에 트와일라잇 틴트.
    private let ink = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let inkSoft = Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.66)
    private let mint = Color(red: 0.44, green: 0.89, blue: 0.76)
    private let coral = Color(red: 1.0, green: 0.48, blue: 0.40)

    var body: some View {
        ZStack {
            background
            content
            closeButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Button("", action: controller.closeCover)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
        )
    }

    // MARK: 배경

    private var background: some View {
        ZStack {
            VisualEffectView()
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.12, blue: 0.19),
                    Color(red: 0.08, green: 0.19, blue: 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.82)
        }
        .ignoresSafeArea()
    }

    // MARK: 모드별 본문

    @ViewBuilder
    private var content: some View {
        switch controller.mode {
        case .resting: resting
        case .ready: ready
        }
    }

    private var resting: some View {
        VStack(spacing: 20) {
            eyebrow(loc("잠깐 쉬어가요", "Take a break"))

            Text(engine.formattedRemaining)
                .font(.system(size: 108, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)

            Text(loc("화면에서 눈을 떼고 크게 한 번 숨 쉬어요.",
                     "Look away from the screen and take a deep breath."))
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(inkSoft)

            Button(action: controller.startFocusFromRest) {
                Text(loc("지금 집중 시작", "Start focusing now"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(inkSoft)
                    .padding(.top, 8)
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
    }

    private var ready: some View {
        VStack(spacing: 22) {
            eyebrow(loc("휴식 끝", "Break over"))

            Text(loc("다시 시작해 볼까요?", "Ready to dive back in?"))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)

            Text(loc("준비되면 눌러요. 눈이 지켜보고 있을게요 👀",
                     "Hit it when you're ready. The eyes are watching 👀"))
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(inkSoft)

            Button(action: controller.startFocus) {
                Text(loc("집중 다시 시작", "Start focusing"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.1, green: 0.11, blue: 0.16))
                    .padding(.horizontal, 34)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(coral))
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .padding(.top, 8)

            Button(loc("조금 더 쉬기", "Rest a bit more"), action: controller.closeCover)
                .buttonStyle(.plain)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(inkSoft)
                .pointingCursor()
        }
    }

    // MARK: 조각

    private func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .tracking(3)
            .foregroundStyle(mint)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: controller.closeCover) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(inkSoft)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .help(loc("가리기 닫기 (Esc)", "Dismiss (Esc)"))
            }
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - 편의

private extension View {
    /// 마우스를 올리면 손가락 커서로 바꾼다.
    func pointingCursor() -> some View {
        onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

import SwiftUI

/// 캐릭터가 참조하는 표시 상태. 컨트롤러가 값을 갱신하면 뷰가 반응한다.
@MainActor
final class EyeModel: ObservableObject {
    /// 등장/퇴장 트리거. true면 메뉴바 아래로 쑥 내려와 머문다.
    @Published var appeared = false
    /// 눈 깜빡임.
    @Published var isBlinking = false
    /// 눈동자 시선. 각 성분 -1...1, 뷰 좌표계(y는 아래로 증가).
    @Published var gaze = CGVector(dx: 0, dy: 0)
    /// 말풍선 문구.
    @Published var message: String = ""
}

/// 👀 눈알 이모지 느낌의 감시 캐릭터.
/// 얼굴 없이 눈 두 개만 메뉴바 아래로 튀어나와 커서를 좇고, 말풍선으로 말을 건다.
struct CheckInCharacterView: View {
    @ObservedObject var model: EyeModel

    private let panelWidth: CGFloat = 220
    private let panelHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 5) {
            eyes
            bubble
            Spacer(minLength: 0)
        }
        .frame(width: panelWidth, height: panelHeight, alignment: .top)
        // 숨을 땐 패널 위(메뉴바 뒤)로 완전히 올라가고, 나올 땐 살짝 아래로.
        .offset(y: model.appeared ? 6 : -(panelHeight + 12))
        .animation(.spring(response: 0.55, dampingFraction: 0.74), value: model.appeared)
    }

    // MARK: 눈 두 개 (👀)

    private var eyes: some View {
        HStack(spacing: 6) {
            eye
            eye
        }
    }

    private var eye: some View {
        ZStack {
            // 👀 처럼 세로로 더 긴 눈.
            Ellipse()
                .fill(.white)
                .overlay(Ellipse().stroke(Color(white: 0.80), lineWidth: 1.5))
                .frame(width: 42, height: model.isBlinking ? 6 : 58)
                .shadow(color: .black.opacity(0.20), radius: 5, x: 0, y: 2)

            if !model.isBlinking {
                Circle()
                    .fill(Color(white: 0.10))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 7, height: 7)
                            .offset(x: -3, y: -3)
                    )
                    .offset(x: model.gaze.dx * 9, y: model.gaze.dy * 13)
            }
        }
        // 고정 높이 컨테이너: 깜빡여도 눈 영역 크기가 그대로라 말풍선이 안 움직인다.
        .frame(width: 42, height: 58)
        .animation(.easeOut(duration: 0.1), value: model.isBlinking)
        .animation(.easeOut(duration: 0.09), value: model.gaze.dx)
        .animation(.easeOut(duration: 0.09), value: model.gaze.dy)
    }

    // MARK: 말풍선

    private var bubble: some View {
        VStack(spacing: 0) {
            TriangleUp()
                .fill(Color.white.opacity(0.97))
                .frame(width: 16, height: 9)

            Text(model.message)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.15))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.97))
                )
        }
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
        .opacity(model.message.isEmpty ? 0 : 1)
    }
}

/// 위를 향한 삼각형(말풍선 꼬리).
private struct TriangleUp: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

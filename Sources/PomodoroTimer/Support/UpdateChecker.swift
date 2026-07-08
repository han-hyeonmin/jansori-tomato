import Foundation
import AppKit

/// GitHub의 최신 릴리즈를 확인해 새 버전이 있으면 알려주는 가벼운 업데이트 체크.
///
/// 전체 자동 설치(Sparkle 등)는 EdDSA 서명·appcast 호스팅이 필요해 무겁다. 여기서는
/// 최신 릴리즈 태그를 비교해 "새 버전 있음"만 표시하고, 클릭 시 릴리즈 페이지를 연다.
/// (Homebrew 사용자는 `brew upgrade`로 갱신)
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var latestVersion: String?

    private let repo = "han-hyeonmin/jansori-tomato"
    private var checked = false

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// 새 버전이 있으면 그 버전 문자열, 없으면 nil.
    var availableUpdate: String? {
        guard let latest = latestVersion,
              latest.compare(currentVersion, options: .numeric) == .orderedDescending
        else { return nil }
        return latest
    }

    /// 앱당 한 번, 백그라운드로 최신 릴리즈를 확인.
    func checkOnce() {
        guard !checked else { return }
        checked = true
        Task { await check() }
    }

    func check() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            latestVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        } catch {
            NSLog("[Update] 확인 실패: \(error.localizedDescription)")
        }
    }

    func openLatestRelease() {
        if let url = URL(string: "https://github.com/\(repo)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }
}

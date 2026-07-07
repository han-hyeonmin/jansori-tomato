import AppKit

// H 모티브 토마토 앱 아이콘을 코드로 그려 iconset PNG들을 생성한다.
// 사용법: swift Scripts/IconGenerator.swift <출력_iconset_디렉토리>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

/// 크기 px의 아이콘 한 장을 그려 PNG 데이터로 반환.
func drawIcon(px: Int) -> Data {
    let S = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx

    // 1) 토마토 몸통 — 둥근 사각형 + 세로 그라데이션.
    let margin = S * 0.045
    let bodyRect = NSRect(x: margin, y: margin, width: S - 2*margin, height: S - 2*margin)
    let radius = (S - 2*margin) * 0.235
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
    let tomato = NSGradient(colors: [color(255, 112, 92), color(226, 59, 46)])!
    tomato.draw(in: bodyPath, angle: -90)

    // 부드러운 상단 하이라이트.
    let highlight = NSGradient(colors: [color(255, 255, 255, 0.28), color(255, 255, 255, 0)])!
    highlight.draw(in: bodyPath, relativeCenterPosition: NSPoint(x: -0.25, y: 0.55))

    // 2) 초록 꼭지(칼릭스) — 5갈래 별.
    let calyx = NSBezierPath()
    let cc = NSPoint(x: S * 0.5, y: S * 0.80)
    let outerR = S * 0.135
    let innerR = S * 0.058
    for i in 0..<10 {
        let r = (i % 2 == 0) ? outerR : innerR
        let angle = CGFloat.pi/2 + CGFloat(i) * (.pi / 5)
        let p = NSPoint(x: cc.x + cos(angle) * r, y: cc.y + sin(angle) * r)
        if i == 0 { calyx.move(to: p) } else { calyx.line(to: p) }
    }
    calyx.close()
    color(58, 190, 96).setFill()
    calyx.fill()

    // 3) 크림색 "H" — 세로 막대 2 + 가로 막대 1.
    let cream = color(255, 243, 226)
    cream.setFill()
    let barW = S * 0.125
    let barTop = S * 0.66
    let barBottom = S * 0.255
    let barH = barTop - barBottom
    let leftX = S * 0.305
    let rightX = S * 0.57
    let barR = S * 0.045
    for x in [leftX, rightX] {
        let bar = NSBezierPath(
            roundedRect: NSRect(x: x, y: barBottom, width: barW, height: barH),
            xRadius: barR, yRadius: barR
        )
        bar.fill()
    }
    let crossH = S * 0.115
    let crossY = barBottom + barH/2 - crossH/2
    let cross = NSBezierPath(
        roundedRect: NSRect(x: leftX, y: crossY, width: (rightX + barW) - leftX, height: crossH),
        xRadius: barR, yRadius: barR
    )
    cross.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// iconset이 요구하는 (파일명, 픽셀크기) 목록.
let specs: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for (name, px) in specs {
    let data = drawIcon(px: px)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    try? data.write(to: url)
    print("✓ \(name) (\(px)px)")
}
print("완료: \(outDir)")

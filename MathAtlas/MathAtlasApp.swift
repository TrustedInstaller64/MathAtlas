//
//  MathAtlasApp.swift
//  MathAtlas
//
//  Created by TrustedInstaller on 2026/6/30.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // Set icon early so it shows during launch / in Finder / Dock
        // NSApp.applicationIconImage = AppIcon.make()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        PromptManager.ensureDefaultsExist()
        if let window = NSApp.windows.first {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
        }
    }
}

// MARK: - Icon (commented out — uncomment to restore code-generated icon)
/*
enum AppIcon {
    static func make() -> NSImage {
        if let icon = NSImage(named: "ICON") { return icon }
        let size: CGFloat = 1024
        let image = NSImage(size: NSSize(width: size, height: size))
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)!
        image.addRepresentation(rep); image.lockFocus()
        let pad: CGFloat = size * 0.04
        let bg = NSBezierPath(roundedRect: NSRect(x: pad, y: pad, width: size-2*pad, height: size-2*pad),
                              xRadius: size*0.22, yRadius: size*0.22)
        NSColor.white.setFill(); bg.fill()
        NSColor(white: 0.85, alpha: 1).setStroke(); bg.lineWidth = size*0.008; bg.stroke()
        let str = NSAttributedString(string: "\u{2211}", attributes: [
            .font: NSFont.systemFont(ofSize: size*0.52, weight: .medium), .foregroundColor: NSColor.black])
        let ss = str.size()
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: (size-ss.width*1.35)/2, yBy: (size-ss.height)/2+size*0.04)
        t.scaleX(by: 1.35, yBy: 1.0); t.concat()
        str.draw(at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        image.unlockFocus()
        return image
    }
}
*/

// MARK: - App

@main
struct MathAtlasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var locale = LocaleManager()
    @State private var settings = AppSettings()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(locale)
                    .environment(settings)
                    .frame(minWidth: 900, minHeight: 600)

                if showSplash {
                    SplashView(isShowing: $showSplash)
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)
        .windowResizability(.contentSize)
        .commands {
            // 文件菜单
            CommandGroup(after: .newItem) {
                Button(locale.newProblem) {}
                    .keyboardShortcut("n", modifiers: [.command])
                Divider()
                Button("关闭") { NSApp.keyWindow?.close() }
                    .keyboardShortcut("w", modifiers: [.command])
            }

            // 编辑菜单 — 保留默认
            CommandGroup(replacing: .undoRedo) {}

            // 显示菜单 — 偏好设置
            CommandGroup(replacing: .appSettings) {
                Button(locale.menuSettings) {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            // App 菜单 — 关于
            CommandGroup(replacing: .appInfo) {
                Button("关于 MathAtlas") {
                    NotificationCenter.default.post(name: .openAbout, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("MathAtlasOpenSettings")
    static let openAbout = Notification.Name("MathAtlasOpenAbout")
}

// MARK: - Splash View

enum SplashSpeed: String, CaseIterable {
    case fast   = "fast"
    case medium = "medium"
    case slow   = "slow"
    var multiplier: Double {
        switch self { case .fast: 1.0; case .medium: 1.6; case .slow: 2.4 }
    }
    var displayName: String {
        switch self { case .fast: "快"; case .medium: "中"; case .slow: "慢" }
    }
}

struct SplashView: View {
    @Binding var isShowing: Bool
    @AppStorage("splashSpeed") private var speedRaw: String = "fast"
    private var speed: Double { SplashSpeed(rawValue: speedRaw)?.multiplier ?? 1.0 }

    @State private var strokeProgress: CGFloat = 0
    @State private var strokeOpacity: Double = 1
    @State private var fillOpacity: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var contentOpacity: Double = 1

    private let sigmaFont = CTFontCreateWithName("Times New Roman" as CFString, 480, nil)
        ?? CTFontCreateUIFontForLanguage(.system, 480, nil)
        ?? CTFontCreateWithName("Helvetica" as CFString, 480, nil)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    // Filled sigma (appears after stroke)
                    SigmaShape(font: sigmaFont)
                        .fill(Color.black.opacity(fillOpacity))
                        .scaleEffect(x: scale, y: -1.0)
                        .frame(width: 320, height: 320)

                    // Stroked sigma (drawing animation)
                    SigmaShape(font: sigmaFont)
                        .trim(from: 0, to: strokeProgress)
                        .stroke(
                            Color.black,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .scaleEffect(x: scale, y: -1.0)
                        .frame(width: 320, height: 320)
                        .opacity(strokeOpacity)
                }

                Text("MathAtlas")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.black.opacity(0.6))
                    .opacity(fillOpacity)
                    .offset(y: -20)
            }
            .opacity(contentOpacity)
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        let s = speed
        // Phase 1: Stroke draws sigma (0 → ~1.2s)
        withAnimation(.easeInOut(duration: 1.2 * s).delay(0.1 * s)) { strokeProgress = 1.0 }

        // Phase 2: Fill + scale (stroke fades, fill appears) — after stroke completes
        let t1 = 1.4 * s
        DispatchQueue.main.asyncAfter(deadline: .now() + t1) {
            withAnimation(.easeOut(duration: 0.2 * s)) { strokeOpacity = 0; fillOpacity = 1 }
            withAnimation(.spring(response: 0.5 * s, dampingFraction: 0.6)) { scale = 1.35 }
        }

        // Phase 3: Sigma + text fade out on white background
        let t2 = 2.2 * s
        DispatchQueue.main.asyncAfter(deadline: .now() + t2) {
            withAnimation(.easeInOut(duration: 0.5 * s)) { contentOpacity = 0 }
        }

        // Phase 4: Show main content
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8 * s) { isShowing = false }
    }
}

// MARK: - Sigma Glyph Shape

struct SigmaShape: Shape {
    let font: CTFont

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Get glyph for ∑ (U+2211)
        let chars: [UniChar] = [0x2211]
        var glyphs: [CGGlyph] = [0]
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, 1)

        guard let glyphPath = CTFontCreatePathForGlyph(font, glyphs[0], nil) else {
            return path
        }

        // Scale and center the glyph path to fit the rect
        let boundingBox = glyphPath.boundingBox
        let glyphWidth = boundingBox.width
        let glyphHeight = boundingBox.height

        guard glyphWidth > 0, glyphHeight > 0 else { return path }

        let scaleX = rect.width / glyphWidth * 0.85
        let scaleY = rect.height / glyphHeight * 0.85
        let scale = min(scaleX, scaleY)

        let offsetX = (rect.width - glyphWidth * scale) / 2 - boundingBox.minX * scale
        let offsetY = (rect.height - glyphHeight * scale) / 2 - boundingBox.minY * scale

        var transform = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: offsetX / scale, y: offsetY / scale)

        if let transformedPath = glyphPath.copy(using: &transform) {
            path = Path(transformedPath)
        }

        return path
    }
}

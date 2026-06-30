import SwiftUI

struct AboutView: View {
    @Environment(LocaleManager.self) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Icon area
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .frame(width: 72, height: 72)

                Text("MathAtlas")
                    .font(.system(size: 20, weight: .bold))

                Text("版本 V1.0.0（正式版）")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider().padding(.horizontal, 40)

            // Info
            VStack(alignment: .leading, spacing: 12) {
                infoRow("软件作者", "@TrustedInstaller64")
                linkRow("GitHub", "https://github.com/TrustedInstaller64")
                linkRow("项目仓库", "https://github.com/TrustedInstaller64/MathAtlas")
                infoRow("Bug 反馈", "xsy3110293296@outlook.com")
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 16)

            Divider().padding(.horizontal, 40)

            Text("如遇到问题，请发送邮件至 xsy3110293296@outlook.com\n附上问题描述与复现步骤，感谢您的支持。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Button("关闭") { dismiss() }
            .buttonStyle(.bordered)
            .padding(.bottom, 16)
        }
        .frame(width: 400, height: 420)
        .background(GlassEffectView().ignoresSafeArea())
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private func linkRow(_ label: String, _ urlString: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .trailing)
            Link(urlString, destination: URL(string: urlString)!)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.accentColor)
        }
    }
}

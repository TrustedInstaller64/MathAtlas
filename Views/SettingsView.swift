import SwiftUI

struct SettingsView: View {
    @Environment(LocaleManager.self) private var locale
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var storagePath: String = ""
    @State private var answerLinesValue: Int = 15
    @State private var answerLinesText: String = "15"
    @State private var answerLinesOutOfRange: Bool = false
    @State private var dataDirs: [(id: String, hasProblems: Bool, hasImages: Bool, health: AppSettings.DataHealth)] = []
    @State private var deleteConfirmID: String?
    @State private var showPandocFail = false
    @State private var showPandocOK = false
    @State private var showXeLaTeXFail = false
    @AppStorage("clearQueueOnLaunch") private var clearQueueOnLaunch = true
    @AppStorage("autoIncludeSolution") private var autoIncludeSolution = false
    @State private var showXeLaTeXOK = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16)).foregroundColor(.white)
                    .frame(width: 34, height: 34).background(Accent.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(locale.settingsTitle).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(locale.localeStr("完成", "Done")) { dismiss() }
                    .buttonStyle(.borderedProminent).tint(Accent.red)
            }
            .padding(.horizontal, 20).padding(.vertical, 12).background(.bar)
            Divider()

            TabView {
                generalTab
                    .tabItem { Label(locale.localeStr("通用", "General"), systemImage: "gear") }
                dataTab
                    .tabItem { Label(locale.localeStr("数据管理", "Data"), systemImage: "externaldrive") }
            }

        }
        .frame(width: 540, height: 520)
        .background(GlassEffectView().ignoresSafeArea())
        .onAppear { storagePath = settings.storagePath; answerLinesValue = settings.answerLines; answerLinesText = "\(settings.answerLines)"; refreshData() }
        .sheet(isPresented: $showPandocOK) { DepResultSheet(title: "Pandoc 已安装", msg: "Pandoc 已就绪，可用于导出 PDF。", ok: true) }
        .sheet(isPresented: $showPandocFail) { DepResultSheet(title: "Pandoc 未安装", msg: "未检测到 Pandoc。", ok: false, cmd: "brew install pandoc") }
        .sheet(isPresented: $showXeLaTeXOK) { DepResultSheet(title: "XeLaTeX 已安装", msg: "XeLaTeX 已就绪，可用于导出 PDF。", ok: true) }
        .sheet(isPresented: $showXeLaTeXFail) { DepResultSheet(title: "XeLaTeX 未安装", msg: "未检测到 XeLaTeX。", ok: false, cmd: "brew install basictex") }
    }

    // MARK: - 通用

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Language
                VStack(alignment: .leading, spacing: 8) {
                    Text(locale.languageSetting).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                    HStack(spacing: 16) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Button { locale.language = lang } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: locale.language == lang ? "circle.fill" : "circle")
                                        .font(.system(size: 12)).foregroundColor(locale.language == lang ? Accent.red : .secondary)
                                    Text(lang.displayName).font(.system(size: 13)).foregroundColor(.primary)
                                }.padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(locale.language == lang ? Accent.red.opacity(0.08) : Color.primary.opacity(0.03)))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(locale.language == lang ? Accent.red.opacity(0.3) : Color.clear, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Divider()

                // Animation
                VStack(alignment: .leading, spacing: 8) {
                    Text(locale.localeStr("详情页动画", "Detail Animation")).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                    HStack(spacing: 16) {
                        ForEach(AnimationStyle.allCases, id: \.self) { style in
                            Button { settings.animationStyle = style } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: settings.animationStyle == style ? "circle.fill" : "circle")
                                        .font(.system(size: 12)).foregroundColor(settings.animationStyle == style ? Accent.red : .secondary)
                                    Text(style.displayName).font(.system(size: 13)).foregroundColor(.primary)
                                }.padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(settings.animationStyle == style ? Accent.red.opacity(0.08) : Color.primary.opacity(0.03)))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(settings.animationStyle == style ? Accent.red.opacity(0.3) : Color.clear, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Divider()

                // Answer lines
                VStack(alignment: .leading, spacing: 8) {
                    Text(locale.localeStr("解答题默认空行数", "Default Answer Blank Lines")).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                    HStack(spacing: 8) {
                        Button { adjustAnswerLines(-1) } label: {
                            Image(systemName: "minus").frame(width: 24, height: 24)
                        }.buttonStyle(.bordered)
                        TextField("", text: $answerLinesText)
                            .frame(width: 50).textFieldStyle(.roundedBorder).font(.system(size: 13))
                            .multilineTextAlignment(.center)
                            .onSubmit { commitAnswerLines() }
                        Button { adjustAnswerLines(+1) } label: {
                            Image(systemName: "plus").frame(width: 24, height: 24)
                        }.buttonStyle(.bordered)
                        Text("行").font(.system(size: 13)).foregroundColor(.secondary)
                        if answerLinesOutOfRange {
                            Text("1-40").font(.system(size: 11)).foregroundColor(.red)
                        }
                    }
                }
                Divider()

                // Print queue settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("待打印").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                    Toggle("启动时清空待打印列表", isOn: $clearQueueOnLaunch).font(.system(size: 12))
                    Toggle("自动包含解析", isOn: $autoIncludeSolution).font(.system(size: 12))
                }
                Divider()

                // Splash animation speed
                VStack(alignment: .leading, spacing: 4) {
                    Text("启动动画速度").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                    Picker("", selection: Binding(
                        get: { UserDefaults.standard.string(forKey: "splashSpeed") ?? "fast" },
                        set: { UserDefaults.standard.set($0, forKey: "splashSpeed") }
                    )) {
                        Text("快").tag("fast")
                        Text("中").tag("medium")
                        Text("慢").tag("slow")
                    }.pickerStyle(.segmented).frame(width: 200)
                }
                Divider()

                // Storage
                VStack(alignment: .leading, spacing: 8) {
                    Text(locale.storageSetting).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                    Text(storagePath).font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 6))
                    HStack(spacing: 8) {
                        Button(locale.chooseFolder) {
                            AppSettings.pickStorageFolder(current: storagePath) { newPath in
                                storagePath = newPath; settings.storagePath = newPath; settings.ensureDirectories()
                            }
                        }.buttonStyle(.bordered)
                        Button(locale.localeStr("恢复默认", "Reset to Default")) {
                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
                            let def = docs.appendingPathComponent("MathAtlasLib").path
                            storagePath = def; settings.storagePath = def; settings.ensureDirectories()
                        }.buttonStyle(.bordered).font(.system(size: 11))
                    }
                }
                Text(locale.defaultStorageNote).font(.system(size: 11)).foregroundColor(.secondary)

                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(locale.localeStr("依赖检测", "Dependencies")).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                    HStack(spacing: 8) {
                        Button("检测 Pandoc") {
                            let s = DependencyChecker.check()
                            if s.pandocInstalled { showPandocOK = true }
                            else { showPandocFail = true }
                        }.buttonStyle(.bordered)
                        Button("检测 XeLaTeX") {
                            let s = DependencyChecker.check()
                            if s.xelatexInstalled { showXeLaTeXOK = true }
                            else { showXeLaTeXFail = true }
                        }.buttonStyle(.bordered)
                    }
                }
            }.padding(20)
        }
    }

    // MARK: - 数据管理

    private var dataTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("以下列出了存储目录中所有题库数据文件夹。被隐藏或删除的题库数据仍保留在磁盘中，您可以在此永久删除。")
                .font(.system(size: 11)).foregroundColor(.secondary).padding(16)

            // 恢复内置题库
            HStack {
                Text("内置题库").font(.system(size: 12, weight: .medium))
                Text("恢复为出厂预置题目（不会覆盖已有题目）")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                Button(locale.localeStr("恢复高中题库", "Restore High School")) {
                    restoreBuiltin(levelID: "high")
                }.buttonStyle(.bordered).font(.system(size: 11))
                Button(locale.localeStr("恢复初中题库", "Restore Middle School")) {
                    restoreBuiltin(levelID: "middle")
                }.buttonStyle(.bordered).font(.system(size: 11))
            }.padding(.horizontal, 16).padding(.bottom, 8)

            if dataDirs.isEmpty {
                Spacer()
                Text("未发现任何数据文件夹").foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(dataDirs, id: \.id) { dir in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    healthBadge(dir.health)
                                    Text(friendlyName(dir.id)).font(.system(size: 12, weight: .medium))
                                }
                                Text(dir.id).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                deleteConfirmID = dir.id
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red).font(.system(size: 12))
                            }.buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .alert("确认删除", isPresented: Binding(get: { deleteConfirmID != nil },
                                                set: { if !$0 { deleteConfirmID = nil } })) {
            Button("取消", role: .cancel) { deleteConfirmID = nil }
            Button("永久删除", role: .destructive) {
                if let id = deleteConfirmID {
                    settings.deleteData(for: id)
                    deleteConfirmID = nil
                    refreshData()
                }
            }
        } message: {
            Text("将永久删除「\(deleteConfirmID ?? "")」的所有题目和图片数据，不可恢复。")
        }
    }

    private func adjustAnswerLines(_ delta: Int) {
        let newVal = answerLinesValue + delta
        commitValue(max(1, min(40, newVal)))
    }

    private func commitAnswerLines() {
        guard let val = Int(answerLinesText.trimmingCharacters(in: .whitespaces)) else {
            answerLinesText = "\(answerLinesValue)"; return
        }
        commitValue(val)
    }

    private func commitValue(_ val: Int) {
        let clamped = max(1, min(40, val))
        answerLinesOutOfRange = val != clamped
        answerLinesValue = clamped
        answerLinesText = "\(clamped)"
        settings.answerLines = clamped
    }

    private func restoreBuiltin(levelID: String) {
        let level = levelID == "high" ? AppLevel.high : AppLevel.middle
        let store = ProblemStore(level: level)
        store.configure(settings: settings)
        let seeds = Problem.seedProblems(for: level)
        for seed in seeds.reversed() {
            store.create(contentType: seed.contentType, latex: seed.latex, tags: seed.tags,
                         category: seed.category, source: seed.source, note: seed.note,
                         solution: seed.solution, solutionContentType: seed.solutionContentType,
                         solutionImageNames: seed.solutionImageNames, imageNames: seed.imageNames)
        }
    }

    private func refreshData() {
        dataDirs = settings.allDataDirectories()
    }

    @ViewBuilder
    private func healthBadge(_ health: AppSettings.DataHealth) -> some View {
        switch health {
        case .ok:        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 10))
        case .missing:   Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.system(size: 10))
        case .corrupted: Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange).font(.system(size: 10))
        }
    }

    private func friendlyName(_ id: String) -> String {
        // Map internal IDs to display names
        let builtinMap = ["high": "高中题库", "middle": "初中题库"]
        if let name = builtinMap[id] { return name }
        // Custom level: look up from settings
        if let custom = settings.customLevels.first(where: { $0.id == id }) {
            return custom.name
        }
        return id
    }
}

struct DepResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String; let msg: String; var ok: Bool; var cmd: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 36)).foregroundColor(ok ? .green : .red)
            Text(title).font(.title3.weight(.semibold))
            Text(msg).font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
            if let c = cmd {
                HStack {
                    Text(c).font(.system(size: 12, design: .monospaced)).padding(8)
                        .background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 6))
                    Button("复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(c, forType: .string)
                    }.buttonStyle(.bordered).font(.system(size: 12))
                }
            }
            Button("关闭") { dismiss() }.buttonStyle(.borderedProminent).tint(Accent.red)
        }
        .padding(30).frame(width: 380, height: ok ? 220 : 280)
        .background(GlassEffectView().ignoresSafeArea())
    }
}

extension LocaleManager {
    func localeStr(_ zh: String, _ en: String) -> String {
        language == .zhHans ? zh : en
    }
}

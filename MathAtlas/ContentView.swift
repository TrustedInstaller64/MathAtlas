import SwiftUI
import UniformTypeIdentifiers
import AppKit
import WebKit
import PDFKit

enum SolutionFilter: String, CaseIterable {
    case all = "all", has = "has", none = "none"
    func label(_ locale: LocaleManager) -> String {
        switch self {
        case .all:  return locale.categoryAll
        case .has:  return locale.localeStr("有解析", "With Solution")
        case .none: return locale.localeStr("无解析", "No Solution")
        }
    }
}

struct ContentView: View {
    @Environment(LocaleManager.self) private var locale
    @Environment(AppSettings.self) private var settings

    @State private var stores: [String: ProblemStore] = [:]
    @State private var printQueue = PrintQueueManager()
    @AppStorage("lastActiveLevelID") private var lastLevelID: String = AppLevel.high.id
    @State private var activeLevel: AppLevel = AppLevel.high

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var activeCategory = "全部"
    @State private var activeTags: Set<String> = []
    @State private var activeSource: String? = nil
    @State private var solutionFilter: SolutionFilter = .all
    @State private var editorOpen = false
    @State private var editingProblem: Problem? = nil
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showingPrintQueue = false
    @State private var showDepWarning = false
    @State private var showNewBankAlert = false
    @State private var showDeleteBankAlert = false
    @State private var newBankName = ""

    // Bulk selection
    @State private var selecting = false
    @State private var selectedIDs: Set<String> = []

    // Detail
    @State private var detailProblem: Problem? = nil
    @State private var savedDetailProblem: Problem? = nil

    private var allLevels: [AppLevel] { settings.allLevels }
    private var store: ProblemStore { storeFor(activeLevel) }
    private var isExpand: Bool { settings.animationStyle == .expand }

    // Custom categories
    @AppStorage("customCategories") private var customCategoryData: String = ""
    @AppStorage("customCategoryIcons") private var customCategoryIcons: String = ""
    @AppStorage("customCategoryColors") private var customCategoryColors: String = ""
    private var customCategories: [String] {
        get { customCategoryData.isEmpty ? [] : customCategoryData.components(separatedBy: ",") }
        nonmutating set { customCategoryData = newValue.joined(separator: ",") }
    }
    private func customCatIcon(_ cat: String) -> String {
        guard let idx = customCategories.firstIndex(of: cat) else { return "tag.fill" }
        let icons = customCategoryIcons.components(separatedBy: ",")
        return idx < icons.count ? icons[idx] : "tag.fill"
    }
    private func customCatColor(_ cat: String) -> Color {
        guard let idx = customCategories.firstIndex(of: cat) else { return .accentColor }
        let colors = customCategoryColors.components(separatedBy: ",")
        guard idx < colors.count else { return .accentColor }
        let hex = colors[idx].trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let num = Int(hex, radix: 16) else { return .accentColor }
        return Color(red: Double((num >> 16) & 0xFF) / 255,
                     green: Double((num >> 8) & 0xFF) / 255,
                     blue: Double(num & 0xFF) / 255)
    }

    // AI
    @AppStorage("aiEnabled") private var aiEnabled: Bool = true
    @AppStorage("aiLight") private var aiLight: String = "green"
    @AppStorage("aiLatency") private var aiLatency: String = ""
    @AppStorage("aiModel") private var aiModel: String = ""
    @AppStorage("aiCheckTime") private var aiCheckTime: String = ""
    @AppStorage("cloudModel") private var cloudModelSetting: String = "deepseek-v4-flash"
    @AppStorage("thinkingEnabled") private var thinkingEnabledSetting: Bool = false
    @AppStorage("thinkingDepth") private var thinkingDepthSetting: String = "medium"

    private func startAIHealthCheck() {
        Task {
            await runAIHealthCheck()
            while true {
                try? await Task.sleep(for: .seconds(3600))
                await runAIHealthCheck()
            }
        }
    }

    private func runAIHealthCheck() async {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "aiBusy") else { return }
        let config = AIConfig(
            provider: .cloud,
            cloudModel: d.string(forKey: "cloudModel") ?? "deepseek-v4-flash",
            cloudEndpoint: d.string(forKey: "cloudEndpoint") ?? "https://api.deepseek.com",
            thinkingEnabled: d.bool(forKey: "thinkingEnabled"),
            thinkingDepth: d.string(forKey: "thinkingDepth") ?? "medium"
        )
        let client = DeepSeekClient(config: config)
        do {
            let (_, latency, m) = try await client.verify()
            let ms = latency
            if ms < 1500 { d.set("green", forKey: "aiLight") }
            else if ms < 3000 { d.set("yellow", forKey: "aiLight") }
            else { d.set("red", forKey: "aiLight") }
            d.set(String(format: "%.0f", latency), forKey: "aiLatency")
            d.set(m, forKey: "aiModel")
        } catch { d.set("red", forKey: "aiLight") }
        d.set(Date().formatted(.dateTime.hour().minute()), forKey: "aiCheckTime")
    }

    private var aiStatusBar: some View {
        let lightColor: Color = aiLight == "yellow" ? .yellow : aiLight == "red" ? .red : .green
        let displayModel = aiModel == "deepseek-v4-pro" ? "DeepSeek V4 Pro"
            : aiModel == "deepseek-v4-flash" ? "DeepSeek V4 Flash" : aiModel
        return VStack(spacing: 0) {
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
            HStack(spacing: 10) {
                Circle().fill(lightColor).frame(width: 7, height: 7)
                if !displayModel.isEmpty { Text(displayModel).font(.system(size: 11, weight: .medium)) }
                if !aiLatency.isEmpty { Text("API \(aiLatency)ms").font(.system(size: 11)).foregroundColor(lightColor) }
                Spacer()
                if !aiCheckTime.isEmpty { Text("于 \(aiCheckTime) 检测").font(.system(size: 9)).foregroundColor(.secondary) }
            }.padding(.horizontal, 16).padding(.vertical, 5)
        }
    }

    private func storeFor(_ level: AppLevel) -> ProblemStore {
        if let s = stores[level.id] { return s }
        let s = ProblemStore(level: level)
        s.configure(settings: settings)
        stores[level.id] = s
        return s
    }

    private func switchTo(_ level: AppLevel) {
        guard level.id != activeLevel.id else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            activeLevel = level; query = ""; activeCategory = "全部"
            activeTags = []; detailProblem = nil; selecting = false; selectedIDs = []
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(240)
        } detail: {
            VStack(spacing: 0) {
                if selecting && !selectedIDs.isEmpty { batchBar }
                mainContentArea
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Sigma — black circle, white Σ, 1.35x horizontal scale
                ZStack {
                    Circle().fill(Color.black).frame(width: 26, height: 26)
                    Text("\u{2211}")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(x: 1.35, y: 1.0)
                }.frame(minWidth: 35)
                if detailProblem != nil {
                    Button { dismissDetail() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                            Text("返回").font(.system(size: 12))
                        }
                    }
                }
                Picker("", selection: Binding(get: { activeLevel }, set: { switchTo($0) })) {
                    ForEach(allLevels, id: \.id) { l in Text(l.displayName).tag(l) }
                }.pickerStyle(.menu).fixedSize()
                // Circle buttons — matching 新增 style
                Button { showNewBankAlert = true } label: {
                    ZStack {
                        Circle().fill(Color.primary.opacity(0.08)).frame(width: 26, height: 26)
                        Image(systemName: "plus").font(.system(size: 11))
                    }.frame(minWidth: 35)
                }.buttonStyle(.plain).help("新建题库")
                Button { showDeleteBankAlert = true } label: {
                    ZStack {
                        Circle().fill(Color.primary.opacity(0.08)).frame(width: 26, height: 26)
                        Image(systemName: "trash").font(.system(size: 10))
                    }
                }.buttonStyle(.plain).help("删除题库")
                ZStack {
                    Circle().fill(Color.primary.opacity(0.08)).frame(width: 26, height: 26)
                    Text("\(store.problems.count)")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
                }.frame(minWidth: 35)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { selecting.toggle(); selectedIDs = [] } label: {
                    Label("选择", systemImage: selecting ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 12))
                }
                Button(action: exportProblems) {
                    Label("导出", systemImage: "square.and.arrow.down").font(.system(size: 12))
                }
                Button(action: { editingProblem = nil; editorOpen = true }) {
                    Label("新增", systemImage: "plus").font(.system(size: 12))
                }.buttonStyle(.borderedProminent).tint(Accent.red)
            }
            if aiEnabled {
                ToolbarItem(placement: .status) {
                    let c: Color = aiLight == "yellow" ? .yellow : aiLight == "red" ? .red : .green
                    let displayModel = aiModel == "deepseek-v4-pro" ? "DeepSeek V4 Pro"
                        : aiModel == "deepseek-v4-flash" ? "DeepSeek V4 Flash" : aiModel
                    let thinkEnabled = thinkingEnabledSetting
                    let thinkDepth = thinkingDepthSetting
                    let depthLabel = thinkDepth == "low" ? "低" : thinkDepth == "medium" ? "中" : "高"
                    HStack(spacing: 6) {
                        Circle().fill(c).frame(width: 6, height: 6)
                        if !displayModel.isEmpty { Text(displayModel).font(.system(size: 10)) }
                        Text(thinkEnabled ? "思考模式：启用  深度：\(depthLabel)" : "思考模式：未启用")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                        if !aiLatency.isEmpty { Text("API \(aiLatency)ms").font(.system(size: 10)).foregroundColor(c) }
                    }
                    .frame(minWidth: 300)
                }
            }
        }
        .environment(store).environment(printQueue)
        .onAppear {
            for level in allLevels { _ = storeFor(level) }
            // Restore last active level
            if let saved = allLevels.first(where: { $0.id == lastLevelID }) {
                activeLevel = saved
            }
            // Esc key: step back one level at a time
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // 53 = Escape
                    if showingPrintQueue {
                        showingPrintQueue = false
                        if let saved = savedDetailProblem { detailProblem = saved; savedDetailProblem = nil }
                        return nil
                    }
                    if detailProblem != nil {
                        detailProblem = nil; savedDetailProblem = nil; return nil
                    }
                }
                return event
            }
            // First-launch dependency check
            if !settings.didCheckDeps {
                settings.didCheckDeps = true
                let status = DependencyChecker.check()
                if !status.allInstalled {
                    showDepWarning = true
                }
            }
            // Sync on first load
            debouncedQuery = query
            if UserDefaults.standard.bool(forKey: "clearQueueOnLaunch") { printQueue.clearAll() }
            if aiEnabled { startAIHealthCheck() }
        }
        .onChange(of: query) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await MainActor.run { debouncedQuery = newValue }
            }
        }
        .onChange(of: activeLevel.id) { _, newID in
            lastLevelID = newID
        }
        .onChange(of: cloudModelSetting) { _, _ in Task { await runAIHealthCheck() } }
        .onChange(of: thinkingEnabledSetting) { _, _ in Task { await runAIHealthCheck() } }
        .onChange(of: thinkingDepthSetting) { _, _ in Task { await runAIHealthCheck() } }
        .sheet(isPresented: $showDepWarning) {
            DepWarningView()
        }
        .sheet(isPresented: $editorOpen) { editingProblem = nil } content: {
            ProblemEditorView(problem: editingProblem, isPresented: $editorOpen)
                .environment(store).environment(locale)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environment(locale).environment(settings)
        }
        .sheet(isPresented: $showAbout) {
            AboutView().environment(locale)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in showSettings = true }
        .onReceive(NotificationCenter.default.publisher(for: .openAbout)) { _ in showAbout = true }
        .alert("新建题库", isPresented: $showNewBankAlert) {
            TextField("题库名称", text: $newBankName)
            Button("创建") {
                let name = newBankName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let newLevel = settings.addCustomLevel(name: name)
                _ = storeFor(newLevel)
                activeLevel = newLevel
                newBankName = ""
            }
            Button("取消", role: .cancel) { newBankName = "" }
        }
        .alert("删除题库", isPresented: $showDeleteBankAlert) {
            Button("删除", role: .destructive) {
                let deletedID = activeLevel.id
                settings.removeCustomLevel(activeLevel)
                stores.removeValue(forKey: deletedID)
                // Switch to first available bank, or create a default
                if let first = allLevels.first(where: { $0.id != deletedID }) {
                    activeLevel = first
                } else {
                    let newLevel = settings.addCustomLevel(name: "默认题库")
                    activeLevel = newLevel
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除「\(activeLevel.displayName)」吗？题目数据将保留在磁盘中。")
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 12) {
            Text("\u{2211}").font(.system(size: 19, weight: .medium)).foregroundColor(.white)
                .scaleEffect(x: 1.35, y: 1.0)
                .frame(width: 34, height: 34).background(Accent.red).clipShape(RoundedRectangle(cornerRadius: 10))
            if detailProblem != nil {
                Button { dismissDetail() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                        Text(locale.localeStr("返回", "Back")).font(.system(size: 13))
                    }.padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).contentShape(Rectangle())
            }
            Picker("", selection: Binding(get: { activeLevel }, set: { switchTo($0) })) {
                ForEach(allLevels, id: \.id) { l in Text(l.displayName).tag(l) }
            }.pickerStyle(.menu).frame(width: 140)

            Button { showNewBankAlert = true } label: {
                Image(systemName: "plus").font(.system(size: 12))
            }.buttonStyle(.plain).help("新建题库")

            Button { showDeleteBankAlert = true } label: {
                Image(systemName: "trash").font(.system(size: 11))
            }.buttonStyle(.plain).foregroundColor(.red).help("删除题库")
            Text(locale.problemsCount(store.problems.count)).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()

            // Bulk select toggle — clear button
            Button {
                selecting.toggle(); selectedIDs = []
            } label: {
                Label(locale.localeStr("选择", "Select"), systemImage: selecting ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 13))
            }.buttonStyle(.bordered).tint(selecting ? Accent.red : nil)

            Button(action: exportProblems) {
                Label(locale.export, systemImage: "square.and.arrow.down").font(.system(size: 13))
            }.buttonStyle(.bordered)
            Button(action: { editingProblem = nil; editorOpen = true }) {
                Label(locale.newProblem, systemImage: "plus").font(.system(size: 13))
            }.buttonStyle(.borderedProminent).tint(Accent.red)
        }.padding(.horizontal, 16).padding(.vertical, 4).background(.bar)
    }

    // MARK: - Batch Bar

    private var batchBar: some View {
        HStack(spacing: 8) {
            Text("已选 \(selectedIDs.count) 道").font(.system(size: 12, weight: .medium))
            Spacer()
            Button(locale.localeStr("添加标签...", "Tag...")) { batchTag() }.buttonStyle(.bordered).font(.system(size: 11))
            if allLevels.count > 1 {
                Menu {
                    ForEach(allLevels.filter { $0.id != activeLevel.id }, id: \.id) { target in
                        if let tgt = stores[target.id] {
                            Button(target.displayName) {
                                moveSelected(to: tgt)
                            }
                        }
                    }
                } label: {
                    Text(locale.localeStr("移动到…", "Move to…")).font(.system(size: 11))
                }
                .disabled(selectedIDs.isEmpty)
            }
            Button(locale.localeStr("加入待打印", "Add to Print")) {
                for id in selectedIDs { printQueue.add(problemID: id, level: activeLevel) }; selectedIDs = []
            }.buttonStyle(.bordered).font(.system(size: 11))
            Button(locale.deleteConfirm) { batchDelete() }.buttonStyle(.bordered).font(.system(size: 11))
                .foregroundColor(Accent.red)
        }
        .padding(.horizontal, 16).padding(.vertical, 8).background(Color.accentColor.opacity(0.08))
    }

    private func batchTag() {
        let alert = NSAlert()
        alert.messageText = "添加标签"
        alert.informativeText = "为选中的 \(selectedIDs.count) 道题目添加标签："
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = input
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            let tag = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !tag.isEmpty else { return }
            for id in selectedIDs {
                if var p = store.problems.first(where: { $0.id == id }), !p.tags.contains(tag) {
                    p.tags.append(tag); store.update(p)
                }
            }
        }
    }

    private func moveSelected(to target: ProblemStore) {
        for id in selectedIDs {
            if let p = store.problems.first(where: { $0.id == id }) {
                var copy = p; copy.id = UUID().uuidString
                target.create(contentType: copy.contentType, latex: copy.latex, tags: copy.tags,
                              category: copy.category, source: copy.source, note: copy.note,
                              solution: copy.solution, solutionContentType: copy.solutionContentType,
                              solutionImageNames: copy.solutionImageNames, imageNames: copy.imageNames)
                // Copy images
                for name in copy.imageNames + copy.solutionImageNames {
                    if let data = store.loadImage(named: name) {
                        _ = target.saveImage(data: data, filename: name)
                    }
                }
            }
        }
        selectedIDs = []; selecting = false
    }

    private func batchDelete() {
        for id in selectedIDs { store.delete(Problem.emptyCopy(id: id)) }
        selectedIDs = []; selecting = false
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Categories — Finder style with icons
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locale.categoryLabel.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8).padding(.bottom, 4)
                        ForEach([locale.categoryAll] + locale.categories + customCategories, id: \.self) { cat in
                            let isCustom = customCategories.contains(cat)
                            let bgColor: Color = isCustom ? customCatColor(cat) : Accent.red
                            HStack(spacing: 6) {
                                Image(systemName: isCustom ? customCatIcon(cat) : iconForCategory(cat))
                                    .font(.system(size: 12)).frame(width: 18)
                                    .foregroundColor(activeCategory == cat ? .white : (isCustom ? bgColor : .secondary))
                                Text(cat).font(.system(size: 12))
                                    .foregroundColor(activeCategory == cat ? .white : .primary)
                                Spacer()
                                Text("\(countForCategory(cat))").font(.system(size: 11, weight: .medium))
                                    .foregroundColor(activeCategory == cat ? .white.opacity(0.8) : .secondary)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(activeCategory == cat ? bgColor : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                            .onTapGesture { activeCategory = cat; detailProblem = nil; showingPrintQueue = false; savedDetailProblem = nil }
                        }                    }
                    // Tags — Finder style
                    if !store.allTags.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(locale.tagLabel.uppercased())
                                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                                Spacer()
                                if !activeTags.isEmpty {
                                    Text(locale.clear).font(.system(size: 10)).foregroundColor(.secondary)
                                        .onTapGesture { activeTags.removeAll(); detailProblem = nil; showingPrintQueue = false; savedDetailProblem = nil }
                                }
                            }.padding(.horizontal, 8)
                            ForEach(store.allTags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Image(systemName: activeTags.contains(tag) ? "tag.fill" : "tag")
                                        .font(.system(size: 11)).frame(width: 18)
                                        .foregroundColor(activeTags.contains(tag) ? .white : .secondary)
                                    Text(tag).font(.system(size: 12))
                                        .foregroundColor(activeTags.contains(tag) ? .white : .primary)
                                    Spacer()
                                    Text("\(countForTag(tag))").font(.system(size: 11, weight: .medium))
                                        .foregroundColor(activeTags.contains(tag) ? .white.opacity(0.8) : .secondary)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(activeTags.contains(tag) ? Accent.red : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if activeTags.contains(tag) { activeTags.remove(tag) } else { activeTags.insert(tag) }
                                    detailProblem = nil; showingPrintQueue = false; savedDetailProblem = nil
                                }
                                .contextMenu {
                                    Button("重命名") { renameTag(tag) }
                                    Button("删除标签") { deleteTag(tag) }
                                }
                            }
                        }
                    }
                    // Sources — Finder style
                    if !store.allSources.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(locale.localeStr("试卷出处", "Source").uppercased())
                                    .font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                                Spacer()
                                if activeSource != nil {
                                    Text(locale.clear).font(.system(size: 10)).foregroundColor(.secondary)
                                        .onTapGesture { activeSource = nil; detailProblem = nil; showingPrintQueue = false; savedDetailProblem = nil }
                                }
                            }.padding(.horizontal, 8)
                            ForEach(store.allSources, id: \.self) { src in
                                HStack(spacing: 6) {
                                    Image(systemName: activeSource == src ? "doc.text.fill" : "doc.text")
                                        .font(.system(size: 11)).frame(width: 18)
                                        .foregroundColor(activeSource == src ? .white : .secondary)
                                    Text(src).font(.system(size: 12))
                                        .foregroundColor(activeSource == src ? .white : .primary)
                                    Spacer()
                                    Text("\(countForSource(src))").font(.system(size: 11, weight: .medium))
                                        .foregroundColor(activeSource == src ? .white.opacity(0.8) : .secondary)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(activeSource == src ? Accent.red : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    activeSource = activeSource == src ? nil : src
                                    detailProblem = nil; showingPrintQueue = false; savedDetailProblem = nil
                                }
                                .contextMenu {
                                    Button("重命名") { renameSource(src) }
                                    Button("删除来源") { deleteSource(src) }
                                }
                            }
                        }
                    }
                }.padding(.vertical, 8).padding(.horizontal, 8)
            }
            Divider()
            // Print queue — pinned at bottom, Finder style
            HStack(spacing: 6) {
                Image(systemName: "printer.fill").font(.system(size: 12)).foregroundColor(.secondary).frame(width: 18)
                Text(locale.localeStr("待打印", "Print Queue")).font(.system(size: 12)).foregroundColor(.primary)
                Spacer()
                if printQueue.count > 0 {
                    Text("\(printQueue.count)").font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Accent.red).clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if showingPrintQueue {
                    showingPrintQueue = false
                    if let saved = savedDetailProblem { detailProblem = saved; savedDetailProblem = nil }
                } else {
                    savedDetailProblem = detailProblem
                    showingPrintQueue = true
                    detailProblem = nil
                }
            }
        }
        
    }

    private func iconForCategory(_ cat: String) -> String {
        if cat == locale.categoryAll || cat == "全部" || cat == "All" { return "list.bullet" }
        if cat == locale.catFill   || cat == "填空题" || cat == "Fill-in-blank" { return "square.dashed" }
        if cat == locale.catChoice || cat == "选择题" || cat == "Multiple choice" { return "checklist" }
        if cat == locale.catAnswer || cat == "解答题" || cat == "Free response" { return "text.append" }
        return "questionmark"
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContentArea: some View {
        ZStack {
            problemListOrDetail
                .opacity(showingPrintQueue ? 0 : 1)
                .allowsHitTesting(!showingPrintQueue)

            if showingPrintQueue {
                InlinePrintQueue(allStores: stores, onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showingPrintQueue = false
                    }
                })
                .transition(isExpand
                    ? .scale(scale: 0.8).combined(with: .opacity)
                    : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                  removal: .move(edge: .trailing).combined(with: .opacity)))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showingPrintQueue)
    }

    @ViewBuilder
    private var problemListOrDetail: some View {
        ZStack {
            ProblemListView(query: $debouncedQuery, activeCategory: activeCategory, activeTags: activeTags,
                            activeSource: activeSource,
                            solutionFilter: $solutionFilter, selecting: $selecting, selectedIDs: $selectedIDs,
                            printQueue: printQueue,
                            onEdit: { p in editingProblem = p; editorOpen = true },
                            onOpen: { p in openDetail(p) })
                .opacity(detailProblem == nil ? 1 : 0)
                .allowsHitTesting(detailProblem == nil)

            if let problem = detailProblem {
                let idx = store.problems.firstIndex(where: { $0.id == problem.id }).map { $0 + 1 } ?? 0
                ProblemDetailView(problem: problem, index: idx, onDismiss: { dismissDetail() })
                    .transition(isExpand
                        ? .scale(scale: 0.8).combined(with: .opacity)
                        : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                      removal: .move(edge: .trailing).combined(with: .opacity)))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: detailProblem != nil)
    }

    private func openDetail(_ p: Problem) {
        guard !selecting else {
            if selectedIDs.contains(p.id) { selectedIDs.remove(p.id) } else { selectedIDs.insert(p.id) }
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { detailProblem = p }
    }

    private func dismissDetail() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { detailProblem = nil }
    }

    private func countForCategory(_ cat: String) -> Int {
        if cat == locale.categoryAll { return store.problems.count }
        for (idx, ik) in Problem.categories.enumerated() {
            if idx < locale.categories.count, locale.categories[idx] == cat { return store.problems.filter { $0.category == ik }.count }
        }
        return store.problems.filter { $0.category == cat }.count
    }

    private func countForTag(_ tag: String) -> Int {
        store.problems.filter { $0.tags.contains(tag) }.count
    }

    private func countForSource(_ src: String) -> Int {
        store.problems.filter { $0.source == src }.count
    }

    private func renameTag(_ oldTag: String) {
        let alert = NSAlert()
        alert.messageText = "重命名标签"; alert.informativeText = "将「\(oldTag)」重命名为："
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = oldTag; alert.accessoryView = input
        alert.addButton(withTitle: "确定"); alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            let newTag = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !newTag.isEmpty, newTag != oldTag else { return }
            for var p in store.problems where p.tags.contains(oldTag) {
                if let idx = p.tags.firstIndex(of: oldTag) { p.tags[idx] = newTag }
                store.update(p)
            }
            if activeTags.contains(oldTag) { activeTags.remove(oldTag); activeTags.insert(newTag) }
        }
    }

    private func deleteTag(_ tag: String) {
        for var p in store.problems where p.tags.contains(tag) { p.tags.removeAll { $0 == tag }; store.update(p) }
        activeTags.remove(tag)
    }

    private func renameSource(_ oldSrc: String) {
        let alert = NSAlert()
        alert.messageText = "重命名来源"; alert.informativeText = "将「\(oldSrc)」重命名为："
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = oldSrc; alert.accessoryView = input
        alert.addButton(withTitle: "确定"); alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            let newSrc = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !newSrc.isEmpty, newSrc != oldSrc else { return }
            for var p in store.problems where p.source == oldSrc { p.source = newSrc; store.update(p) }
            if activeSource == oldSrc { activeSource = newSrc }
        }
    }

    private func deleteSource(_ src: String) {
        for var p in store.problems where p.source == src { p.source = ""; store.update(p) }
        if activeSource == src { activeSource = nil }
    }

    private func exportProblems() {
        guard let url = store.exportJSON() else { return }
        let panel = NSSavePanel(); panel.title = locale.export; panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = [UTType.json]; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let dest = panel.url { try? FileManager.default.copyItem(at: url, to: dest) }
    }
}

// MARK: - Inline Print Queue

struct InlinePrintQueue: View {
    let allStores: [String: ProblemStore]
    let onDismiss: () -> Void
    @Environment(LocaleManager.self) private var locale
    @Environment(AppSettings.self) private var settings
    @Environment(PrintQueueManager.self) private var printQueue
    @AppStorage("clearQueueOnLaunch") private var clearQueueOnLaunch: Bool = true
    @AppStorage("autoIncludeSolution") private var autoIncludeSolution: Bool = false
    @State private var includeSolution = false
    @State private var isExporting = false
    @State private var depStatus = DependencyChecker.Status()
    @State private var showErrorLog = false
    @State private var errorLogText = ""
    @State private var pdfProgress: Double = 0
    @State private var pdfProgressLabel: String = ""
    @State private var showProgressBar = false
    @State private var printAnswerLines: Int = 15
    @State private var ppOnePage: [String: Bool] = [:]
    @State private var ppLines: [String: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { onDismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                        Text(locale.localeStr("返回", "Back")).font(.system(size: 13))
                    }.padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).contentShape(Rectangle())

                Image(systemName: "printer.fill").font(.system(size: 16)).foregroundColor(.white)
                    .frame(width: 34, height: 34).background(Accent.red).clipShape(RoundedRectangle(cornerRadius: 10))
                Text(locale.localeStr("待打印", "Print Queue")).font(.system(size: 15, weight: .semibold))
                Text("\(printQueue.count) 道").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Toggle(isOn: $includeSolution) {
                    Text(locale.localeStr("解析", "Sol.")).font(.system(size: 11))
                }.toggleStyle(.checkbox)
                Toggle(isOn: Binding(
                    get: { printQueue.entries.filter { !($0.level == "__blank__" || $0.problemID.hasPrefix("blank-")) }.allSatisfy { ppOnePage[$0.problemID] ?? false } },
                    set: { val in
                        var copy = ppOnePage
                        for e in printQueue.entries where !(e.level == "__blank__" || e.problemID.hasPrefix("blank-")) {
                            copy[e.problemID] = val
                            if val {
                                UserDefaults.standard.set(true, forKey: "ppOnePage_\(e.problemID)")
                            } else {
                                UserDefaults.standard.removeObject(forKey: "ppOnePage_\(e.problemID)")
                            }
                        }
                        ppOnePage = copy
                    }
                )) {
                    Text("一页一题").font(.system(size: 11))
                }.toggleStyle(.checkbox)
                Button(locale.localeStr("按题型排序", "Sort by Type")) {
                    let catOrder = ["填空题": 0, "选择题": 1, "解答题": 2]
                    let sorted = printQueue.entries.sorted {
                        let a = findProblem($0)?.category ?? ""
                        let b = findProblem($1)?.category ?? ""
                        return (catOrder[a] ?? 99) < (catOrder[b] ?? 99)
                    }
                    printQueue.replaceAll(sorted)
                }.buttonStyle(.bordered).font(.system(size: 12))
                Button("添加空白页") { addBlankPage() }.buttonStyle(.bordered).font(.system(size: 12))
                Button(locale.localeStr("清空", "Clear")) { printQueue.clearAll(); includeSolution = autoIncludeSolution; ppOnePage.removeAll(); ppLines.removeAll() }.buttonStyle(.bordered).font(.system(size: 12))
                Button(locale.localeStr("导出MD", "Export MD")) { exportDOCX() }.buttonStyle(.bordered).font(.system(size: 12))
                if depStatus.allInstalled {
                    Button(locale.localeStr("导出PDF", "Export PDF")) { exportPDFDirect() }.buttonStyle(.borderedProminent).tint(Accent.red).font(.system(size: 12))
                }
            }.padding(.horizontal, 20).padding(.vertical, 10).background(.bar)
                .onAppear {
                    depStatus = DependencyChecker.check()
                    DispatchQueue.main.async {
                        printAnswerLines = settings.answerLines
                        includeSolution = autoIncludeSolution
                        var op = [String: Bool]()
                        var lp = [String: Int]()
                        for e in printQueue.entries {
                            op[e.problemID] = UserDefaults.standard.bool(forKey: "ppOnePage_\(e.problemID)")
                            lp[e.problemID] = UserDefaults.standard.integer(forKey: "ppLines_\(e.problemID)")
                        }
                        ppOnePage = op
                        ppLines = lp
                    }
                }
            // PDF export progress
            if showProgressBar {
                VStack(spacing: 4) {
                    ProgressView(value: min(pdfProgress, 100), total: 100)
                        .progressViewStyle(.linear).tint(Accent.red)
                    Text(pdfProgressLabel).font(.system(size: 11)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Divider()
            .sheet(isPresented: $showErrorLog) {
                ErrorLogView(log: errorLogText)
            }

            if printQueue.entries.isEmpty {
                Spacer()
                Text(locale.localeStr("待打印队列为空", "Print queue is empty")).foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(printQueue.entries) { entry in
                        let isBlank = entry.level == "__blank__" || entry.problemID.hasPrefix("blank-")
                        HStack(spacing: 4) {
                            if isBlank {
                                Image(systemName: "doc.fill").font(.system(size: 11)).foregroundColor(.secondary)
                                Text("空白页").font(.system(size: 12)).foregroundColor(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                let problem = findProblem(entry)
                                Text(problem?.category ?? "?").font(.system(size: 11)).foregroundColor(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(plainPreview(problem)).font(.system(size: 12)).lineLimit(1)
                                Spacer()
                                // Per-problem controls
                                let pid = entry.problemID
                                Toggle(isOn: Binding(
                                    get: { ppOnePage[pid] ?? false },
                                    set: { var copy = ppOnePage; copy[pid] = $0; ppOnePage = copy
                                        if $0 { UserDefaults.standard.set(true, forKey: "ppOnePage_\(pid)") }
                                        else { UserDefaults.standard.removeObject(forKey: "ppOnePage_\(pid)") } }
                                )) {
                                    Text("一页一题").font(.system(size: 9))
                                }.toggleStyle(.checkbox)
                                if !(ppOnePage[pid] ?? false) {
                                    HStack(spacing: 2) {
                                        Text("空行").font(.system(size: 9)).foregroundColor(.secondary)
                                        TextField("", value: Binding(
                                            get: { ppLines[pid] ?? 0 },
                                            set: { var copy = ppLines; copy[pid] = $0; ppLines = copy; UserDefaults.standard.set($0, forKey: "ppLines_\(pid)") }
                                        ), format: .number)
                                            .frame(width: 30).textFieldStyle(.roundedBorder).font(.system(size: 10))
                                    }
                                }
                            }
                            Button { printQueue.remove(problemID: entry.problemID) } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.secondary)
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 4)
                    }
                    .onMove { printQueue.move(fromOffsets: $0, toOffset: $1) }
                }
            }
        }
    }

    private func addBlankPage() {
        let blankID = "blank-\(Int(Date().timeIntervalSince1970 * 1000))"
        printQueue.addBlank(problemID: blankID)
    }

    private func findProblem(_ entry: PrintQueueEntry) -> Problem? {
        allStores[entry.level]?.problems.first { $0.id == entry.problemID }
    }

    private func plainPreview(_ p: Problem?) -> String {
        guard let p else { return "" }
        return String(p.latex
            .replacingOccurrences(of: "\\\\begin\\{[^}]*\\}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\\\end\\{[^}]*\\}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\\\textbf\\{[^}]*\\}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\\\textit\\{[^}]*\\}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\\\underline\\{[^}]*\\}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\\\[a-zA-Z]+(\\{[^}]*\\})*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[\\\\{}]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces).prefix(80))
    }

    private func exportPDFDirect() {
        isExporting = true; pdfProgress = 0; pdfProgressLabel = "正在生成 Markdown..."
        withAnimation(.easeInOut(duration: 0.2)) { showProgressBar = true }

        Task {
            let tempDir = FileManager.default.temporaryDirectory
            let mdURL = tempDir.appendingPathComponent("math-export.md")
            let pdfURL = tempDir.appendingPathComponent("math-export.pdf")

            guard let md = generateMDContent() else { dismissProgress(); return }
            await progress(25, "Markdown 生成完成")

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = "math-problems.pdf"
            guard panel.runModal() == .OK, let url = panel.url else { dismissProgress(); return }

            try? md.write(to: mdURL, atomically: true, encoding: .utf8)
            await progress(50, "临时文件已写入")

            await progress(50, "正在用 Pandoc 渲染 PDF...")
            let (success, log) = await Task.detached {
                DependencyChecker.runPandoc(mdURL: mdURL, pdfURL: pdfURL)
            }.value
            await progress(90, "Pandoc 完成")

            if success {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.copyItem(at: pdfURL, to: url)
                await progress(100, "完成！")
            } else {
                errorLogText = log; showErrorLog = true
                try? log.write(to: tempDir.appendingPathComponent("math-export-error.log"), atomically: true, encoding: .utf8)
                await progress(100, "导出失败")
            }

            // Keep "完成！" visible for 1 second, then slide out
            try? await Task.sleep(for: .seconds(1))
            dismissProgress()
        }
    }

    @MainActor
    private func progress(_ pct: Double, _ label: String) async {
        pdfProgress = pct; pdfProgressLabel = label
    }

    @MainActor
    private func dismissProgress() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showProgressBar = false
        }
        isExporting = false
    }

    private func generateMDContent() -> String? {
        let entries = printQueue.entries
        guard !entries.isEmpty else { return nil }

        var md = """
        ---
        papersize: a4
        geometry: \"top=1.8cm, bottom=1.8cm, left=1.8cm, right=1.8cm\"
        mainfont: PingFang SC
        header-includes: |
          \\usepackage{enumitem}
          \\usepackage{amsmath}
          \\usepackage{array}
          \\usepackage{fancyhdr}
          \\pagestyle{fancy}
          \\fancyhf{}
          \\renewcommand{\\headrulewidth}{0pt}
          \\fancyfoot[R]{\\small\\textsf{$\\Sigma$ MathAtlas}\\\\ \\scriptsize\\texttt{@TrustedInstaller64}}
          \\fancyfoot[C]{\\thepage}
        ---

        """

        func pandocBlock(_ s: String) -> String {
            "\n```{=latex}\n\(s)\n```\n"
        }
        /// Add space after \quad when directly followed by Chinese characters (export only).
        func fixQuadSpacing(_ s: String) -> String {
            s.replacingOccurrences(of: "\\\\quad([\\u{4e00}-\\u{9fff}])", with: "\\\\quad $1", options: .regularExpression)
        }

        var problemNum = 0
        var hasContent = false
        for entry in entries {
            // Blank page
            if entry.level == "__blank__" || entry.problemID.hasPrefix("blank-") {
                if hasContent { md += "\n\\newpage\n" }
                md += "\\vspace*{\\fill}\n\n\\newpage\n"
                hasContent = true
                continue
            }
            let store = allStores[entry.level] ?? ProblemStore(level: AppLevel.high)
            guard let p = store.problems.first(where: { $0.id == entry.problemID }) else { continue }
            problemNum += 1

            let onePage = UserDefaults.standard.bool(forKey: "ppOnePage_\(entry.problemID)")
            let lines = UserDefaults.standard.integer(forKey: "ppLines_\(entry.problemID)")
            let useLines = lines > 0 ? lines : printAnswerLines

            if onePage, hasContent { md += "\n\\newpage\n" }
            hasContent = true

            md += "\\hrulefill\n\n"
            md += "**\(problemNum). [\(p.category)]** "
            if !p.source.isEmpty { md += "（\(p.source)）" }
            md += "\n\n\(pandocBlock(fixQuadSpacing(p.latex)))\n\n"

            if includeSolution, !p.solution.isEmpty {
                md += "**解析**\n\(pandocBlock(fixQuadSpacing(p.solution)))\n\n"
            }

            if !onePage, !["填空题", "选择题"].contains(p.category) {
                md += "\\vspace{\(useLines)\\baselineskip}\n\n"
            }
        }
        // Replace Chinese full-width colons with English half-width (only in export)
        return md.replacingOccurrences(of: "\u{FF1A}", with: ":")
    }

    private func exportDOCX() {
        isExporting = true; pdfProgress = 0; pdfProgressLabel = "正在生成 Markdown..."
        withAnimation(.easeInOut(duration: 0.2)) { showProgressBar = true }

        Task {
            guard let md = generateMDContent() else { dismissProgress(); return }
            await progress(25, "Markdown 生成完成")

            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
            panel.nameFieldStringValue = "math-problems.md"
            guard panel.runModal() == .OK, let url = panel.url else { dismissProgress(); return }

            try? md.write(to: url, atomically: true, encoding: .utf8)
            await progress(100, "完成！")

            try? await Task.sleep(for: .seconds(1))
            dismissProgress()
        }
    }
}


// MARK: - Dependency Warning View

struct DepWarningView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status = DependencyChecker.check()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 18)).foregroundColor(.orange)
                Text("缺少依赖").font(.title3.weight(.semibold))
                Spacer()
                Button("完成") { dismiss() }.buttonStyle(.borderedProminent).tint(Accent.red)
            }.padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        depRow("Pandoc", installed: status.pandocInstalled)
                        depRow("XeLaTeX (MacTeX/BasicTeX)", installed: status.xelatexInstalled)
                    }

                    Text("导出 PDF 需要 Pandoc 和 XeLaTeX。未安装的依赖请按以下步骤安装：")
                        .font(.system(size: 12)).foregroundColor(.secondary)

                    // Install Homebrew (if any dep missing)
                    if !status.allInstalled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. 安装 Homebrew（如已安装可跳过）")
                                .font(.system(size: 13, weight: .semibold))
                            Text("打开终端（Terminal），粘贴以下命令：")
                                .font(.system(size: 12)).foregroundColor(.secondary)
                            copyableCode("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                        }

                        // Pandoc
                        if !status.pandocInstalled {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("2. 安装 Pandoc").font(.system(size: 13, weight: .semibold))
                                Text("在终端中运行：").font(.system(size: 12)).foregroundColor(.secondary)
                                copyableCode("brew install pandoc")
                            }
                        }

                        // XeLaTeX
                        if !status.xelatexInstalled {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(status.pandocInstalled ? "2." : "3.") + Text(" 安装 XeLaTeX (BasicTeX)")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("BasicTeX 约 100MB，含 XeLaTeX。在终端中运行：")
                                    .font(.system(size: 12)).foregroundColor(.secondary)
                                copyableCode("brew install basictex")
                            }
                        }

                        Text("安装完成后，重启 MathAtlas 即可使用导出 PDF 功能。")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }.padding(20)
            }
        }
        .frame(width: 520, height: 440)
        .background(GlassEffectView().ignoresSafeArea())
    }

    private func depRow(_ name: String, installed: Bool) -> some View {
        HStack {
            Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(installed ? .green : .red)
            Text(name).font(.system(size: 13))
            Text(installed ? "已安装" : "未安装")
                .font(.system(size: 12)).foregroundColor(.secondary)
        }
    }

    private func copyableCode(_ code: String) -> some View {
        HStack {
            Text(code).font(.system(size: 11, design: .monospaced))
                .padding(8)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button("复制") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
            }.buttonStyle(.bordered).font(.system(size: 11))
        }
    }
}

// MARK: - Error Log View

struct ErrorLogView: View {
    let log: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pandoc 错误日志").font(.headline)
                Spacer()
                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log, forType: .string)
                }.buttonStyle(.bordered)
                Button("关闭") { dismiss() }.buttonStyle(.borderedProminent).tint(Accent.red)
            }.padding()
            Divider()
            ScrollView {
                Text(log).font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
            }
        }
        .frame(width: 600, height: 400)
        .background(GlassEffectView().ignoresSafeArea())
    }
}

extension Problem {
    static func emptyCopy(id: String) -> Problem {
        Problem(id: id, contentType: "latex", latex: "", tags: [], category: "填空题",
                source: "", note: "", solution: "", solutionContentType: "latex",
                solutionImageNames: [], imageNames: [], createdAt: 0, updatedAt: 0)
    }
}

// MARK: - Shared views & constants

struct GlassEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSVisualEffectView(); v.material = .underWindowBackground
        v.blendingMode = .behindWindow; v.state = .active; return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}



enum Accent {
    static let red = Color(white: 0.12) // dark enough for white text in both modes
    static let accentGray = Color.primary.opacity(0.85)
    static let bgPrimary = Color(nsColor: .textBackgroundColor)
    static let bgSecondary = Color.primary.opacity(0.06)
    static let textSecondary = Color.secondary
    static let border = Color.primary.opacity(0.1)
}

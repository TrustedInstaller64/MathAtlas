import SwiftUI
import AppKit

/// A question bank level — built-in or custom
struct AppLevel: Identifiable, Equatable, Hashable, Codable {
    let id: String
    var name: String
    var isBuiltin: Bool

    var displayName: String { name }

    static let high   = AppLevel(id: "high",   name: "高中题库", isBuiltin: true)
    static let middle = AppLevel(id: "middle", name: "初中题库", isBuiltin: true)

    static var builtins: [AppLevel] { [.high, .middle] }
}

/// Animation style for entering detail view
enum AnimationStyle: String, CaseIterable {
    case expand = "expand"
    case slide  = "slide"
    var displayName: String { self == .expand ? "扩散展开" : "侧边滑入" }
}

/// Global app settings — persisted via @AppStorage / UserDefaults
@Observable
final class AppSettings {
    /// Storage root directory
    var storagePath: String {
        didSet { UserDefaults.standard.set(storagePath, forKey: "storagePath") }
    }

    /// Animation preference
    var animationStyle: AnimationStyle {
        didSet { UserDefaults.standard.set(animationStyle.rawValue, forKey: "animationStyle") }
    }

    /// Answer space lines for free-response problems (default 15)
    var answerLines: Int {
        didSet { UserDefaults.standard.set(answerLines, forKey: "answerLines") }
    }

    /// Whether first-launch dependency check has been done
    var didCheckDeps: Bool {
        didSet { UserDefaults.standard.set(didCheckDeps, forKey: "didCheckDeps") }
    }

    /// Custom levels: id → display name
    var customLevels: [AppLevel] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(customLevels) {
                UserDefaults.standard.set(data, forKey: "customLevels")
            }
        }
    }

    /// IDs of built-in levels the user has removed
    var hiddenBuiltinIDs: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(hiddenBuiltinIDs), forKey: "hiddenBuiltinIDs")
        }
    }

    /// All available levels (visible builtins + custom)
    var allLevels: [AppLevel] {
        AppLevel.builtins.filter { !hiddenBuiltinIDs.contains($0.id) } + customLevels
    }

    /// Create a new custom level
    func addCustomLevel(name: String) -> AppLevel {
        let id = "custom-\(UUID().uuidString.prefix(8))"
        let level = AppLevel(id: id, name: name, isBuiltin: false)
        customLevels.append(level)
        ensureDirectories(for: level)
        return level
    }

    /// Delete a level (builtins are hidden, custom are removed)
    func removeCustomLevel(_ level: AppLevel) {
        if level.isBuiltin {
            hiddenBuiltinIDs.insert(level.id)
        } else {
            customLevels.removeAll { $0.id == level.id }
        }
    }

    /// Ensure storage directories exist for a specific level
    func ensureDirectories(for level: AppLevel) {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: storagePath).appendingPathComponent(level.id)
        try? fm.createDirectory(atPath: dir.path, withIntermediateDirectories: true)
        try? fm.createDirectory(at: imagesDirectoryURL(for: level), withIntermediateDirectories: true)
    }

    // MARK: - Data management

    /// Health status for a level
    enum DataHealth { case ok, missing, corrupted }

    /// Check if a level's problems.json is valid
    func checkDataHealth(for levelID: String) -> DataHealth {
        let url = URL(fileURLWithPath: storagePath).appendingPathComponent(levelID).appendingPathComponent("problems.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url),
              let _ = try? JSONDecoder().decode([Problem].self, from: data) else { return .corrupted }
        return .ok
    }

    /// List all level directories that have data on disk (with health)
    func allDataDirectories() -> [(id: String, hasProblems: Bool, hasImages: Bool, health: DataHealth)] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: storagePath) else { return [] }
        return contents.compactMap { name in
            let dir = URL(fileURLWithPath: storagePath).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            if name == "images" { return nil }
            let hasProblems = fm.fileExists(atPath: dir.appendingPathComponent("problems.json").path)
            let hasImages = (try? fm.contentsOfDirectory(atPath: dir.appendingPathComponent("images").path).count) ?? 0 > 0
            let health = checkDataHealth(for: name)
            return (name, hasProblems, hasImages, health)
        }
    }

    /// Permanently delete data for a level ID
    func deleteData(for levelID: String) {
        let dir = URL(fileURLWithPath: storagePath).appendingPathComponent(levelID)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Level-specific paths
    func problemsFileURL(for level: AppLevel) -> URL {
        URL(fileURLWithPath: storagePath).appendingPathComponent(level.id).appendingPathComponent("problems.json")
    }

    func imagesDirectoryURL(for level: AppLevel) -> URL {
        URL(fileURLWithPath: storagePath).appendingPathComponent(level.id).appendingPathComponent("images")
    }

    init() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: "storagePath") ?? ""
        if saved.isEmpty {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storagePath = docs.appendingPathComponent("MathAtlasLib").path
        } else {
            self.storagePath = saved
        }
        let animRaw = defaults.string(forKey: "animationStyle") ?? AnimationStyle.expand.rawValue
        self.animationStyle = AnimationStyle(rawValue: animRaw) ?? .expand
        let al = defaults.integer(forKey: "answerLines")
        self.answerLines = al == 0 ? 15 : al
        self.didCheckDeps = defaults.bool(forKey: "didCheckDeps")
        if let data = defaults.data(forKey: "customLevels"),
           let decoded = try? JSONDecoder().decode([AppLevel].self, from: data) {
            self.customLevels = decoded
        }
        let hiddenArr = defaults.stringArray(forKey: "hiddenBuiltinIDs") ?? []
        self.hiddenBuiltinIDs = Set(hiddenArr)
        ensureDirectories()
    }

    /// Create all storage + images directories if missing
    func ensureDirectories() {
        let fm = FileManager.default
        for level in allLevels {
            let dir = URL(fileURLWithPath: storagePath).appendingPathComponent(level.id)
            try? fm.createDirectory(atPath: dir.path, withIntermediateDirectories: true)
            try? fm.createDirectory(at: imagesDirectoryURL(for: level), withIntermediateDirectories: true)
        }
    }

    /// Open NSOpenPanel to let user pick a new storage folder
    static func pickStorageFolder(current: String, completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "选择题库存储位置"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if !current.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: current)
        }
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }
}
import Foundation

/// Manages AI prompt storage — reads/writes JSON files, handles defaults and migration.
enum PromptManager {

    // MARK: - Paths

    /// User-configurable directory (stored in AppStorage).
    static var promptDirectory: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: "promptDirectory"),
               !path.isEmpty { return URL(fileURLWithPath: path) }
            return defaultPromptsDirectory
        }
        set { UserDefaults.standard.set(newValue.path, forKey: "promptDirectory") }
    }

    /// Default: MathAtlasLib / Prompts (same parent as question bank data)
    static var defaultPromptsDirectory: URL {
        let libPath = UserDefaults.standard.string(forKey: "storagePath") ?? ""
        if !libPath.isEmpty { return URL(fileURLWithPath: libPath).appendingPathComponent("Prompts") }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent("MathAtlasLib/Prompts")
    }

    // MARK: - Prompt keys

    enum Key: String, CaseIterable {
        case tag      = "tag_generation"
        case category = "category_classification"
        case solution = "solution_generation"

        var fileName: String { "\(rawValue).json" }
        var displayName: String {
            switch self {
            case .tag:      return "标签生成"
            case .category: return "题型分类"
            case .solution: return "解析生成"
            }
        }
    }

    // MARK: - Default prompts

    static func defaultPrompt(for key: Key) -> String {
        switch key {
        case .tag:
            return """
            你是一个数学题库标签助手。{levelGuidance}
            当前题目已有标签：{existingTags}。
            请生成 2-5 个简洁的中文标签，每个标签用英文逗号(,)分隔。不要中文逗号、不要编号、不要换行、不要多余文字。
            题目：{problem}
            """
        case .category:
            return """
            判断以下数学题目的题型。{levelGuidance}
            规则：
            - 有"____"或"\\_\\_"等填空标记 → 填空题
            - 有"A. B. C. D."等选项字母 → 选择题
            - 要求写出完整解答过程 → 解答题
            - 当前分类为「{category}」
            只输出：填空题 / 选择题 / 解答题。不要任何解释。
            题目：{problem}
            """
        case .solution:
            return """
            你是一个数学教师。为以下题目编写解析，使用 LaTeX 格式。{levelGuidance}
            重要规则：
            - 所有数学公式和符号必须用 \\(...\\) 包裹（行内公式）或 \\[...\\] 包裹（独立公式）
            - 禁止使用 Markdown 的 ** 粗体语法，请用 \\textbf{...} 代替
            - \\textbf{...} 内部不要包含 \\(...\\) 或 \\[...\\] 数学公式
            要求：写出关键计算步骤，每步做简要说明。不要展开解释概念，不要重复题目。保持精炼。
            直接输出解析内容，禁止使用"好的"、"以下是"、"让我们"等开场白。
            题目：{problem}
            """
        }
    }

    // MARK: - Read / Write

    static func loadPrompt(for key: Key) -> String {
        let url = promptDirectory.appendingPathComponent(key.fileName)
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode([String: String].self, from: data),
              let prompt = json["prompt"], !prompt.isEmpty
        else { return defaultPrompt(for: key) }
        return prompt
    }

    static func savePrompt(_ text: String, for key: Key) throws {
        let url = promptDirectory.appendingPathComponent(key.fileName)
        try FileManager.default.createDirectory(at: promptDirectory, withIntermediateDirectories: true)
        let json = ["prompt": text]
        let data = try JSONEncoder().encode(json)
        try data.write(to: url)
    }

    /// Write all default prompts to the current directory (overwrites).
    static func restoreDefaults() throws {
        try FileManager.default.createDirectory(at: promptDirectory, withIntermediateDirectories: true)
        for key in Key.allCases {
            let url = promptDirectory.appendingPathComponent(key.fileName)
            let json = ["prompt": defaultPrompt(for: key)]
            let data = try JSONEncoder().encode(json)
            try data.write(to: url)
        }
    }

    /// Ensure default prompts exist on first launch.
    static func ensureDefaultsExist() {
        for key in Key.allCases {
            let url = promptDirectory.appendingPathComponent(key.fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? savePrompt(defaultPrompt(for: key), for: key)
            }
        }
    }

    /// Move prompt files from old directory to new directory.
    static func movePrompts(from oldDir: URL, to newDir: URL) throws {
        try FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
        for key in Key.allCases {
            let oldURL = oldDir.appendingPathComponent(key.fileName)
            let newURL = newDir.appendingPathComponent(key.fileName)
            if FileManager.default.fileExists(atPath: oldURL.path) {
                try? FileManager.default.removeItem(at: newURL)
                try FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        }
    }
}

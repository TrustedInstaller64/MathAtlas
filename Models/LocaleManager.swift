import SwiftUI

/// Supported languages
enum AppLanguage: String, CaseIterable {
    case zhHans = "zh-Hans"
    case en     = "en"

    var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en:     return "English"
        }
    }
}

/// Observable locale manager — reads/writes @AppStorage for "language"
@Observable
final class LocaleManager {
    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "language") ?? AppLanguage.zhHans.rawValue
        language = AppLanguage(rawValue: raw) ?? .zhHans
    }

    // MARK: - Localized strings

    var appTitle: String       { "MathAtlas" }
    var problemsCount: (_ n: Int) -> String { { n in
        self.language == .zhHans ? "共 \(n) 道题目" : "\(n) problem\(n == 1 ? "" : "s")"
    }}
    var searchPlaceholder: String { language == .zhHans ? "搜索题目内容、标签、来源……" : "Search problems, tags, source…" }
    var export: String            { language == .zhHans ? "导出" : "Export" }
    var newProblem: String        { language == .zhHans ? "新增题目" : "New Problem" }
    var categoryLabel: String     { language == .zhHans ? "题型" : "Category" }
    var tagLabel: String          { language == .zhHans ? "标签" : "Tags" }
    var clear: String             { language == .zhHans ? "清除" : "Clear" }
    var editProblem: String       { language == .zhHans ? "编辑题目" : "Edit Problem" }
    var cancel: String            { language == .zhHans ? "取消" : "Cancel" }
    var saveEdit: String          { language == .zhHans ? "保存修改" : "Save Changes" }
    var addProblem: String        { language == .zhHans ? "添加题目" : "Add Problem" }
    var preview: String           { language == .zhHans ? "实时预览" : "Live Preview" }
    var previewPlaceholder: String { language == .zhHans ? "输入内容后这里会实时渲染。" : "Enter content to see the preview." }
    var source: String            { language == .zhHans ? "来源" : "Source" }
    var note: String             { language == .zhHans ? "备注" : "Note" }
    var tagPlaceholder: String    { language == .zhHans ? "标签 (回车添加)" : "Tag (Enter to add)" }
    var questionLabel: String     { language == .zhHans ? "题目内容" : "Question" }
    var solutionLabel: String     { language == .zhHans ? "解析 / 解答" : "Solution" }
    var imageAttach: String       { language == .zhHans ? "图片附件" : "Image Attachments" }
    var dropZoneHint: String      { language == .zhHans ? "拖拽图片到此处" : "Drop image here" }
    var releaseToAdd: String      { language == .zhHans ? "松开以添加" : "Release to add" }
    var pickImage: String         { language == .zhHans ? "选择图片..." : "Choose Image..." }
    var loading: String           { language == .zhHans ? "加载中……" : "Loading…" }
    var emptyLibrary: String      { language == .zhHans ? "题库为空，点击右上角「新增题目」开始添加。" : "Library is empty. Click \"New Problem\" to start." }
    var noMatch: String           { language == .zhHans ? "没有符合条件的题目。" : "No matching problems." }

    // Delete confirmation
    var deleteTitle: String       { language == .zhHans ? "确认删除这道题目？" : "Delete this problem?" }
    var deleteMessage: String     { language == .zhHans ? "此操作无法撤销，题目将从本地题库中永久移除。" : "This action cannot be undone. The problem will be permanently removed." }
    var deleteConfirm: String     { language == .zhHans ? "删除" : "Delete" }

    // Content type
    var contentTypeLatex: String   { "LaTeX 公式" }
    var contentTypeText: String    { language == .zhHans ? "纯文本" : "Text" }
    var contentTypeImage: String   { language == .zhHans ? "图片" : "Image" }

    var contentTypeLabels: [String] { [contentTypeLatex, contentTypeText, contentTypeImage] }

    // Solution
    var solutionToggle: String     { language == .zhHans ? "解析" : "Solution" }

    // Categories
    var categoryAll: String        { language == .zhHans ? "全部" : "All" }
    var catFill: String            { language == .zhHans ? "填空题" : "Fill-in-blank" }
    var catChoice: String          { language == .zhHans ? "选择题" : "Multiple choice" }
    var catAnswer: String          { language == .zhHans ? "解答题" : "Free response" }
    var catUncat: String           { language == .zhHans ? "未分类" : "Uncategorized" }

    var categories: [String] { [catFill, catChoice, catAnswer, catUncat] }

    // Source viewer
    var sourceTitle: String        { language == .zhHans ? "LaTeX 源码" : "LaTeX Source" }
    var close: String              { language == .zhHans ? "关闭" : "Close" }

    // Image dropdown prompt
    var imgPromptQ: String         { language == .zhHans ? "图片作为题目主体" : "Image as question body" }
    var imgPromptQAttach: String   { language == .zhHans ? "题目附加图片" : "Question image attachment" }
    var imgPromptS: String         { language == .zhHans ? "图片作为解析主体" : "Image as solution body" }
    var imgPromptSAttach: String   { language == .zhHans ? "解析附加图片" : "Solution image attachment" }

    // Settings
    var settingsTitle: String      { language == .zhHans ? "设置" : "Settings" }
    var languageSetting: String    { language == .zhHans ? "语言 / Language" : "Language" }
    var storageSetting: String     { language == .zhHans ? "题库存储位置" : "Library Storage Location" }
    var chooseFolder: String       { language == .zhHans ? "选择文件夹..." : "Choose Folder…" }
    var defaultStorageNote: String { language == .zhHans
        ? "默认为 Documents 文件夹下的 MathAtlasLib" : "Defaults to MathAtlasLib inside Documents" }

    // Menu commands
    var menuFile: String           { language == .zhHans ? "文件" : "File" }
    var menuEdit: String           { language == .zhHans ? "编辑" : "Edit" }
    var menuView: String           { language == .zhHans ? "显示" : "View" }
    var menuSettings: String       { language == .zhHans ? "偏好设置…" : "Preferences…" }
}

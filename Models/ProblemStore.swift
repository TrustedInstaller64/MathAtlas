import Foundation
import SwiftUI

@Observable
final class ProblemStore {
    private(set) var problems: [Problem] = []
    private(set) var ready = false

    let level: AppLevel
    private var settings: AppSettings?

    // MARK: - Caches
    private var htmlCache: [String: String] = [:]
    private var imageCache = NSCache<NSString, NSData>()

    init(level: AppLevel = .high) {
        self.level = level
    }

    /// Inject settings after init (called from MathBankApp)
    func configure(settings: AppSettings) {
        self.settings = settings
        settings.ensureDirectories()
        load()
    }

    // MARK: - HTML cache

    func cachedHTML(for problem: Problem) -> String {
        if let cached = htmlCache[problem.id] { return cached }
        let html = LaTeXParser.toHTML(problem.latex)
        htmlCache[problem.id] = html
        return html
    }

    func invalidateCache(for problemID: String) {
        htmlCache.removeValue(forKey: problemID)
    }

    /// Strip LaTeX markup for a readable plain-text preview
    func plainTextPreview(for problem: Problem) -> String {
        var s = problem.latex
        // Remove \begin{...} and \end{...} tags only (keep content between them)
        s = s.replacingOccurrences(of: "\\\\begin\\{[^}]*\\}", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\end\\{[^}]*\\}", with: "", options: .regularExpression)
        // Remove math delimiters
        s = s.replacingOccurrences(of: "\\\\\\(|\\\\\\)|\\\\\\[|\\\\\\]|\\$\\$?", with: "", options: .regularExpression)
        // Remove any \command
        s = s.replacingOccurrences(of: "\\\\[a-zA-Z]+(\\[[^]]*\\])?(\\{[^}]*\\})*", with: "", options: .regularExpression)
        // Remove escaped braces
        s = s.replacingOccurrences(of: "\\\\\\{|\\\\\\}", with: "", options: .regularExpression)
        // Remove standalone braces and backslashes
        s = s.replacingOccurrences(of: "[{}]", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\", with: "", options: .regularExpression)
        // Fill blanks
        s = s.replacingOccurrences(of: "_{2,}", with: "____", options: .regularExpression)
        // Collapse whitespace
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - File-based persistence

    private func load() {
        guard let settings else { return }
        let url = settings.problemsFileURL(for: level)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Problem].self, from: data) else {
            problems = Problem.seedProblems(for: level)
            save()
            ready = true
            return
        }
        problems = decoded
        // Migrate Markdown **bold** → LaTeX \textbf{bold} in existing data
        var migrated = false
        for i in problems.indices {
            var p = problems[i]
            let before = p.solution + p.latex
            p.solution = p.solution.replacingOccurrences(
                of: "\\*\\*([^*]+)\\*\\*", with: "\\\\textbf{$1}", options: .regularExpression)
            p.latex = p.latex.replacingOccurrences(
                of: "\\*\\*([^*]+)\\*\\*", with: "\\\\textbf{$1}", options: .regularExpression)
            if before != p.solution + p.latex {
                problems[i] = p
                migrated = true
            }
        }
        if migrated { save() }
        ready = true
    }

    private func save() {
        guard let settings else { return }
        settings.ensureDirectories()
        if let data = try? JSONEncoder().encode(problems) {
            let dir = settings.problemsFileURL(for: level).deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: settings.problemsFileURL(for: level))
        }
    }

    // MARK: - CRUD

    private func uid() -> String {
        "\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 100000...999999))"
    }

    func create(contentType: String, latex: String, tags: [String], category: String, source: String, note: String,
                solution: String = "", solutionContentType: String = "latex",
                solutionImageNames: [String] = [], imageNames: [String] = []) {
        let now = Date().timeIntervalSince1970
        let problem = Problem(
            id: uid(), contentType: contentType, latex: latex, tags: tags,
            category: category, source: source, note: note,
            solution: solution, solutionContentType: solutionContentType,
            solutionImageNames: solutionImageNames, imageNames: imageNames,
            createdAt: now, updatedAt: now
        )
        problems.insert(problem, at: 0)
        htmlCache.removeValue(forKey: problem.id)
        save()
    }

    func update(_ problem: Problem) {
        if let idx = problems.firstIndex(where: { $0.id == problem.id }) {
            var u = problem
            u.updatedAt = Date().timeIntervalSince1970
            problems[idx] = u
            save()
        }
    }

    func delete(_ problem: Problem) {
        deleteImages(for: problem)
        problems.removeAll { $0.id == problem.id }
        save()
    }

    // MARK: - Image Management

    var imageDirectory: URL {
        settings?.imagesDirectoryURL(for: level)
            ?? (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent("MathAtlasLib/\(level.id)/images")
    }

    func saveImage(data: Data, filename: String) -> Bool {
        let url = imageDirectory.appendingPathComponent(filename)
        try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        do { try data.write(to: url); imageCache.setObject(NSData(data: data), forKey: filename as NSString); return true }
        catch { print("Failed to save image: \(error)"); return false }
    }

    func loadImage(named filename: String) -> Data? {
        if let cached = imageCache.object(forKey: filename as NSString) { return cached as Data }
        guard let data = try? Data(contentsOf: imageDirectory.appendingPathComponent(filename)) else { return nil }
        imageCache.setObject(NSData(data: data), forKey: filename as NSString)
        return data
    }

    func deleteImages(for problem: Problem) {
        for name in problem.imageNames + problem.solutionImageNames {
            try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(name))
            imageCache.removeObject(forKey: name as NSString)
        }
    }

    // MARK: - Export

    func exportJSON() -> URL? {
        guard let data = try? JSONEncoder().encode(problems),
              let json = String(data: data, encoding: .utf8) else { return nil }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let filename = "math-problems-\(df.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try json.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }

    // MARK: - Helpers

    var allTags: [String] {
        var set = Set<String>()
        problems.forEach { $0.tags.forEach { set.insert($0) } }
        return set.sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    var allSources: [String] {
        var set = Set<String>()
        problems.forEach { if !$0.source.isEmpty { set.insert($0.source) } }
        return set.sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    func categoryCount(_ category: String) -> Int {
        if category == "全部" || category == "All" { return problems.count }
        return problems.filter { $0.category == category }.count
    }

    func filtered(query: String, category: String, tags: [String], source: String? = nil) -> [Problem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return problems.filter { p in
            if category != "全部" && category != "All" && p.category != category { return false }
            if !tags.isEmpty && !tags.allSatisfy({ p.tags.contains($0) }) { return false }
            if let src = source, p.source != src { return false }
            if !q.isEmpty {
                let haystack = "\(p.latex) \(p.tags.joined(separator: " ")) \(p.source) \(p.note)".lowercased()
                if !haystack.contains(q) { return false }
            }
            return true
        }
    }
}

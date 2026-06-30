import Foundation

/// Checks for required external tools
enum DependencyChecker {

    struct Status {
        var pandocInstalled = false
        var pandocVersion: String?
        var xelatexInstalled = false
        var xelatexVersion: String?
        var allInstalled: Bool { pandocInstalled && xelatexInstalled }

        static let pandocInstallCmd  = "brew install pandoc"
        static let xelatexInstallCmd = "brew install basictex"
        static let pandocDesc  = "Pandoc — 将 Markdown 转换为 PDF"
        static let xelatexDesc = "XeLaTeX (via BasicTeX) — PDF 排版引擎"
    }

    static func check() -> Status {
        var s = Status()
        s.pandocInstalled = toolExists("pandoc")
        if s.pandocInstalled { s.pandocVersion = toolVersion("pandoc", args: ["--version"]) }
        s.xelatexInstalled = toolExists("xelatex")
        if s.xelatexInstalled { s.xelatexVersion = toolVersion("xelatex", args: ["--version"]) }
        return s
    }

    private static func toolVersion(_ name: String, args: [String]) -> String? {
        guard let path = findToolPath(name) else { return nil }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run(); task.waitUntilExit() }
        catch { return nil }
        let data = try? pipe.fileHandleForReading.readToEnd()
        return data.flatMap { String(data: $0, encoding: .utf8) }?
            .components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespaces)
    }

    private static func toolExists(_ name: String) -> Bool {
        // The `which` command may not find tools due to limited PATH in GUI apps.
        // Check well-known installation paths directly.
        let commonPaths = [
            "/opt/homebrew/bin",           // Apple Silicon Homebrew
            "/usr/local/bin",              // Intel Homebrew
            "/usr/local/texlive/2024/bin/universal-darwin", // MacTeX
            "/usr/local/texlive/2025/bin/universal-darwin",
            "/Library/TeX/texbin",         // BasicTeX symlink
        ]
        // First try `which`
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["which", name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let whichPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !whichPath.isEmpty && task.terminationStatus == 0 { return true }

        // Fallback: check common paths
        let fm = FileManager.default
        for dir in commonPaths {
            if fm.fileExists(atPath: "\(dir)/\(name)") { return true }
        }
        return false
    }

    /// Run pandoc to convert .md to .pdf
    /// Returns (success: Bool, output: String)
    static func runPandoc(mdURL: URL, pdfURL: URL) -> (success: Bool, log: String) {
        // Find pandoc path explicitly
        let pandocPath: String
        if let p = findToolPath("pandoc") {
            pandocPath = p
        } else {
            return (false, "错误：未找到 pandoc。请确认 pandoc 已安装。\n\n安装命令：brew install pandoc")
        }

        guard FileManager.default.fileExists(atPath: mdURL.path) else {
            return (false, "错误：MD 文件不存在\n路径：\(mdURL.path)")
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: pandocPath)
        task.arguments = [
            "--verbose",
            mdURL.path,
            "-o", pdfURL.path,
            "--pdf-engine=xelatex"
        ]
        task.currentDirectoryURL = mdURL.deletingLastPathComponent()

        // Set environment to include Homebrew paths
        var env = ProcessInfo.processInfo.environment
        var path = env["PATH"] ?? "/usr/bin:/bin"
        path = "/opt/homebrew/bin:/usr/local/bin:/Library/TeX/texbin:" + path
        env["PATH"] = path
        task.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
        } catch {
            return (false, "启动 pandoc 失败：\(error.localizedDescription)\n命令：\(pandocPath)")
        }

        // Read output on background thread to avoid deadlock
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        group.enter(); group.enter()
        DispatchQueue.global().async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        DispatchQueue.global().async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.wait()
        task.waitUntilExit()

        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        let log = """
        === 命令 ===
        \(pandocPath) \(mdURL.path) -o \(pdfURL.path) --pdf-engine=xelatex

        === STDOUT ===
        \(outStr.isEmpty ? "(无输出)" : outStr)

        === STDERR ===
        \(errStr.isEmpty ? "(无输出)" : errStr)

        === 退出码: \(task.terminationStatus) ===
        \(task.terminationStatus == 0 ? "成功" : "失败")
        """

        return (task.terminationStatus == 0, log)
    }

    private static func findToolPath(_ name: String) -> String? {
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
        ]
        let fm = FileManager.default
        for dir in commonPaths {
            let path = "\(dir)/\(name)"
            if fm.isExecutableFile(atPath: path) { return path }
        }
        // Try `which`
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["which", name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.launch()
        task.waitUntilExit()
        let data = try? pipe.fileHandleForReading.readToEnd()
        let path = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }
}

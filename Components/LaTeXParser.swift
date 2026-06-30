import Foundation

/// Converts LaTeX problem source into HTML for KaTeX rendering.
///
/// Line-by-line port of `/MathBandHTML/components/latex-renderer.tsx`.
/// Architecture:
///   1. parseBlocks      — 仅 enumerate / tabular / center → HTML
///   2. inlineContent    — 数学分隔符 → KaTeX span；纯文本 → renderPlainText
///   3. renderPlainText  — 文本格式化（\textbf 剥离、\\ 换行、\_\_ 填空）
///
/// 绝不解析数学内容结构。\begin{cases}、&、\\[6pt] 等全部原样交给 KaTeX。
enum LaTeXParser {

    // MARK: - Entry

    static func toHTML(_ latex: String) -> String {
        var src = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        src = src.replacingOccurrences(of: "^\\\\item\\s*", with: "",
                                       options: .regularExpression)
        return "<div class=\"prob\">\(parseBlocks(src))</div>"
    }

    // MARK: - Block-level parsing (ref: parseBlocks, latex-renderer.tsx:173-256)

    /// 仅匹配 enumerate / tabular / center。其他一切（包括 cases/aligned/matrix）
    /// 都不在此处理 —— 它们由 inlineContent 通过数学分隔符交给 KaTeX。
    private static func parseBlocks(_ src: String) -> String {
        var result = ""
        var i = src.startIndex
        var textBuf = ""

        func flushText() {
            guard !textBuf.trimmingCharacters(in: .whitespaces).isEmpty else {
                textBuf = ""
                return
            }
            result += inlineContent(textBuf)
            textBuf = ""
        }

        while i < src.endIndex {
            let rest = src[i...]  // Substring, shares indices with src
            let beginPattern = "\\\\begin\\{(enumerate|tabular|center)\\}"
            guard let beginRange = rest.range(of: beginPattern, options: .regularExpression) else {
                textBuf += String(rest)
                break
            }

            let envName: String = {
                let t = String(rest[beginRange])
                return t.replacingOccurrences(of: "\\begin{", with: "")
                        .replacingOccurrences(of: "}", with: "")
            }()

            // Text before this environment
            textBuf += String(rest[rest.startIndex..<beginRange.lowerBound])

            // bodyStart = right after \begin{name} (absolute index in src)
            var bodyStart = beginRange.upperBound

            // enumerate 可选参数 [...]
            var options = ""
            if envName == "enumerate", bodyStart < src.endIndex, src[bodyStart] == "[" {
                if let closeIdx = src[bodyStart...].firstIndex(of: "]" as Character) {
                    options = String(src[src.index(after: bodyStart)..<closeIdx])
                    bodyStart = src.index(after: closeIdx)
                }
            }

            // 找匹配的 \end{name}（支持同名嵌套，ref: findMatchingEnd）
            let endIdx = findMatchingEnd(in: src, name: envName, from: bodyStart)
            guard let bodyEnd = endIdx else {
                textBuf += String(rest)
                break
            }
            let body = String(src[bodyStart..<bodyEnd])
            let endTag = "\\end{\(envName)}"
            i = src.index(bodyEnd, offsetBy: endTag.count)

            flushText()

            switch envName {
            case "tabular":
                result += renderTabular(body)
            case "center":
                result += "<div class=\"tac\">\(parseBlocks(body))</div>"
            default: // enumerate
                result += renderEnum(body, opts: options)
            }
        }

        flushText()
        return result
    }

    // MARK: - findMatchingEnd (ref: latex-renderer.tsx:49-71)

    /// 从 from 位置开始，找到与 \begin{name} 匹配的 \end{name}。
    /// 支持同名嵌套（如 enumerate 套 enumerate）。返回 \end{name} 起始位置的索引。
    private static func findMatchingEnd(in src: String, name: String, from: String.Index) -> String.Index? {
        let beginPat = "\\\\begin\\{\(NSRegularExpression.escapedPattern(for: name))\\}"
        let endPat   = "\\\\end\\{\(NSRegularExpression.escapedPattern(for: name))\\}"
        guard let beginRe = try? NSRegularExpression(pattern: beginPat),
              let endRe   = try? NSRegularExpression(pattern: endPat) else { return nil }

        var depth = 0
        var i = from
        let nsRange = NSRange(src.startIndex..., in: src)

        while i < src.endIndex {
            let searchRange = NSRange(i..., in: src)
            let b = beginRe.firstMatch(in: src, options: [], range: searchRange)
            let e = endRe.firstMatch(in: src, options: [], range: searchRange)

            guard let eMatch = e else { return nil }

            if let bMatch = b, bMatch.range.location < eMatch.range.location {
                depth += 1
                i = Range(bMatch.range, in: src)!.upperBound
            } else {
                if depth == 0 { return Range(eMatch.range, in: src)!.lowerBound }
                depth -= 1
                i = Range(eMatch.range, in: src)!.upperBound
            }
        }
        return nil
    }

    // MARK: - InlineContent (ref: latex-renderer.tsx:261-323)

    /// 处理不含块级环境的文本：数学公式提取 → KaTeX span；纯文本 → renderPlainText。
    /// ref: `InlineContent` — flushBuf 时调用 renderPlainText；数学定界符内的内容直接交给 KaTeX。
    private static func inlineContent(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        var buf = ""

        func flushBuf() {
            guard !buf.isEmpty else { return }
            result += renderPlainText(buf)
            buf = ""
        }

        while i < text.endIndex {
            let two = text[i...].prefix(2)

            // 行间公式 \[ ... \]  —— ref: line 276-283
            if two == "\\[" {
                let start = text.index(i, offsetBy: 2)
                if let end = text[start...].firstRange(of: "\\]") {
                    flushBuf()
                    let math = String(text[start..<end.lowerBound])
                    result += "<span class=\"md\">\(escAttr(math))</span>"
                    i = end.upperBound
                    continue
                }
            }
            // 行间公式 $$ ... $$  —— ref: line 285-293
            if two == "$$" {
                let start = text.index(i, offsetBy: 2)
                if let end = text[start...].firstRange(of: "$$") {
                    flushBuf()
                    let math = String(text[start..<end.lowerBound])
                    result += "<span class=\"md\">\(escAttr(math))</span>"
                    i = end.upperBound
                    continue
                }
            }
            // 行内公式 \( ... \)  —— ref: line 295-305
            if two == "\\(" {
                let start = text.index(i, offsetBy: 2)
                if let end = text[start...].firstRange(of: "\\)") {
                    flushBuf()
                    let math = String(text[start..<end.lowerBound])
                    result += "<span class=\"mi\">\(escAttr("\\displaystyle \(math)"))</span>"
                    i = end.upperBound
                    continue
                }
            }
            // 行内公式 $ ... $ (not $$) —— ref: line 306-317
            if text[i] == "$" && two != "$$" {
                let start = text.index(after: i)
                if let end = text[start...].firstIndex(of: "$" as Character) {
                    flushBuf()
                    let math = String(text[start..<end])
                    result += "<span class=\"mi\">\(escAttr("\\displaystyle \(math)"))</span>"
                    i = text.index(after: end)
                    continue
                }
            }

            buf.append(text[i])
            i = text.index(after: i)
        }

        flushBuf()
        return result
    }

    // MARK: - renderPlainText (ref: latex-renderer.tsx:326-379)

    /// 渲染不含数学公式的纯文本：LaTeX 文本命令剥离、换行、填空线、转义字符。
    private static func renderPlainText(_ input: String) -> String {
        var s = input

        // \source{...} → 标记  —— ref: line 330
        s = s.replacingOccurrences(of: "\\\\source\\{([^}]*)\\}",
                                   with: "\u{300c}$1\u{300d}",
                                   options: .regularExpression)
        // Text styling → HTML tags
        s = s.replacingOccurrences(of: "\\\\textbf\\{([^}]*)\\}", with: "<b>$1</b>", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\textit\\{([^}]*)\\}", with: "<i>$1</i>", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\underline\\{([^}]*)\\}", with: "<u>$1</u>", options: .regularExpression)
        // Other style commands → strip, keep content
        s = s.replacingOccurrences(of: "\\\\(?:textsf|textrm|mathrm|text|emph|overline)\\{([^}]*)\\}",
                                   with: "$1",
                                   options: .regularExpression)

        // 间距命令 → 空格  —— ref: line 334-335
        s = s.replacingOccurrences(of: "\\\\(?:quad|qquad|qued)", with: "\u{2003}",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\[,;:! ]", with: " ",
                                   options: .regularExpression)

        // 转义字符  —— ref: line 338-342
        s = s.replacingOccurrences(of: "\\\\~", with: "~")
        s = s.replacingOccurrences(of: "\\\\#", with: "#")
        s = s.replacingOccurrences(of: "\\\\%", with: "%")
        s = s.replacingOccurrences(of: "\\\\&", with: "&amp;")

        // 移除不需渲染的 LaTeX 命令 —— ref: line 344-348
        s = s.replacingOccurrences(of: "\\\\setcounter\\{[^}]*\\}\\{[^}]*\\}", with: "",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\(?:clearpage|newpage|par|noindent|displaystyle|centering)\\b",
                                   with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\vspace\\*?\\{[^}]*\\}", with: "",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\(?:label|ref|pageref)\\{[^}]*\\}", with: "",
                                   options: .regularExpression)

        // \__ \__ … → 填空占位 —— ref: line 351
        s = s.replacingOccurrences(of: "(?:\\\\_){2,}", with: "\u{0000}B\u{0000}",
                                   options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\_", with: "_")

        // 按 \\ 换行切分 —— ref: line 356
        let lines = s.components(separatedBy: "\\\\")
        var out = ""
        for (idx, line) in lines.enumerated() {
            if idx > 0 { out += "<br>" }
            // 处理填空占位 —— ref: line 360-376
            let segs = line.components(separatedBy: "\u{0000}B\u{0000}")
            for (si, seg) in segs.enumerated() {
                if si > 0 {
                    out += "<span class=\"bl\">&nbsp;&nbsp;&nbsp;&nbsp;</span>"
                }
                if !seg.isEmpty {
                    out += seg
                }
            }
        }
        return out
    }

    // MARK: - Enum / Itemize (ref: splitItems + render, latex-renderer.tsx:76-131, 224-248)

    private static func renderEnum(_ body: String, opts: String) -> String {
        let alpha = opts.contains("\\Alph") || opts.contains("\\alph")
        let items = splitItems(body)
        var h = "<ol class=\"lst\">"
        for (i, item) in items.enumerated() {
            let label: String = alpha
                ? (i < 26 ? "\(UnicodeScalar(65 + i)!)." : "(\(i + 1))")
                : "(\(i + 1))"
            h += "<li><span class=\"ln\">\(label)</span><span class=\"lc\">\(parseBlocks(item))</span></li>"
        }
        h += "</ol>"
        return h
    }

    /// ref: splitItems, latex-renderer.tsx:76-126
    private static func splitItems(_ body: String) -> [String] {
        var items: [String] = []
        var cur = ""
        var i = body.startIndex
        var envDepth = 0
        var mathDepth = 0

        while i < body.endIndex {
            let c = body[i...]

            if c.hasPrefix("\\(") || c.hasPrefix("\\[") {
                mathDepth += 1; cur += String(c.prefix(2)); i = body.index(i, offsetBy: 2); continue
            }
            if c.hasPrefix("\\)") || c.hasPrefix("\\]") {
                mathDepth = max(0, mathDepth - 1); cur += String(c.prefix(2)); i = body.index(i, offsetBy: 2); continue
            }
            if c.hasPrefix("\\begin") {
                envDepth += 1; cur += "\\begin"; i = body.index(i, offsetBy: 6); continue
            }
            if c.hasPrefix("\\end") {
                envDepth = max(0, envDepth - 1); cur += "\\end"; i = body.index(i, offsetBy: 4); continue
            }

            if mathDepth == 0 && envDepth == 0 && c.hasPrefix("\\item") {
                let after = body.index(i, offsetBy: 5, limitedBy: body.endIndex) ?? body.endIndex
                if after >= body.endIndex || !body[after].isLetter {
                    let t = cur.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { items.append(t) }
                    cur = ""
                    i = after
                    continue
                }
            }
            cur.append(body[i])
            i = body.index(after: i)
        }
        let t = cur.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { items.append(t) }
        if let first = items.first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.removeFirst()
        }
        return items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: - Table (ref: renderTabular, latex-renderer.tsx:135-168)

    private static func renderTabular(_ body: String) -> String {
        var s = body
        s = s.replacingOccurrences(of: "^\\s*\\{[^}]*\\}", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\hline", with: "")
        let rows = s.components(separatedBy: "\\\\")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var h = "<div class=\"tw\"><table>"
        for row in rows {
            h += "<tr>"
            for cell in row.components(separatedBy: "&").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                h += "<td>\(inlineContent(cell))</td>"
            }
            h += "</tr>"
        }
        h += "</table></div>"
        return h
    }

    // MARK: - Helpers

    /// HTML-escape 数学内容以便安全嵌入 span 标签。
    /// ref: KaTeX span 内容只经过此函数，不经过 renderPlainText。
    private static func escAttr(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "\"", with: "&quot;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}

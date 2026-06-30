import SwiftUI
import WebKit

/// Renders LaTeX via WKWebView + KaTeX. The full HTML (with parsed LaTeX content)
/// is generated in Swift and loaded directly — no JS bridge needed.
struct KaTeXWebView: NSViewRepresentable {
    let latex: String
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(dynamicHeight: $dynamicHeight)
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.loadContent(latex)
        return context.coordinator.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.render(latex)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let webView: NonScrollingWebView
        @Binding var dynamicHeight: CGFloat
        private var lastLatex: String?
        private var lastReportedHeight: CGFloat = 0
        private var pageLoaded = false

        init(dynamicHeight: Binding<CGFloat>) {
            self._dynamicHeight = dynamicHeight
            let config = WKWebViewConfiguration()
            let wv = NonScrollingWebView(frame: .zero, configuration: config)
            wv.setValue(false, forKey: "drawsBackground")
            self.webView = wv
            super.init()
            config.userContentController.add(self, name: "height")
            wv.navigationDelegate = self
        }

        func loadContent(_ latex: String) {
            lastLatex = latex
            loadHTML(buildPage(for: latex))
        }

        func render(_ latex: String) {
            guard latex != lastLatex else { return }
            lastLatex = latex
            loadHTML(buildPage(for: latex))
        }

        /// Copy KaTeX + HTML to temp dir, load via loadFileURL (WKWebView sandbox compat)
        private func loadHTML(_ html: String) {
            guard let resURL = Bundle.main.resourceURL else { return }
            let fm = FileManager.default
            let tmpDir = fm.temporaryDirectory.appendingPathComponent("katex-" + UUID().uuidString)
            try? fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)

            // Copy KaTeX CSS + JS + fonts to temp dir
            for file in ["katex.min.css", "katex.min.js"] {
                let src = resURL.appendingPathComponent(file)
                let dst = tmpDir.appendingPathComponent(file)
                try? fm.copyItem(at: src, to: dst)
            }
            // Copy all .woff2 font files (KaTeX CSS references them by relative path)
            if let fontURLs = try? fm.contentsOfDirectory(at: resURL, includingPropertiesForKeys: nil) {
                for url in fontURLs where url.pathExtension == "woff2" {
                    let dst = tmpDir.appendingPathComponent(url.lastPathComponent)
                    try? fm.copyItem(at: url, to: dst)
                }
            }
            // Write HTML to temp dir
            let htmlFile = tmpDir.appendingPathComponent("page.html")
            try? html.write(to: htmlFile, atomically: true, encoding: .utf8)
            pageLoaded = false
            webView.loadFileURL(htmlFile, allowingReadAccessTo: tmpDir)
        }

        /// Build a complete self-contained HTML page with parsed LaTeX and KaTeX.
        private func buildPage(for latex: String) -> String {
            let bodyHTML = LaTeXParser.toHTML(latex)
            let escapedBody = bodyHTML
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")

            return """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1.0">
            <link rel="stylesheet" href="katex.min.css">
            <style>
            :root{--fg:#1a1a1a;--fg2:#666;--bd:#e5e5e5;--muted:#999}
            @media(prefers-color-scheme:dark){:root{--fg:#e5e5e5;--fg2:#aaa;--bd:#333;--muted:#888}}
            *{margin:0;padding:0;box-sizing:border-box}
            body{font-family:"Noto Serif SC","STSong",serif;font-size:15px;line-height:1.85;
            color:var(--fg);padding:12px;-webkit-text-size-adjust:none}
            .prob{word-wrap:break-word}
            .mi{display:inline}.md{display:block;margin:6px 0}
            .lst{margin:6px 0 6px 4px;padding:0;list-style:none}
            .lst li{display:flex;gap:6px;margin-bottom:5px}
            .ln{flex-shrink:0;font-weight:500;color:var(--muted);min-width:24px;text-align:right}
            .lc{flex:1;min-width:0}
            .tw{overflow-x:auto;margin:8px 0}
            .tw table{border-collapse:collapse;margin:0 auto;font-size:14px}
            .tw td{border:1px solid var(--bd);padding:4px 10px;text-align:center;white-space:nowrap}
            .tac{text-align:center}
            .bl{display:inline-block;min-width:3rem;border-bottom:1px solid;margin:0 2px;vertical-align:middle;opacity:.6}
            .katex{font-size:1.1em}.katex-display{margin:4px 0!important}
            </style></head>
            <body>
            <div id="content"></div>
            <script src="katex.min.js"></script>
            <script>
            (function(){
            var c=document.getElementById('content');
            c.innerHTML=`\(escapedBody)`;
            c.querySelectorAll('.mi').forEach(function(e){
            try{katex.render(e.textContent,e,{displayMode:false,throwOnError:false,strict:false,trust:true})}
            catch(x){e.textContent='[err]'}
            });
            c.querySelectorAll('.md').forEach(function(e){
            try{katex.render(e.textContent,e,{displayMode:true,throwOnError:false,strict:false,trust:true})}
            catch(x){e.textContent='[err]'}
            });
            setTimeout(function(){window.webkit.messageHandlers.height.postMessage(document.body.scrollHeight)},50);
            setTimeout(function(){window.webkit.messageHandlers.height.postMessage(document.body.scrollHeight)},300);
            })();
            </script>
            </body></html>
            """
        }

        func webView(_ webView: WKWebView, didFinish nav: WKNavigation!) {
            pageLoaded = true
        }

        func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
            if msg.name == "height", let h = msg.body as? CGFloat {
                let newH = h + 16
                // Only update if height changed significantly (prevents layout loop)
                guard abs(newH - lastReportedHeight) > 2 else { return }
                lastReportedHeight = newH
                DispatchQueue.main.async { self.dynamicHeight = newH }
            }
        }
    }
}

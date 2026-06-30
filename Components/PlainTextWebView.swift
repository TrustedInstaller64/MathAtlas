import SwiftUI
import WebKit

struct PlainTextWebView: NSViewRepresentable {
    let text: String
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(dynamicHeight: $dynamicHeight)
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.loadContent(text)
        return context.coordinator.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.render(text)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let webView: NonScrollingWebView
        @Binding var dynamicHeight: CGFloat
        private var lastText: String?

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

        func loadContent(_ text: String) {
            lastText = text
            
//            let html = buildPage(for: text)
//            print(html)
            
            webView.loadHTMLString(buildPage(for: text), baseURL: nil)
        }

        func render(_ text: String) {
            guard text != lastText else { return }
            lastText = text
            webView.loadHTMLString(buildPage(for: text), baseURL: nil)
        }

        private func buildPage(for text: String) -> String {
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            return """
            <!DOCTYPE html><html><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1.0">
            <style>
            :root{color-scheme:light dark}
            body{font-family:-apple-system,"Noto Serif SC",serif;font-size:15px;
            line-height:1.8;padding:12px;margin:0;-webkit-text-size-adjust:none}
            @media(prefers-color-scheme:dark){body{color:#e5e5e5}}
            </style></head>
            <body><div id="c"></div><script>
            document.getElementById('c').textContent=`\(escaped)`;
            setTimeout(function(){window.webkit.messageHandlers.height.postMessage(document.body.scrollHeight)},50);
            setTimeout(function(){window.webkit.messageHandlers.height.postMessage(document.body.scrollHeight)},300);
            </script></body></html>
            """
        }

        func webView(_ webView: WKWebView, didFinish nav: WKNavigation!) {}
        func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
            if msg.name == "height", let h = msg.body as? CGFloat {
                DispatchQueue.main.async { self.dynamicHeight = h + 16 }
            }
        }
    }
}

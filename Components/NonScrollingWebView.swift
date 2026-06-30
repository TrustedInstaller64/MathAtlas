import WebKit

/// WKWebView that forwards scroll events to parent ScrollView.
final class NonScrollingWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

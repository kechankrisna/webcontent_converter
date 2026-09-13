//
//  WKWebView+Debug.swift
//  webcontent_converter
//

import WebKit

extension WKWebView {
    /// WKWebView has no right-click "Inspect Element" the way WebView2 does
    /// — the closest equivalent is opting the WebView into Safari's Web
    /// Inspector (macOS: Safari > Develop menu > pick this app/window; the
    /// page then opens in Safari's own Inspector window, not in-place).
    ///
    /// DEBUG-only: `isInspectable` exposes the page's full DOM/JS/network
    /// internals to anyone with Screen Sharing or physical access to the
    /// machine running the app, so it must never be left on in a release
    /// build.
    func enableInspectorInDebugBuilds() {
        #if DEBUG
            if #available(iOS 16.4, macOS 13.3, *) {
                isInspectable = true
            }
        #endif
    }
}

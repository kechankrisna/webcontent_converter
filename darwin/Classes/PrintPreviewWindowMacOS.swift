//
//  PrintPreviewWindowMacOS.swift
//  webcontent_converter
//

#if os(macOS)

    import Cocoa
    import WebKit

    /// Opens print preview in a genuine standalone top-level window — its
    /// own title bar, its own WKWebView — rather than printing from a
    /// WebView that was never part of any window's view hierarchy. Loads
    /// `content` into it, shows the window immediately (so the user watches
    /// it load, like a browser tab), then once loaded presents
    /// `webView.printOperation(with:)` as a sheet on that window — WebKit's
    /// print pipeline, presented in-context the way a page's own
    /// `window.print()` would, rather than an app-modal dialog floating
    /// with no visible page behind it.
    ///
    /// Mirrors the Windows implementation's `PrintPreviewWindow`: a genuine
    /// popup window + its own WebView2 session, then
    /// `ShowPrintUI(COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER)` (WebView2's
    /// `window.print()` equivalent). See windows/print_preview_window.h.
    ///
    /// Reload/Print are exposed as window toolbar buttons, not a
    /// right-click menu: WKWebView's macOS context menu isn't reachable
    /// through any public API. WKUIDelegate's context-menu hooks
    /// (`contextMenuConfigurationForElement:`, etc.) are declared
    /// `TARGET_OS_IOS`-only in WebKit's own headers, and overriding
    /// `NSView.menu(for:)` on a WKWebView subclass — the one technique
    /// documented to work elsewhere — verifiably did not take effect here
    /// (confirmed against a real build, not just a stale-binary guess). A
    /// toolbar is plain `NSToolbar`/`AppKit`, with no dependency on
    /// WebKit's internal event routing to work.
    ///
    /// Deliberately not built on the plugin's shared/queued WebView job
    /// machinery (`ConversionQueue`): like the Windows counterpart, this
    /// window needs to stay open and independently interactable regardless
    /// of what the shared queue is doing with other requests — reusing it
    /// would mean the next PDF/image conversion could yank this window's
    /// content out from under the user mid-preview.
    ///
    /// Two independent completion signals, also matching Windows:
    /// `onComplete` fires once the print sheet has been presented (or the
    /// request fails before getting that far) — not once the user closes
    /// the window — matching `showsPrintPanel`'s own fire-and-forget
    /// presentation contract. `onWindowClosed` fires once the window
    /// actually closes, so the plugin can drop its strong reference.
    /// Construct and call `start()`; never reused after either callback
    /// fires with failure/closed.
    final class PrintPreviewWindowMacOS: NSObject, WKNavigationDelegate, NSWindowDelegate, NSToolbarDelegate {

        private let content: String
        private let durationMs: Int64
        private let margins: [String: Double]?
        private let format: [String: Any]?
        private var onComplete: ((Bool, String?) -> Void)?
        var onWindowClosed: (() -> Void)?

        private var window: NSWindow!
        private var webView: WKWebView!
        private var completed = false

        // Guards against attaching a second print sheet to `window` while
        // one is already showing -- AppKit doesn't allow it (the "Print
        // Page…" menu item lets the user re-invoke presentPrint() at any
        // time, not just once on initial load). Reset once the showing
        // sheet is dismissed, via printOperationDidRun below.
        private var isPrintSheetShowing = false

        // Covers window/WebView creation through the print sheet actually
        // being presented — not the user's time spent with the preview
        // window open afterward, which isn't observable (see class comment).
        private let watchdog = RequestWatchdog()

        init(
            content: String, durationMs: Int64, margins: [String: Double]?, format: [String: Any]?,
            onComplete: @escaping (Bool, String?) -> Void
        ) {
            self.content = content
            self.durationMs = durationMs
            self.margins = margins
            self.format = format
            self.onComplete = onComplete
            super.init()
        }

        func start() {
            let frame = NSRect(x: 0, y: 0, width: 900, height: 1100)
            let window = NSWindow(
                contentRect: frame,
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title =
                (Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Print Preview")
                + " — Print Preview"
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window

            let configuration = WKWebViewConfiguration()
            configuration.suppressesIncrementalRendering = false
            configuration.preferences.javaScriptEnabled = true
            let webView = WKWebView(frame: frame, configuration: configuration)
            webView.enableInspectorInDebugBuilds()
            webView.navigationDelegate = self
            window.contentView = webView
            self.webView = webView

            setUpToolbar(on: window)

            // Shown immediately, before content finishes loading — the
            // window is the browser here, so the user watches it load
            // rather than seeing nothing until a print dialog appears.
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            let timeoutMs = max(30_000, durationMs + 30_000)
            watchdog.arm(timeoutMs: timeoutMs) { [weak self] in
                self?.fail("Print preview timed out")
                self?.window.close()
            }

            webView.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Only the *initial* load should trigger the print flow. Once
            // `completed` is true, presentPrint() has already run once;
            // subsequent navigations are user-triggered reloads (see the
            // toolbar's Reload button), which should just re-render the
            // page, not silently pop a second print sheet on top of
            // whatever the user is doing with the first one.
            guard !completed else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(durationMs) / 1000)) {
                [weak self] in
                self?.presentPrint()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Only tear down the window for a failure during the *initial*
            // load. Once the first load already succeeded (`completed` ==
            // true), the window is something the user is actively viewing/
            // printing from -- a later reload failing shouldn't yank it out
            // from under them; the page just stays as it was.
            guard !completed else { return }
            watchdog.disarm()
            fail("WebView failed to load: \(error.localizedDescription)")
            window.close()
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            self.webView(webView, didFail: navigation, withError: error)
        }

        // If the WebView's renderer process crashes, neither didFinish nor
        // didFail fires — without this, the window would sit open,
        // unresponsive, until the watchdog eventually gives up. Same
        // initial-load-only scoping as didFail above.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard !completed else { return }
            watchdog.disarm()
            fail("WebView content process terminated")
            window.close()
        }

        private func presentPrint() {
            // A sheet is already showing -- either the initial auto-print
            // hasn't been dismissed yet, or the user double-triggered
            // "Print Page…". AppKit doesn't allow attaching a second sheet
            // to the same window, so just leave the existing one be.
            guard !isPrintSheetShowing else { return }

            watchdog.disarm()
            guard #available(macOS 11.0, *) else {
                fail("Print preview requires macOS 11.0 or newer")
                window.close()
                return
            }

            let printInfo = Self.buildPrintInfo(margins: margins, format: format)
            let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "WebView"

            let printOperation = webView.printOperation(with: printInfo)
            printOperation.showsPrintPanel = true
            printOperation.showsProgressPanel = true
            printOperation.jobTitle = "\(appName) Print Preview"

            // Presented as a sheet on the preview window — window.print()'s
            // AppKit equivalent — rather than an app-modal dialog with no
            // page visible behind it, matching the Windows popup-window +
            // ShowPrintUI experience. The window is left open afterward
            // (Print or Cancel) for the user to keep viewing/reprinting,
            // same as Windows leaves its popup open after ShowPrintUI;
            // windowWillClose below tears down once they close it themselves.
            isPrintSheetShowing = true
            printOperation.runModal(
                for: window, delegate: self,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)

            // Mirrors ShowPrintUI's fire-and-forget contract: resolve once
            // the print UI has been presented, not once the user finishes
            // with it (runModal itself doesn't block here).
            succeed()
        }

        @objc private func printOperationDidRun(
            _ printOperation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?
        ) {
            isPrintSheetShowing = false
        }

        func windowWillClose(_ notification: Notification) {
            watchdog.disarm()
            fail("Print preview window closed")  // no-op if already succeeded
            webView.navigationDelegate = nil
            window.delegate = nil
            onWindowClosed?()
            onWindowClosed = nil
        }

        private func succeed() {
            guard !completed else { return }
            completed = true
            let callback = onComplete
            onComplete = nil
            callback?(true, nil)
        }

        private func fail(_ message: String) {
            guard !completed else { return }
            completed = true
            let callback = onComplete
            onComplete = nil
            callback?(false, message)
        }

        // Same paper/margin parsing `createWebPrintJobMacOS` used — inches
        // straight to points (`* 72.0`), since `PdfMargins.toMap()` and
        // `PaperFormat` both deal in inches, not the WebView's CSS pixels.
        private static func buildPrintInfo(margins: [String: Double]?, format: [String: Any]?)
            -> NSPrintInfo
        {
            let printInfo = NSPrintInfo()

            let formatName = format?["name"] as? String
            if formatName?.isEmpty == false {
                let paperWidthIn: Double
                let paperHeightIn: Double
                if formatName == "custom" {
                    paperWidthIn = format?["width"] as? Double ?? 1.0
                    paperHeightIn = format?["height"] as? Double ?? 1.0
                } else {
                    let paperFormat = PaperFormat.fromString(formatName!)
                    paperWidthIn = paperFormat.width
                    paperHeightIn = paperFormat.height
                }
                printInfo.paperSize = NSSize(
                    width: CGFloat(paperWidthIn * 72.0), height: CGFloat(paperHeightIn * 72.0))
            }

            if let margins = margins {
                printInfo.topMargin = CGFloat((margins["top"] ?? 0.0) * 72.0)
                printInfo.bottomMargin = CGFloat((margins["bottom"] ?? 0.0) * 72.0)
                printInfo.leftMargin = CGFloat((margins["left"] ?? 0.0) * 72.0)
                printInfo.rightMargin = CGFloat((margins["right"] ?? 0.0) * 72.0)
            }

            return printInfo
        }

        // MARK: - Toolbar (Reload / Print)

        private static let reloadItemID = NSToolbarItem.Identifier("webcontent_converter.reload")
        private static let printItemID = NSToolbarItem.Identifier("webcontent_converter.print")

        private func setUpToolbar(on window: NSWindow) {
            let toolbar = NSToolbar(identifier: "webcontent_converter.printPreviewToolbar")
            toolbar.delegate = self
            toolbar.displayMode = .iconAndLabel
            toolbar.allowsUserCustomization = false
            window.toolbar = toolbar
            if #available(macOS 11.0, *) {
                window.toolbarStyle = .automatic
            }
        }

        func toolbar(
            _ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
            willBeInsertedIntoToolbar flag: Bool
        ) -> NSToolbarItem? {
            switch itemIdentifier {
            case Self.reloadItemID:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.label = "Reload"
                item.paletteLabel = "Reload"
                item.toolTip = "Reload the page"
                if #available(macOS 11.0, *) {
                    item.image = NSImage(
                        systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
                }
                item.target = self
                item.action = #selector(toolbarReload)
                return item
            case Self.printItemID:
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.label = "Print"
                item.paletteLabel = "Print"
                item.toolTip = "Print Page…"
                if #available(macOS 11.0, *) {
                    item.image = NSImage(
                        systemSymbolName: "printer", accessibilityDescription: "Print")
                }
                item.target = self
                item.action = #selector(toolbarPrint)
                return item
            default:
                return nil
            }
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [Self.reloadItemID, .flexibleSpace, Self.printItemID]
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [Self.reloadItemID, Self.printItemID, .flexibleSpace]
        }

        // WKWebView's own built-in Reload (available only via a context
        // menu we can't reach anyway, see class comment) replays the
        // page's last-committed URL, which for content loaded via
        // `loadHTMLString(_:baseURL:)` isn't a real, re-fetchable
        // resource. Re-running the original loadHTMLString call directly
        // sidesteps that entirely.
        @objc private func toolbarReload() {
            webView.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
        }

        @objc private func toolbarPrint() {
            presentPrint()
        }
    }

#endif

//
//  FLWebView.swift
//  webcontent_converter
//
//  Created by whitehat on 17/4/21.
//  Updated by whitehat on 26/4/26
//

#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import Cocoa
#endif
import WebKit

#if os(iOS)
class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    /// add this to recieve args
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
          return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        print("frame \(frame)")
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
    
}
#else
class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    public func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func create(
        withViewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> NSView {
        let _arguments = args as? Dictionary<String, Any>
        let width = _arguments!["width"] as! Double? ?? 1
        let height = _arguments!["height"] as! Double? ?? 1
        let frame = CGRect(x: 0, y: 0, width: width, height: height )
        print("🏭 Factory creating view with frame: \(frame)")
        
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
}

class FLNativeView: NSView {
    private var _arguments : Dictionary<String, Any>?
    private var _webView : WKWebView?
    private var eventMonitor: Any?
    private var mouseMonitor: Any?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _arguments = args as? Dictionary<String, Any>
        
        super.init(frame: frame)
        
        print("🎯 FLNativeView init with frame: \(frame)")
        
        // Essential configuration for Flutter 3.22.3
        self.wantsLayer = true
        self.layer?.isOpaque = false
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Create and configure WebView
        setupWebView()
        
        // Load content
        loadContent()
        
        // ✅ FORCE: Setup global event monitoring with scrollbar support
        setupGlobalEventMonitoring()
        
        print("🎯 Scroll, key navigation and scrollbar support completed")
    }
    
    required init?(coder nsCoder: NSCoder) {
        super.init(coder: nsCoder)
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true
        
        // Enable user interaction
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Create WebView with full bounds
        _webView = WKWebView(frame: self.bounds, configuration: configuration)
        
        guard let webView = _webView else { return }
        
        // ✅ SCROLLBAR: Configure WebView for scrolling with visible scrollbars
        webView.wantsLayer = true
        webView.layer?.isOpaque = true
        webView.autoresizingMask = [.width, .height]
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        
        // ✅ SCROLLBAR: Enable scrollbars (they're enabled by default but let's be explicit)
        if let scrollView = webView.enclosingScrollView {
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = false  // Always show scrollbars
            print("✅ Scrollbars configured")
        }
        
        // Add WebView directly to self
        self.addSubview(webView)
        
        print("✅ WebView created for scrolling with scrollbar support: \(webView.frame)")
    }
    
    private func loadContent() {
        let content = _arguments?["content"] as? String
        let url = _arguments?["url"] as? String
        
        print("📄 Loading content: \(content?.prefix(100) ?? "nil")")
        print("🔗 Loading URL: \(url ?? "nil")")
        
        guard let webView = _webView else { return }
        
        let baseURL = url != nil ? URL(string: url!) : Bundle.main.resourceURL
        
        if let urlString = url, let url = URL(string: urlString) {
            print("🌐 Loading URL: \(urlString)")
            webView.load(URLRequest(url: url))
        } else if let content = content {
            print("📝 Loading HTML content")
            webView.loadHTMLString(content, baseURL: baseURL)
        }
    }
    
    // ✅ ENHANCED: Global event monitoring with scrollbar support
    private func setupGlobalEventMonitoring() {
        // Monitor scroll wheel and key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] event in
            
            guard let strongSelf = self,
                  let window = strongSelf.window else {
                return event
            }
            
            let locationInWindow = event.locationInWindow
            let locationInView = strongSelf.convert(locationInWindow, from: nil)
            
            // Check if event is within our view
            if strongSelf.bounds.contains(locationInView) {
                print("🎯 GLOBAL EVENT CAPTURED in bounds: \(event.type.rawValue)")
                
                if event.type == .scrollWheel {
                    strongSelf.handleScrollEvent(event)
                    return nil  // Consume the event
                } else if event.type == .keyDown {
                    strongSelf.handleKeyEvent(event)
                    return nil  // Consume the event
                }
            }
            
            return event
        }
        
        // ✅ NEW: Monitor mouse events for scrollbar interactions
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            
            guard let strongSelf = self,
                  let window = strongSelf.window,
                  let webView = strongSelf._webView else {
                return event
            }
            
            let locationInWindow = event.locationInWindow
            let locationInView = strongSelf.convert(locationInWindow, from: nil)
            
            // Check if event is within our view
            if strongSelf.bounds.contains(locationInView) {
                // Convert to WebView coordinates
                let locationInWebView = webView.convert(locationInView, from: strongSelf)
                
                // Check if click is in scrollbar area (right edge for vertical, bottom edge for horizontal)
                let isInVerticalScrollbarArea = locationInWebView.x > webView.bounds.width - 20  // 20px from right edge
                let isInHorizontalScrollbarArea = locationInWebView.y < 20  // 20px from bottom
                
                if isInVerticalScrollbarArea || isInHorizontalScrollbarArea {
                    if event.type == .leftMouseDown {
                        print("📜 SCROLLBAR CLICK detected at: \(locationInWebView)")
                    } else if event.type == .leftMouseDragged {
                        print("📜 SCROLLBAR DRAG detected")
                    } else if event.type == .leftMouseUp {
                        print("📜 SCROLLBAR RELEASE detected")
                    }
                    
                    // Forward scrollbar events directly to WebView
                    strongSelf.forwardEventToWebView(event)
                    return nil  // Consume the event
                }
                
                // For other mouse events within WebView, also forward them
                print("🖱️ MOUSE EVENT in WebView: \(event.type.rawValue)")
                strongSelf.forwardEventToWebView(event)
                return nil  // Consume the event
            }
            
            return event
        }
        
        print("✅ Global event monitoring with scrollbar support setup")
    }
    
    // ✅ NEW: Forward mouse events directly to WebView
    private func forwardEventToWebView(_ event: NSEvent) {
        guard let webView = _webView else { return }
        
        switch event.type {
        case .leftMouseDown:
            webView.mouseDown(with: event)
        case .leftMouseDragged:
            webView.mouseDragged(with: event)
        case .leftMouseUp:
            webView.mouseUp(with: event)
        case .rightMouseDown:
            webView.rightMouseDown(with: event)
        case .rightMouseUp:
            webView.rightMouseUp(with: event)
        case .scrollWheel:
            webView.scrollWheel(with: event)
        default:
            break
        }
    }
    
    // ✅ HANDLE: Scroll events from global monitor
    private func handleScrollEvent(_ event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        let deltaX = event.scrollingDeltaX
        
        if abs(deltaY) > 0 || abs(deltaX) > 0 {
            if abs(deltaY) > abs(deltaX) {
                // Vertical scrolling
                if deltaY > 0 {
                    print("🖱️ GLOBAL SCROLL UP: \(deltaY)")
                } else {
                    print("🖱️ GLOBAL SCROLL DOWN: \(abs(deltaY))")
                }
                
                // Use native WebView scrolling for better scrollbar sync
                _webView?.scrollWheel(with: event)
            } else {
                // Horizontal scrolling
                if deltaX > 0 {
                    print("🖱️ GLOBAL SCROLL LEFT: \(deltaX)")
                } else {
                    print("🖱️ GLOBAL SCROLL RIGHT: \(abs(deltaX))")
                }
                
                // Use native WebView scrolling for horizontal
                _webView?.scrollWheel(with: event)
            }
        }
    }
    
    // ✅ HANDLE: Key events from global monitor
    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        
        switch keyCode {
        case 126: // Up arrow key
            print("⬆️ GLOBAL KEY UP: Arrow Up")
            scrollWebViewUp()
            
        case 125: // Down arrow key
            print("⬇️ GLOBAL KEY DOWN: Arrow Down")
            scrollWebViewDown()
            
        case 123: // Left arrow key
            print("⬅️ GLOBAL KEY LEFT: Arrow Left")
            scrollWebViewLeft()
            
        case 124: // Right arrow key
            print("➡️ GLOBAL KEY RIGHT: Arrow Right")
            scrollWebViewRight()
            
        case 116: // Page Up
            print("⬆️ GLOBAL KEY UP: Page Up")
            scrollWebViewPageUp()
            
        case 121: // Page Down
            print("⬇️ GLOBAL KEY DOWN: Page Down")
            scrollWebViewPageDown()
            
        case 115: // Home key
            print("🏠 GLOBAL KEY: Home - Scroll to Top")
            scrollWebViewToTop()
            
        case 119: // End key
            print("🔚 GLOBAL KEY: End - Scroll to Bottom")
            scrollWebViewToBottom()
            
        case 49: // Space bar
            print("⬇️ GLOBAL KEY DOWN: Space - Page Down")
            scrollWebViewPageDown()
            
        default:
            print("⌨️ GLOBAL KEY: \(keyCode) - Ignored")
        }
    }
    
    // MARK: - Scroll and Key Event Handling (Fallback)
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override var canBecomeKeyView: Bool {
        return true
    }
    
    // ✅ FALLBACK: Handle mouse events
    override func mouseDown(with event: NSEvent) {
        print("🖱️ FALLBACK MOUSE DOWN")
        forwardEventToWebView(event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        print("🖱️ FALLBACK MOUSE DRAGGED")
        forwardEventToWebView(event)
    }
    
    override func mouseUp(with event: NSEvent) {
        print("🖱️ FALLBACK MOUSE UP")
        forwardEventToWebView(event)
    }
    
    // ✅ FALLBACK: Handle scroll wheel
    override func scrollWheel(with event: NSEvent) {
        print("🖱️ FALLBACK SCROLL EVENT")
        handleScrollEvent(event)
    }
    
    // ✅ FALLBACK: Handle keys
    override func keyDown(with event: NSEvent) {
        print("⌨️ FALLBACK KEY EVENT: \(event.keyCode)")
        handleKeyEvent(event)
    }
    
    // ✅ SCROLL FUNCTIONS: Enhanced with horizontal scrolling
    private func scrollWebViewUp() {
        let scrollScript = "window.scrollBy(0, -50);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Scroll up error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrollWebViewDown() {
        let scrollScript = "window.scrollBy(0, 50);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Scroll down error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrollWebViewLeft() {
        let scrollScript = "window.scrollBy(-50, 0);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Scroll left error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrollWebViewRight() {
        let scrollScript = "window.scrollBy(50, 0);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Scroll right error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrollWebViewPageUp() {
        let scrollScript = "window.scrollBy(0, -window.innerHeight * 0.8);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Page up error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrollWebViewPageDown() {
        let scrollScript = "window.scrollBy(0, window.innerHeight * 0.8);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Page down error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrollWebViewToTop() {
        let scrollScript = "window.scrollTo(0, 0);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Scroll to top error: \(error.localizedDescription)")
            }
        }
    }
    
    private func scrollWebViewToBottom() {
        let scrollScript = "window.scrollTo(0, document.body.scrollHeight);"
        _webView?.evaluateJavaScript(scrollScript) { (result, error) in
            if let error = error {
                print("❌ Scroll to bottom error: \(error.localizedDescription)")
            }
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        if let window = window {
            print("🏠 FLNativeView moved to window - full interaction monitoring active")
            
            // Try to become first responder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.makeFirstResponder(self)
            }
        }
    }
    
    override func layout() {
        super.layout()
        _webView?.frame = self.bounds
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        
        if hitView == _webView || hitView == self {
            print("🎯 Hit test for interaction at \(point)")
            
            // Force focus when clicked
            DispatchQueue.main.async {
                _ = self.becomeFirstResponder()
                self.window?.makeFirstResponder(self)
            }
            
            return self
        }
        
        return hitView
    }
    
    override func becomeFirstResponder() -> Bool {
        print("🎯 FLNativeView BECAME first responder")
        return super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        print("🎯 FLNativeView RESIGNED first responder")
        return super.resignFirstResponder()
    }
    
    deinit {
        print("🗑️ FLNativeView deinit")
        dispose()
    }
    
    func dispose() {
        // ✅ CLEANUP: Remove all event monitors
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
            print("✅ Global event monitor removed")
        }
        
        if let mouseMonitor = mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
            print("✅ Mouse monitor removed")
        }
        
        _webView?.stopLoading()
        _webView?.removeFromSuperview()
        _webView = nil
        _arguments = nil
    }
}
#endif

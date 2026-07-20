import WebKit

#if os(iOS)
    import Flutter
    import UIKit
#else
    import FlutterMacOS
    import Cocoa
    import PDFKit
#endif

/// Per-job WKNavigationDelegate. Each conversion job gets its own instance
/// rather than sharing one delegate/handler-pair across every job: a job
/// abandoned via watchdog timeout doesn't stop its WKWebView's callbacks
/// from eventually firing, and with a single shared delegate + shared
/// `pendingDidFinishHandler`, a stale job's late callback would invoke
/// whichever *different* job happens to be current by then — the exact
/// "second call's field reassignment corrupts the first call's still-
/// pending completion" race the queue was built to prevent, reintroduced
/// one level down inside a single job's async chain. Retained via
/// `SwiftWebcontentConverterPlugin.activeDelegates` for the job's lifetime
/// since `WKWebView.navigationDelegate` is weak.
private final class JobNavigationDelegate: NSObject, WKNavigationDelegate {
    var onFinish: (() -> Void)?
    var onError: ((Error) -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onError?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onError?(error)
    }

    // If the WebView's renderer process crashes (plausible with very large
    // content), neither didFinish nor didFail fires — without this, the job
    // was only ever recovered by the watchdog, 30+ seconds later.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onError?(
            NSError(
                domain: "WebcontentConverter", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "WebView content process terminated"]))
    }
}

public class SwiftWebcontentConverterPlugin: NSObject, FlutterPlugin {
    let conversionQueue = ConversionQueue(maxQueuedRequests: 32)

    // Strong retention for the currently in-flight job's (WKWebView,
    // JobNavigationDelegate) pair — navigationDelegate is weak, so without
    // this the delegate (and transitively the WKWebView it captures) would
    // be deallocated as soon as the job closure that created them returns.
    // Removed in `finish()`/`dispose(_:)` once the job completes.
    private var activeDelegates: [JobNavigationDelegate] = []

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
            let channel = FlutterMethodChannel(
                name: "webcontent_converter", binaryMessenger: registrar.messenger())
        #else
            let channel = FlutterMethodChannel(
                name: "webcontent_converter", binaryMessenger: registrar.messenger)
        #endif
        let instance = SwiftWebcontentConverterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        #if os(iOS)
            // binding native view to flutter widget (iOS only)
            let viewID = "webview-view-type"
            let factory = FLNativeViewFactory(messenger: registrar.messenger())
            registrar.register(factory, withId: viewID)
        #else
            // binding native view to flutter widget (macOS)
            let viewID = "webview-view-type"
            let factory = FLNativeViewFactory(messenger: registrar.messenger)
            registrar.register(factory, withId: viewID)
        #endif
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method

        // Handled before the arguments force-unwrap below: this call
        // carries no "content" argument, and `arguments!` crashes on nil.
        if method == "isWebviewAvailable" {
            result(NSClassFromString("WKWebView") != nil)
            return
        }

        let arguments = call.arguments as? [String: Any]
        let content = arguments!["content"] as? String
        var duration = arguments!["duration"] as? Double
        if duration == nil { duration = 2000.0 }

        switch method {
        case "contentToImage":
            guard let content = content else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT", message: "Content is required", details: nil))
                return
            }

            if conversionQueue.isQueueFull() {
                result(
                    FlutterError(
                        code: "TOO_MANY_REQUESTS",
                        message: "Too many pending conversion requests",
                        details: nil))
                return
            }

            let format = arguments!["format"] as? [String: Any]
            let margins = arguments!["margins"] as? [String: Double]
            let durationMs = Int64(duration!)

            conversionQueue.startOrQueue { [weak self] in
                guard let self = self else { return }

                var completed = false
                let watchdog = RequestWatchdog()
                let timeoutMs = max(30_000, durationMs + 30_000)

                // All closures throughout the capture flow use `finish` to
                // guard against double-resolution (success, fallback, error,
                // timeout). It disarms the watchdog, fires onRequestFinished
                // BEFORE resolving the Flutter result, and no-ops if already
                // completed.
                func finish(_ action: @escaping () -> Void) {
                    guard !completed else { return }
                    completed = true
                    watchdog.disarm()
                    self.conversionQueue.onRequestFinished()
                    action()
                }

                // --- Create WebView + its own navigation delegate first ---
                // `wv` is captured directly by every closure below instead of
                // going through `self.webView`: that was a single mutable
                // property shared across jobs, so once this job is abandoned
                // (timeout/error) and the *next* job reassigns it, a late-
                // firing continuation of this job would silently start
                // operating on the next job's live WebView instead.
                #if os(iOS)
                    let wv = WKWebView()
                    wv.isHidden = true
                    wv.tag = 100
                #else
                    let frame = CGRect(x: 0, y: 0, width: 800, height: 300)
                    let configuration = WKWebViewConfiguration()
                    configuration.suppressesIncrementalRendering = false
                    configuration.preferences.javaScriptEnabled = true

                    let wv = WKWebView(frame: frame, configuration: configuration)
                    wv.wantsLayer = true
                    wv.viewWithTag(100)

                    if let layer = wv.layer {
                        layer.backgroundColor = NSColor.white.cgColor
                        layer.isOpaque = true
                    }
                #endif

                let jobDelegate = JobNavigationDelegate()
                wv.navigationDelegate = jobDelegate
                self.activeDelegates.append(jobDelegate)

                func teardown() {
                    self.dispose(wv)
                    self.activeDelegates.removeAll { $0 === jobDelegate }
                }

                // --- didFinish handler (replaces KVO on isLoading) ---
                jobDelegate.onFinish = {
                    #if os(iOS)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("scrollView.contentSiz.height = \(wv.scrollView.contentSize.height)")
                            print("scrollView.contentSiz.width = \(wv.scrollView.contentSize.width)")
                            if #available(iOS 11.0, *) {
                                let configuration = WKSnapshotConfiguration()
                                let formatName = format?["name"] as? String
                                if(format != nil && formatName != nil) {
                                    guard let formatName = formatName else {
                                        finish {
                                            result(
                                                FlutterError(
                                                    code: "INVALID_ARGUMENT", message: "Name is invalided", details: nil))
                                        }
                                        return
                                    }
                                    let pageFormat = PaperFormat.fromString(formatName);

                                    print("pageFormat.width = \(pageFormat.width)")
                                    print("pageFormat.height = \(pageFormat.height)")
                                    print("pageFormat.widthPixels = \(pageFormat.widthPixels)")
                                    print("pageFormat.heightPixels = \(pageFormat.heightPixels)")
                                    let pageWidth = CGFloat(pageFormat.widthPixels)
                                    let pageHeight = CGFloat(pageFormat.heightPixels)

                                    // ✅ SEAMLESS CONTENT: Use WebView scrollable content directly
                                    let originalFrame = wv // ✅ CONTINUOUS CONTENT: Remove page breaks entirely
                                    let printFormatter = wv.viewPrintFormatter()
                                    let renderer = UIPrintPageRenderer()

                                    let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
                                    let printableRect = pageRect

                                    renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
                                    renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")
                                    renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

                                    print("📄 Total pages: \(renderer.numberOfPages)")

                                    // ✅ SINGLE CONTINUOUS IMAGE: Create one long continuous image
                                    let renderer_image = UIGraphicsImageRenderer(size: CGSize(width: pageWidth, height: CGFloat(renderer.numberOfPages) * pageHeight))
                                    let fullImage = renderer_image.image { context in
                                        // Fill with white background
                                        UIColor.white.setFill()
                                        context.fill(CGRect(origin: .zero, size: CGSize(width: pageWidth, height: CGFloat(renderer.numberOfPages) * pageHeight)))

                                        // ✅ CONTINUOUS RENDERING: Draw all pages as one continuous flow
                                        for pageIndex in 0..<renderer.numberOfPages {
                                            context.cgContext.saveGState()
                                            context.cgContext.translateBy(x: 0, y: CGFloat(pageIndex) * pageHeight)

                                            // Draw page content
                                            renderer.drawPage(at: pageIndex, in: CGRect(origin: .zero, size: CGSize(width: pageWidth, height: pageHeight)))

                                            context.cgContext.restoreGState()
                                        }
                                    }

                                    // Convert to JPEG and return
                                    if let data = fullImage.jpegData(compressionQuality: 1.0) {
                                        let bytes = FlutterStandardTypedData.init(bytes: data)
                                        finish {
                                            result(bytes)
                                            teardown()
                                        }
                                        print("✅ Continuous content snapshot successful! Image bytes: \(data.count)")
                                        return
                                    }

                                }else{
                                    var size = wv.scrollView.contentSize
                                    print("width = \(size.width)")
                                    print("height = \(size.height)")
                                    configuration.rect = CGRect(origin: .zero, size: size)
                                    wv.snapshotView(afterScreenUpdates: false)
                                }

//
                                wv.takeSnapshot(with: configuration) {
                                    (image, error) in
                                    // Add error handling first
                                    if let error = error {
                                        print(
                                            "❌ iOS Snapshot error: \(error.localizedDescription)"
                                        )
                                        // Try iOS fallback method with better size handling
                                        if let fallbackImage = wv
                                            .snapshotWithContentSize()
                                        {
                                            if let data = fallbackImage.jpegData(
                                                compressionQuality: 1.0)
                                            {
                                                let bytes = FlutterStandardTypedData.init(
                                                    bytes: data)
                                                finish {
                                                    result(bytes)
                                                    teardown()
                                                }
                                                print(
                                                    "✅ iOS fallback snapshot successful! Image bytes: \(data.count)"
                                                )
                                                return
                                            }
                                        }
                                        print("❌ iOS fallback method also failed")
                                        let emptyBytes = FlutterStandardTypedData.init(bytes: Data())
                                        finish {
                                            result(emptyBytes)  // Return empty bytes if all methods fail
                                            teardown()
                                        }
                                        return
                                    }
                                    print("use wv.takeSnapshot")

                                    // Check if image is nil
                                    guard let image = image else {
                                        print("❌ No image returned from iOS snapshot")
                                        // Try fallback method with better size handling
                                        if let fallbackImage = wv
                                            .snapshotWithContentSize()
                                        {
                                            if let data = fallbackImage.jpegData(
                                                compressionQuality: 1.0)
                                            {
                                                let bytes = FlutterStandardTypedData.init(
                                                    bytes: data)
                                                finish {
                                                    result(bytes)
                                                    teardown()
                                                }
                                                print(
                                                    "✅ iOS fallback snapshot successful! Image bytes: \(data.count)"
                                                )
                                                return
                                            }
                                        }
                                        let emptyBytes = FlutterStandardTypedData.init(bytes: Data())
                                        finish {
                                            result(emptyBytes)
                                            teardown()
                                        }
                                        return
                                    }

                                    // Try to convert to JPEG data
                                    guard let data = image.jpegData(compressionQuality: 1)
                                    else {
                                        print("❌ Could not convert iOS image to JPEG data")
                                        // Try fallback method with better size handling
                                        if let fallbackImage = wv
                                            .snapshotWithContentSize()
                                        {
                                            if let fallbackData = fallbackImage.jpegData(
                                                compressionQuality: 1.0)
                                            {
                                                let bytes = FlutterStandardTypedData.init(
                                                    bytes: fallbackData)
                                                finish {
                                                    result(bytes)
                                                    teardown()
                                                }
                                                print(
                                                    "✅ iOS fallback snapshot successful! Image bytes: \(fallbackData.count)"
                                                )
                                                return
                                            }
                                        }
                                        let emptyBytes = FlutterStandardTypedData.init(bytes: Data())
                                        finish {
                                            result(emptyBytes)
                                            teardown()
                                        }
                                        return
                                    }

                                    // Success case
                                    let bytes = FlutterStandardTypedData.init(bytes: data)
                                    finish {
                                        result(bytes)
                                        teardown()
                                    }
                                    print(
                                        "✅ iOS snapshot successful! Image bytes: \(data.count)")
                                }
                            }
                        }
                    #else  // macOS
                        // First, get the actual content size by evaluating JavaScript
                        wv.evaluateJavaScript(
                            "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight)"
                        ) { (height, error) in
                            wv.evaluateJavaScript(
                                "Math.max(document.body.scrollWidth, document.body.offsetWidth)"
                            ) { (width, error) in

                                // 🔧 AUTO HEIGHT & WIDTH - Get actual content dimensions
                                var contentWidth = width as? Double ?? CGFloat(PaperFormat.a4.widthPixels)  // Fallback to A4 width
                                var contentHeight = height as? Double ?? CGFloat(PaperFormat.a4.heightPixels)  // Fallback to A4 height
                                let marginTop = CGFloat(inchToPx(margins?["top"] ?? 0.0))
                                let marginBottom = CGFloat(inchToPx(margins?["bottom"] ?? 0.0))
                                let marginLeft = CGFloat(inchToPx(margins?["left"] ?? 0.0))
                                let marginRight = CGFloat(inchToPx(margins?["right"] ?? 0.0))
                                let formatName = format?["name"] as? String
                                if(format != nil && formatName != nil  && ((formatName?.isEmpty) != nil) ) {
                                  let paperFormat =  PaperFormat.fromString(formatName!);
                                    contentWidth = CGFloat(paperFormat.widthPixels) + marginLeft + marginRight + 300; // 300 DPI = high-quality print resolution
                                }

                                print("📏 WebView frame: \(wv.frame)")

                                // Resize the WebView to match content size for full capture
                                let originalFrame = wv.frame
                                let fullContentFrame = CGRect(
                                    x: 0, y: 0, width: contentWidth, height: contentHeight)
                                wv.frame = fullContentFrame

                                // Wait a moment for the resize to take effect
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    let configuration = WKSnapshotConfiguration()
                                    configuration.rect = CGRect(
                                        origin: .zero, size: fullContentFrame.size)

                                    wv.takeSnapshot(with: configuration) {
                                        (image, error) in
                                        // Restore original frame
                                        wv.frame = originalFrame

                                        if let error = error {
                                            print(
                                                "❌ Snapshot error: \(error.localizedDescription)"
                                            )
                                            // Try fallback method
                                            if let fallbackImage = wv.snapshotMacOS()
                                            {
                                                if let data = fallbackImage.jpegDataMacOS() {
                                                    let bytes = FlutterStandardTypedData(
                                                        bytes: data)
                                                    finish {
                                                        result(bytes)
                                                        teardown()
                                                    }
                                                    return
                                                }
                                            }
                                            let emptyBytes = FlutterStandardTypedData(bytes: Data())
                                            finish {
                                                result(emptyBytes)
                                                teardown()
                                            }
                                            return
                                        }

                                        guard let image = image else {
                                            print("❌ No image returned from snapshot")
                                            let emptyBytes = FlutterStandardTypedData(bytes: Data())
                                            finish {
                                                result(emptyBytes)
                                                teardown()
                                            }
                                            return
                                        }

                                        guard
                                            let cgImage = image.cgImage(
                                                forProposedRect: nil, context: nil, hints: nil)
                                        else {
                                            print("❌ Could not get CGImage from NSImage")
                                            let emptyBytes = FlutterStandardTypedData(bytes: Data())
                                            finish {
                                                result(emptyBytes)
                                                teardown()
                                            }
                                            return
                                        }

                                        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                                        guard
                                            let data = bitmapRep.representation(
                                                using: .jpeg, properties: [:])
                                        else {
                                            print("❌ Could not convert to JPEG data")
                                            let emptyBytes = FlutterStandardTypedData(bytes: Data())
                                            finish {
                                                result(emptyBytes)
                                                teardown()
                                            }
                                            return
                                        }

                                        print(
                                            "✅ Successfully captured full content! Image bytes: \(data.count)"
                                        )
                                        let bytes = FlutterStandardTypedData(bytes: data)
                                        finish {
                                            result(bytes)
                                            teardown()
                                        }
                                    }
                                }
                            }
                        }
                    #endif
                }

                jobDelegate.onError = { error in
                    finish {
                        wv.stopLoading()
                        result(
                            FlutterError(
                                code: "WEBVIEW_LOAD_ERROR",
                                message: "WebView failed to load: \(error.localizedDescription)",
                                details: nil))
                        teardown()
                    }
                }

                // --- Arm watchdog ---
                watchdog.arm(timeoutMs: timeoutMs) {
                    finish {
                        wv.stopLoading()
                        result(
                            FlutterError(
                                code: "TIMEOUT",
                                message: "Conversion timed out after \(timeoutMs)ms",
                                details: nil))
                        teardown()
                    }
                }

                // --- Start loading (delegate is already wired) ---
                wv.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
                #if os(macOS)
                    print("📱 macOS WebView initialized with frame: \(wv.frame)")
                #endif
            }

        case "contentToPDF":
            if conversionQueue.isQueueFull() {
                result(
                    FlutterError(
                        code: "TOO_MANY_REQUESTS",
                        message: "Too many pending conversion requests",
                        details: nil))
                return
            }

            let path = arguments!["savedPath"] as? String
            let format = arguments!["format"] as? [String: Any]
            let margins = arguments!["margins"] as? [String: Double]
            let savedPath = URL.init(string: path!)?.path
            let durationMs = Int64(duration!)

            conversionQueue.startOrQueue { [weak self] in
                guard let self = self else { return }

                var completed = false
                let watchdog = RequestWatchdog()
                let timeoutMs = max(30_000, durationMs + 30_000)

                func finish(_ action: @escaping () -> Void) {
                    guard !completed else { return }
                    completed = true
                    watchdog.disarm()
                    self.conversionQueue.onRequestFinished()
                    action()
                }

                #if os(iOS)
                    guard let content else {
                        finish {
                            result(
                                FlutterError(
                                    code: "INVALID_ARGUMENT", message: "Content is required", details: nil))
                        }
                        return
                    }

                    let wv = WKWebView()
                    wv.isHidden = false
                    wv.tag = 100

                    let jobDelegate = JobNavigationDelegate()
                    wv.navigationDelegate = jobDelegate
                    self.activeDelegates.append(jobDelegate)

                    func teardown() {
                        self.dispose(wv)
                        self.activeDelegates.removeAll { $0 === jobDelegate }
                    }

                    jobDelegate.onFinish = {
                        DispatchQueue.main.asyncAfter(deadline: .now() + (Double(durationMs) / 10000)) {
                            print("height = \(wv.scrollView.contentSize.height)")
                            print("width = \(wv.scrollView.contentSize.width)")
                            if #available(iOS 11.0, *) {
                                let configuration = WKSnapshotConfiguration()
                                let formatName = format?["name"] as? String
                                if(format != nil && formatName != nil  && ((formatName?.isEmpty) != nil) ) {
                                    if formatName == "custom" {
                                        // ✅ CUSTOM: Use width and height from format dictionary
                                        let customWidth = CGFloat(inchToPx(format!["width"] as? Double ?? 1.0))
                                        let customHeight = CGFloat(inchToPx(format!["height"] as? Double ?? 1.0))

                                        print("📐 Using custom format - width: \(customWidth), height: \(customHeight)")

                                        configuration.rect = CGRect(x: 0, y: 0, width: customWidth, height: customHeight)

                                    } else {
                                        // ✅ PREDEFINED: Use standard paper format
                                        let paperFormat = PaperFormat.fromString(formatName!)

                                        print("📄 Using predefined format: \(formatName!) - \(paperFormat.widthPixels) x \(paperFormat.heightPixels)")

                                        configuration.rect = CGRect(x: 0, y: 0, width: CGFloat(paperFormat.widthPixels), height: CGFloat(paperFormat.heightPixels))
                                    }
                                }else{
                                    configuration.rect = CGRect(
                                        x: 0, y: 0, width: CGFloat( inchToPx(format!["width"] as? Double ?? PaperFormat.a4.width) ),
                                        height: CGFloat(inchToPx(format!["height"] as? Double ?? PaperFormat.a4.height) ))
                                }

                                guard
                                    let path = wv.exportAsPdfFromWebView(
                                        savedPath: savedPath!, format: format!, margins: margins!)
                                else {
                                    finish {
                                        result(nil)
                                        teardown()
                                    }
                                    return
                                }
                                finish {
                                    result(path)
                                    teardown()
                                }
                            } else {
                                finish {
                                    result(nil)
                                    teardown()
                                }
                            }
                        }
                    }

                #else
                    // macOS PDF generation implementation
                    guard let content = content else {
                        finish {
                            result(
                                FlutterError(
                                    code: "INVALID_ARGUMENT", message: "Content is required", details: nil))
                        }
                        return
                    }

                    let formatName = format?["name"] as? String

                    // An explicit format request means the output PDF's page
                    // geometry (ultimately CGContext's mediaBox in
                    // mergePdfPageSlices) must be genuine PDF points — 72/inch,
                    // fixed by the PDF spec — not the WebView's CSS-pixel
                    // convention (96/inch). Using 96/inch for the *page* here
                    // made every explicit-format PDF ~1.33x (96/72) larger than
                    // requested — most obvious on a small custom page (e.g.
                    // 1"x1"). Auto-detected sizing (no format given, below) has
                    // no physical-inch contract to honor, so it's left at the
                    // WebView's native CSS-pixel scale, unchanged.
                    let hasExplicitFormat = (formatName?.isEmpty == false)
                    let dpiScale: Double = hasExplicitFormat ? 72.0 : 96.0

                    let marginTop = CGFloat((margins?["top"] ?? 0.0) * dpiScale)
                    let marginBottom = CGFloat((margins?["bottom"] ?? 0.0) * dpiScale)
                    let marginLeft = CGFloat((margins?["left"] ?? 0.0) * dpiScale)
                    let marginRight = CGFloat((margins?["right"] ?? 0.0) * dpiScale)

                    let initialFormatWidthPx: Double?
                    let initialFormatHeightPx: Double?
                    if hasExplicitFormat {
                        if formatName == "custom" {
                            initialFormatWidthPx = (format!["width"] as? Double ?? 1.0) * dpiScale
                            initialFormatHeightPx = (format!["height"] as? Double ?? 1.0) * dpiScale
                        } else {
                            let paperFormat = PaperFormat.fromString(formatName!)
                            initialFormatWidthPx = paperFormat.width * dpiScale
                            initialFormatHeightPx = paperFormat.height * dpiScale
                        }
                    } else {
                        initialFormatWidthPx = nil
                        initialFormatHeightPx = nil
                    }

                    let initialRenderWidth = max(
                        1.0, (initialFormatWidthPx ?? 800.0) - Double(marginLeft) - Double(marginRight))

                    let wv = WKWebView(
                        frame: CGRect(x: 0, y: 0, width: initialRenderWidth, height: 10))
                    wv.isHidden = false
                    wv.viewWithTag(100)

                    let jobDelegate = JobNavigationDelegate()
                    wv.navigationDelegate = jobDelegate
                    self.activeDelegates.append(jobDelegate)

                    func teardown() {
                        self.dispose(wv)
                        self.activeDelegates.removeAll { $0 === jobDelegate }
                    }

                    jobDelegate.onFinish = {
                        print("macOS WebView finished loading")

                        wv.evaluateJavaScript(
                            "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight)"
                        ) { (height, error) in

                            wv.evaluateJavaScript(
                                "Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth)"
                            ) { (width, error) in
                                let contentWidth = width as? Double ?? CGFloat(PaperFormat.a4.widthPixels)
                                let contentHeight = height as? Double ?? CGFloat(PaperFormat.a4.heightPixels)

                                let pageWidthPx: Double
                                let pageHeightPx: Double
                                if let formatWidthPx = initialFormatWidthPx,
                                   let formatHeightPx = initialFormatHeightPx {
                                    pageWidthPx = formatWidthPx
                                    pageHeightPx = formatHeightPx
                                } else {
                                    pageWidthPx = Double(contentWidth) + Double(marginLeft) + Double(marginRight)
                                    pageHeightPx = Double(contentHeight) + Double(marginTop) + Double(marginBottom)
                                }

                                let renderWidth = max(1.0, pageWidthPx - Double(marginLeft) - Double(marginRight))

                                print("📏 WebView frame: \(wv.frame)")
                                print("📏 Page geometry: \(pageWidthPx) x \(pageHeightPx), render width: \(renderWidth)")
                                print("marginTop \(marginTop)")
                                print("marginBottom \(marginBottom)")
                                print("marginLeft \(marginLeft)")
                                print("marginRight \(marginRight)")

                                let originalFrame = wv.frame
                                let fullContentFrame = CGRect(
                                    x: 0, y: 0, width: renderWidth, height: Double(contentHeight))
                                wv.frame = fullContentFrame
                                print("📏 WebView fullContentFrame: \(fullContentFrame)")

                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + (Double(durationMs) / 10000)
                                ) {
                                    guard #available(macOS 11.0, *) else {
                                        finish {
                                            result(nil)
                                            teardown()
                                        }
                                        return
                                    }

                                    let slices = computePdfPageSlices(
                                        contentHeight: Double(contentHeight),
                                        pageHeight: pageHeightPx,
                                        marginTop: Double(marginTop),
                                        marginBottom: Double(marginBottom)
                                    )
                                    print("📄 Total pages: \(slices.count)")

                                    self.capturePdfPageSlicesSequentially(webView: wv, slices: slices, pageWidth: renderWidth) { pageDatas in
                                        wv.frame = originalFrame

                                        guard let pageDatas = pageDatas,
                                              let mergedData = mergePdfPageSlices(
                                                pageDatas: pageDatas,
                                                pageWidth: pageWidthPx,
                                                pageHeight: pageHeightPx,
                                                marginTop: Double(marginTop),
                                                marginLeft: Double(marginLeft)
                                              )
                                        else {
                                            print("❌ PDF page capture or merge failed")
                                            finish {
                                                result(nil)
                                                teardown()
                                            }
                                            return
                                        }

                                        do {
                                            let url = URL(fileURLWithPath: savedPath!)
                                            try mergedData.write(to: url)
                                            print(
                                                "✅ PDF saved successfully to: \(savedPath!) (\(mergedData.count) bytes, \(pageDatas.count) pages)"
                                            )
                                            finish {
                                                result(savedPath!)
                                                teardown()
                                            }
                                        } catch {
                                            print("❌ Failed to save PDF: \(error.localizedDescription)")
                                            finish {
                                                result(nil)
                                                teardown()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                #endif

                jobDelegate.onError = { error in
                    finish {
                        wv.stopLoading()
                        result(
                            FlutterError(
                                code: "WEBVIEW_LOAD_ERROR",
                                message: "WebView failed to load: \(error.localizedDescription)",
                                details: nil))
                        teardown()
                    }
                }

                watchdog.arm(timeoutMs: timeoutMs) {
                    finish {
                        wv.stopLoading()
                        result(
                            FlutterError(
                                code: "TIMEOUT",
                                message: "Conversion timed out after \(timeoutMs)ms",
                                details: nil))
                        teardown()
                    }
                }

                // --- Start loading (delegate is already wired) ---
                wv.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
            }

        case "printPreview":
            if conversionQueue.isQueueFull() {
                result(
                    FlutterError(
                        code: "TOO_MANY_REQUESTS",
                        message: "Too many pending conversion requests",
                        details: nil))
                return
            }

            guard let content = content else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT", message: "Content is required", details: nil))
                return
            }
            let margins = arguments!["margins"] as? [String: Double]
            let format = arguments!["format"] as? [String: Any]
            let durationMs = Int64(duration!)

            conversionQueue.startOrQueue { [weak self] in
                guard let self = self else { return }

                var completed = false
                let watchdog = RequestWatchdog()
                let timeoutMs = max(30_000, durationMs + 30_000)

                func finish(_ action: @escaping () -> Void) {
                    guard !completed else { return }
                    completed = true
                    watchdog.disarm()
                    self.conversionQueue.onRequestFinished()
                    action()
                }

                #if os(iOS)
                    let wv = WKWebView()
                    wv.isHidden = true
                    wv.tag = 100

                    let jobDelegate = JobNavigationDelegate()
                    wv.navigationDelegate = jobDelegate
                    self.activeDelegates.append(jobDelegate)

                    func teardown() {
                        self.dispose(wv)
                        self.activeDelegates.removeAll { $0 === jobDelegate }
                    }

                    jobDelegate.onFinish = {
                        DispatchQueue.main.asyncAfter(deadline: .now() + (Double(durationMs) / 10000)) {
                            print("height = \(wv.scrollView.contentSize.height)")
                            print("width = \(wv.scrollView.contentSize.width)")
                            self.createWebPrintJob(webView: wv)
                            finish {
                                result(nil)
                                teardown()
                            }
                        }
                    }
                #else
                    // macOS: use a reasonable fixed frame for initial page
                    // rendering only; printOperation(with:) uses WebKit's own
                    // print pipeline which sizes content for the paper/margins
                    // described by NSPrintInfo, independent of the on-screen frame.
                    let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
                    let configuration = WKWebViewConfiguration()
                    configuration.suppressesIncrementalRendering = false
                    configuration.preferences.javaScriptEnabled = true

                    let wv = WKWebView(frame: frame, configuration: configuration)
                    wv.wantsLayer = true

                    let jobDelegate = JobNavigationDelegate()
                    wv.navigationDelegate = jobDelegate
                    self.activeDelegates.append(jobDelegate)

                    func teardown() {
                        self.dispose(wv)
                        self.activeDelegates.removeAll { $0 === jobDelegate }
                    }

                    jobDelegate.onFinish = {
                        DispatchQueue.main.asyncAfter(deadline: .now() + (Double(durationMs) / 1000)) {
                            // On macOS, printOperation.run() runs its own nested
                            // event loop and blocks until the user dismisses the print
                            // panel. The watchdog is disarmed BEFORE run() so it
                            // doesn't false-positive TIMEOUT during normal user
                            // interaction with the system print dialog.
                            watchdog.disarm()
                            guard #available(macOS 11.0, *) else {
                                print("❌ Print preview requires macOS 11.0 or newer")
                                finish {
                                    result(nil)
                                    teardown()
                                }
                                return
                            }
                            self.createWebPrintJobMacOS(webView: wv, margins: margins, format: format)
                            // After the dialog closes, free the queue slot.
                            finish {
                                result(nil)
                                teardown()
                            }
                        }
                    }
                #endif

                jobDelegate.onError = { error in
                    finish {
                        wv.stopLoading()
                        result(
                            FlutterError(
                                code: "WEBVIEW_LOAD_ERROR",
                                message: "WebView failed to load: \(error.localizedDescription)",
                                details: nil))
                        teardown()
                    }
                }

                watchdog.arm(timeoutMs: timeoutMs) {
                    finish {
                        wv.stopLoading()
                        result(
                            FlutterError(
                                code: "TIMEOUT",
                                message: "Conversion timed out after \(timeoutMs)ms",
                                details: nil))
                        teardown()
                    }
                }

                // --- Start loading (delegate is already wired) ---
                wv.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
            }

        case "getPlatformVersion":
            #if os(iOS)
                result("iOS " + UIDevice.current.systemVersion)
            #else
                result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
            #endif
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    #if os(iOS)
        private func createWebPrintJob(webView: WKWebView) {

            let printInfo = UIPrintInfo(dictionary: nil)
            let appName = Bundle.main.infoDictionary!["CFBundleName"] as! String
            printInfo.jobName = "\(appName) print preview"
            printInfo.outputType = .general
            let printController = UIPrintInteractionController.shared

            printController.printInfo = printInfo
            let printFormatter = webView.viewPrintFormatter()
            let defaultBestPaper = UIPrintPaper.bestPaper(
                forPageSize: CGSize(width: 595, height: 842), withPapersFrom: [])

            printController.printFormatter = printFormatter
            printController.present(
                animated: true,
                completionHandler: { (data, response, error) in
                    ///Ï
                })
        }
    #endif

    #if os(macOS)
        @available(macOS 11.0, *)
        private func createWebPrintJobMacOS(webView: WKWebView, margins: [String: Double]?, format: [String: Any]?) {
            print("🖨️ Creating macOS print job...")

            // Use a dedicated NSPrintInfo rather than .shared to avoid
            // mutating global state (e.g. default printer, shared margins).
            let printInfo = NSPrintInfo()

            // --- Parse format (inches → points, same pattern as contentToPDF) ---
            let formatName = format?["name"] as? String
            let hasExplicitFormat = (formatName?.isEmpty == false)
            if hasExplicitFormat {
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
                    width: CGFloat(paperWidthIn * 72.0),
                    height: CGFloat(paperHeightIn * 72.0))
            }

            // --- Parse margins (inches → points directly, no /96.0 factor) ---
            // PdfMargins.toMap() always sends inches, so the conversion is simply ×72.
            if let margins = margins {
                printInfo.topMargin = CGFloat((margins["top"] ?? 0.0) * 72.0)
                printInfo.bottomMargin = CGFloat((margins["bottom"] ?? 0.0) * 72.0)
                printInfo.leftMargin = CGFloat((margins["left"] ?? 0.0) * 72.0)
                printInfo.rightMargin = CGFloat((margins["right"] ?? 0.0) * 72.0)
            }

            // --- Leave jobDisposition at its default (spool) so showsPrintPanel
            //     below actually shows the standard system print panel with its
            //     built-in preview — consistent with Windows' ShowPrintUI. ---
            let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "WebView"

            // --- Use WKWebView.printOperation(with:) (macOS 11.0+). This hands
            //     printing off to WebKit's own print pipeline: content is laid
            //     out for the paper size / margins in printInfo, independent of
            //     the WebView's on-screen frame — the same way Safari prints. ---
            let printOperation = webView.printOperation(with: printInfo)
            printOperation.showsPrintPanel = true
            printOperation.showsProgressPanel = true
            printOperation.jobTitle = "\(appName) Print Preview"

            // Run the print operation (blocks in a nested event loop until
            // the user dismisses the panel — watchdog is already disarmed).
            printOperation.run()
        }
    #endif

    #if os(macOS)
        @available(macOS 11.0, *)
        private func capturePdfPageSlicesSequentially(
            webView: WKWebView,
            slices: [PdfPageSlice],
            pageWidth: Double,
            index: Int = 0,
            collected: [Data] = [],
            completion: @escaping ([Data]?) -> Void
        ) {
            guard index < slices.count else {
                completion(collected)
                return
            }

            let slice = slices[index]
            let configuration = WKPDFConfiguration()
            configuration.rect = CGRect(
                x: 0, y: slice.sourceY, width: pageWidth, height: slice.sourceHeight)

            webView.createPDF(configuration: configuration) { pdfResult in
                switch pdfResult {
                case .success(let data):
                    self.capturePdfPageSlicesSequentially(
                        webView: webView,
                        slices: slices,
                        pageWidth: pageWidth,
                        index: index + 1,
                        collected: collected + [data],
                        completion: completion
                    )
                case .failure(let error):
                    print("❌ PDF page \(index) creation failed: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    #endif

    // Operates on the specific `webView` passed in — never a shared class
    // property — so disposing one job's WebView can never tear down a
    // *different*, currently in-flight job's WebView that happens to be
    // referenced by a stale/shared field at the moment this runs.
    func dispose(_ webView: WKWebView) {
        #if os(iOS)
            if let viewWithTag = webView.viewWithTag(100) {
                viewWithTag.removeFromSuperview()  // remove hidden webview when pdf is generated
            }
        #else
            // On macOS, just remove the webView from its parent if it has one
            webView.removeFromSuperview()
        #endif

        // clear WKWebView cache (available on both platforms)
        if #available(iOS 9.0, macOS 10.11, *) {
            WKWebsiteDataStore.default().fetchDataRecords(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()
            ) { records in
                records.forEach { record in
                    WKWebsiteDataStore.default().removeData(
                        ofTypes: record.dataTypes, for: [record], completionHandler: {})
                }
            }
        }
    }

    func getPath() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docDirectoryPath = paths[0]
        let pdfPath = docDirectoryPath.appendingPathComponent("invoice.pdf")
        print("pdfPath.absoluteString \(pdfPath.absoluteString)")
        return pdfPath.path
    }
}

// WKWebView extension for export web html content into pdf
// iOS-specific WKWebView extension for export web html content into pdf
#if os(iOS)
    extension WKWebView {

        func snapshot() -> UIImage? {
            // Get the actual content size instead of bounds
            let contentSize = self.scrollView.contentSize

            // Validate size - ensure we have reasonable dimensions
            let finalSize: CGSize
            if contentSize.width <= 0 || contentSize.height <= 0 {
                print("⚠️ Invalid content size (\(contentSize)), using fallback size")
                finalSize = CGSize(width: 800, height: 600)  // Fallback size
            } else {
                finalSize = contentSize
            }

            print("📏 Creating iOS snapshot with size: \(finalSize)")

            // Use modern UIGraphicsImageRenderer (iOS 10+)
            if #available(iOS 10.0, *) {
                let renderer = UIGraphicsImageRenderer(size: finalSize)
                let image = renderer.image { context in
                    // Fill with white background
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: finalSize))

                    // Draw the WebView content
                    let cgContext = context.cgContext
                    cgContext.saveGState()

                    // If using content size, we need to scale appropriately
                    if finalSize != self.bounds.size {
                        let scaleX = finalSize.width / self.bounds.size.width
                        let scaleY = finalSize.height / self.bounds.size.height
                        cgContext.scaleBy(x: scaleX, y: scaleY)
                    }

                    // Draw the WebView layer
                    self.layer.render(in: cgContext)
                    cgContext.restoreGState()
                }
                return image
            } else {
                // Fallback for iOS < 10.0 (though this shouldn't happen with modern iOS)
                UIGraphicsBeginImageContextWithOptions(finalSize, true, 0)
                defer { UIGraphicsEndImageContext() }

                guard let context = UIGraphicsGetCurrentContext() else {
                    print("❌ Could not get graphics context")
                    return nil
                }

                // Fill with white background
                context.setFillColor(UIColor.white.cgColor)
                context.fill(CGRect(origin: .zero, size: finalSize))

                // Draw the WebView
                if finalSize != self.bounds.size {
                    let scaleX = finalSize.width / self.bounds.size.width
                    let scaleY = finalSize.height / self.bounds.size.height
                    context.scaleBy(x: scaleX, y: scaleY)
                }

                self.layer.render(in: context)
                return UIGraphicsGetImageFromCurrentImageContext()
            }
        }

        // Add a better snapshot method that ensures WebView is properly sized
        func snapshotWithContentSize() -> UIImage? {
            let originalFrame = self.frame
            let contentSize = self.scrollView.contentSize

            // Ensure WebView has proper size
            if contentSize.width > 0 && contentSize.height > 0 {
                self.frame = CGRect(origin: .zero, size: contentSize)
                self.layoutIfNeeded()
            }

            // Take snapshot
            let image = self.snapshot()

            // Restore original frame
            self.frame = originalFrame

            return image
        }

        // Call this function when WKWebView finish loading
        func exportAsPdfFromWebView(
            savedPath: String, format: [String: Any], margins: [String: Double]
        ) -> String? {
            
            let formatter = self.viewPrintFormatter()
            // paperRect/printableRect below (and UIGraphicsBeginPDFContextToData,
            // which generatePdfData() calls under the hood) are always in genuine
            // PDF points — 72/inch, fixed by the PDF spec — never the WebView's
            // CSS-pixel convention (96/inch, correct for on-screen content sizing
            // but not for the physical page). Using inchToPx (96/inch) here made
            // every generated PDF ~1.33x (96/72) larger than requested — most
            // obvious on a small custom page (e.g. 1"x1").
            let marginTop = CGFloat(inchToPt(margins["top"] ?? 0))
            let marginBottom = CGFloat(inchToPt(margins["bottom"] ?? 0))
            let marginLeft = CGFloat(inchToPt(margins["left"] ?? 0))
            let marginRight = CGFloat(inchToPt(margins["right"] ?? 0))
            let widthInPixel = CGFloat(inchToPt(format["width"] as? Double ?? PaperFormat.a4.width))
            let heightInPixel = CGFloat(inchToPt(format["height"] as? Double ?? PaperFormat.a4.height))
            print("marginTop \(marginTop)")
            print("marginBottom \(marginBottom)")
            print("marginLeft \(marginLeft)")
            print("marginRight \(marginRight)")
            print("widthInPixel \(widthInPixel)")
            print("heightInPixel \(heightInPixel)")
            formatter.perPageContentInsets = UIEdgeInsets(top: marginTop, left: marginLeft, bottom: marginBottom, right: marginRight)
            var page = CGRect(x: 0, y: 0, width: widthInPixel, height: heightInPixel)
            let formatName = format["name"] as? String
            if(formatName != nil  && ((formatName?.isEmpty) != nil) ) {
                if formatName == "custom" {
                    page = CGRect(x: 0, y: 0, width: widthInPixel,height: heightInPixel)
                }else{
                    let paperFormat =  PaperFormat.fromString(formatName!);
                    page = CGRect(x: 0, y: 0, width: CGFloat(inchToPt(paperFormat.width)),height: CGFloat(inchToPt(paperFormat.height)))
                }

            }
            
            let printable = page.insetBy(dx: 0, dy: 0)
            let render = UIPrintPageRenderer()
            render.addPrintFormatter(formatter, startingAtPageAt: 0)
            render.setValue(NSValue(cgRect: page), forKey: "paperRect")
            render.setValue(NSValue(cgRect: printable), forKey: "printableRect")
            let pdfData = render.generatePdfData()
            let path = self.saveWebViewPdf(data: pdfData, savedPath: savedPath)
            return path
        }

        // Save pdf file in file document directory
        func saveWebViewPdf(data: NSMutableData, savedPath: String) -> String? {
            let url = URL.init(string: savedPath)!
            if data.write(toFile: savedPath, atomically: true) {
                return url.path
            } else {
                return nil
            }
        }
    }

    // render format
    extension UIPrintPageRenderer {

        func generatePdfData() -> NSMutableData {
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, self.paperRect, nil)
            self.prepare(forDrawingPages: NSMakeRange(0, self.numberOfPages))
            let printRect = UIGraphicsGetPDFContextBounds()
            for pdfPage in 0..<self.numberOfPages {
                UIGraphicsBeginPDFPage()
                self.drawPage(at: pdfPage, in: printRect)
            }
            UIGraphicsEndPDFContext()
            return pdfData
        }
    }
#endif

// used convert current inches value into real CGFloat
extension CGFloat {
    func toPixel() -> CGFloat {
        if self > 0 {
            return self * 96
        }
        return 0
    }
}

// macOS-specific extensions for WKWebView
#if os(macOS)
    extension WKWebView {

        // 🔍 CSS-ONLY TEXT ZOOM METHOD
        func setTextZoom(zoom: Double, completion: @escaping () -> Void) {
            print("🔍 Setting CSS-only text zoom to \(zoom * 100)%")
            if zoom != 1.0 {
                let cssTextZoom = """
                    // Apply zoom to all text elements including tables
                    document.body.style.fontSize = '\(zoom)em';
                    
                    // Specifically target table elements
                    var allElements = document.querySelectorAll('*');
                    allElements.forEach(function(element) {
                        var tagName = element.tagName.toLowerCase();
                        
                        // List of elements that should have text scaling
                        var textElements = ['p', 'div', 'span', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 
                                          'li', 'td', 'th', 'tr', 'table', 'thead', 'tbody', 'tfoot',
                                          'label', 'a', 'button', 'input', 'textarea', 'pre', 'code', 
                                          'blockquote', 'em', 'strong', 'b', 'i', 'u', 'small', 
                                          'mark', 'del', 'ins', 'sub', 'sup'];
                        
                        if (textElements.includes(tagName)) {
                            // Get current font size
                            var currentStyle = window.getComputedStyle(element);
                            var currentFontSize = parseFloat(currentStyle.fontSize);
                            
                            if (!isNaN(currentFontSize) && currentFontSize > 0) {
                                // Apply zoom
                                element.style.setProperty('font-size', (currentFontSize * \(zoom)) + 'px', 'important');
                            }
                        }
                    });
                    
                    console.log('Table-focused text zoom applied: \(zoom * 100)%');
                """

                self.evaluateJavaScript(cssTextZoom) { (result, error) in
                    if let error = error {
                        print("❌ CSS text zoom error: \(error.localizedDescription)")
                    } else {
                        print("✅ CSS-only text zoom applied successfully")
                    }

                    // Force layout update
                    self.needsLayout = true
                    self.layoutSubtreeIfNeeded()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        completion()
                    }
                }
            } else {
                completion()
            }
        }

        // Save pdf file in file document directory
        func saveWebViewPdf(data: NSMutableData, savedPath: String) -> String? {
            let url = URL.init(string: savedPath)!
            if data.write(toFile: savedPath, atomically: true) {
                return url.path
            } else {
                return nil
            }
        }

        func snapshotMacOS() -> NSImage? {
            print("🎯 Starting macOS snapshot process...")

            // Get the actual content size first
            var contentHeight: CGFloat = self.frame.height
            var contentWidth: CGFloat = self.frame.width

            // Try to get content size via JavaScript synchronously
            let semaphore = DispatchSemaphore(value: 0)
            self.evaluateJavaScript(
                "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight)"
            ) { (height, error) in
                if let height = height as? Double {
                    contentHeight = CGFloat(height)
                }
                semaphore.signal()
            }
            semaphore.wait()

            let semaphore2 = DispatchSemaphore(value: 0)
            self.evaluateJavaScript(
                "Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth)"
            ) { (width, error) in
                if let width = width as? Double {
                    contentWidth = CGFloat(width)
                }
                semaphore2.signal()
            }
            semaphore2.wait()

            print("📏 Full content size: \(contentWidth) x \(contentHeight)")

            // Store original frame
            let originalFrame = self.frame

            // Temporarily resize to content size
            self.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)

            // Ensure the view is properly laid out
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()

            // Force display
            self.display()

            // Create image with content size
            let imageSize = CGSize(width: contentWidth, height: contentHeight)
            let image = NSImage(size: imageSize)

            image.lockFocus()

            // Fill with white background
            NSColor.white.setFill()
            CGRect(origin: .zero, size: imageSize).fill()

            // Draw the content
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()

                // Handle coordinate system
                context.translateBy(x: 0, y: imageSize.height)
                context.scaleBy(x: 1, y: -1)

                // Draw the layer
                if let layer = self.layer {
                    layer.render(in: context)
                }

                context.restoreGState()
            }

            image.unlockFocus()

            // Restore original frame
            self.frame = originalFrame

            print("📸 Generated full content NSImage with size: \(image.size)")
            return image
        }
    }

    extension NSImage {
        func jpegDataMacOS() -> Data? {
            guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return nil
            }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            return bitmapRep.representation(using: .jpeg, properties: [:])
        }
    }
#endif
import WebKit

#if os(iOS)
    import Flutter
    import UIKit
#else
    import FlutterMacOS
    import Cocoa
    import PDFKit
#endif

public class SwiftWebcontentConverterPlugin: NSObject, FlutterPlugin {
    var webView: WKWebView!
    var urlObservation: NSKeyValueObservation?
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

            #if os(iOS)
                self.webView = WKWebView()
                self.webView.isHidden = true
                self.webView.tag = 100
                self.webView.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
            #else
                // For macOS, create a properly sized WebView to prevent GPU crashes
                let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
                let configuration = WKWebViewConfiguration()
                configuration.suppressesIncrementalRendering = false
                configuration.preferences.javaScriptEnabled = true

                self.webView = WKWebView(frame: frame, configuration: configuration)
                self.webView.wantsLayer = true
                self.webView.viewWithTag(100)

                if let layer = self.webView.layer {
                    layer.backgroundColor = NSColor.white.cgColor
                    layer.isOpaque = true
                }

                self.webView.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
                print("📱 macOS WebView initialized with frame: \(self.webView.frame)")
            #endif

            var bytes = FlutterStandardTypedData.init(bytes: Data())
            urlObservation = webView.observe(
                \.isLoading,
                changeHandler: { (webView, change) in
                    if !webView.isLoading {
                        #if os(iOS)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                print("height = \(self.webView.scrollView.contentSize.height)")
                                print("width = \(self.webView.scrollView.contentSize.width)")
                                if #available(iOS 11.0, *) {
                                    let configuration = WKSnapshotConfiguration()
                                    var size = self.webView.scrollView.contentSize
                                    print("height = \(size.height)")
                                    configuration.rect = CGRect(origin: .zero, size: size)
                                    self.webView.snapshotView(afterScreenUpdates: false)
                                    self.webView.takeSnapshot(with: configuration) {
                                        (image, error) in
                                        // Add error handling first
                                        if let error = error {
                                            print(
                                                "❌ iOS Snapshot error: \(error.localizedDescription)"
                                            )
                                            // Try iOS fallback method with better size handling
                                            if let fallbackImage = self.webView
                                                .snapshotWithContentSize()
                                            {
                                                if let data = fallbackImage.jpegData(
                                                    compressionQuality: 1.0)
                                                {
                                                    bytes = FlutterStandardTypedData.init(
                                                        bytes: data)
                                                    result(bytes)
                                                    self.dispose()
                                                    print(
                                                        "✅ iOS fallback snapshot successful! Image bytes: \(data.count)"
                                                    )
                                                    return
                                                }
                                            }
                                            print("❌ iOS fallback method also failed")
                                            result(bytes)  // Return empty bytes if all methods fail
                                            self.dispose()
                                            return
                                        }

                                        // Check if image is nil
                                        guard let image = image else {
                                            print("❌ No image returned from iOS snapshot")
                                            // Try fallback method with better size handling
                                            if let fallbackImage = self.webView
                                                .snapshotWithContentSize()
                                            {
                                                if let data = fallbackImage.jpegData(
                                                    compressionQuality: 1.0)
                                                {
                                                    bytes = FlutterStandardTypedData.init(
                                                        bytes: data)
                                                    result(bytes)
                                                    self.dispose()
                                                    print(
                                                        "✅ iOS fallback snapshot successful! Image bytes: \(data.count)"
                                                    )
                                                    return
                                                }
                                            }
                                            result(bytes)
                                            self.dispose()
                                            return
                                        }

                                        // Try to convert to JPEG data
                                        guard let data = image.jpegData(compressionQuality: 1)
                                        else {
                                            print("❌ Could not convert iOS image to JPEG data")
                                            // Try fallback method with better size handling
                                            if let fallbackImage = self.webView
                                                .snapshotWithContentSize()
                                            {
                                                if let fallbackData = fallbackImage.jpegData(
                                                    compressionQuality: 1.0)
                                                {
                                                    bytes = FlutterStandardTypedData.init(
                                                        bytes: fallbackData)
                                                    result(bytes)
                                                    self.dispose()
                                                    print(
                                                        "✅ iOS fallback snapshot successful! Image bytes: \(fallbackData.count)"
                                                    )
                                                    return
                                                }
                                            }
                                            result(bytes)
                                            self.dispose()
                                            return
                                        }

                                        // Success case
                                        bytes = FlutterStandardTypedData.init(bytes: data)
                                        result(bytes)
                                        self.dispose()
                                        print(
                                            "✅ iOS snapshot successful! Image bytes: \(data.count)")
                                    }
                                }
                            }
                        #else  // macOS

                            // First, get the actual content size by evaluating JavaScript
                            self.webView.evaluateJavaScript(
                                "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight)"
                            ) { (height, error) in
                                //                            self.webView.evaluateJavaScript("document.body.scrollWidth") { (result, error) in
                                //                                print("scrollWidth = \(result)")
                                //                            }
                                //                            self.webView.evaluateJavaScript("document.body.offsetWidth") { (result, error) in
                                //                                print("offsetWidth = \(result)")
                                //                            }
                                //                            self.webView.evaluateJavaScript("document.documentElement.clientWidth") { (result, error) in
                                //                                print("clientWidth = \(result)")
                                //                            }
                                //                            self.webView.evaluateJavaScript("document.documentElement.scrollWidth") { (result, error) in
                                //                                print("scrollWidth = \(result)")
                                //                            }
                                //                            self.webView.evaluateJavaScript("document.documentElement.offsetWidth") { (result, error) in
                                //                                print("offsetWidth = \(result)")
                                //                            }
                                self.webView.evaluateJavaScript(
                                    "Math.max(document.body.scrollWidth, document.body.offsetWidth)"
                                ) { (width, error) in

                                    let contentHeight = height as? Double ?? 600.0
                                    let contentWidth = width as? Double ?? 800.0
                                    print("height = \(contentHeight)")
                                    print("width = \(width) \(contentWidth)")

                                    print("📏 WebView frame: \(self.webView.frame)")

                                    // Resize the WebView to match content size for full capture
                                    let originalFrame = self.webView.frame
                                    let fullContentFrame = CGRect(
                                        x: 0, y: 0, width: contentWidth, height: contentHeight)
                                    self.webView.frame = fullContentFrame

                                    // Wait a moment for the resize to take effect
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        let configuration = WKSnapshotConfiguration()
                                        configuration.rect = CGRect(
                                            origin: .zero, size: fullContentFrame.size)

                                        self.webView.takeSnapshot(with: configuration) {
                                            (image, error) in
                                            // Restore original frame
                                            self.webView.frame = originalFrame

                                            if let error = error {
                                                print(
                                                    "❌ Snapshot error: \(error.localizedDescription)"
                                                )
                                                // Try fallback method
                                                if let fallbackImage = self.webView.snapshotMacOS()
                                                {
                                                    if let data = fallbackImage.jpegDataMacOS() {
                                                        bytes = FlutterStandardTypedData(
                                                            bytes: data)
                                                        result(bytes)
                                                        self.dispose()
                                                        return
                                                    }
                                                }
                                                result(bytes)
                                                self.dispose()
                                                return
                                            }

                                            guard let image = image else {
                                                print("❌ No image returned from snapshot")
                                                result(bytes)
                                                self.dispose()
                                                return
                                            }

                                            guard
                                                let cgImage = image.cgImage(
                                                    forProposedRect: nil, context: nil, hints: nil)
                                            else {
                                                print("❌ Could not get CGImage from NSImage")
                                                result(bytes)
                                                self.dispose()
                                                return
                                            }

                                            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                                            guard
                                                let data = bitmapRep.representation(
                                                    using: .jpeg, properties: [:])
                                            else {
                                                print("❌ Could not convert to JPEG data")
                                                result(bytes)
                                                self.dispose()
                                                return
                                            }

                                            print(
                                                "✅ Successfully captured full content! Image bytes: \(data.count)"
                                            )
                                            bytes = FlutterStandardTypedData(bytes: data)
                                            result(bytes)
                                            self.dispose()
                                        }
                                    }
                                }
                            }

                        #endif
                    }
                })

            break
        case "contentToPDF":
            #if os(iOS)
                let path = arguments!["savedPath"] as? String
                let savedPath = URL.init(string: path!)?.path
                let format = arguments!["format"] as? [String: Double]
                let margins = arguments!["margins"] as? [String: Double]
                self.webView = WKWebView()
                self.webView.isHidden = false
                self.webView.tag = 100
                self.webView.loadHTMLString(content!, baseURL: Bundle.main.resourceURL)  // load html into hidden webview
                urlObservation = webView.observe(
                    \.isLoading,
                    changeHandler: { (webView, change) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + (duration! / 10000)) {
                            print("height = \(self.webView.scrollView.contentSize.height)")
                            print("width = \(self.webView.scrollView.contentSize.width)")
                            if #available(iOS 11.0, *) {
                                let configuration = WKSnapshotConfiguration()
                                configuration.rect = CGRect(
                                    x: 0, y: 0, width: CGFloat(format!["width"] ?? 8.27).toPixel(),
                                    height: CGFloat(format!["height"] ?? 11.27).toPixel())
                                guard
                                    let path = self.webView.exportAsPdfFromWebView(
                                        savedPath: savedPath!, format: format!, margins: margins!)
                                else {
                                    result(nil)
                                    return
                                }
                                result(path)
                            } else {
                                result(nil)
                            }
                            //dispose
                            self.dispose()
                        }
                    })
            #else
                // macOS PDF generation implementation
                let path = arguments!["savedPath"] as? String
                let savedPath = URL.init(string: path!)?.path
                let format = arguments!["format"] as? [String: Double]
                let margins = arguments!["margins"] as? [String: Double]

                guard let content = content else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "Content is required", details: nil))
                    return
                }

                self.webView = WKWebView()
                self.webView.isHidden = false
                self.webView.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
                self.webView.viewWithTag(100)

                urlObservation = webView.observe(
                    \.isLoading,
                    changeHandler: { (webView, change) in
                        print("macOS WebView finished loading")

                        // First, get the actual content size by evaluating JavaScript
                        self.webView.evaluateJavaScript(
                            "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight)"
                        ) { (height, error) in

                            self.webView.evaluateJavaScript(
                                "Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth)"
                            ) { (width, error) in

                                // 🔧 AUTO HEIGHT & WIDTH - Get actual content dimensions
                                var contentHeight = height as? Double ?? 842.0  // Fallback to A4 height
                                var contentWidth = width as? Double ?? 595.0  // Fallback to A4 width
                                contentWidth = contentWidth * 1
                                print("📏 WebView frame: \(self.webView.frame)")

                                // Resize the WebView to match content size for full capture
                                let originalFrame = self.webView.frame
                                let fullContentFrame = CGRect(
                                    x: 0, y: 0, width: contentWidth, height: contentHeight)

                                self.webView.frame = fullContentFrame
                                print("📏 WebView fullContentFrame: \(fullContentFrame)")
                                self.webView.setTextZoom(zoom: 0.92) {
                                    DispatchQueue.main.asyncAfter(
                                        deadline: .now() + (duration! / 10000)
                                    ) {
                                        if #available(macOS 11.0, *) {
                                            let configuration = WKPDFConfiguration()
                                            configuration.rect = CGRect(
                                                origin: .zero, size: fullContentFrame.size)

                                            self.webView.createPDF(configuration: configuration) {
                                                (pdfResult) in
                                                switch pdfResult {
                                                case .success(let data):
                                                    // Save PDF data to the specified path
                                                    do {
                                                        let url = URL(fileURLWithPath: savedPath!)
                                                        try data.write(to: url)
                                                        print(
                                                            "✅ PDF saved successfully to: \(savedPath!) (\(data.count) bytes)"
                                                        )
                                                        result(savedPath!)  // Return the saved path
                                                    } catch {
                                                        print(
                                                            "❌ Failed to save PDF: \(error.localizedDescription)"
                                                        )
                                                        result(nil)
                                                    }
                                                    self.dispose()
                                                case .failure(let error):
                                                    print(
                                                        "❌ PDF creation failed: \(error.localizedDescription)"
                                                    )
                                                    result(nil)
                                                    self.dispose()
                                                }
                                            }
                                        } else {
                                            result(nil)
                                        }
                                    }
                                }
                            }
                        }
                    })

            #endif
            break

        case "printPreview":
            #if os(iOS)
                let url = arguments!["url"] as? String?
                let margins = arguments!["margins"] as? [String: Double]
                let baseURL = url != nil ? URL(string: url!!) : Bundle.main.resourceURL
                self.webView = WKWebView()
                self.webView.isHidden = true
                self.webView.tag = 100
                self.webView.loadHTMLString(content!, baseURL: baseURL)  // load html into hidden webview
                urlObservation = webView.observe(
                    \.isLoading,
                    changeHandler: { (webView, change) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + (duration! / 10000)) {
                            print("height = \(self.webView.scrollView.contentSize.height)")
                            print("width = \(self.webView.scrollView.contentSize.width)")
                            self.createWebPrintJob(webView: webView)
                            result(nil)
                            //dispose
                            self.dispose()
                        }
                    })
            #else
                // macOS print preview implementation
                let url = arguments!["url"] as? String?
                let margins = arguments!["margins"] as? [String: Double]
                let baseURL = url != nil ? URL(string: url!!) : Bundle.main.resourceURL

                // Create WebView for print preview
                let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
                let configuration = WKWebViewConfiguration()
                configuration.suppressesIncrementalRendering = false
                configuration.preferences.javaScriptEnabled = true

                self.webView = WKWebView(frame: frame, configuration: configuration)
                self.webView.wantsLayer = true

                self.webView.loadHTMLString(content!, baseURL: baseURL)

                urlObservation = webView.observe(
                    \.isLoading,
                    changeHandler: { (webView, change) in
                        if !webView.isLoading {
                            DispatchQueue.main.asyncAfter(deadline: .now() + (duration! / 1000)) {
                                self.createWebPrintJobMacOS(webView: webView, margins: margins)
                                result(nil)
                                self.dispose()
                            }
                        }
                    })
            #endif
            break
        default:
            #if os(iOS)
                result("iOS " + UIDevice.current.systemVersion)
            #else
                result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
            #endif
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
        private func createWebPrintJobMacOS(webView: WKWebView, margins: [String: Double]?) {
            print("🖨️ Creating macOS print job...")

            let printInfo = NSPrintInfo.shared

            // Set up print info
            let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "WebView"
            printInfo.jobDisposition = .preview  // This shows the print preview

            // Set margins if provided
            if let margins = margins {
                printInfo.leftMargin = CGFloat(margins["left"] ?? 0.0) * 72.0 / 96.0
                printInfo.rightMargin = CGFloat(margins["right"] ?? 0.0) * 72.0 / 96.0
                printInfo.topMargin = CGFloat(margins["top"] ?? 0.0) * 72.0 / 96.0
                printInfo.bottomMargin = CGFloat(margins["bottom"] ?? 0.0) * 72.0 / 96.0
            }

            // Create print operation
            let printOperation = NSPrintOperation(view: webView, printInfo: printInfo)
            printOperation.showsPrintPanel = true  // Show print dialog
            printOperation.showsProgressPanel = true
            printOperation.jobTitle = "\(appName) Print Preview"

            // Run the print operation
            printOperation.run()
        }
    #endif

    func dispose() {
        //dispose
        #if os(iOS)
            if let viewWithTag = self.webView.viewWithTag(100) {
                viewWithTag.removeFromSuperview()  // remove hidden webview when pdf is generated
            }
        #else
            // On macOS, just remove the webView from its parent if it has one
            self.webView.removeFromSuperview()
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
        self.webView = nil
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
            savedPath: String, format: [String: Double], margins: [String: Double]
        ) -> String? {
            let formatter = self.viewPrintFormatter()
            formatter.perPageContentInsets = UIEdgeInsets(
                top: CGFloat(margins["top"] ?? 0).toPixel(),
                left: CGFloat(margins["left"] ?? 0).toPixel(),
                bottom: CGFloat(margins["bottom"] ?? 0).toPixel(),
                right: CGFloat(margins["right"] ?? 0).toPixel())
            let page = CGRect(
                x: 0, y: 0, width: CGFloat(format["width"] ?? 8.27).toPixel(),
                height: CGFloat(format["height"] ?? 11.27).toPixel())
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

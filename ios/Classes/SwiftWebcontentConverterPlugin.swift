import Flutter
import UIKit
import WebKit

public class SwiftWebcontentConverterPlugin: NSObject, FlutterPlugin {
    var webView : WKWebView!
    var urlObservation: NSKeyValueObservation?
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "webcontent_converter", binaryMessenger: registrar.messenger())
        let instance = SwiftWebcontentConverterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // binding native view to flutter widget
        let viewID = "webview-view-type"
        let factory = FLNativeViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: viewID)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let method = call.method
        let arguments = call.arguments as? [String: Any]
        let content = arguments!["content"] as? String
        var duration = arguments!["duration"] as? Double
        if(duration==nil){ duration = 2000.0}
        switch method {
        case "contentToImage":
            self.webView = WKWebView()
            self.webView.isHidden = true
            self.webView.tag = 100
            self.webView.loadHTMLString(content!, baseURL: Bundle.main.resourceURL)// load html into hidden webview
            var bytes = FlutterStandardTypedData.init(bytes: Data() )
            urlObservation = webView.observe(\.isLoading, changeHandler: { (webView, change) in
                DispatchQueue.main.asyncAfter(deadline: .now() + (duration!/10000) ) {
                    let configuration = WKSnapshotConfiguration()
                    var size = self.webView.scrollView.contentSize
                    size.height = size.height + 50
                    print("height = \(size.height)")
                    configuration.rect = CGRect(origin: .zero, size: size)
                    self.webView.snapshotView(afterScreenUpdates: true)
                    self.webView.takeSnapshot(with: configuration) { (image, error) in
                        guard let data = image!.jpegData(compressionQuality: 1) else {
                            result( bytes )
                            self.dispose()
                            return
                        }
                        bytes = FlutterStandardTypedData.init(bytes: data)
                        result(bytes)
                        self.dispose()
                    }
                    
                }
            })
            
            break
        case "contentToPDF":
            let path = arguments!["savedPath"] as? String
            let savedPath = URL.init(string: path!)?.path
            let format = arguments!["format"] as? Dictionary<String, Double>
            let margins = arguments!["margins"] as? Dictionary<String, Double>
            self.webView = WKWebView()
            self.webView.isHidden = false
            self.webView.tag = 100
            self.webView.loadHTMLString(content!, baseURL: Bundle.main.resourceURL)// load html into hidden webview
            urlObservation = webView.observe(\.isLoading, changeHandler: { (webView, change) in
                DispatchQueue.main.asyncAfter(deadline: .now() + (duration!/10000) ) {
                    print("height = \(self.webView.scrollView.contentSize.height)")
                    print("width = \(self.webView.scrollView.contentSize.width)")
                    guard let path = self.webView.exportAsPdfFromWebView(savedPath: savedPath!, format: format!, margins: margins!) else {
                        result(nil)
                        return
                    }
                    result(path)
                    //dispose
                    self.dispose()
                }
            })
            break
            
        case "printPreview":
            let url = arguments!["url"] as? String?
            let margins = arguments!["margins"] as? Dictionary<String, Double>
            let baseURL = url != nil ? URL(string: url!!) : Bundle.main.resourceURL;
            self.webView = WKWebView()
            self.webView.isHidden = true
            self.webView.tag = 100
            self.webView.loadHTMLString(content!, baseURL: baseURL)// load html into hidden webview
            urlObservation = webView.observe(\.isLoading, changeHandler: { (webView, change) in
                DispatchQueue.main.asyncAfter(deadline: .now() + (duration!/10000) ) {
                    self.createWebPrintJob(webView: webView)
                    result(nil)
                    self.dispose()
                }
            })
            break
        default:
            result("iOS " + UIDevice.current.systemVersion)
        }
        
    }
    
    private func createWebPrintJob(webView: WKWebView) {
        
        let printInfo = UIPrintInfo(dictionary: nil)
        let appName = Bundle.main.infoDictionary!["CFBundleName"] as! String
        printInfo.jobName = "\(appName) print preview"
        printInfo.outputType = .general
        let printController =  UIPrintInteractionController.shared
        
        printController.printInfo = printInfo
        let printFormatter = webView.viewPrintFormatter();
        let defaultBestPaper = UIPrintPaper.bestPaper(forPageSize: CGSize(width: 595, height: 842), withPapersFrom: [])
        
        printController.printFormatter = printFormatter
        printController.present(animated: true, completionHandler: { (data, response, error) in
            ///Ï
        })
    }
    
    func dispose() {
        //dispose
        if let viewWithTag = self.webView.viewWithTag(100) {
            viewWithTag.removeFromSuperview() // remove hidden webview when pdf is generated
            // clear WKWebView cache
            WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                records.forEach { record in
                    WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
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
extension WKWebView {
    
    func snapshot() -> UIImage?
    {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, true, 0);
        self.drawHierarchy(in: self.bounds, afterScreenUpdates: true);
        let snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return snapshotImage;
    }
    
    // Call this function when WKWebView finish loading
    func exportAsPdfFromWebView(savedPath: String, format: Dictionary<String, Double>, margins: Dictionary<String, Double>) -> String? {
        let formatter = self.viewPrintFormatter()
        formatter.perPageContentInsets = UIEdgeInsets(top: CGFloat(margins["top"] ?? 0).toPixel(), left:CGFloat(margins["left"] ?? 0).toPixel(), bottom: CGFloat(margins["bottom"] ?? 0).toPixel(), right: CGFloat(margins["right"] ?? 0).toPixel() )
        let page = CGRect(x: 0, y: 0, width: CGFloat(format["width"] ?? 8.27).toPixel(), height: CGFloat(format["height"] ?? 11.27).toPixel() )
        let printable = page.insetBy(dx: 0, dy: 0)
        let render = CustomPrintPageRenderer(headerText: "47-0412 Faith is Substance - English", footerText: "Page")
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

// used convert current inches value into real CGFloat
extension CGFloat{
    func toPixel() -> CGFloat {
        if(self>0){
            return self * 96
        }
        return 0
    }
}

class CustomPrintPageRenderer: UIPrintPageRenderer {
    
    var headerHeightValue: CGFloat
    var footerHeightValue: CGFloat

    let headerText: String
    let footerText: String

    init(headerText: String, footerText: String, headerHeightValue: CGFloat = 50.0, footerHeightValue: CGFloat = 50.0) {
        self.headerText = headerText
        self.footerText = footerText
        self.headerHeightValue = headerHeightValue
        self.footerHeightValue = footerHeightValue
    }
    
    override var headerHeight: CGFloat {
        get {
            headerHeightValue
        }
        set {
            headerHeightValue = newValue
        }
    }
    
    override var footerHeight: CGFloat {
        get {
            footerHeightValue
        }
        set {
            footerHeightValue = newValue
        }
    }
    
    override func drawHeaderForPage(at pageIndex: Int, in headerRect: CGRect) {
        let attributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
            NSAttributedString.Key.foregroundColor: UIColor.gray
        ]

        let textSize = headerText.size(withAttributes: attributes)
        let textRect = CGRect(x: headerRect.midX - textSize.width / 2, y: headerRect.midY - textSize.height / 2, width: textSize.width, height: textSize.height)

        headerText.draw(in: textRect, withAttributes: attributes)
    }
    
    override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
        let footerText = "\(footerText) \(pageIndex + 1)"
        let attributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
            NSAttributedString.Key.foregroundColor: UIColor.darkGray
        ]

        let textSize = footerText.size(withAttributes: attributes)
        let textRect = CGRect(x: footerRect.midX - textSize.width / 2, y: footerRect.midY - textSize.height / 2, width: textSize.width, height: textSize.height)

        footerText.draw(in: textRect, withAttributes: attributes)
    }

    func generatePdfData() -> NSMutableData {
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, self.paperRect, nil)
        self.prepare(forDrawingPages: NSMakeRange(0, self.numberOfPages))
        let printRect = UIGraphicsGetPDFContextBounds()
        for pdfPage in 0..<self.numberOfPages {
            UIGraphicsBeginPDFPage()
            self.drawPage(at: pdfPage, in: printRect)
        }
        UIGraphicsEndPDFContext();
        return pdfData
    }
}

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
                        print("height = \(self.webView.scrollView.contentSize.height)")
                        print("width = \(self.webView.scrollView.contentSize.width)")
                        let configuration = WKSnapshotConfiguration()
                        configuration.rect = CGRect(origin: .zero, size: (self.webView.scrollView.contentSize))
                    if #available(iOS 11.0, *) {
                        self.webView.snapshotView(afterScreenUpdates: true)
                        self.webView.takeSnapshot(with: configuration) { (image, error) in
                            guard let data = image!.jpegData(compressionQuality: 1) else {
                                result( bytes )
                                self.dispose()
                                return
                            }
                            bytes = FlutterStandardTypedData.init(bytes: data)
                            result(bytes)
                            // UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
                            //dispose
                            self.dispose()
                            print("Got snapshot")
                        }
                    } else {
                        result( bytes )
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
                        let configuration = WKSnapshotConfiguration()
                        configuration.rect = CGRect(x: 0, y: 0, width: CGFloat(format!["width"] ?? 8.27).toPixel(), height: CGFloat(format!["height"] ?? 11.27).toPixel() )
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
        default:
            result("iOS " + UIDevice.current.systemVersion)
        }
        
    }
    
    
    func dispose() {
        //dispose
        if let viewWithTag = self.webView.viewWithTag(100) {
            viewWithTag.removeFromSuperview() // remove hidden webview when pdf is generated
            // clear WKWebView cache
            if #available(iOS 9.0, *) {
                WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                    records.forEach { record in
                        WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                    }
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

    
    // Call this function when WKWebView finish loading
    func exportAsPdfFromWebView(savedPath: String, format: Dictionary<String, Double>, margins: Dictionary<String, Double>) -> String? {
        let formatter = self.viewPrintFormatter()
        formatter.perPageContentInsets = UIEdgeInsets(top: CGFloat(margins["top"] ?? 0).toPixel(), left:CGFloat(margins["left"] ?? 0).toPixel(), bottom: CGFloat(margins["bottom"] ?? 0).toPixel(), right: CGFloat(margins["right"] ?? 0).toPixel() )
        let page = CGRect(x: 0, y: 0, width: CGFloat(format["width"] ?? 8.27).toPixel(), height: CGFloat(format["height"] ?? 11.27).toPixel() )
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
        UIGraphicsEndPDFContext();
        return pdfData
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

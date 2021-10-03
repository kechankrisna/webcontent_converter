import Cocoa
import FlutterMacOS
import WebKit

public class WebcontentConverterPlugin: NSObject, FlutterPlugin {
  var webView : WKWebView!
  var urlObservation: NSKeyValueObservation?
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "webcontent_converter", binaryMessenger: registrar.messenger)
    let instance = WebcontentConverterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let method = call.method
    let arguments = call.arguments as? [String: Any]
    let content = arguments!["content"] as? String
    var duration = arguments!["duration"] as? Double
    if(duration==nil){ duration = 2000.0}
    
    switch method {
    case "contentToImage":
        self.webView = WKWebView();
        
        self.webView.isHidden = false;
        self.webView.viewWithTag(100);        self.webView.loadHTMLString(content!, baseURL: Bundle.main.resourceURL)// load html into hidden webview
        var bytes = FlutterStandardTypedData.init(bytes: Data() )
        urlObservation = webView.observe(\.isLoading, changeHandler: { (webView, change) in
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration!/10000) ) {
                print("height = \(self.webView.enclosingScrollView?.contentSize.width)")
                    print("width = \(self.webView.enclosingScrollView?.contentSize.width)")
                if #available(macOS 10.13, *) {
                    let size = CGSize(width: 600, height: 600);
                    let configuration = WKSnapshotConfiguration()
                    configuration.rect = CGRect(origin: .zero, size: size)
                    self.webView.takeSnapshot(with: configuration) { (image, error) in
                        
                        guard let data = image!.png else {
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
                    // Fallback on earlier versions
                    result( bytes )
                    self.dispose()
                }
                
                
            }
        })
        
        break
    default:
      result(FlutterMethodNotImplemented)
    }
  }
    
    func dispose() {
        
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

//
extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:]) }
}
extension Data {
    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }
}
extension NSImage {
    var png: Data? { tiffRepresentation?.bitmap?.png }
}

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

    /// the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func create(
//        withFrame frame: CGRect,
        withViewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> NSView {
        let _arguments = args as? Dictionary<String, Any>
        let width = _arguments!["width"] as! Double? ?? 1
        let height = _arguments!["height"] as! Double? ?? 1
        let frame = CGRect(x: 0, y: 0, width: width, height: height )
        print("frame \(frame)")
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
}
#endif


#if os(iOS)
class FLNativeView: NSObject, FlutterPlatformView {
    private var _frame: CGRect?
    private var _view: UIView?
    private var _arguments : Dictionary<String, Any>?
    private var _webView : WKWebView?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _arguments = args as? Dictionary<String, Any>
        let width = _arguments!["width"] as! Double? ?? 1
        let height = _arguments!["height"] as! Double? ?? 1
        _frame = CGRect(x: 0, y: 0, width: width, height: height )
        _view = UIView(frame: _frame!)
        print("init view.width \(_view!.frame.width)")
        print("init view.height \(_view!.frame.height)")
        _view!.clipsToBounds = true
        let configuration = WKWebViewConfiguration()
        _webView = WKWebView(frame: _view!.bounds, configuration: configuration)
        _webView!.tag = 100
        _webView!.scrollView.bounces = true
        
        super.init()
        // Views can be created here
        createNativeView(view: _view!)
    }

 
    func view() -> UIView {
        return _view!
    }

    func createNativeView(view _view: UIView){
        let content = _arguments!["content"]! as? String?
        let url = _arguments!["url"]! as? String?
        let baseURL = url != nil ? URL(string: url!!) : Bundle.main.resourceURL;
        if(url != nil){
            _webView!.load(URLRequest(url: baseURL!))
        }else{
            if(content != nil ){
                _webView!.loadHTMLString(content!!, baseURL: baseURL)
            }
        }
        _view.addSubview(_webView!)
    }
    
    deinit {
        self.dispose()
    }
    
    func dispose() {
        print("dispose")
        _arguments = nil
        _webView = nil
        _view = nil
    }
}
#else
class FLNativeView: NSView {
    private var _frame: CGRect?
    private var _view: NSView?
    private var _arguments : Dictionary<String, Any>?
    private var _webView : WKWebView?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _arguments = args as? Dictionary<String, Any>
        let width = _arguments!["width"] as! Double? ?? 1
        let height = _arguments!["height"] as! Double? ?? 1
        _frame = CGRect(x: 0, y: 0, width: width, height: height )
        _view = NSView(frame: _frame!)
        print("init view.width \(_view!.frame.width)")
        print("init view.height \(_view!.frame.height)")
        let configuration = WKWebViewConfiguration()
        _webView = WKWebView(frame: _view!.bounds, configuration: configuration)
        
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: height ))
        
        wantsLayer = true

        // ✅ ADD THIS: Add _view to self so it becomes visible
        self.addSubview(_view!)
        
        // Views can be created here
        createNativeView(view: _view!)
    }
    
    required init?(coder nsCoder: NSCoder) {
      super.init(coder: nsCoder)
    }

    func view() -> NSView {
        return _view!
    }

    func createNativeView(view _view: NSView){
        let content = _arguments!["content"] as? String?
        let url = _arguments!["url"] as? String?
        print("init view.content \(String(describing: content))")
        print("init view.url \(String(describing: url))")
        
        // Configure WebView for macOS
        _webView!.wantsLayer = true
        _webView!.autoresizingMask = [.width, .height] // ✅ ADD: Auto-resize with parent
        if let layer = _webView!.layer {
            layer.isOpaque = true
        }
        
        let baseURL = url != nil ? URL(string: url!!) : Bundle.main.resourceURL;
        if(url != nil){
            print("Loading URL: \(url!!)")
            _webView!.load(URLRequest(url: baseURL!))
        }else{
            if(content != nil ){
                print("Loading HTML content: \(content!!.prefix(100))...")
                _webView!.loadHTMLString(content!!, baseURL: baseURL)
                print("_webView.loadHTMLString")
            }
        }
        _view.addSubview(_webView!)
        print("_view.addSubview")
        print("WebView frame: \(_webView!.frame)")
        print("self frame: \(self.frame)")
    }
    
    deinit {
        self.dispose()
    }
    
    func dispose() {
        print("dispose FLNativeView")
        _webView?.stopLoading()
        _webView?.removeFromSuperview()
        _view?.removeFromSuperview()
        _arguments = nil
        _webView = nil
        _view = nil
    }
}
#endif

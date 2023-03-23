//
//  FLWebView.swift
//  webcontent_converter
//
//  Created by whitehat on 17/4/21.
//

import Flutter
import UIKit
import WebKit

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
//        print("init view.bounds \(_view?.bounds)")
        _view!.clipsToBounds = true
        let configuration = WKWebViewConfiguration()
        _webView = WKWebView(frame: _view!.bounds, configuration: configuration)
        _webView!.tag = 100
        _webView!.scrollView.bounces = true
        super.init()
        // iOS views can be created here
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

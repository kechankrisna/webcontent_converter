import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("WebView Screen")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: Wrap(
                children: [
                  TextButton(
                    onPressed: () {
                      WebcontentConverter.logger.info("Reload WebView");
                    },
                    child: Text("onPressed: Reload WebView"),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 400,
              child: LayoutBuilder(
                builder: (ctn, constains) {
                  return WebcontentConverter.embedWebView(
                    width: constains.maxWidth,
                    height: constains.maxHeight,

                    // content: Demo.getInvoiceContent(),
                    url: "https://flutter.dev/",
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onPressed,
        child: Icon(Icons.replay_outlined),
      ),
    );
  }

  void _onPressed() {}
}

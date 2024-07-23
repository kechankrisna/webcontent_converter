import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import '../services/demo.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  WebViewScreenState createState() => WebViewScreenState();
}

class WebViewScreenState extends State<WebViewScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('WebView Screen'),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 400,
                child: LayoutBuilder(
                  builder: (ctn, constains) => WebcontentConverter.embedWebView(
                    width: constains.maxWidth,
                    height: constains.maxHeight,

                    content: Demo.getInvoiceContent(),

                    /// url: "https://example.com/",
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _onPressed,
          child: const Icon(Icons.replay_outlined),
        ),
      );

  void _onPressed() {}
}

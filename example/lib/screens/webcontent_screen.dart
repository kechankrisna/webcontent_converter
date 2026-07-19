import 'package:flutter/material.dart';
import 'package:webcontent_converter/webcontent_converter.dart'
    hide PaperFormat;

class WebcontentScreen extends StatefulWidget {
  const WebcontentScreen({super.key});

  @override
  State<WebcontentScreen> createState() => _WebcontentScreenState();
}

class _WebcontentScreenState extends State<WebcontentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Webcontent Converter Example'),
      ),
      body: Center(
          child: Column(
        children: [
          /// ensureInitialized called
          ElevatedButton(
              onPressed: () async {
                await WebcontentConverter.initWebcontentConverter();
                WebcontentConverter.logger
                    .info("WebcontentConverter initialized");
                // WebcontentConverter.logger.info(
                //     windowBrower?.isConnected.toString() ?? 'no browser path');
              },
              child: Text("ensureInitialized")),

          /// deinitWebcontentConverter called
          ElevatedButton(
              onPressed: () async {
                await WebcontentConverter.deinitWebcontentConverter();
                WebcontentConverter.logger
                    .info("WebcontentConverter deinitialized");
                // WebcontentConverter.logger.info(
                //     windowBrower?.isConnected.toString() ?? 'no browser path');
              },
              child: Text("deinitWebcontentConverter")),
        ],
      )),
    );
  }
}

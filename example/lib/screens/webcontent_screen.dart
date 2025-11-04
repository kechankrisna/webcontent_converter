import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:puppeteer/puppeteer.dart' as pp;
import 'package:webcontent_converter/webcontent_converter.dart'
    hide PaperFormat;
import 'package:path/path.dart' as p;

import '../services/demo.dart';

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
                WebcontentConverter.logger.info(
                    windowBrower?.isConnected.toString() ?? 'no browser path');
              },
              child: Text("ensureInitialized")),

          /// deinitWebcontentConverter called
          ElevatedButton(
              onPressed: () async {
                await WebcontentConverter.deinitWebcontentConverter();
                WebcontentConverter.logger
                    .info("WebcontentConverter deinitialized");
                WebcontentConverter.logger.info(
                    windowBrower?.isConnected.toString() ?? 'no browser path');
              },
              child: Text("deinitWebcontentConverter")),

          /// raw pupeteer button to quick pdf from content
          ElevatedButton(
              onPressed: () async {
                var content = Demo.getInvoiceContent();

// Start the browser and go to a web page
                var browser = await pp.puppeteer.launch();
                var page = await browser.newPage();
                // await page.goto(
                //   'https://pub.dev/documentation/puppeteer/latest/',
                //   wait: pp.Until.networkAlmostIdle,
                // );
                await page.setContent(content,
                    wait: pp.Until.networkAlmostIdle);

                // For this example, we force the "screen" media-type because sometime
                // CSS rules with "@media print" can change the look of the page.
                await page.emulateMediaType(pp.MediaType.screen);
                final dirPath = io.Directory.current.path;
                // Capture the PDF and save it to a file.
                await page.pdf(
                  format: pp.PaperFormat.a4,
                  printBackground: true,
                  output: io.File(p.join(dirPath, 'dart.pdf')).openWrite(),
                );
                await browser.close();
              },
              child: Text("raw pupeteer"))
        ],
      )),
    );
  }
}

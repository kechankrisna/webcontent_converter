import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import '../services/demo.dart';
// import 'package:webcontent_converter_example/services/webview_helper.dart';

class ContentToImageScreen extends StatefulWidget {
  const ContentToImageScreen({super.key});

  @override
  ContentToImageScreenState createState() => ContentToImageScreenState();
}

class ContentToImageScreenState extends State<ContentToImageScreen> {
  int _counter = 1;
  Uint8List? _bytes;
  io.File? _file;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Content to Image'),
          actions: [
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: _convert,
            ),
            IconButton(
              icon: const Icon(Icons.wifi_rounded),
              onPressed: _startPrintWireless,
            ),
            IconButton(
              icon: const Icon(Icons.bluetooth),
              onPressed: _startPrintBluetooth,
            ),
          ],
        ),
        body: Container(
          color: Colors.white,
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              children: [
                if (_file != null)
                  Container(
                    width: 400,
                    alignment: Alignment.topCenter,
                    child: Image.memory(_file!.readAsBytesSync()),
                  ),
                const Divider(),
                if (_bytes?.isNotEmpty ?? false)
                  Container(
                    width: 400,
                    alignment: Alignment.topCenter,
                    decoration:
                        BoxDecoration(border: Border.all(color: Colors.blue)),
                    child: Image.memory(_bytes!),
                  ),
              ],
            ),
          ),
        ),
      );

  ///[convert html] content into bytes
  Future<void> _convert() async {
    final stopwatch = Stopwatch()..start();
    final bytes = await WebcontentConverter.contentToImage(
      content: _counter.isEven
          ? Demo.getShortReceiptContent()
          : Demo.getReceiptContent(),
      executablePath: WebViewHelper.executablePath(),
    );
    WebcontentConverter.logger
        .info('completed executed in ${stopwatch.elapsed}');
    setState(() => _counter += 1);
    if (bytes.isNotEmpty) {
      await _saveFile(bytes);
      WebcontentConverter.logger.info('bytes.length ${bytes.length}');
    }
  }

  ///[save bytes] into file
  Future<void> _saveFile(Uint8List bytes) async {
    setState(() => _bytes = bytes);
    if (kIsWeb) {
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = join(dir.path, 'receipt.jpg');
    final file = io.File(path);
    await file.writeAsBytes(bytes);
    WebcontentConverter.logger.info(file.path);
    setState(() => _file = file);
  }

  void _startPrintWireless() {
    // var p = ESCPrinterService(_bytes);
    // p.startPrint();
  }

  void _startPrintBluetooth() {
    // var p = ESCPrinterService(_bytes);
    // p.startBluePrint();
  }
}

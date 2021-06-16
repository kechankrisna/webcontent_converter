import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';

class ContentToImageScreen extends StatefulWidget {
  @override
  _ContentToImageScreenState createState() => _ContentToImageScreenState();
}

class _ContentToImageScreenState extends State<ContentToImageScreen> {
  Uint8List? _bytes;
  File? _file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Content to Image"),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: _convert,
          ),
          IconButton(
            icon: Icon(Icons.wifi_rounded),
            onPressed: _startPrintWireless,
          ),
          IconButton(
            icon: Icon(Icons.bluetooth),
            onPressed: _startPrintBluetooth,
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: ListView(
          children: [
            if (_file != null) Image.memory(_file!.readAsBytesSync()),
          ],
        ),
      ),
    );
  }

  ///[convert html] content into bytes
  _convert() async {
    final content = Demo.getReceiptContent();
    var bytes = await WebcontentConverter.contentToImage(content: content);
    if (bytes.length > 0) _saveFile(bytes);
    WebcontentConverter.logger.info(bytes);
  }

  ///[save bytes] into file
  _saveFile(Uint8List bytes) async {
    setState(() => _bytes = bytes);
    var dir = await getTemporaryDirectory();
    var path = join(dir.path, "receipt.jpg");
    File file = File(path);
    await file.writeAsBytes(bytes);
    WebcontentConverter.logger.info(file.path);
    setState(() => _file = file);
  }

  _startPrintWireless() async {
    // var p = ESCPrinterService(_bytes);
    // p.startPrint();
  }

  _startPrintBluetooth() {
    // var p = ESCPrinterService(_bytes);
    // p.startBluePrint();
  }
}

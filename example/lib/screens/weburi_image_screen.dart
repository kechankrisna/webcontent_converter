import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class WebUriToImageScreen extends StatefulWidget {
  @override
  _WebUriToImageScreenState createState() => _WebUriToImageScreenState();
}

class _WebUriToImageScreenState extends State<WebUriToImageScreen> {
  Uint8List? _bytes;
  File? _file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("URI to Image"),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: _convert,
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _testPrint,
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
    var bytes = await WebcontentConverter.webUriToImage(
        uri: "http://127.0.0.1:5500/example/assets/receipt.html");
    if (bytes.length > 0) _saveFile(bytes);
  }

  ///[save bytes] into file
  _saveFile(Uint8List bytes) async {
    setState(() => _bytes = bytes);
    var dir = await getTemporaryDirectory();
    var path = join(dir.path, "receipt.jpg");
    File file = File(path);
    await file.writeAsBytes(bytes);
    WebcontentConverter.logger(file.path);
    setState(() => _file = file);
  }

  _testPrint() async {
    // var p = ESCPrinterService(_bytes);
    // p.startPrint();
  }
}

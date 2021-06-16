import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class FilePathToImageScreen extends StatefulWidget {
  @override
  _FilePathToImageScreenState createState() => _FilePathToImageScreenState();
}

class _FilePathToImageScreenState extends State<FilePathToImageScreen> {
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

  ///[convert asset file html] content into bytes
  _convert() async {
    var bytes =
        await WebcontentConverter.filePathToImage(path: "assets/receipt.html");
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

  _testPrint() async {
    // var p = ESCPrinterService(_bytes);
    // p.startPrint();
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class FilePathToImageScreen extends StatefulWidget {
  @override
  _FilePathToImageScreenState createState() => _FilePathToImageScreenState();
}

class _FilePathToImageScreenState extends State<FilePathToImageScreen> {
  int _counter = 1;
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
              Divider(),
              if (_bytes?.isNotEmpty == true)
                Container(
                  width: 400,
                  alignment: Alignment.topCenter,
                  decoration:
                      BoxDecoration(border: Border.all(color: Colors.blue)),
                  child: Image.memory(_bytes!),
                )
            ],
          ),
        ),
      ),
    );
  }

  ///[convert asset file html] content into bytes
  _convert() async {
    var stopwatch = Stopwatch()..start();
    var bytes = await WebcontentConverter.filePathToImage(
      path:
          _counter.isEven ? "assets/short_receipt.html" : "assets/receipt.html",
      executablePath: WebViewHelper.executablePath(),
    );
    WebcontentConverter.logger
        .info("completed executed in ${stopwatch.elapsed}");
    setState(() => _counter += 1);
    if (bytes.isNotEmpty) {
      _saveFile(bytes);
      WebcontentConverter.logger.info("bytes.length ${bytes.length}");
    }
  }

  ///[save bytes] into file
  _saveFile(Uint8List bytes) async {
    setState(() => _bytes = bytes);
    if (kIsWeb) {
      return;
    }
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

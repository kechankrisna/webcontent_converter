import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class WebUriToImageScreen extends StatefulWidget {
  @override
  _WebUriToImageScreenState createState() => _WebUriToImageScreenState();
}

class _WebUriToImageScreenState extends State<WebUriToImageScreen> {
  int _counter = 1;
  Uint8List? _bytes;
  io.File? _file;

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

              // if (_file != null) Image.memory(_file.readAsBytesSync()),
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

  ///[convert html] content into bytes
  _convert() async {
    var stopwatch = Stopwatch()..start();
    var bytes = await WebcontentConverter.webUriToImage(
      uri: _counter.isEven
          ? "http://127.0.0.1:5500/example/assets/short_receipt.html"
          : "http://127.0.0.1:5500/example/assets/receipt.html",
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
    io.File file = io.File(path);
    await file.writeAsBytes(bytes);
    WebcontentConverter.logger(file.path);
    setState(() => _file = file);
  }

  _testPrint() async {
    // var p = ESCPrinterService(_bytes);
    // p.startPrint();
  }
}

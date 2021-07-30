import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class WebUriToPDFScreen extends StatefulWidget {
  @override
  _WebUriToPDFScreenState createState() => _WebUriToPDFScreenState();
}

class _WebUriToPDFScreenState extends State<WebUriToPDFScreen> {
  File? _file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("URI to PDF"),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _convert,
          ),
          IconButton(
            icon: Icon(Icons.chrome_reader_mode),
            onPressed: _previewPDF,
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

  ///[convert html] content into pdf
  _convert() async {
    var dir = await getApplicationDocumentsDirectory();
    var savedPath = join(dir.path, "sample.pdf");
    var result = await WebcontentConverter.webUriToPdf(
        uri: "http://127.0.0.1:5500/example/assets/invoice.html",
        savedPath: savedPath);
    WebcontentConverter.logger.info(result ?? '');
  }

  _previewPDF() async {}
}

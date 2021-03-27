import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';

class ContentToPDFScreen extends StatefulWidget {
  @override
  _ContentToPDFScreenState createState() => _ContentToPDFScreenState();
}

class _ContentToPDFScreenState extends State<ContentToPDFScreen> {
  File _file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Content to PDF"),
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
            if (_file != null) Image.memory(_file.readAsBytesSync()),
          ],
        ),
      ),
    );
  }

  ///[convert html] content into pdf
  _convert() async {
    final content = Demo.getInvoiceContent();
    var dir = await getApplicationDocumentsDirectory();
    var savedPath = join(dir.path, "sample.pdf");
    var result = await WebcontentConverter.contentToPDF(
      content: content,
      savedPath: savedPath,
      format: PaperFormat.a4,
      margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
    );

    WebcontentConverter.logger.info(result);
  }

  _previewPDF() async {}
}

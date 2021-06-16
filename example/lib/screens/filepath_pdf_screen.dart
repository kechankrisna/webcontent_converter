import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class FilePathToPDFScreen extends StatefulWidget {
  @override
  _FilePathToPDFScreenState createState() => _FilePathToPDFScreenState();
}

class _FilePathToPDFScreenState extends State<FilePathToPDFScreen> {
  File? _file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Filepath to PDF"),
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

  ///[convert asset file html] content into pdf
  _convert() async {
    var dir = await getApplicationDocumentsDirectory();
    var savedPath = join(dir.path, "sample.pdf");
    var result = await WebcontentConverter.filePathToPdf(
      path: "assets/invoice.html",
      savedPath: savedPath,
      format: PaperFormat.a4,
      margins: PdfMargins.px(top: 35, bottom: 35, right: 35, left: 35),
    );

    WebcontentConverter.logger.info(result ?? '');
  }

  _previewPDF() async {}
}

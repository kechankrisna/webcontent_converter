import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';
// import 'package:webcontent_converter_example/services/webview_helper.dart';

class ContentToPDFScreen extends StatefulWidget {
  @override
  _ContentToPDFScreenState createState() => _ContentToPDFScreenState();
}

class _ContentToPDFScreenState extends State<ContentToPDFScreen> {
  io.File? _file;

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
        alignment: Alignment.center,
        color: Colors.white,
        child: _file != null
            ? Container(
                constraints: BoxConstraints(maxWidth: 600),
                child: PdfPreview(
                  build: (format) async {
                    return await _file!.readAsBytes();
                  },
                  useActions: false,
                  scrollViewDecoration:
                      BoxDecoration(color: Colors.transparent),
                ),
              )
            : null,
      ),
    );
  }

  ///[convert html] content into pdf
  _convert() async {
    final content = Demo.getInvoiceContent();
    var savedPath = "sample.pdf";
    if (!kIsWeb) {
      var dir = await getApplicationDocumentsDirectory();
      savedPath = join(dir.path, "sample.pdf");
    }

    var result = await WebcontentConverter.contentToPDF(
      content: content,
      savedPath: savedPath,
      format: PaperFormat.a4,
      margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
      executablePath: WebViewHelper.executablePath(),
    );

    WebcontentConverter.logger.info("completed");
    if (!kIsWeb) setState(() => _file = io.File(savedPath));

    /// [printing]
    // await Printing.layoutPdf(
    //     onLayout: (PdfPageFormat format) => _file.readAsBytes());

    WebcontentConverter.logger.info(result ?? '');
  }

  _previewPDF() async {}
}

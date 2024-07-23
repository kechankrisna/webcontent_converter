import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import '../services/demo.dart';
// import 'package:webcontent_converter_example/services/webview_helper.dart';

class ContentToPDFScreen extends StatefulWidget {
  const ContentToPDFScreen({super.key});

  @override
  ContentToPDFScreenState createState() => ContentToPDFScreenState();
}

class ContentToPDFScreenState extends State<ContentToPDFScreen> {
  io.File? _file;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Content to PDF'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _convert,
            ),
            IconButton(
              icon: const Icon(Icons.chrome_reader_mode),
              onPressed: _previewPDF,
            ),
          ],
        ),
        body: Container(
          alignment: Alignment.center,
          color: Colors.white,
          child: _file != null
              ? Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: PdfPreview(
                    build: (format) async => _file!.readAsBytes(),
                    useActions: false,
                    scrollViewDecoration:
                        const BoxDecoration(color: Colors.transparent),
                  ),
                )
              : null,
        ),
      );

  ///[convert html] content into pdf
  Future<void> _convert() async {
    final content = Demo.getInvoiceContent();
    var savedPath = 'sample.pdf';
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      savedPath = join(dir.path, 'sample.pdf');
    }

    final result = await WebcontentConverter.contentToPDF(
      content: content,
      savedPath: savedPath,
      format: PaperFormat.a4(isPortrait: true),
      margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
      executablePath: WebViewHelper.executablePath(),
    );

    WebcontentConverter.logger.info('completed');
    if (!kIsWeb) {
      setState(() => _file = io.File(savedPath));
    }

    /// [printing]
    // await Printing.layoutPdf(
    //     onLayout: (PdfPageFormat format) => _file.readAsBytes());

    WebcontentConverter.logger.info(result ?? '');
  }

  void _previewPDF() {}
}

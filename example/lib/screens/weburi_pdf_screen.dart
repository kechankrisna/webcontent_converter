import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class WebUriToPDFScreen extends StatefulWidget {
  const WebUriToPDFScreen({super.key});

  @override
  WebUriToPDFScreenState createState() => WebUriToPDFScreenState();
}

class WebUriToPDFScreenState extends State<WebUriToPDFScreen> {
  io.File? _file;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('URI to PDF'),
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
    var savedPath = 'sample.pdf';
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      savedPath = join(dir.path, 'sample.pdf');
    }
    final result = await WebcontentConverter.webUriToPdf(
      uri: 'http://127.0.0.1:5500/example/assets/invoice.html',
      savedPath: savedPath,
      executablePath: WebViewHelper.executablePath(),
      format: PaperFormat.a4(isPortrait: true),
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

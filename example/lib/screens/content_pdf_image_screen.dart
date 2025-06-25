import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as PDF;
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';
// import 'package:webcontent_converter_example/services/webview_helper.dart';

class ContentToPDFImageScreen extends StatefulWidget {
  @override
  _ContentToPDFImageScreenState createState() =>
      _ContentToPDFImageScreenState();
}

class _ContentToPDFImageScreenState extends State<ContentToPDFImageScreen> {
  Uint8List? _fileBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Content to PDF Image"),
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
        child: _fileBytes != null
            ? Container(
                constraints: BoxConstraints(maxWidth: 600),
                child: PdfPreview(
                  build: (format) async {
                    if (kIsWeb) {
                      final doc = pw.Document();
                      doc.addPage(
                        pw.Page(
                          build: (pw.Context context) {
                            return [
                              pw.Image(
                                pw.MemoryImage(
                                  _fileBytes!,
                                ),
                              )
                            ].first;
                          },
                          
                        ),
                      );
                      return doc.save();
                    } else {
                      // For other platforms, we can return the Uint8List directly
                      return _fileBytes!;
                    }
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

    var result = await WebcontentConverter.contentToPDFImage(
      content: content,
      format: PaperFormat.a4,
      margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
      executablePath: WebViewHelper.executablePath(),
    );

    WebcontentConverter.logger.info("completed");

    print("result: ${result?.length}");
    setState(() {
      _fileBytes = result;
    });

    /// [printing]
    // await Printing.layoutPdf(
    //     onLayout: (PdfPageFormat format) => _file.readAsBytes());

    WebcontentConverter.logger.info(result ?? '');
  }

  _previewPDF() async {}
}

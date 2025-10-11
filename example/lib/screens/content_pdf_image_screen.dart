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
        color: Colors.white,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          primary: false,
          child: Column(
            children: [
              // if (_fileBytes != null)
              //   Container(
              //     width: 400,
              //     alignment: Alignment.topCenter,
              //     child: Image.memory(_fileBytes!.readAsBytesSync()),
              //   ),
              Divider(),
              if (_fileBytes?.isNotEmpty == true)
                Container(
                  width: double.infinity,
                  alignment: Alignment.topCenter,
                  decoration:
                      BoxDecoration(border: Border.all(color: Colors.blue)),
                  child: Image.memory(_fileBytes!),
                )
            ],
          ),
        ),
      ),
      // body: Container(
      //   alignment: Alignment.center,
      //   color: Colors.white,
      //   child: _fileBytes != null
      //       ? Container(
      //           constraints: BoxConstraints(maxWidth: 600),
      //           child: PdfPreview(
      //             build: (format) async {
      //               if (kIsWeb) {
      //                 final doc = pw.Document();
      //                 doc.addPage(
      //                   pw.Page(
      //                     build: (pw.Context context) {
      //                       return [
      //                         pw.Image(
      //                           pw.MemoryImage(
      //                             _fileBytes!,
      //                           ),
      //                         )
      //                       ].first;
      //                     },
                          
      //                   ),
      //                 );
      //                 return doc.save();
      //               } else {
      //                 // For other platforms, we can return the Uint8List directly
      //                 return _fileBytes!;
      //               }
      //             },
      //             useActions: false,
      //             scrollViewDecoration:
      //                 BoxDecoration(color: Colors.transparent),
      //           ),
      //         )
      //       : null,
      // ),
    );
  }

  ///[convert html] content into pdf
  _convert() async {
    final content = Demo.getInvoiceContent();

    var result = await WebcontentConverter.contentToImage(
      content: content,
      // format: PaperFormat.a4,
      // margins: PdfMargins.px(top: 55, bottom: 55, right: 55, left: 55),
      executablePath: WebViewHelper.executablePath(),
      args: {
        "format": {
          "width": PaperFormat.a4.width,
          "height": PaperFormat.a4.height,
          "name": PaperFormat.a4.name,
        },
        "margins": {'top': 0.25, 'bottom': 0.25, 'right': 0.25, 'left': 0.25},
        // "landscape": false,
        // "printBackground": true,
        // "scale": 1.0,
        // "preferCSSPageSize": true,
        // "pageRanges": '1-2',
        // "displayHeaderFooter": true,
        // "headerTemplate":
        //     '<div style="font-size:10px !important; width:100%; text-align:center; margin-top:10px;"><span class="title"></span></div>',
        // "footerTemplate":
        //     '<div style="font-size:10px !important; width:100%; text-align:center; margin-bottom:10px;"><span class="pageNumber"></span> / <span class="totalPages"></span></div>',
      }
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

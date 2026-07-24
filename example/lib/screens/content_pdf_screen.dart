import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:webcontent_converter/page.dart';

import './controllers/content_pdf_screen_controller.dart';
// import 'package:webcontent_converter_example/services/webview_helper.dart';

class ContentToPDFScreen extends StatefulWidget {
  @override
  _ContentToPDFScreenState createState() => _ContentToPDFScreenState();
}

class _ContentToPDFScreenState extends State<ContentToPDFScreen> {
  late ContentPDFScreenController controller = ContentPDFScreenController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: ContentPdfScreenScaffold(),
    );
  }
}

class ContentPdfScreenScaffold extends StatelessWidget {
  const ContentPdfScreenScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final controller = Provider.of<ContentPDFScreenController>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Content to PDF"),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () async {
              await controller.convert(
                content_file: "invoice.html",
                format: PaperFormat.a4,
                margins: PdfMargins.inches(
                  top: 0.25,
                  bottom: 0.25,
                  right: 0.25,
                  left: 0.25,
                ),
              );
            },
            tooltip: "Convert to PDF (invoice)",
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () async {
              await controller.convert(
                content_file: "short_label.html",
                format: PaperFormat.inches(
                  name: "custom",
                  width: 1,
                  height: 1,
                ),
                margins: PdfMargins.inches(
                  top: 0.00,
                  bottom: 0.00,
                  right: 0.00,
                  left: 0.00,
                ),
              );
            },
            tooltip: "Convert to PDF (short label)",
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () async {
              await controller.convert(
                content_file: "long_label.html",
                format: PaperFormat.inches(
                  name: "custom",
                  width: 1.57,
                  height: 1.18,
                ),
                margins: PdfMargins.inches(
                  top: 0.00,
                  bottom: 0.00,
                  right: 0.00,
                  left: 0.00,
                ),
              );
            },
            tooltip: "Convert to PDF (long label)",
          ),
          IconButton(
            icon: Icon(Icons.chrome_reader_mode),
            onPressed: () async {
              await controller.previewPDF(content_file: "invoice.html");
            },
            tooltip: "Preview PDF",
          ),
        ],
      ),
      body: Container(
        alignment: Alignment.center,
        color: Colors.white,
        child: Row(
          children: [
            if (size.width > 600)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(
                    maxWidth: size.width / 2,
                    maxHeight: size.height,
                  ),
                  child: TextFormField(
                    maxLines: null,
                    controller: controller.textEditingController,
                  ),
                ),
              ),
            if (controller.file != null)
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: size.width / 2,
                    maxHeight: size.height,
                  ),
                  child: PdfPreview(
                    build: (format) async {
                      return await controller.file!.readAsBytes();
                    },
                    useActions: false,
                    scrollViewDecoration: BoxDecoration(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.pickContent,
        child: Icon(Icons.file_open),
      ),
    );
  }
}

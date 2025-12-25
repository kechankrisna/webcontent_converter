import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/content_pdf_image_screen_controller.dart';
// import 'package:webcontent_converter_example/services/webview_helper.dart';

class ContentToPDFImageScreen extends StatefulWidget {
  @override
  _ContentToPDFImageScreenState createState() =>
      _ContentToPDFImageScreenState();
}

class _ContentToPDFImageScreenState extends State<ContentToPDFImageScreen> {
  late ContentPDFImageScreenController controller =
      ContentPDFImageScreenController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: ContentToPDFImageScreenScaffold(),
    );
  }
}

class ContentToPDFImageScreenScaffold extends StatelessWidget {
  const ContentToPDFImageScreenScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final controller = Provider.of<ContentPDFImageScreenController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Content to PDF Image"),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: controller.convert,
          ),
          IconButton(
            icon: Icon(Icons.chrome_reader_mode),
            onPressed: controller.previewPDF,
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        alignment: Alignment.topCenter,
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
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: size.width / 2,
                  maxHeight: size.height,
                ),
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
                      // Divider(),
                      if (controller.bytes?.isNotEmpty == true)
                        Container(
                          width: double.infinity,
                          alignment: Alignment.topCenter,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue)),
                          child: Image.memory(controller.bytes!),
                        )
                    ],
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
}

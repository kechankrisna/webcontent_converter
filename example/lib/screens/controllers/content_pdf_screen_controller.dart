import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';

class ContentPDFScreenController extends ChangeNotifier {
  int counter = 1;
  io.File? file;
  final TextEditingController textEditingController = TextEditingController();

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  ContentPDFScreenController() {
    ///
  }

  Future<void> pickContent() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final fileContent = await picked.xFile.readAsString();
    textEditingController.text = fileContent;
    notifyListeners();
  }

  Future<void> convert() async {
    final defaultContent =
        counter.isEven ? Demo.getShortLabelContent() : Demo.getInvoiceContent();

    var savedPath = "sample_${DateTime.now().millisecondsSinceEpoch}.pdf";
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      savedPath = join(dir.path, savedPath);
    }

    final result = await WebcontentConverter.contentToPDF(
      content: textEditingController.text.isNotEmpty
          ? textEditingController.text
          : defaultContent,
      savedPath: savedPath,
      format: counter.isEven
          ? PaperFormat.inches(name: "custom", width: 1, height: 1)
          : PaperFormat.a4,
      margins: counter.isEven
          ? PdfMargins.inches(top: 0.01, bottom: 0.01, right: 0.01, left: 0.01)
          : PdfMargins.inches(top: 0.25, bottom: 0.25, right: 0.25, left: 0.25),
      executablePath: WebViewHelper.executablePath(),
    );

    counter += 1;
    WebcontentConverter.logger.info("completed");
    if (!kIsWeb) file = io.File(savedPath);

    WebcontentConverter.logger.info(result ?? '');
    notifyListeners();
  }

  previewPDF() async {
    final defaultContent =
        counter.isEven ? Demo.getShortLabelContent() : Demo.getInvoiceContent();
    WebcontentConverter.printPreview(
      content: textEditingController.text.isNotEmpty
          ? textEditingController.text
          : defaultContent,
    );
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}

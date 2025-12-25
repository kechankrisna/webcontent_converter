import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';

class ContentImageScreenController extends ChangeNotifier {
  int counter = 1;
  io.File? file;
  Uint8List? bytes;
  final TextEditingController textEditingController = TextEditingController();

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  ContentImageScreenController() {
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
        counter.isEven ? Demo.getShortReceiptContent() : Demo.getReceiptContent();

    var savedPath = "sample_${DateTime.now().millisecondsSinceEpoch}.pdf";
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      savedPath = join(dir.path, savedPath);
    }

    final result = await WebcontentConverter.contentToImage(
      content: textEditingController.text.isNotEmpty
          ? textEditingController.text
          : defaultContent,
      executablePath: WebViewHelper.executablePath(),
      args: {
        "is_html2bitmap": false,
        "bitmap_width": 300.0,
        // "format": {"width": 8.27, "height": 11.69, "name": "a4"},
      },
    );

    bytes = result;
    notifyListeners();

    counter += 1;
    WebcontentConverter.logger.info("completed");
    if (!kIsWeb) file = io.File(savedPath);

    bytes != null && file != null
        ? await file!.writeAsBytes(bytes!)
        : null;
    WebcontentConverter.logger.info(result ?? '');
    notifyListeners();
  }

  previewPDF() async {
    final defaultContent =
        counter.isEven ? Demo.getShortReceiptContent() : Demo.getReceiptContent();
    WebcontentConverter.printPreview(
      content: textEditingController.text.isNotEmpty
          ? textEditingController.text
          : defaultContent,
    );
  }

  startPrintWireless() async {
    // var p = ESCPrinterService(_bytes);
    // p.startPrint();
  }

  startPrintBluetooth() {
    // var p = ESCPrinterService(_bytes);
    // p.startBluePrint();
  }

  changeCounter(int v) {
    counter = v;
    notifyListeners();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}

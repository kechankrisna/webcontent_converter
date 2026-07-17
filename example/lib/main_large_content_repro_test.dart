import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/services/demo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (WebViewHelper.isDesktop) {
    await windowManager.ensureInitialized();
  }
  runApp(MaterialApp(home: ReproScreen()));
}

class ReproScreen extends StatefulWidget {
  @override
  State<ReproScreen> createState() => _ReproScreenState();
}

class _ReproScreenState extends State<ReproScreen> {
  String status = "starting...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => runRepro());
  }

  Future<void> runRepro() async {
    final content = Demo.getShortLabelContent();
    log("LARGE CONTENT REPRO: content length=${content.length} chars");
    setState(() => status = "content=${content.length} chars\ntesting PDF...");

    final dir = await getApplicationDocumentsDirectory();

    try {
      final pdfPath = join(dir.path, "large_content_repro.pdf");
      final pdfResult = await WebcontentConverter.contentToPDF(
        content: content,
        savedPath: pdfPath,
        format: PaperFormat.inches(name: "label", width: 1, height: 1),
        margins: PdfMargins.inches(top: 0.05, bottom: 0.05, left: 0.05, right: 0.05),
        executablePath: WebViewHelper.executablePath(),
      );
      log("LARGE CONTENT REPRO: PDF SUCCESS result=$pdfResult");
      setState(() => status = "PDF: OK\ntesting image...");
    } catch (e) {
      log("LARGE CONTENT REPRO: PDF FAILED $e");
      setState(() => status = "PDF: FAILED $e\ntesting image...");
    }

    try {
      final result = await WebcontentConverter.contentToImage(
        content: content,
        executablePath: WebViewHelper.executablePath(),
        args: {"is_html2bitmap": false, "bitmap_width": 300.0},
      );
      final imgPath = join(dir.path, "large_content_repro.png");
      await File(imgPath).writeAsBytes(result);
      log("LARGE CONTENT REPRO: IMAGE SUCCESS bytes=${result.length}");
      setState(() => status = "ALL DONE\nimage bytes=${result.length}");
    } catch (e) {
      log("LARGE CONTENT REPRO: IMAGE FAILED $e");
      setState(() => status = "IMAGE: FAILED $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

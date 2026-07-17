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
    final dir = await getApplicationDocumentsDirectory();

    setState(() => status = "pdf with enableLogger: true...");
    await WebcontentConverter.contentToPDF(
      content: Demo.getInvoiceContent(),
      savedPath: join(dir.path, "logger_repro_pdf_on.pdf"),
      format: PaperFormat.a4,
      margins: PdfMargins.inches(top: 0.25, bottom: 0.25, left: 0.25, right: 0.25),
      executablePath: WebViewHelper.executablePath(),
      enableLogger: true,
    );

    setState(() => status = "pdf with enableLogger: false...");
    await WebcontentConverter.contentToPDF(
      content: Demo.getInvoiceContent(),
      savedPath: join(dir.path, "logger_repro_pdf_off.pdf"),
      format: PaperFormat.a4,
      margins: PdfMargins.inches(top: 0.25, bottom: 0.25, left: 0.25, right: 0.25),
      executablePath: WebViewHelper.executablePath(),
      enableLogger: false,
    );

    setState(() => status = "image with enableLogger: true...");
    await WebcontentConverter.contentToImage(
      content: Demo.getShortReceiptContent(),
      executablePath: WebViewHelper.executablePath(),
      args: {"is_html2bitmap": false, "bitmap_width": 300.0},
      enableLogger: true,
    );

    setState(() => status = "image with enableLogger: false...");
    await WebcontentConverter.contentToImage(
      content: Demo.getShortReceiptContent(),
      executablePath: WebViewHelper.executablePath(),
      args: {"is_html2bitmap": false, "bitmap_width": 300.0},
      enableLogger: false,
    );

    setState(() => status = "ALL DONE");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

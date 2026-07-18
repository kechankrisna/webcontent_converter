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
    final dir = await getApplicationDocumentsDirectory();
    for (var i = 1; i <= 3; i++) {
      setState(() => status = "call $i/3...");
      try {
        final result = await WebcontentConverter.contentToPDFImage(
          content: Demo.getInvoiceContent(),
          format: PaperFormat.a4,
          margins: PdfMargins.inches(top: 0.25, bottom: 0.25, left: 0.25, right: 0.25),
          executablePath: WebViewHelper.executablePath(),
        );
        if (result == null) {
          log("PDFIMAGE REPRO call $i: NULL result");
          setState(() => status = "call $i: NULL result");
          continue;
        }
        final savedPath = join(dir.path, "pdfimage_repro_$i.pdf");
        await File(savedPath).writeAsBytes(result);
        // Real PDFs start with "%PDF-".
        final looksLikePdf = result.length > 5 &&
            String.fromCharCodes(result.sublist(0, 5)) == "%PDF-";
        log("PDFIMAGE REPRO call $i: SUCCESS bytes=${result.length} looksLikePdf=$looksLikePdf path=$savedPath");
        setState(() => status =
            "call $i: OK bytes=${result.length} looksLikePdf=$looksLikePdf");
      } catch (e) {
        log("PDFIMAGE REPRO call $i: FAILED $e");
        setState(() => status = "call $i: FAILED $e");
      }
    }
    log("PDFIMAGE REPRO: all done");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

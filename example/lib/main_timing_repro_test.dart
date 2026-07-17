import 'dart:developer';
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
    const total = 15;
    final dir = await getApplicationDocumentsDirectory();

    // PDF timing pass -- sequential, awaited, same content every time.
    setState(() => status = "PDF pass...");
    final pdfTimes = <int>[];
    for (var i = 1; i <= total; i++) {
      final sw = Stopwatch()..start();
      final savedPath = join(dir.path, "timing_pdf_$i.pdf");
      try {
        await WebcontentConverter.contentToPDF(
          content: Demo.getInvoiceContent(),
          savedPath: savedPath,
          format: PaperFormat.a4,
          margins: PdfMargins.inches(top: 0.25, bottom: 0.25, left: 0.25, right: 0.25),
          executablePath: WebViewHelper.executablePath(),
        );
        pdfTimes.add(sw.elapsedMilliseconds);
        log("TIMING pdf $i: ${sw.elapsedMilliseconds}ms");
      } catch (e) {
        log("TIMING pdf $i: FAILED $e");
        pdfTimes.add(-1);
      }
    }

    // Image timing pass -- same shape, same content every time.
    setState(() => status = "Image pass...");
    final imageTimes = <int>[];
    for (var i = 1; i <= total; i++) {
      final sw = Stopwatch()..start();
      try {
        await WebcontentConverter.contentToImage(
          content: Demo.getShortReceiptContent(),
          executablePath: WebViewHelper.executablePath(),
          args: {"is_html2bitmap": false, "bitmap_width": 300.0},
        );
        imageTimes.add(sw.elapsedMilliseconds);
        log("TIMING image $i: ${sw.elapsedMilliseconds}ms");
      } catch (e) {
        log("TIMING image $i: FAILED $e");
        imageTimes.add(-1);
      }
    }

    final pdfAvg = pdfTimes.where((t) => t >= 0).isEmpty
        ? -1
        : pdfTimes.where((t) => t >= 0).reduce((a, b) => a + b) /
            pdfTimes.where((t) => t >= 0).length;
    final imageAvg = imageTimes.where((t) => t >= 0).isEmpty
        ? -1
        : imageTimes.where((t) => t >= 0).reduce((a, b) => a + b) /
            imageTimes.where((t) => t >= 0).length;

    log("TIMING SUMMARY pdf=$pdfTimes avg=$pdfAvg");
    log("TIMING SUMMARY image=$imageTimes avg=$imageAvg");
    setState(() => status =
        "DONE\npdf avg: ${pdfAvg.toStringAsFixed(0)}ms\nimage avg: ${imageAvg.toStringAsFixed(0)}ms\n\npdf: $pdfTimes\n\nimage: $imageTimes");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

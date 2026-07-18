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
    // Phase 1: mimic content_image_screen's usage -- a few sequential
    // contentToImage calls, same as the image button's Future.forEach loop.
    setState(() => status = "phase 1: image conversions...");
    for (var i = 1; i <= 4; i++) {
      log("MIXED REPRO image $i: starting");
      try {
        final result = await WebcontentConverter.contentToImage(
          content: Demo.getShortReceiptContent(),
          args: {"is_html2bitmap": false, "bitmap_width": 300.0},
        );
        log("MIXED REPRO image $i: SUCCESS bytes=${result.length}");
      } catch (e) {
        log("MIXED REPRO image $i: FAILED error=$e");
      }
    }

    // Phase 2: mimic rapid manual taps on the PDF convert button -- fired
    // unawaited, roughly a click apart, exactly like IconButton.onPressed
    // with no in-flight guard.
    setState(() => status = "phase 2: rapid PDF taps...");
    final dir = await getApplicationDocumentsDirectory();
    final futures = <Future<void>>[];
    for (var i = 1; i <= 4; i++) {
      final savedPath = join(dir.path, "mixed_repro_$i.pdf");
      log("MIXED REPRO pdf $i: firing (unawaited)");
      final f = WebcontentConverter.contentToPDF(
        content: Demo.getInvoiceContent(),
        savedPath: savedPath,
        format: PaperFormat.a4,
        margins: PdfMargins.inches(top: 0.25, bottom: 0.25, left: 0.25, right: 0.25),
      ).then((result) {
        final exists = result != null && File(result).existsSync();
        log("MIXED REPRO pdf $i: SUCCESS result=$result exists=$exists");
      }).catchError((e) {
        log("MIXED REPRO pdf $i: FAILED error=$e");
      });
      futures.add(f);
      await Future.delayed(const Duration(milliseconds: 900));
    }

    await Future.wait(futures);
    log("MIXED REPRO: all settled");
    setState(() => status = "ALL SETTLED");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

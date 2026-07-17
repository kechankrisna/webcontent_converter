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
    for (var i = 1; i <= 3; i++) {
      final sw = Stopwatch()..start();
      setState(() => status = "run $i: starting...");
      log("REPRO run $i: starting");
      try {
        final dir = await getApplicationDocumentsDirectory();
        final savedPath = join(dir.path, "repro_$i.pdf");
        final result = await WebcontentConverter.contentToPDF(
          content: i.isEven ? Demo.getShortLabelContent() : Demo.getInvoiceContent(),
          savedPath: savedPath,
           format: i.isEven
            ? PaperFormat.inches(name: "letter", width: 1, height: 1)
            : PaperFormat.a4,
        margins: i.isEven
            ? PdfMargins.inches(top: 0.05, bottom: 0.05, right: 0.05, left: 0.05)
            : PdfMargins.inches(
                top: 0.25, bottom: 0.25, right: 0.25, left: 0.25),
          executablePath: WebViewHelper.executablePath(),
        );
        final exists = result != null && File(result).existsSync();
        log("REPRO run $i: SUCCESS result=$result exists=$exists elapsedMs=${sw.elapsedMilliseconds}");
        setState(() => status = "run $i: SUCCESS ($result)");
      } catch (e, st) {
        log("REPRO run $i: FAILED error=$e", stackTrace: st);
        setState(() => status = "run $i: FAILED $e");
      }
    }
    log("REPRO all runs complete");
    setState(() => status = "$status\nALL RUNS COMPLETE");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

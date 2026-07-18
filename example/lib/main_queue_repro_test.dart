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
    const total = 10;
    setState(() => status = "firing $total unawaited requests...");
    log("QUEUE REPRO: firing $total requests without awaiting between them");

    final dir = await getApplicationDocumentsDirectory();
    final futures = <Future<void>>[];
    for (var i = 1; i <= total; i++) {
      final savedPath = join(dir.path, "queue_repro_$i.pdf");
      final f = WebcontentConverter.contentToPDF(
        content: Demo.getInvoiceContent(),
        savedPath: savedPath,
        format: PaperFormat.a4,
        margins: PdfMargins.inches(top: 0.25, bottom: 0.25, left: 0.25, right: 0.25),
      ).then((result) {
        final exists = result != null && File(result).existsSync();
        log("QUEUE REPRO run $i: SUCCESS result=$result exists=$exists");
      }).catchError((e) {
        log("QUEUE REPRO run $i: FAILED error=$e");
      });
      futures.add(f);
    }

    await Future.wait(futures);
    log("QUEUE REPRO: all $total requests settled");
    setState(() => status = "ALL $total REQUESTS SETTLED");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

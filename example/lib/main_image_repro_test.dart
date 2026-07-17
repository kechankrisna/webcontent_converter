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
    for (var i = 1; i <= 2; i++) {
      setState(() => status = "run $i: starting...");
      log("IMAGE REPRO run $i: starting");
      try {
        final dir = await getApplicationDocumentsDirectory();
        final savedPath = join(dir.path, "image_repro_$i.png");
        final result = await WebcontentConverter.contentToImage(
          content: i.isEven
              ? Demo.getShortReceiptContent()
              : Demo.getReceiptContent(),
          executablePath: WebViewHelper.executablePath(),
          args: {
            "is_html2bitmap": false,
            "bitmap_width": 300.0,
          },
        );
        await File(savedPath).writeAsBytes(result);
        log("IMAGE REPRO run $i: SUCCESS bytes=${result.length} path=$savedPath");
        setState(() => status = "run $i: SUCCESS (${result.length} bytes)");
      } catch (e, st) {
        log("IMAGE REPRO run $i: FAILED error=$e", stackTrace: st);
        setState(() => status = "run $i: FAILED $e");
      }
    }
    log("IMAGE REPRO all runs complete");
    setState(() => status = "$status\nALL RUNS COMPLETE");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

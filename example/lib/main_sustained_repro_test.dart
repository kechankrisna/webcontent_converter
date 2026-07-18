import 'dart:developer';
import 'package:flutter/material.dart';
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
    const total = 60;
    final times = <int>[];
    var hangs = 0;

    for (var i = 1; i <= total; i++) {
      final sw = Stopwatch()..start();
      setState(() => status = "call $i/$total...");
      try {
        await WebcontentConverter.contentToImage(
          content: i.isEven
              ? Demo.getShortReceiptContent()
              : Demo.getReceiptContent(),
          args: {"is_html2bitmap": false, "bitmap_width": 300.0},
          enableLogger: false,
        );
        final ms = sw.elapsedMilliseconds;
        times.add(ms);
        final hung = ms > 500;
        if (hung) hangs++;
        log("SUSTAINED REPRO call $i: ${ms}ms${hung ? ' (HANG)' : ''}");
      } catch (e) {
        times.add(-1);
        log("SUSTAINED REPRO call $i: FAILED $e");
      }
    }

    // Split into thirds to see whether the hang rate trends up over the run.
    final third = total ~/ 3;
    int hangsIn(int start, int end) =>
        times.sublist(start, end).where((t) => t > 500).length;
    final first = hangsIn(0, third);
    final middle = hangsIn(third, third * 2);
    final last = hangsIn(third * 2, total);

    final summary =
        "DONE: $hangs/$total hangs (${(hangs * 100 / total).toStringAsFixed(0)}%)\n"
        "first $third: $first hangs\n"
        "middle $third: $middle hangs\n"
        "last ${total - third * 2}: $last hangs\n"
        "times: $times";
    log("SUSTAINED REPRO SUMMARY: $summary");
    setState(() => status = summary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webcontent_converter_example/screens/controllers/content_image_screen_controller.dart';

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
  late final controller = ContentImageScreenController();
  String status = "starting...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => runRepro());
  }

  Future<void> runRepro() async {
    // Simulate 5 rapid taps in a row, like a user mashing the button.
    // Only the first should actually start a batch; the rest should be
    // no-ops because isConverting is already true.
    setState(() => status = "firing 5 rapid taps...");
    log("BATCH GUARD REPRO: firing 5 rapid taps");
    for (var i = 1; i <= 5; i++) {
      // Unawaited on purpose -- mimics 5 rapid button presses.
      // ignore: unawaited_futures
      controller.convertBatch();
      log("BATCH GUARD REPRO: tap $i fired, isConverting=${controller.isConverting}");
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Wait for the (single) batch to fully finish.
    setState(() => status = "waiting for batch to settle...");
    while (controller.isConverting) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    log("BATCH GUARD REPRO: batch settled, final counter=${controller.counter}");
    setState(() =>
        status = "DONE\nfinal counter=${controller.counter}\n(should be 2, not ~15+, if the guard worked)");
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Scaffold(
        body: Center(child: Text(status, textAlign: TextAlign.center)),
      ),
    );
  }
}

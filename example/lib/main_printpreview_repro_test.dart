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
    setState(() => status = "calling printPreview...");
    try {
      final result = await WebcontentConverter.printPreview(
        content: Demo.getInvoiceContent(),
        autoClose: false,
        duration: 1000,
      );
      print("PRINTPREVIEW REPRO: SUCCESS result=$result");
      setState(() => status = "printPreview returned: $result");
    } catch (e) {
      print("PRINTPREVIEW REPRO: FAILED $e");
      setState(() => status = "FAILED: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(status, textAlign: TextAlign.center)),
    );
  }
}

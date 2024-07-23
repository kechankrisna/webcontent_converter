import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class FilePathToImageScreen extends StatefulWidget {
  const FilePathToImageScreen({super.key});

  @override
  FilePathToImageScreenState createState() => FilePathToImageScreenState();
}

class FilePathToImageScreenState extends State<FilePathToImageScreen> {
  int _counter = 1;
  Uint8List? _bytes;
  File? _file;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('URI to Image'),
          actions: [
            IconButton(
              icon: const Icon(Icons.image),
              onPressed: _convert,
            ),
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _testPrint,
            ),
          ],
        ),
        body: Container(
          color: Colors.white,
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              children: [
                if (_file != null)
                  Container(
                    width: 400,
                    alignment: Alignment.topCenter,
                    child: Image.memory(_file!.readAsBytesSync()),
                  ),
                const Divider(),
                if (_bytes?.isNotEmpty ?? false)
                  Container(
                    width: 400,
                    alignment: Alignment.topCenter,
                    decoration:
                        BoxDecoration(border: Border.all(color: Colors.blue)),
                    child: Image.memory(_bytes!),
                  ),
              ],
            ),
          ),
        ),
      );

  ///[convert asset file html] content into bytes
  Future<void> _convert() async {
    final stopwatch = Stopwatch()..start();
    final bytes = await WebcontentConverter.filePathToImage(
      path:
          _counter.isEven ? 'assets/short_receipt.html' : 'assets/receipt.html',
      executablePath: WebViewHelper.executablePath(),
    );
    WebcontentConverter.logger
        .info('completed executed in ${stopwatch.elapsed}');
    setState(() => _counter += 1);
    if (bytes.isNotEmpty) {
      await _saveFile(bytes);
      WebcontentConverter.logger.info('bytes.length ${bytes.length}');
    }
  }

  ///[save bytes] into file
  Future<void> _saveFile(Uint8List bytes) async {
    setState(() => _bytes = bytes);
    if (kIsWeb) {
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = join(dir.path, 'receipt.jpg');
    final file = File(path);
    await file.writeAsBytes(bytes);
    WebcontentConverter.logger.info(file.path);
    setState(() => _file = file);
  }

  void _testPrint() {
    // var p = ESCPrinterService(_bytes);
    // p.startPrint();
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webcontent_converter/demo.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('contentToImage', () {
    testWidgets(
      'renders real HTML through the native plugin into a decodable image',
      (tester) async {
        final bytes = await WebcontentConverter.contentToImage(
          content: Demo.getShortReceiptContent(),
          duration: 3000,
          enableLogger: false,
        );

        expect(bytes, isNotEmpty);

        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('contentToPDF', () {
    testWidgets(
      'writes a real, well-formed PDF file through the native plugin',
      (tester) async {
        final dir = await getTemporaryDirectory();
        final savedPath = p.join(
          dir.path,
          'integration_test_${DateTime.now().microsecondsSinceEpoch}.pdf',
        );

        final resultPath = await WebcontentConverter.contentToPDF(
          content: Demo.getShortReceiptContent(),
          savedPath: savedPath,
          duration: 3000,
          enableLogger: false,
        );

        expect(resultPath, savedPath);
        final file = File(savedPath);
        expect(file.existsSync(), isTrue);

        final bytes = await file.readAsBytes();
        expect(_looksLikePdf(bytes), isTrue,
            reason: 'expected a %PDF- header and non-trivial size, got '
                '${bytes.length} bytes');

        await file.delete();
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

bool _looksLikePdf(Uint8List bytes) {
  if (bytes.length <= 500) return false;
  return String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
}

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

  group('contentToImage with format (Windows PDF-rasterized path)', () {
    testWidgets(
      'produces an A4-sized PNG for single-page content',
      (tester) async {
        final bytes = await WebcontentConverter.contentToImage(
          content: Demo.getShortReceiptContent(),
          duration: 3000,
          enableLogger: false,
          args: {
            'format': {
              'width': PaperFormat.a4.width,
              'height': PaperFormat.a4.height,
              'name': PaperFormat.a4.name,
            },
          },
        );

        expect(bytes, isNotEmpty);

        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final expectedWidth = (PaperFormat.a4.width * 96).round();
        final expectedHeight = (PaperFormat.a4.height * 96).round();

        expect(frame.image.width, expectedWidth);
        expect(frame.image.height % expectedHeight, 0,
            reason:
                'height should be an exact multiple of one A4 page height');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'stitches a longer letter-format invoice into a multi-page PNG',
      (tester) async {
        final bytes = await WebcontentConverter.contentToImage(
          content: Demo.getInvoiceContent(),
          duration: 3000,
          enableLogger: false,
          args: {
            'format': {
              'width': PaperFormat.letter.width,
              'height': PaperFormat.letter.height,
              'name': PaperFormat.letter.name,
            },
            'margins': {
              'top': 0.25,
              'bottom': 0.25,
              'right': 0.25,
              'left': 0.25,
            },
          },
        );

        expect(bytes, isNotEmpty);

        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final expectedWidth = (PaperFormat.letter.width * 96).round();
        final expectedHeight = (PaperFormat.letter.height * 96).round();

        expect(frame.image.width, expectedWidth);
        expect(frame.image.height % expectedHeight, 0,
            reason: 'height should be an exact multiple of one letter '
                'page height');
        expect(frame.image.height ~/ expectedHeight, greaterThan(1),
            reason: 'this invoice content is expected to span more than '
                'one page');
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

  group('contentToPDFImage', () {
    testWidgets(
      'returns real PDF bytes through the native plugin on every platform',
      (tester) async {
        final bytes = await WebcontentConverter.contentToPDFImage(
          content: Demo.getShortReceiptContent(),
          duration: 3000,
          enableLogger: false,
        );

        expect(bytes, isNotNull);
        expect(_looksLikePdf(bytes!), isTrue,
            reason: 'expected a %PDF- header and non-trivial size, got '
                '${bytes.length} bytes');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('isWebviewAvailable', () {
    testWidgets(
      'reports the real native webview as available on this device',
      (tester) async {
        final available = await WebcontentConverter.isWebviewAvailable();

        expect(available, isTrue,
            reason: 'this device/emulator/simulator is expected to have a '
                'working native webview (WebView2/WKWebView/WebView)');
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });
}

bool _looksLikePdf(Uint8List bytes) {
  if (bytes.length <= 500) return false;
  return String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
}

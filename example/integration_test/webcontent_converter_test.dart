import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show PlatformException;
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

  // Windows and Android both enforce a content-size guard (default 1GB,
  // see kMaxContentSizeBytes / MAX_CONTENT_SIZE_BYTES); overridable per call
  // via `maximumContentSize` (in MB). macOS/iOS have no such guard, so this
  // group is meaningful there only in that it must not regress (still
  // succeed) rather than exercising the cap itself.
  group('contentToImage maximumContentSize override', () {
    testWidgets(
      'rejects content larger than a caller-specified cap',
      (tester) async {
        // ~2MB of synthetic content -- comfortably over the 1MB cap below.
        final largeContent = 'A' * (2 * 1024 * 1024);
        await expectLater(
          WebcontentConverter.contentToImage(
            content: largeContent,
            duration: 1000,
            enableLogger: false,
            maximumContentSize: 1,
          ),
          throwsA(isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'CONTENT_TOO_LARGE',
          )),
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets(
      'leaves normal content unaffected when not specified',
      (tester) async {
        final bytes = await WebcontentConverter.contentToImage(
          content: Demo.getShortReceiptContent(),
          duration: 1000,
          enableLogger: false,
        );
        expect(bytes, isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  // Each platform rasterizes a `format`-ed page through a completely
  // different native pipeline, so there's no single universal "96dpi"
  // pixel count to assert against -- see the per-platform helpers below,
  // each backed by the native source that produces it:
  //   - windows/pdf_image_capture_request.cpp:30,89-92 -- exact
  //     `std::lround(inches * 96)`. This is the platform the group name
  //     and original expectations below were written against.
  //   - darwin/Classes/SwiftWebcontentConverterPlugin.swift:212-246 (iOS)
  //     draws page-sized rects through `UIGraphicsImageRenderer`, which
  //     bakes in the device's screen scale (`UIScreen.main.scale`); it
  //     never reads `margins`.
  //   - darwin/Classes/SwiftWebcontentConverterPlugin.swift:386-412
  //     (macOS) sizes the WebView to (truncated width + margins + a fixed
  //     300pt pad) then `takeSnapshot`s it, which bakes in the display's
  //     backing scale factor. Height is whatever the page's actual,
  //     unpaginated content height happens to be -- format only
  //     constrains width -- so there's no page-height relationship to
  //     assert on macOS.
  //   - android/.../Page.kt + PdfPrinter.kt round-trips inches through
  //     96dpi px -> print mils -> px, truncating at each step; lossless
  //     for paper sizes whose 96dpi size is already a whole number (e.g.
  //     letter), lossy by a couple of px otherwise (e.g. a4).
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

        if (Platform.isWindows) {
          final expectedWidth = _roundedPx96(PaperFormat.a4.width);
          final expectedHeight = _roundedPx96(PaperFormat.a4.height);
          expect(frame.image.width, expectedWidth);
          expect(frame.image.height % expectedHeight, 0,
              reason:
                  'height should be an exact multiple of one A4 page height');
        } else if (Platform.isAndroid) {
          final expectedWidth = _androidPagePx96(PaperFormat.a4.width);
          final expectedHeight = _androidPagePx96(PaperFormat.a4.height);
          expect(frame.image.width, expectedWidth);
          expect(frame.image.height % expectedHeight, 0,
              reason:
                  'height should be an exact multiple of one A4 page height');
        } else if (Platform.isIOS) {
          final scale = _devicePixelRatio;
          final expectedWidth =
              (_truncatedPx96(PaperFormat.a4.width) * scale).round();
          final expectedHeight =
              (_truncatedPx96(PaperFormat.a4.height) * scale).round();
          expect(frame.image.width, expectedWidth);
          expect(frame.image.height % expectedHeight, 0,
              reason: 'height should be an exact multiple of one (scaled) '
                  'A4 page height');
        } else if (Platform.isMacOS) {
          final scale = _devicePixelRatio;
          final expectedWidth =
              ((_truncatedPx96(PaperFormat.a4.width) + 300) * scale).round();
          expect(frame.image.width, expectedWidth);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'stitches a longer letter-format invoice into a multi-page PNG',
      (tester) async {
        const marginIn = 0.25;
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
              'top': marginIn,
              'bottom': marginIn,
              'right': marginIn,
              'left': marginIn,
            },
          },
        );

        expect(bytes, isNotEmpty);

        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();

        if (Platform.isWindows) {
          final expectedWidth = _roundedPx96(PaperFormat.letter.width);
          final expectedHeight = _roundedPx96(PaperFormat.letter.height);
          expect(frame.image.width, expectedWidth);
          expect(frame.image.height % expectedHeight, 0,
              reason: 'height should be an exact multiple of one letter '
                  'page height');
          expect(frame.image.height ~/ expectedHeight, greaterThan(1),
              reason: 'this invoice content is expected to span more than '
                  'one page');
        } else if (Platform.isAndroid) {
          final expectedWidth = _androidPagePx96(PaperFormat.letter.width);
          final expectedHeight = _androidPagePx96(PaperFormat.letter.height);
          expect(frame.image.width, expectedWidth);
          expect(frame.image.height % expectedHeight, 0,
              reason: 'height should be an exact multiple of one letter '
                  'page height');
          expect(frame.image.height ~/ expectedHeight, greaterThan(1),
              reason: 'this invoice content is expected to span more than '
                  'one page');
        } else if (Platform.isIOS) {
          final scale = _devicePixelRatio;
          final expectedWidth =
              (_truncatedPx96(PaperFormat.letter.width) * scale).round();
          final expectedHeight =
              (_truncatedPx96(PaperFormat.letter.height) * scale).round();
          expect(frame.image.width, expectedWidth);
          expect(frame.image.height % expectedHeight, 0,
              reason: 'height should be an exact multiple of one (scaled) '
                  'letter page height');
          expect(frame.image.height ~/ expectedHeight, greaterThan(1),
              reason: 'this invoice content is expected to span more than '
                  'one page');
        } else if (Platform.isMacOS) {
          final scale = _devicePixelRatio;
          final marginPx = marginIn * 96;
          final expectedWidth = ((_truncatedPx96(PaperFormat.letter.width) +
                      marginPx + marginPx + 300) *
                  scale)
              .round();
          expect(frame.image.width, expectedWidth);
        }
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

/// windows/pdf_image_capture_request.cpp:30,89-92 -- `std::lround(inches *
/// 96)`, the platform these dimensions were originally written against.
int _roundedPx96(num inches) => (inches * 96).round();

/// darwin/Classes/Page.swift:18-20,137-144 -- `Int(inches * 96.0)`
/// truncates toward zero rather than rounding. Used directly for iOS/macOS
/// (before device-scale is applied), and as the starting point for
/// Android's own (lossier) conversion below.
int _truncatedPx96(num inches) => (inches * 96).toInt();

/// The real screen/display scale (UIScreen.main.scale on iOS,
/// NSScreen.backingScaleFactor on macOS) that the native snapshot APIs
/// bake into the output PNG's pixel dimensions.
double get _devicePixelRatio =>
    ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

/// Mirrors Android's exact inches -> 96dpi px -> print mils -> px
/// round-trip (android/.../Page.kt:85-86, WebcontentConverterPlugin.kt:673-
/// 674, PdfPrinter.kt:94-106), which truncates (not rounds) at every step.
/// Lossless for paper sizes whose 96dpi size is already a whole number
/// (e.g. letter: 8.5in -> 816px exactly); lossy by a couple of px
/// otherwise (e.g. a4: 8.27in -> 793px -> 792px after the mils round
/// trip) -- this is a real, deterministic native-code quirk, not
/// device/density-dependent, so it's replicated exactly here rather than
/// tolerated with a fudge factor.
int _androidPagePx96(num inches) {
  final widthPixels = (inches * 96).toInt();
  final widthInMile = widthPixels * 1000 ~/ 96;
  return (widthInMile / 1000.0 * 96).toInt();
}

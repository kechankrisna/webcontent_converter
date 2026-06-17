import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webcontent_converter/webcontent_converter.dart'
    hide buildMarginCssForTest, buildInAppWebViewSizeForTest;
import 'package:webcontent_converter/src/webcontent_converter/webcontent_converter_io.dart'
    show buildMarginCssForTest, buildInAppWebViewSizeForTest;

void main() {
  const MethodChannel channel = MethodChannel('webcontent_converter');

  TestWidgetsFlutterBinding.ensureInitialized();

  test("paper format", () {
    expect(PaperFormat.fromString("a5"), PaperFormat.a5);
  });

  test("is isChromeAvailable", () {
    expect(WebViewHelper.isChromeAvailable, true);
  });

  group('_buildMarginCss', () {
    test('zero margins produces zero @page block', () {
      final css = buildMarginCssForTest(PdfMargins.zero);
      expect(css, '@page { margin: 0in 0in 0in 0in; }');
    });

    test('inch margins are serialised correctly', () {
      final css = buildMarginCssForTest(
        PdfMargins.inches(top: 0.5, bottom: 0.5, left: 0.75, right: 0.75),
      );
      expect(css, '@page { margin: 0.5in 0.75in 0.5in 0.75in; }');
    });
  });

  group('_buildInAppWebViewSize', () {
    test('A4 maps to correct logical pixel dimensions', () {
      final size = buildInAppWebViewSizeForTest(PaperFormat.a4);
      expect(size.width, closeTo(8.27 * 96, 0.5));
      expect(size.height, closeTo(11.7 * 96, 0.5));
    });

    test('letter maps to correct logical pixel dimensions', () {
      final size = buildInAppWebViewSizeForTest(PaperFormat.letter);
      expect(size.width, closeTo(8.5 * 96, 0.5));
      expect(size.height, closeTo(11.0 * 96, 0.5));
    });
  });
}

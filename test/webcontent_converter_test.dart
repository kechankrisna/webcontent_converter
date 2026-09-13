import 'package:flutter_test/flutter_test.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("paper format", () {
    expect(PaperFormat.fromString("a5"), PaperFormat.a5);
  });

  test("is isChromeAvailable", () {
    expect(WebViewHelper.isChromeAvailable, true);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("is isChromeAvailable", () {
    expect(WebViewHelper.isChromeAvailable, true);
  });
}

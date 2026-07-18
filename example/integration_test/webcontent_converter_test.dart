import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
}

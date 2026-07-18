// Guards the Dart-side contract with the native Android/iOS/macOS/Windows
// plugins: which method channel call each public API makes, with which
// arguments, how it surfaces native results, and how it propagates native
// failures. It intercepts the platform channel instead of the real native
// code, so it cannot catch a regression inside the Kotlin/Swift/C++
// implementations themselves — see PAGINATION_TEST_RESULTS.md / the plan
// follow-up for real per-platform integration coverage.
//
// contentToPDFImage's Windows/macOS branch is exercised only when this
// suite runs on a Windows or macOS host (matching `dart:io Platform`,
// which isn't injectable); on any other host it exercises the same
// direct-channel branch Android/iOS use.
import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:webcontent_converter/webcontent_converter.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  const MethodChannel channel = MethodChannel('webcontent_converter');

  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late io.Directory tempDir;

  setUp(() {
    tempDir = io.Directory.systemTemp.createTempSync('webcontent_converter_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('contentToImage', () {
    test('invokes the native channel with method name and default arguments', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return Uint8List.fromList([1, 2, 3]);
      });

      final result = await WebcontentConverter.contentToImage(
        content: '<h1>hi</h1>',
        enableLogger: false,
      );

      expect(captured.method, 'contentToImage');
      expect(captured.arguments['content'], '<h1>hi</h1>');
      expect(captured.arguments['duration'], 2000.0);
      expect(captured.arguments['scale'], 3);
      expect(result, Uint8List.fromList([1, 2, 3]));
    });

    test('forwards custom duration and scale', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return Uint8List.fromList([]);
      });

      await WebcontentConverter.contentToImage(
        content: 'x',
        duration: 500,
        scale: 5,
        enableLogger: false,
      );

      expect(captured.arguments['duration'], 500.0);
      expect(captured.arguments['scale'], 5);
    });

    test('merges extra args into the payload, letting them override defaults', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return Uint8List.fromList([]);
      });

      await WebcontentConverter.contentToImage(
        content: 'x',
        args: {'scale': 10, 'custom': 'value'},
        enableLogger: false,
      );

      expect(captured.arguments['scale'], 10);
      expect(captured.arguments['custom'], 'value');
    });

    test('propagates a PlatformException raised by the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'RENDER_FAILED', message: 'webview crashed');
      });

      expect(
        () => WebcontentConverter.contentToImage(content: 'x', enableLogger: false),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('contentToPDF', () {
    test('invokes the native channel with default margins and format', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return '/tmp/out.pdf';
      });

      final result = await WebcontentConverter.contentToPDF(
        content: '<h1>invoice</h1>',
        savedPath: '/tmp/out.pdf',
        enableLogger: false,
      );

      expect(captured.method, 'contentToPDF');
      expect(captured.arguments['content'], '<h1>invoice</h1>');
      expect(captured.arguments['savedPath'], '/tmp/out.pdf');
      expect(captured.arguments['margins'], PdfMargins.zero.toMap());
      expect(captured.arguments['format'], PaperFormat.a4.toMap());
      expect(result, '/tmp/out.pdf');
    });

    test('serialises custom margins and format', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return '/tmp/out.pdf';
      });

      final margins = PdfMargins.px(top: 10, bottom: 10, left: 5, right: 5);
      await WebcontentConverter.contentToPDF(
        content: 'x',
        savedPath: '/tmp/out.pdf',
        margins: margins,
        format: PaperFormat.letter,
        enableLogger: false,
      );

      expect(captured.arguments['margins'], margins.toMap());
      expect(captured.arguments['format'], PaperFormat.letter.toMap());
    });

    test('merges extra args into the payload', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return '/tmp/out.pdf';
      });

      await WebcontentConverter.contentToPDF(
        content: 'x',
        savedPath: '/tmp/out.pdf',
        args: {'custom': 'value'},
        enableLogger: false,
      );

      expect(captured.arguments['custom'], 'value');
    });

    test('propagates a PlatformException raised by the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'WRITE_FAILED', message: 'disk full');
      });

      expect(
        () => WebcontentConverter.contentToPDF(
          content: 'x',
          savedPath: '/tmp/out.pdf',
          enableLogger: false,
        ),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('contentToPDFImage', () {
    final isDesktopPdfHost = io.Platform.isWindows || io.Platform.isMacOS;

    test(
      'routes through native contentToPDF and reads the temp file back as bytes',
      () async {
        String? capturedSavedPath;
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'contentToPDF');
          capturedSavedPath = call.arguments['savedPath'] as String;
          await io.File(capturedSavedPath!).writeAsBytes([9, 9, 9]);
          return capturedSavedPath;
        });

        final result = await WebcontentConverter.contentToPDFImage(
          content: 'x',
          enableLogger: false,
        );

        expect(result, Uint8List.fromList([9, 9, 9]));
        expect(capturedSavedPath, isNotNull);
        expect(io.File(capturedSavedPath!).existsSync(), isFalse,
            reason: 'temp pdf must be deleted after being read back');
      },
      skip: isDesktopPdfHost ? false : 'exercises the Windows/macOS-only branch',
    );

    test(
      'calls the dedicated native contentToPDFImage method directly',
      () async {
        late MethodCall captured;
        messenger.setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return Uint8List.fromList([4, 5, 6]);
        });

        final result = await WebcontentConverter.contentToPDFImage(
          content: 'x',
          enableLogger: false,
        );

        expect(captured.method, 'contentToPDFImage');
        expect(result, Uint8List.fromList([4, 5, 6]));
      },
      skip: isDesktopPdfHost ? 'exercises the mobile-only branch' : false,
    );

    test('propagates a PlatformException raised by the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'CONVERT_FAILED', message: 'native failure');
      });

      expect(
        () => WebcontentConverter.contentToPDFImage(content: 'x', enableLogger: false),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}

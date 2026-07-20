// Guards the Dart-side contract with the native Android/iOS/macOS/Windows
// plugins: which method channel call each public API makes, with which
// arguments, how it surfaces native results, and how it propagates native
// failures. It intercepts the platform channel instead of the real native
// code, so it cannot catch a regression inside the Kotlin/Swift/C++
// implementations themselves — see
// example/integration_test/webcontent_converter_test.dart for real
// per-platform integration coverage against the actual native code.
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

  group('printPreview', () {
    test('invokes the native channel with content, margins, and format', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await WebcontentConverter.printPreview(
        content: '<h1>print</h1>',
        margins: PdfMargins.inches(top: 0.5, bottom: 0.5, left: 0.75, right: 0.75),
        format: PaperFormat.letter,
      );

      expect(captured.method, 'printPreview');
      expect(captured.arguments['content'], '<h1>print</h1>');
      final margins = Map<String, dynamic>.from(
          captured.arguments['margins'] as Map);
      expect(margins['top'], 0.5);
      expect(margins['bottom'], 0.5);
      expect(margins['left'], 0.75);
      expect(margins['right'], 0.75);
      final format = Map<String, dynamic>.from(
          captured.arguments['format'] as Map);
      expect(format['name'], 'letter');
      expect(format['width'], PaperFormat.letter.width);
      expect(format['height'], PaperFormat.letter.height);
    });

    test('uses default margins and format when not supplied', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      await WebcontentConverter.printPreview(
        content: '<h1>print</h1>',
      );

      expect(captured.arguments['margins'], PdfMargins.zero.toMap());
      final format =
          Map<String, dynamic>.from(captured.arguments['format'] as Map);
      expect(format['name'], 'a4');
    });

    test('sends the payload via the native channel when args are provided', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return null;
      });

      // On desktop (macOS, Windows) the platform branch builds its own
      // invokeMethod map and doesn't forward extra args; on mobile the
      // full merged arguments map is passed through. Regardless,
      // printPreview still sends the method channel call successfully.
      await WebcontentConverter.printPreview(
        content: '<h1>print</h1>',
        args: {'custom': 'extra'},
      );

      // Core arguments always present regardless of platform branch.
      expect(captured.method, 'printPreview');
      expect(captured.arguments['content'], isNotNull);
    });

    test('propagates a PlatformException raised by the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'PRINT_FAILED', message: 'native failure');
      });

      expect(
        () => WebcontentConverter.printPreview(content: '<h1>print</h1>'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('returns true on success', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      final result = await WebcontentConverter.printPreview(
        content: '<h1>print</h1>',
      );

      expect(result, isTrue);
    });
  });

  group('isWebviewAvailable', () {
    test('invokes the native channel with no arguments and returns its bool result', () async {
      late MethodCall captured;
      messenger.setMockMethodCallHandler(channel, (call) async {
        captured = call;
        return true;
      });

      final result = await WebcontentConverter.isWebviewAvailable();

      expect(captured.method, 'isWebviewAvailable');
      expect(result, isTrue);
    });

    test('surfaces a native false result', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => false);

      final result = await WebcontentConverter.isWebviewAvailable();

      expect(result, isFalse);
    });

    test('treats a null native result as unavailable', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      final result = await WebcontentConverter.isWebviewAvailable();

      expect(result, isFalse);
    });

    test('propagates a PlatformException raised by the native side', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'CHECK_FAILED', message: 'native failure');
      });

      expect(
        () => WebcontentConverter.isWebviewAvailable(),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}

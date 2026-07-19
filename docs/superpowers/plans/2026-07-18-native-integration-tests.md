# Native Platform Integration Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove `contentToImage`, `contentToPDF`, and `contentToPDFImage` actually produce correct output through the *real* native Android/iOS/macOS/Windows plugin code (not a mocked channel), and wire that proof into CI so a future native-side regression fails a build automatically.

**Architecture:** Use Flutter's `integration_test` package in the `example/` app. A single shared Dart test file (`example/integration_test/webcontent_converter_test.dart`) calls the public `WebcontentConverter` API and asserts on the real bytes/files it gets back (non-empty, decodable image; well-formed `%PDF-` file). `flutter test integration_test/<file>.dart -d <device>` runs that same file against a real Android emulator, iOS simulator, macOS host, or Windows host — no hand-written native XCTest/JUnit/CMake harness needed; the Flutter tool drives the native build and app launch itself. A GitHub Actions workflow (`.github/workflows/integration_test.yml`) runs it on all four platforms on every push/PR.

**Tech Stack:** Flutter 3.41.9 (pinned via `.fvmrc`), `integration_test` (Flutter SDK package), GitHub Actions (`subosito/flutter-action`, `reactivecircus/android-emulator-runner` for the Android emulator).

## Global Constraints

- Pin Flutter to `3.41.9` everywhere (matches this repo's `.fvmrc`) — do not float `channel: stable`, to avoid CI flakiness from upstream Flutter changes.
- No changes to native plugin code (`android/`, `darwin/`, `windows/`) or to `lib/` — this plan only adds test files and CI config.
- Test content comes from the existing `Demo` class (`package:webcontent_converter/demo.dart`, e.g. `Demo.getShortReceiptContent()`) — do not invent new HTML fixtures.
- A PDF is considered valid if its first 5 bytes are the ASCII string `%PDF-` and its length exceeds 500 bytes (rules out an empty/truncated file silently "succeeding").
- An image is considered valid if `ui.instantiateImageCodec` can decode it and the resulting frame has `width > 0 && height > 0`.
- Every integration test must carry a generous timeout (`Timeout(Duration(minutes: 3))`) — real webview rendering on a cold Android emulator is slow; a tight default timeout will flake, not fail correctly.

---

### Task 1: Add the `integration_test` dependency to the example app

**Files:**
- Modify: `example/pubspec.yaml`

**Interfaces:**
- Produces: `integration_test` package available for import as `package:integration_test/integration_test.dart` inside `example/`.

- [ ] **Step 1: Add the dependency**

In `example/pubspec.yaml`, under `dev_dependencies:`, add `integration_test` alongside the existing `flutter_test`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
```

- [ ] **Step 2: Fetch packages**

Run: `cd example && (fvm flutter pub get || flutter pub get)`
Expected: `Got dependencies!` with no version-resolution errors.

- [ ] **Step 3: Commit**

```bash
git add example/pubspec.yaml example/pubspec.lock
git commit -m "test: add integration_test dependency to example app"
```

---

### Task 2: `contentToImage` integration test

**Files:**
- Create: `example/integration_test/webcontent_converter_test.dart`

**Interfaces:**
- Consumes: `WebcontentConverter.contentToImage({required String content, ...})` from `package:webcontent_converter/webcontent_converter.dart`, returns `Future<Uint8List>`. `Demo.getShortReceiptContent()` from `package:webcontent_converter/demo.dart`, returns `String`.
- Produces: `main()` entrypoint that `flutter test integration_test/webcontent_converter_test.dart -d <device>` runs; a `_looksLikePdf(Uint8List)` helper is added in Task 3, don't add it yet.

- [ ] **Step 1: Write the test file**

```dart
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
```

- [ ] **Step 2: Run it on macOS (the fastest locally-available real target)**

Run: `cd example && (fvm flutter test integration_test/webcontent_converter_test.dart -d macos || flutter test integration_test/webcontent_converter_test.dart -d macos)`
Expected: `All tests passed!` — this exercises the real Darwin plugin (`darwin/Classes/SwiftWebcontentConverterPlugin.swift`), not a mock.

- [ ] **Step 3: Commit**

```bash
git add example/integration_test/webcontent_converter_test.dart
git commit -m "test: add real-device contentToImage integration test"
```

---

### Task 3: `contentToPDF` integration test

**Files:**
- Modify: `example/integration_test/webcontent_converter_test.dart`

**Interfaces:**
- Consumes: `WebcontentConverter.contentToPDF({required String content, required String savedPath, ...})`, returns `Future<String?>`. `getTemporaryDirectory()` from `package:path_provider/path_provider.dart` (already an `example/pubspec.yaml` dependency).
- Produces: `_looksLikePdf(Uint8List bytes)` helper, reused by Task 4.

- [ ] **Step 1: Add the PDF helper and imports**

Add these imports alongside the existing ones:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
```

Add this top-level helper below `main()`:

```dart
bool _looksLikePdf(Uint8List bytes) {
  if (bytes.length <= 500) return false;
  return String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
}
```

- [ ] **Step 2: Add the test**

Add a new group inside `main()`, after the `contentToImage` group:

```dart
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
```

- [ ] **Step 3: Run it on macOS**

Run: `cd example && (fvm flutter test integration_test/webcontent_converter_test.dart -d macos || flutter test integration_test/webcontent_converter_test.dart -d macos)`
Expected: `All tests passed!` (2 tests now).

- [ ] **Step 4: Commit**

```bash
git add example/integration_test/webcontent_converter_test.dart
git commit -m "test: add real-device contentToPDF integration test"
```

---

### Task 4: `contentToPDFImage` integration test

**Files:**
- Modify: `example/integration_test/webcontent_converter_test.dart`

**Interfaces:**
- Consumes: `WebcontentConverter.contentToPDFImage({required String content, ...})`, returns `Future<Uint8List?>`; reuses `_looksLikePdf` from Task 3.

- [ ] **Step 1: Add the test**

Add a new group after `contentToPDF`:

```dart
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
```

- [ ] **Step 2: Run it on macOS**

Run: `cd example && (fvm flutter test integration_test/webcontent_converter_test.dart -d macos || flutter test integration_test/webcontent_converter_test.dart -d macos)`
Expected: `All tests passed!` (3 tests now). This exercises the Windows/macOS `contentToPDF`-passthrough branch in `lib/src/webcontent_converter/webcontent_converter_io.dart`'s `contentToPDFImage`, for real, on macOS.

- [ ] **Step 3: Commit**

```bash
git add example/integration_test/webcontent_converter_test.dart
git commit -m "test: add real-device contentToPDFImage integration test"
```

---

### Task 5: Verify the full suite on the iOS simulator

**Files:** none (verification only).

- [ ] **Step 1: List the booted iOS simulator**

Run: `(fvm flutter devices || flutter devices)`
Expected: an entry like `iPhone 17 (mobile) • <UDID> • ios • ...`. Note the UDID.

- [ ] **Step 2: Run the suite against it**

Run: `cd example && (fvm flutter test integration_test/webcontent_converter_test.dart -d <UDID> || flutter test integration_test/webcontent_converter_test.dart -d <UDID>)`
Expected: `All tests passed!` (3 tests) — exercises the same Darwin plugin source but through the iOS `UIViewController`/`WKWebView` path (`sharedDarwinSource: true` means it's the same Swift file as macOS, but the runtime UI path differs, so this is a real, distinct check).

- [ ] **Step 3: If a test fails here but passed on macOS**

Do not paper over it — this means the shared Darwin source has an iOS-specific bug (e.g. a UIKit-only API behaving differently). Stop and report the failure; it is a real finding, not a flake to retry away.

---

### Task 6: Android emulator run (best-effort, local)

**Files:** none (verification only).

- [ ] **Step 1: Check for an available emulator**

Run: `(fvm flutter emulators || flutter emulators)`
If none listed, run `flutter emulators --create` or skip this task — Task 7's CI workflow covers Android regardless, so this task is a nice-to-have local confidence check, not a blocker.

- [ ] **Step 2: Launch it and run the suite**

Run: `(fvm flutter emulators --launch <emulator-id> || flutter emulators --launch <emulator-id>)`, wait for boot, then:
Run: `cd example && (fvm flutter test integration_test/webcontent_converter_test.dart -d <emulator-id> || flutter test integration_test/webcontent_converter_test.dart -d <emulator-id>)`
Expected: `All tests passed!` (3 tests) — exercises `android/src/main/kotlin/.../WebcontentConverterPlugin.kt` for real.

- [ ] **Step 3: If no emulator can be started in this environment**

Skip this task and rely on Task 7's `reactivecircus/android-emulator-runner` CI job for Android coverage. Note in the final report that Android was verified via CI config only, not a local run.

---

### Task 7: CI workflow across all four platforms

**Files:**
- Create: `.github/workflows/integration_test.yml`

**Interfaces:**
- Consumes: `example/integration_test/webcontent_converter_test.dart` (Tasks 2-4).

- [ ] **Step 1: Write the workflow**

```yaml
name: Integration Tests

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

env:
  FLUTTER_VERSION: "3.41.9"

jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
      - run: flutter pub get
      - run: flutter pub get
        working-directory: example
      - name: Run integration tests on Android emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          target: google_apis
          arch: x86_64
          working-directory: example
          script: flutter test integration_test/webcontent_converter_test.dart -d emulator-5554

  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
      - run: flutter pub get
      - run: flutter pub get
        working-directory: example
      - name: Boot an iOS simulator
        run: |
          UDID=$(xcrun simctl list devices available iPhone | grep -m1 -Eo '[0-9A-F-]{36}')
          echo "SIMULATOR_UDID=$UDID" >> "$GITHUB_ENV"
          xcrun simctl boot "$UDID"
      - name: Run integration tests on iOS simulator
        working-directory: example
        run: flutter test integration_test/webcontent_converter_test.dart -d "$SIMULATOR_UDID"

  macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
      - run: flutter pub get
      - run: flutter pub get
        working-directory: example
      - name: Run integration tests on macOS
        working-directory: example
        run: flutter config --enable-macos-desktop && flutter test integration_test/webcontent_converter_test.dart -d macos

  windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
      - run: flutter pub get
      - run: flutter pub get
        working-directory: example
      - name: Run integration tests on Windows
        working-directory: example
        run: |
          flutter config --enable-windows-desktop
          flutter test integration_test/webcontent_converter_test.dart -d windows
```

- [ ] **Step 2: Validate YAML syntax locally**

Run: `python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/integration_test.yml'))" && echo "valid yaml"`
Expected: `valid yaml` with no exception.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/integration_test.yml
git commit -m "ci: run integration tests on android, ios, macos, and windows"
```

- [ ] **Step 4: Push and confirm the workflow runs**

This step requires the user's explicit go-ahead to push (per repo convention: never push without asking). Once pushed, watch the four jobs in the GitHub Actions tab; report back which passed/failed rather than assuming success.

---

## Known Limitations (report these, don't silently work around them)

- The Android CI job assumes the emulator device id `emulator-5554`, which is `reactivecircus/android-emulator-runner`'s standard default — if that action's default ever changes, the job needs updating to match.
- `contentToPDFImage`'s Windows/macOS-specific branch (native `contentToPDF` passthrough + temp-file cleanup, see [webcontent_converter_io.dart:445-458](../../../lib/src/webcontent_converter/webcontent_converter_io.dart#L445-L458)) is only exercised by the macOS and Windows CI jobs; Android/iOS exercise the direct `contentToPDFImage` channel branch instead — this mirrors production behavior exactly, so it's correct, not a gap.
- These tests assert *shape* (valid PNG/PDF, non-trivial size) rather than pixel-perfect visual regression. Visual regression (e.g. "does the receipt still look right") is out of scope for this plan — flag to the user as a possible follow-up if wanted.

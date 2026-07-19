# macOS `printPreview`: Route Through Native WKWebView Print Pipeline

## Problem

`WebcontentConverter.printPreview()` already has three platform-specific
paths
([webcontent_converter_io.dart:610-652](../../../lib/src/webcontent_converter/webcontent_converter_io.dart#L610-L652)):

- **Windows** resolves `content` (fetching via `Dio` if only a `url` was
  given) and invokes this package's own native channel, because
  `flutter_inappwebview_windows` declares `printCurrentPage` on its Dart
  controller but never implemented the native handler for it
  (`MissingPluginException` at runtime).
- **Mobile** (Android/iOS) invokes the native channel directly.
- **macOS** is the outlier: it calls `_printPreviewViaInAppWebView`, which
  spins up a `flutter_inappwebview` `HeadlessInAppWebView` and calls
  `controller.printCurrentPage()` — a second, independent WebView
  integration that bypasses this package's own `ConversionQueue` /
  `RequestWatchdog` job serialization (added in the "Darwin WebView Queue &
  Watchdog" work,
  `docs/superpowers/specs/2026-07-19-darwin-webview-queue-design.md`)
  entirely.

A native macOS `printPreview` handler already exists in
`SwiftWebcontentConverterPlugin.swift`
([SwiftWebcontentConverterPlugin.swift:817-937](../../../darwin/Classes/SwiftWebcontentConverterPlugin.swift#L817-L937))
and *is* wired through the queue/watchdog job pattern like
`contentToImage`/`contentToPDF` — it's simply never called from Dart. It
also has real gaps that would surface immediately if it were wired up
today:

1. **Crash risk.** `content` is force-unwrapped
   (`wv.loadHTMLString(content!, baseURL: baseURL)`,
   [SwiftWebcontentConverterPlugin.swift:936](../../../darwin/Classes/SwiftWebcontentConverterPlugin.swift#L936)).
   A url-only call (no `content`) would crash instead of erroring.
2. **No real pagination/sizing.** The WebView is pinned to a fixed 800×600
   frame
   ([SwiftWebcontentConverterPlugin.swift:876](../../../darwin/Classes/SwiftWebcontentConverterPlugin.swift#L876)),
   then printed via the generic `NSPrintOperation(view: webView,
   printInfo:)`
   ([SwiftWebcontentConverterPlugin.swift:992](../../../darwin/Classes/SwiftWebcontentConverterPlugin.swift#L992)).
   This treats the WebView as a plain `NSView` and does not use WebKit's
   own print/pagination pipeline, so output doesn't reflect the actual
   page format or full content.
3. **`format` argument ignored entirely**, `margins` are converted with the
   wrong factor: `margins["left"] * 72.0 / 96.0`
   ([SwiftWebcontentConverterPlugin.swift:985-988](../../../darwin/Classes/SwiftWebcontentConverterPlugin.swift#L985-L988))
   treats the value as CSS pixels (96/inch), but `PdfMargins.toMap()`
   always sends **inches**
   ([page.dart:126-133](../../../lib/page.dart#L126-L133)) — the same
   "points vs. pixels" class of bug already fixed for `contentToPDF` in
   commit `f8e1284`, just not yet applied here.
4. **`jobDisposition = .preview`**
   ([SwiftWebcontentConverterPlugin.swift:981](../../../darwin/Classes/SwiftWebcontentConverterPlugin.swift#L981))
   routes output straight to Preview.app rather than showing the standard
   print panel — inconsistent with `showsPrintPanel = true` two lines
   below it, and not what "print preview" should mean here.

## Chosen approach

### Dart: mirror Windows' wiring, not macOS's current one

Replace the macOS branch of `printPreview()`
([webcontent_converter_io.dart:632-646](../../../lib/src/webcontent_converter/webcontent_converter_io.dart#L632-L646))
with the same shape as the Windows branch immediately above it — resolve
`content` from `url` via `Dio` if needed, then invoke the native channel —
but also forward `margins`/`format`, which the native macOS handler (unlike
Windows' `ShowPrintUI`, which exposes no such controls) will now honor:

```dart
} else if (io.Platform.isMacOS) {
  WebcontentConverter.logger
      .info("[printPreview] macOS: using native WKWebView print dialog");
  String? resolvedContent = content;
  if (resolvedContent == null && url != null) {
    final response = await Dio().get(url);
    resolvedContent = response.data.toString();
  }
  if (resolvedContent == null) {
    throw ArgumentError('printPreview requires either a url or content');
  }
  await _channel.invokeMethod('printPreview', {
    'content': resolvedContent,
    'duration': duration ?? 0,
    'margins': _margins.toMap(),
    'format': format.toMap(),
  });
  return true;
}
```

`_printPreviewViaInAppWebView`, `_buildMarginCss`, `_buildInAppWebViewSize`,
their test-only exports, and the `flutter_inappwebview` import are deleted
entirely (see Cleanup below) — nothing else in this package uses them.

### Native macOS: `WKWebView.printOperation(with:)` instead of generic `NSPrintOperation(view:)`

WKWebView exposes `printOperation(with printInfo: NSPrintInfo) ->
NSPrintOperation` (macOS 10.13+, package's `osx.deployment_target` is
already 10.15), which hands printing off to WebKit's own print pipeline —
content is laid out for the print media/page size described by the
`NSPrintInfo`, the same way Safari's print does, independent of the
WebView's on-screen frame. This replaces the manual frame-resize approach
`contentToPDF` uses (JS content measurement, page slicing) — that approach
exists there because `createPDF(configuration:)` needs an explicit source
rect per slice; `printOperation(with:)` needs no such thing, since
pagination is WebKit's problem once `NSPrintInfo.paperSize` is set
correctly.

Rewritten macOS branch of the `printPreview` case:

1. **Guard `content`** with a `FlutterError(code: "INVALID_ARGUMENT", ...)`
   instead of force-unwrapping, matching the existing guard shape in
   `contentToPDF`'s macOS branch.
2. **Parse `format`** the same way `contentToPDF` already does: if
   `formatName == "custom"`, use `format["width"]`/`format["height"]`
   (inches); otherwise `PaperFormat.fromString(formatName)`. Convert to
   points (`* 72.0`) for `NSPrintInfo.paperSize`.
3. **Parse `margins`** as inches → points directly (`* 72.0`, dropping the
   erroneous `/ 96.0`), fixing bug #3 above.
4. **Build `NSPrintInfo`**: `paperSize`, `topMargin`/`bottomMargin`/
   `leftMargin`/`rightMargin` as above; leave `jobDisposition` at its
   default (removing the `.preview` override) so `showsPrintPanel = true`
   shows the standard system print panel with its own live preview —
   fixing bug #4 above, and matching what Windows' `ShowPrintUI` shows.
5. **No frame resize.** The WebView is created and loaded as today (a
   reasonable fixed frame is fine purely for initial page rendering); the
   800×600-tied `NSPrintOperation(view:)` call is replaced with
   `webView.printOperation(with: printInfo)`, configured with
   `showsPrintPanel = true`, `showsProgressPanel = true`, `jobTitle`.
6. **Timing/queue behavior is unchanged** from the existing job: watchdog
   disarmed immediately before `printOperation.run()` (already the case,
   and still required — `run()` blocks in a nested event loop until the
   user dismisses the panel), `finish { result(nil); teardown() }` after
   `run()` returns, same as today.

## Non-goals

- Changing Windows, Android, iOS, or Linux/web `printPreview` behavior —
  iOS's `UIPrintInteractionController` path in the same native file is
  untouched.
- Any change to `contentToImage` or `contentToPDF` (Dart or native).
- Landscape/orientation handling — `format.width`/`height` map directly to
  `paperSize` as given; no new orientation logic is introduced beyond what
  exists today (pre-existing gap, out of scope).
- Removing `autoClose` from the Dart API surface — it's already ignored by
  every native `printPreview` path (Windows, mobile, and now macOS); left
  as a harmless unused argument rather than a breaking API change.

## Cleanup

- Delete `_printPreviewViaInAppWebView`, `_buildMarginCss`,
  `_buildInAppWebViewSize`, and their `buildMarginCssForTest`/
  `buildInAppWebViewSizeForTest` exports from `webcontent_converter_io.dart`.
- Delete the `import 'package:flutter_inappwebview/flutter_inappwebview.dart' as iaw;`
  line.
- Delete the corresponding `_buildMarginCss`/`_buildInAppWebViewSize` test
  groups (lines 21-47) and the split hide/show import (lines 3-6) in
  `test/webcontent_converter_test.dart`, replacing the import with a plain
  `import 'package:webcontent_converter/webcontent_converter.dart';`.
- Remove `flutter_inappwebview: ^6.1.5` from `pubspec.yaml`. Confirmed
  unused elsewhere in this package (`embedWebView` uses `AppKitView`/
  `UiKitView`/`AndroidView` backed by this package's own
  `FLNativeViewFactory`, not `flutter_inappwebview`); the podspec has no
  native dependency on it either. Consuming apps in this monorepo that use
  `flutter_inappwebview` (e.g. `adaptive_webview`) declare it directly in
  their own `pubspec.yaml`, so this doesn't affect their builds.

## Testing

- **Dart unit tests**: add a `printPreview` group to
  `test/native_channel_test.dart` (mocking `MethodChannel`, following the
  existing pattern for `contentToImage`/`contentToPDF`) covering: macOS
  path sends `content`/`margins`/`format` with url resolved via `Dio` when
  only `url` is given; throws `ArgumentError` when neither `url` nor
  `content` is given.
- **Manual verification** (native Swift changes have no unit coverage in
  this repo): run the `example/` app on macOS, call `printPreview` with
  content-only and url-only inputs, confirm the system print panel appears
  sized to the requested format/margins with no crash, confirm Cancel and
  Print both resolve the queue (no stuck `TOO_MANY_REQUESTS` on a
  follow-up call).

## Risks / things to verify during implementation

- Confirm `webView.printOperation(with:)` actually reflects `paperSize`/
  margins in the print panel's preview for typical HTML content (tables,
  receipts) — this is the load-bearing assumption behind dropping the
  manual frame-resize approach entirely.
- Confirm dropping `jobDisposition = .preview` doesn't change default
  printer-selection behavior in a way that breaks any existing downstream
  automation (unlikely, since this is a user-facing interactive dialog by
  design, but worth a quick manual check).

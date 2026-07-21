# Windows `contentToImage` Paper Format Support: Design

**Status: implemented.** The original plan below (rasterizing via WebView2's
own built-in PDF viewer) was attempted first and abandoned after real
testing surfaced problems no amount of parameter-tuning fixed — see
"What actually shipped" at the end of this doc for the approach that
replaced it.

## Problem

`contentToImage` accepts an `args: {"format": {...}}` paper-size map on
every platform's Dart call site (see
[content_pdf_image_screen_controller.dart:54-59](../../../example/lib/screens/controllers/content_pdf_image_screen_controller.dart#L54-L59)
for exactly this usage with `PaperFormat.a4`), but **Windows silently
ignored it**:

- `windows/webcontent_converter_plugin.cpp`'s `HandleContentToImage` only
  read `content` and `duration` out of the arguments map — no `format`, no
  `margins`, and not even `scale` (which the Dart API always sends,
  default `3`, and which every other platform's `contentToImage` also
  ignores today — a separate, smaller gap noted below but out of scope for
  this design).
- `windows/image_capture_request.cpp` (`ImageCaptureRequest`) always
  measures the page's natural `scrollWidth`/`scrollHeight` via JS and
  captures exactly that. There was no code path that sized the capture to
  a fixed paper size.

The other three platforms all honor `format` for `contentToImage`, with
varying implementations:

- **Android** (`WebcontentConverterPlugin.kt`, `PdfPrinter.kt`): when
  `format` is present, routes through `view.toPDFBitmap(format, margins,
  ...)` — prints the WebView to a PDF via `PrintAttributes` sized to the
  paper format, then rasterizes **every** page of that PDF via
  `android.graphics.pdf.PdfRenderer` and stitches them into one tall
  bitmap, one page per vertical slot at the paper's pixel size
  (`PdfPrinter.kt`'s `convertPdfToBitmapBytes`). This is the
  cross-platform precedent this design follows for multi-page content.
- **macOS**: resizes the WKWebView's capture width to the paper's pixel
  width before `takeSnapshot`; height still follows natural content (no
  page-splitting).
- **iOS**: renders via `UIPrintPageRenderer` at the paper's fixed pixel
  size.

Confirmed with the user this is a real gap they hit via their own
invoice-format testing (`letter`, `legal`, `tabloid`, `ledger`,
`a0`–`a6`), and that it should be fixed by reusing the PDF pipeline
(`PdfConversionRequest`, already paper-geometry-correct) rather than
teaching the screenshot capture path paper geometry from scratch.

## Attempt 1 (abandoned): rasterize via WebView2's own PDF viewer

The original plan: generate a PDF via the existing `PdfConversionRequest`,
then load it into WebView2's built-in Chromium/PDFium viewer
(`webview->Navigate(L"file:///...")`) and screenshot it page-by-page via
the same `Page.captureScreenshot` DevTools call `ImageCaptureRequest`
already uses, stitching multi-page output vertically to mirror Android's
`PdfPrinter.kt`.

This required a new `WebView2Session::NavigateToUrl` capability (nothing
in this plugin previously navigated WebView2 to a real URL — everything
else serves synthetic in-memory HTML), a `/Type/Page` byte-scan page-count
heuristic, and hiding the PDF viewer's toolbar via
`ICoreWebView2Settings7::put_HiddenPdfToolbarItems`.

**Why it was abandoned.** Real testing (not just documentation reading)
surfaced two distinct, compounding problems:

1. **Solid-gray output.** The controller was resized to the target pixel
   size *after* `NavigationCompleted` fired, with capture happening
   immediately after — the compositor hadn't repainted at the new size
   yet, so `Page.captureScreenshot` reliably captured stale/blank content.
   Fixed by sizing the controller *before* navigating (Chrome's PDF viewer
   computes its automatic-fit zoom from the viewport size at load time,
   not continuously) plus a short settle delay — confirmed by the
   before/after PNG byte size going from a suspiciously identical 6032
   bytes across three different parameter attempts to a real, varying
   ~36-39KB once fixed.
2. **Uncontrollable auto-zoom (the actual blocker).** Once real content
   was captured, the PDF page rendered at roughly 38% of the target
   viewport with gray letterboxing around it. Neither the documented
   `#zoom=100` PDF Open Parameter fragment nor resizing the viewport
   before vs. after navigation changed this at all — output was
   byte-for-byte identical across attempts, ruling out a timing race and
   pointing at a hardcoded/undocumented auto-fit behavior in Edge's
   built-in PDF viewer that the public WebView2 API surface doesn't
   expose a way to override. A further diagnostic (3x larger viewport, to
   determine if the page scaled proportionally) produced a *different*
   failure (blank output again) instead of a clean answer — evidence this
   was genuinely undocumented, version-sensitive Chromium behavior rather
   than one missing parameter.

Given an embedded browser's PDF viewer chrome/zoom is not really a
public, stable contract to build on, this was dropped in favor of a real
PDF rasterizer once the user confirmed the pivot.

## What actually shipped: WinRT `Windows.Data.Pdf`

`PdfImageCaptureRequest` (`windows/pdf_image_capture_request.h/.cpp`):

1. Generates a PDF at the requested paper size/margins via the
   **unchanged** `PdfConversionRequest` (same class `contentToPDF` uses),
   to a temp file.
2. Loads that file via `winrt::Windows::Storage::StorageFile` +
   `winrt::Windows::Data::Pdf::PdfDocument::LoadFromFileAsync`.
3. Reads `PageCount` directly from the API — no byte-scan heuristic
   needed, unlike Attempt 1.
4. For each page: `PdfPage::RenderToStreamAsync` with
   `PdfPageRenderOptions::DestinationWidth`/`DestinationHeight` set to the
   paper size in pixels (96 DPI, matching Android's own pixel convention
   for `contentToImage`) — a real rasterizer call, not a browser viewport
   at the mercy of auto-zoom.
5. Drains each rendered page into a `Gdiplus::Bitmap` (via
   `SHCreateMemStream`, an idiom already used elsewhere in this codebase)
   and draws it into a combined canvas at the correct vertical offset,
   mirroring Android's per-page stitching loop exactly.
6. Encodes the combined canvas via the existing `EncodeHBitmapAsPng`
   (`windows/png_encoder.h`, now also exposing `EnsureGdiplusStarted` so
   this file can construct `Gdiplus::Bitmap` objects directly, not just
   call the one existing encode entry point).
7. Deletes the temp PDF on every exit path (success, failure, timeout —
   handled once in the destructor and once in `Succeed`/`Fail`).

`windows/webcontent_converter_plugin.cpp`'s `HandleContentToImage` now
reads `format`/`margins` the same way `HandleContentToPdf` already does,
and routes to `PdfImageCaptureRequest` when `format` is present; without
it, behavior is unchanged (`ImageCaptureRequest`'s natural-size path).

### New build surface: C++/WinRT, scoped to this plugin only

This is the first use of C++/WinRT (and coroutines) in this codebase.
`windows/CMakeLists.txt` adds, for this plugin's target only:

```cmake
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_20)
target_link_libraries(${PLUGIN_NAME} PRIVATE "WindowsApp.lib")
```

`target_compile_features` is per-target and additive across calls — CMake
uses the highest standard requested for a given target, so this raises
only `webcontent_converter_plugin` to C++20 (for native `<coroutine>`
support) without touching the Runner exe or any other plugin, which stay
on the app-wide C++17 from `apply_standard_settings`. `WindowsApp.lib` is
the standard, documented umbrella import lib Win32 (non-UWP-packaged)
apps link to call WinRT APIs — not something that requires UWP packaging.

`Windows.Data.Pdf` and `Windows.Storage.Streams` types used here are
agile/free-threaded, so no apartment marshaling is needed around the
actual PDF-rendering calls; `RasterizeAsync` captures a
`winrt::apartment_context` up front and `co_await`s it once before
touching `this` or resolving the Flutter result, since the coroutine may
otherwise resume on a thread-pool thread after a `co_await`.

## Verified

Folded into the permanent suite
(`example/integration_test/webcontent_converter_test.dart`, group
`contentToImage with format (Windows PDF-rasterized path)`):

- A4, single-page short-receipt content → exact 794×1123px (96 DPI) PNG.
- Letter format, a longer invoice → correctly stitched multi-page PNG
  (816×2112px, i.e. exactly 2 letter-page heights), with table headers
  repeating cleanly across the page break, no gaps/overlaps at the seam.

Both the mock suite (`flutter test` from repo root) and the full
real-device integration suite
(`flutter test integration_test/webcontent_converter_test.dart -d
windows`) pass with no regressions to the existing
`contentToImage`/`contentToPDF`/`contentToPDFImage`/`isWebviewAvailable`
cases.

## Non-goals

- Changing Android, iOS, macOS, or Linux/web — this is Windows-only.
- Fixing `scale` being ignored by `contentToImage`'s existing natural-size
  path (`ImageCaptureRequest`) on any platform — a real, separate gap
  noticed during this investigation, but unrelated to paper-format support
  and not something the user asked to fix here.
- Changing the wire format of `contentToImage` as seen from Dart — `args:
  {"format": {...}, "margins": {...}}` already worked on every other
  platform; this only makes Windows honor what's already sent.

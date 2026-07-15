# macOS Multi-Page PDF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `WebcontentConverter.contentToPDF` on macOS emit a real multi-page PDF — each page sized to the requested `PaperFormat` (A4, Letter, custom, etc.) minus margins — instead of one arbitrarily tall single page.

**Architecture:** Mechanically slice the rendered content into fixed-height, page-sized chunks (no CSS print-media awareness), capture each slice with `WKWebView.createPDF`, and merge the resulting single-page PDF blobs into one multi-page document with PDFKit. Two of the three new pieces are pure/testable Swift (page geometry math, PDF merge composition); the third (WebKit capture loop) is native rendering glue verified manually through the example app.

**Tech Stack:** Swift, WebKit (`WKWebView`/`WKPDFConfiguration`), PDFKit (`PDFDocument`, `PDFPage`), Core Graphics (`CGContext` PDF context), XCTest.

## Global Constraints

- Design source of truth: `docs/superpowers/specs/2026-07-15-macos-multipage-pdf-design.md`.
- CSS print-media pagination fidelity (page-break-inside, orphans/widows, `@page`) is explicitly out of scope — mechanical fixed-height slicing is acceptable, including cutting a table row or paragraph across a page boundary.
- Only the macOS branch of `contentToPDF` in `darwin/Classes/SwiftWebcontentConverterPlugin.swift` changes. iOS, Windows, Linux, and `contentToPDFImage` are unaffected.
- "No format requested" (auto-size) mode must keep producing exactly one page sized to fit all content, unchanged from today — pagination only kicks in when a `PaperFormat` is supplied.
- New public Swift symbols must be `public` (not `internal`) because macOS unit tests live in a separate module (`RunnerTests`, part of the example app) that imports `webcontent_converter`.
- All geometry units are CSS pixels @ 96 DPI, matching the existing `inchToPx`/`PaperFormat.widthPixels`/`heightPixels` convention in `darwin/Classes/Page.swift`.

---

### Task 1: Page-slice geometry helper

**Files:**
- Modify: `darwin/Classes/Page.swift` (append to end of file)
- Test: `example/macos/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Produces: `public struct PdfPageSlice { public let sourceY: Double; public let sourceHeight: Double; public init(sourceY: Double, sourceHeight: Double) }` and `public func computePdfPageSlices(contentHeight: Double, pageHeight: Double, marginTop: Double, marginBottom: Double) -> [PdfPageSlice]`, both consumed by Task 3.

- [ ] **Step 1: Write the failing tests**

Open `example/macos/RunnerTests/RunnerTests.swift` and replace its contents with:

```swift
import Cocoa
import FlutterMacOS
import XCTest
import webcontent_converter

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testComputePdfPageSlices_contentShorterThanOnePage_returnsSingleSliceMatchingActualContent() {
    let slices = computePdfPageSlices(contentHeight: 300, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 1)
    XCTAssertEqual(slices[0].sourceY, 0)
    XCTAssertEqual(slices[0].sourceHeight, 300)
  }

  func testComputePdfPageSlices_exactMultipleOfPageHeight_returnsExpectedPageCount() {
    // usableHeight = 1000 - 100 = 900; content = 1800 = exactly 2 pages.
    let slices = computePdfPageSlices(contentHeight: 1800, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 2)
    XCTAssertEqual(slices[0].sourceY, 0)
    XCTAssertEqual(slices[0].sourceHeight, 900)
    XCTAssertEqual(slices[1].sourceY, 900)
    XCTAssertEqual(slices[1].sourceHeight, 900)
  }

  func testComputePdfPageSlices_withRemainder_lastPageIsShorter() {
    // usableHeight = 900; content = 2000 -> ceil(2000/900) = 3 pages, last = 2000 - 1800 = 200.
    let slices = computePdfPageSlices(contentHeight: 2000, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 3)
    XCTAssertEqual(slices[2].sourceY, 1800)
    XCTAssertEqual(slices[2].sourceHeight, 200)
  }

  func testComputePdfPageSlices_zeroContent_returnsSingleSliceWithMinimumPositiveHeight() {
    let slices = computePdfPageSlices(contentHeight: 0, pageHeight: 1000, marginTop: 50, marginBottom: 50)
    XCTAssertEqual(slices.count, 1)
    XCTAssertEqual(slices[0].sourceHeight, 1)
  }

  func testComputePdfPageSlices_marginsExceedPageHeight_clampsUsableHeightToMinimumOne() {
    // usableHeight would be negative (100 - 120 = -20) and is clamped to a
    // minimum of 1, so degenerate margins degrade to many 1-unit-tall
    // pages instead of a negative-size rect or a crash.
    let slices = computePdfPageSlices(contentHeight: 10, pageHeight: 100, marginTop: 60, marginBottom: 60)
    XCTAssertEqual(slices.count, 10)
    XCTAssertEqual(slices.first?.sourceHeight, 1)
    XCTAssertEqual(slices.last?.sourceY, 9)
    XCTAssertEqual(slices.last?.sourceHeight, 1)
  }
}
```

- [ ] **Step 2: Run tests to verify they fail to compile**

Run: `cd example/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests 2>&1 | tail -40`
Expected: FAIL — compile error, `computePdfPageSlices` / `PdfPageSlice` not found in module `webcontent_converter` (if `pod install` hasn't run yet for this checkout, run `cd example/macos && pod install` first).

- [ ] **Step 3: Implement the geometry helper**

Append to `darwin/Classes/Page.swift`:

```swift
// MARK: - PDF Page Slicing

/// A single page's vertical slice of rendered source content, expressed in
/// the same coordinate space as the resized WKWebView frame used to render
/// it (CSS pixels @ 96 DPI, matching `PaperFormat.heightPixels`).
public struct PdfPageSlice {
    public let sourceY: Double
    public let sourceHeight: Double

    public init(sourceY: Double, sourceHeight: Double) {
        self.sourceY = sourceY
        self.sourceHeight = sourceHeight
    }
}

/// Compute the vertical slices needed to paginate `contentHeight` worth of
/// rendered content into pages of `pageHeight`, after subtracting
/// `marginTop`/`marginBottom` (the usable content height per page).
///
/// Always returns at least one slice. A single page whose content is
/// shorter than the usable page height captures exactly that content's
/// height (not padded to a full page) — the merge step is responsible for
/// placing it at the top margin and leaving the remainder blank.
public func computePdfPageSlices(
    contentHeight: Double,
    pageHeight: Double,
    marginTop: Double,
    marginBottom: Double
) -> [PdfPageSlice] {
    let usableHeight = max(1.0, pageHeight - marginTop - marginBottom)
    let clampedContentHeight = max(0.0, contentHeight)

    if clampedContentHeight <= usableHeight {
        return [PdfPageSlice(sourceY: 0, sourceHeight: max(clampedContentHeight, 1.0))]
    }

    let pageCount = Int(ceil(clampedContentHeight / usableHeight))
    return (0..<pageCount).map { pageIndex in
        let sourceY = Double(pageIndex) * usableHeight
        let sourceHeight = min(usableHeight, clampedContentHeight - sourceY)
        return PdfPageSlice(sourceY: sourceY, sourceHeight: sourceHeight)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd example/macos && pod install && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests 2>&1 | tail -40`
Expected: PASS — all 6 tests (including the pre-existing `testExample`) succeed.

- [ ] **Step 5: Commit**

```bash
git add darwin/Classes/Page.swift example/macos/RunnerTests/RunnerTests.swift
git commit -m "feat: add page-slice geometry helper for macOS PDF pagination"
```

---

### Task 2: PDF page merge helper

**Files:**
- Create: `darwin/Classes/PdfPageMerger.swift`
- Test: `example/macos/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1 directly (independent geometry input), but is consumed together with Task 1's output in Task 3.
- Produces: `public func mergePdfPageSlices(pageDatas: [Data], pageWidth: Double, pageHeight: Double, marginTop: Double, marginLeft: Double) -> Data?`, consumed by Task 3.

- [ ] **Step 1: Write the failing tests**

Append to the `RunnerTests` class in `example/macos/RunnerTests/RunnerTests.swift` (before the closing `}` of the class):

```swift

  private func makeTestPdfPageData(width: CGFloat, height: CGFloat) -> Data {
    let pdfData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
      fatalError("failed to create test PDF context")
    }
    context.beginPDFPage(nil)
    context.setFillColor(NSColor.red.cgColor)
    context.fill(mediaBox)
    context.endPDFPage()
    context.closePDF()
    return pdfData as Data
  }

  func testMergePdfPageSlices_emptyInput_returnsNil() {
    let result = mergePdfPageSlices(pageDatas: [], pageWidth: 800, pageHeight: 1000, marginTop: 50, marginLeft: 50)
    XCTAssertNil(result)
  }

  func testMergePdfPageSlices_invalidPdfData_returnsNil() {
    let result = mergePdfPageSlices(
      pageDatas: [Data([0x00, 0x01, 0x02])],
      pageWidth: 800, pageHeight: 1000, marginTop: 50, marginLeft: 50
    )
    XCTAssertNil(result)
  }

  func testMergePdfPageSlices_twoSlices_producesTwoPagesAtRequestedSize() {
    let slice1 = makeTestPdfPageData(width: 700, height: 900)
    let slice2 = makeTestPdfPageData(width: 700, height: 300)

    let merged = mergePdfPageSlices(
      pageDatas: [slice1, slice2],
      pageWidth: 800, pageHeight: 1000, marginTop: 50, marginLeft: 50
    )

    XCTAssertNotNil(merged)
    let document = PDFDocument(data: merged!)
    XCTAssertNotNil(document)
    XCTAssertEqual(document?.pageCount, 2)

    for pageIndex in 0..<2 {
      let bounds = document!.page(at: pageIndex)!.bounds(for: .mediaBox)
      XCTAssertEqual(Double(bounds.width), 800, accuracy: 0.5)
      XCTAssertEqual(Double(bounds.height), 1000, accuracy: 0.5)
    }
  }
```

Add `import PDFKit` and `import Quartz` (for `CGDataConsumer`) alongside the existing imports at the top of `example/macos/RunnerTests/RunnerTests.swift`:

```swift
import Cocoa
import FlutterMacOS
import XCTest
import PDFKit
import webcontent_converter
```

(`CGDataConsumer`/`CGContext` come from Core Graphics, already transitively available via `Cocoa`.)

- [ ] **Step 2: Run tests to verify they fail to compile**

Run: `cd example/macos && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests 2>&1 | tail -40`
Expected: FAIL — compile error, `mergePdfPageSlices` not found in module `webcontent_converter`.

- [ ] **Step 3: Implement the merge helper**

Create `darwin/Classes/PdfPageMerger.swift`:

```swift
//
//  PdfPageMerger.swift
//  webcontent_converter
//

import Foundation
import CoreGraphics
import PDFKit

/// Compose a sequence of single-page PDF byte blobs (each already cropped
/// to one page's worth of source content, in page order) into one PDF
/// document. Each slice is drawn into a full `pageWidth` x `pageHeight`
/// page, offset by `marginLeft`/`marginTop` so the printable margin stays
/// blank around the content — mirroring the margin-as-inset semantics the
/// iOS pagination path already uses in `exportAsPdfFromWebView`.
///
/// Returns `nil` if `pageDatas` is empty, if the PDF context can't be
/// created, or if any entry isn't a valid single-page PDF.
public func mergePdfPageSlices(
    pageDatas: [Data],
    pageWidth: Double,
    pageHeight: Double,
    marginTop: Double,
    marginLeft: Double
) -> Data? {
    guard !pageDatas.isEmpty else { return nil }

    let outputData = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    guard let consumer = CGDataConsumer(data: outputData as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        return nil
    }

    for sliceData in pageDatas {
        guard let sliceDocument = PDFDocument(data: sliceData),
              let slicePage = sliceDocument.page(at: 0) else {
            return nil
        }

        let sliceBounds = slicePage.bounds(for: .mediaBox)
        // Content hangs from the top margin; its own height determines how
        // far down the page it reaches (shorter than a full page on the
        // last page of a document).
        let originY = pageHeight - marginTop - Double(sliceBounds.height)

        context.beginPDFPage(nil)
        context.saveGState()
        context.translateBy(x: CGFloat(marginLeft), y: CGFloat(originY))
        slicePage.draw(with: .mediaBox, to: context)
        context.restoreGState()
        context.endPDFPage()
    }

    context.closePDF()
    return outputData as Data
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd example/macos && pod install && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests 2>&1 | tail -40`
Expected: PASS — all 9 tests succeed.

- [ ] **Step 5: Commit**

```bash
git add darwin/Classes/PdfPageMerger.swift example/macos/RunnerTests/RunnerTests.swift
git commit -m "feat: add PDF page merge helper for macOS PDF pagination"
```

---

### Task 3: Wire pagination into `contentToPDF` on macOS

**Files:**
- Modify: `darwin/Classes/SwiftWebcontentConverterPlugin.swift:488-563` (macOS branch of the `contentToPDF` case)

**Interfaces:**
- Consumes: `computePdfPageSlices(contentHeight:pageHeight:marginTop:marginBottom:) -> [PdfPageSlice]` (Task 1), `mergePdfPageSlices(pageDatas:pageWidth:pageHeight:marginTop:marginLeft:) -> Data?` (Task 2).
- Produces: no new public API — same `contentToPDF` platform-channel contract (`result(savedPath)` on success, `result(nil)` on failure).

- [ ] **Step 1: Replace the macOS content-sizing and PDF-generation block**

In `darwin/Classes/SwiftWebcontentConverterPlugin.swift`, inside the macOS `contentToPDF` case, find this block (starting right after `// 🔧 AUTO HEIGHT & WIDTH - Get actual content dimensions`):

```swift
                                let formatName = format?["name"] as? String
                                if(format != nil && formatName != nil  && ((formatName?.isEmpty) != nil) ) {
                                    if formatName == "custom" {
                                        // ✅ CUSTOM: Use width and height from format dictionary
                                        let customWidth = CGFloat(inchToPx(format!["width"] as? Double ?? 1.0))
                                        let customHeight = CGFloat(inchToPx(format!["height"] as? Double ?? 1.0))
                                                                            
                                        print("📐 Using custom format - width: \(customWidth), height: \(customHeight)")
                                        
                                        contentWidth = customWidth + marginLeft + marginRight; // 300 DPI = high-quality print
                                        contentWidth = customHeight + marginTop + marginBottom;
                                    } else {
                                        let paperFormat =  PaperFormat.fromString(formatName!);
                                        contentWidth = CGFloat(paperFormat.widthPixels) + marginLeft + marginRight + 300; // 300 DPI = high-quality print resolution
                                        //                                    contentHeight = CGFloat(paperFormat.heightPixels);
                                    }
                                }
                                
                                print("📏 WebView frame: \(self.webView.frame)")
                                print("📏 Content size: \(contentWidth) x \(contentHeight)")

                                // Resize the WebView to match content size for full capture
                                let originalFrame = self.webView.frame
                                let fullContentFrame = CGRect(
                                    x: 0, y: 0, width: contentWidth, height: contentHeight)

                                self.webView.frame = fullContentFrame
                                print("📏 WebView fullContentFrame: \(fullContentFrame)")
                                
                                    DispatchQueue.main.asyncAfter(
                                        deadline: .now() + (duration! / 10000)
                                    ) {
                                        if #available(macOS 11.0, *) {
                                            let configuration = WKPDFConfiguration()
                                            configuration.rect = CGRect(
                                                origin: .zero, size: fullContentFrame.size)

                                            self.webView.createPDF(configuration: configuration) {
                                                (pdfResult) in
                                                switch pdfResult {
                                                case .success(let data):
                                                    // Save PDF data to the specified path
                                                    do {
                                                        let url = URL(fileURLWithPath: savedPath!)
                                                        try data.write(to: url)
                                                        print(
                                                            "✅ PDF saved successfully to: \(savedPath!) (\(data.count) bytes)"
                                                        )
                                                        result(savedPath!)  // Return the saved path
                                                    } catch {
                                                        print(
                                                            "❌ Failed to save PDF: \(error.localizedDescription)"
                                                        )
                                                        result(nil)
                                                    }
                                                    self.dispose()
                                                case .failure(let error):
                                                    print(
                                                        "❌ PDF creation failed: \(error.localizedDescription)"
                                                    )
                                                    result(nil)
                                                    self.dispose()
                                                }
                                            }
                                        } else {
                                            result(nil)
                                        }
                                    
                                }
```

Replace it with:

```swift
                                let formatName = format?["name"] as? String

                                let pageWidthPx: Double
                                let pageHeightPx: Double
                                if let formatName = formatName, !formatName.isEmpty {
                                    if formatName == "custom" {
                                        pageWidthPx = inchToPx(format!["width"] as? Double ?? 1.0)
                                        pageHeightPx = inchToPx(format!["height"] as? Double ?? 1.0)
                                    } else {
                                        let paperFormat = PaperFormat.fromString(formatName)
                                        pageWidthPx = Double(paperFormat.widthPixels)
                                        pageHeightPx = Double(paperFormat.heightPixels)
                                    }
                                } else {
                                    // No explicit format: preserve the existing "one page,
                                    // sized to fit all content" behavior instead of paginating
                                    // against an arbitrary page size. Padding pageHeight by the
                                    // margins guarantees computePdfPageSlices always returns
                                    // exactly one slice below.
                                    pageWidthPx = Double(contentWidth) + Double(marginLeft) + Double(marginRight)
                                    pageHeightPx = Double(contentHeight) + Double(marginTop) + Double(marginBottom)
                                }

                                let renderWidth = max(1.0, pageWidthPx - Double(marginLeft) - Double(marginRight))

                                print("📏 WebView frame: \(self.webView.frame)")
                                print("📏 Page geometry: \(pageWidthPx) x \(pageHeightPx), render width: \(renderWidth)")

                                // Resize the WebView to the full rendered content height at the
                                // printable width, so every Y-coordinate in its frame maps 1:1
                                // to a document Y-offset for the page slicing below.
                                let originalFrame = self.webView.frame
                                let fullContentFrame = CGRect(
                                    x: 0, y: 0, width: renderWidth, height: Double(contentHeight))
                                self.webView.frame = fullContentFrame
                                print("📏 WebView fullContentFrame: \(fullContentFrame)")

                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + (duration! / 10000)
                                ) {
                                    guard #available(macOS 11.0, *) else {
                                        result(nil)
                                        self.dispose()
                                        return
                                    }

                                    let slices = computePdfPageSlices(
                                        contentHeight: Double(contentHeight),
                                        pageHeight: pageHeightPx,
                                        marginTop: Double(marginTop),
                                        marginBottom: Double(marginBottom)
                                    )
                                    print("📄 Total pages: \(slices.count)")

                                    self.capturePdfPageSlicesSequentially(slices: slices, pageWidth: renderWidth) { pageDatas in
                                        self.webView.frame = originalFrame

                                        guard let pageDatas = pageDatas,
                                              let mergedData = mergePdfPageSlices(
                                                pageDatas: pageDatas,
                                                pageWidth: pageWidthPx,
                                                pageHeight: pageHeightPx,
                                                marginTop: Double(marginTop),
                                                marginLeft: Double(marginLeft)
                                              )
                                        else {
                                            print("❌ PDF page capture or merge failed")
                                            result(nil)
                                            self.dispose()
                                            return
                                        }

                                        do {
                                            let url = URL(fileURLWithPath: savedPath!)
                                            try mergedData.write(to: url)
                                            print(
                                                "✅ PDF saved successfully to: \(savedPath!) (\(mergedData.count) bytes, \(pageDatas.count) pages)"
                                            )
                                            result(savedPath!)
                                        } catch {
                                            print("❌ Failed to save PDF: \(error.localizedDescription)")
                                            result(nil)
                                        }
                                        self.dispose()
                                    }
                                }
```

- [ ] **Step 2: Add the sequential page-capture helper**

In `darwin/Classes/SwiftWebcontentConverterPlugin.swift`, add this private method to the `SwiftWebcontentConverterPlugin` class, directly above `func dispose() {` (around line 684):

```swift
    #if os(macOS)
        private func capturePdfPageSlicesSequentially(
            slices: [PdfPageSlice],
            pageWidth: Double,
            index: Int = 0,
            collected: [Data] = [],
            completion: @escaping ([Data]?) -> Void
        ) {
            guard index < slices.count else {
                completion(collected)
                return
            }

            let slice = slices[index]
            let configuration = WKPDFConfiguration()
            configuration.rect = CGRect(
                x: 0, y: slice.sourceY, width: pageWidth, height: slice.sourceHeight)

            self.webView.createPDF(configuration: configuration) { pdfResult in
                switch pdfResult {
                case .success(let data):
                    self.capturePdfPageSlicesSequentially(
                        slices: slices,
                        pageWidth: pageWidth,
                        index: index + 1,
                        collected: collected + [data],
                        completion: completion
                    )
                case .failure(let error):
                    print("❌ PDF page \(index) creation failed: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    #endif

```

- [ ] **Step 3: Build the example app for macOS to confirm compilation**

Run: `cd example && flutter build macos --debug 2>&1 | tail -60`
Expected: `Building macOS application...` completes without Swift compiler errors. If it fails on unresolved `computePdfPageSlices`/`mergePdfPageSlices`/`PdfPageSlice`, re-run `cd macos && pod install` first (new Swift files need to be picked up by the pod's file list, which CocoaPods derives from `Classes/**/*` in the podspec — no podspec change needed, but a fresh `pod install` ensures Xcode's project file references the new `PdfPageMerger.swift`).

- [ ] **Step 4: Manually verify multi-page output**

Temporarily edit `example/lib/screens/controllers/content_pdf_screen_controller.dart`'s `convert()` method — replace the `content:` argument's value (both the ternary and its usage) with a long synthetic string so the content clearly exceeds one A4 page:

```dart
    final longContent = '<html><body>' +
        List.generate(120, (i) => '<p>Line $i - multi-page pagination test</p>').join() +
        '</body></html>';

    final result = await WebcontentConverter.contentToPDF(
      content: longContent,
      savedPath: savedPath,
      format: PaperFormat.a4,
      margins: PdfMargins.inches(top: 0.25, bottom: 0.25, right: 0.25, left: 0.25),
      executablePath: WebViewHelper.executablePath(),
    );
```

Run: `cd example && flutter run -d macos`

In the running app, navigate to the content-to-PDF screen and tap the convert/generate action. Then:

1. Find the generated file — the app logs the saved path via `WebcontentConverter.logger.info(result ?? '')`; look for a line like `.../Documents/sample_<timestamp>.pdf` in the `flutter run` console output.
2. Open it: `open "<the path printed above>"`.
3. In Preview.app, open the sidebar (View > Thumbnails) and confirm there are multiple pages (with 120 lines of text at default font size on A4, expect roughly 3-5 pages).
4. Select a page and check Tools > Show Inspector > page size reads approximately 8.27in x 11.7in (A4) — not one tall custom-sized page.
5. Revert the temporary edit to `content_pdf_screen_controller.dart` (`git checkout -- example/lib/screens/controllers/content_pdf_screen_controller.dart`) once verified — it was for manual testing only, not a permanent fixture.

Expected: multi-page PDF at correct A4 page size, content flowing across pages with no crash and no console errors from `capturePdfPageSlicesSequentially`/`mergePdfPageSlices`.

- [ ] **Step 5: Manually verify the no-format (auto-size) case is unaffected**

In the same running app session (or re-run), trigger `contentToPDF` with no `format` argument or with the existing demo flow's default path (short invoice content, `counter.isOdd` branch already uses `PaperFormat.a4` — to test the *auto* single-page path specifically, temporarily call `WebcontentConverter.contentToPDF` with `format` omitted, or add a quick throwaway button). Confirm the resulting PDF is still exactly one page sized to fit the content (not paginated into multiple pages), matching pre-change behavior. Revert any throwaway test code afterward.

- [ ] **Step 6: Commit**

```bash
git add darwin/Classes/SwiftWebcontentConverterPlugin.swift example/macos/Podfile.lock
git commit -m "feat: paginate macOS contentToPDF output into PaperFormat-sized pages"
```

(Include `example/macos/Podfile.lock` only if `pod install` in Step 3 changed it as a result of picking up the new `PdfPageMerger.swift` source file.)

---

## Self-Review Notes

- **Spec coverage:** Task 1 covers the geometry algorithm from the spec's "Algorithm" steps 4-5; Task 2 covers step 6's merge/margin behavior; Task 3 covers steps 1-3 and 7-8 (frame resize, sequential capture, write-and-return, failure-stops-the-loop). The spec's "Existing bug fixed" section (dead code at old lines 504-505) is resolved by Task 3 Step 1 replacing that whole block. The `((formatName?.isEmpty) != nil)` always-true condition bug is also fixed as a natural consequence of the Task 3 rewrite (replaced with `if let formatName = formatName, !formatName.isEmpty`).
- **Non-goals honored:** `contentToPDFImage`, iOS, Windows, and Linux paths are untouched by every task. The "auto/no-format" single-page behavior is explicitly preserved and has its own verification step (Task 3 Step 5).
- **Type consistency:** `PdfPageSlice.sourceY`/`sourceHeight`, `computePdfPageSlices`'s signature, and `mergePdfPageSlices`'s signature are declared identically in Tasks 1-2 and consumed with matching argument labels/types in Task 3.

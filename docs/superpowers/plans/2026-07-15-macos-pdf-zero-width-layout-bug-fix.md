# macOS contentToPDF Zero-Width Layout Bug Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix macOS `contentToPDF` producing more pages than expected for content using percentage-based CSS widths, by creating the `WKWebView` at its target render width *before* loading content instead of resizing it afterward.

**Architecture:** Move the page-geometry computation (`pageWidthPx`/`pageHeightPx`/`renderWidth`) that already exists in the pagination code so it runs *before* `WKWebView` creation instead of after. Construct the WebView at that width (or, for auto-size mode where no format-derived width exists yet, a reasonable 800px default matching the rest of the plugin) from the start, so WebKit's first layout pass resolves percentage-based widths against a definite containing block. Everything downstream (measurement, slicing, capture, merge) is otherwise unchanged.

**Tech Stack:** Swift, WebKit (`WKWebView`).

## Global Constraints

- Design source of truth: `docs/superpowers/specs/2026-07-15-macos-pdf-zero-width-layout-bug-design.md`.
- Only the macOS branch of `contentToPDF` in `darwin/Classes/SwiftWebcontentConverterPlugin.swift` changes (lines 449-586 in the current merged code). iOS, Windows, Linux, and `contentToImage` (which already creates its WebView at a fixed non-zero width) are unaffected.
- The pagination math itself (`computePdfPageSlices`, `mergePdfPageSlices`, `capturePdfPageSlicesSequentially`) does not change — this fix only changes how/when the WebView is sized before those functions run.
- For a `PaperFormat`-specified request (named or `custom`), the WebView's *starting* width must equal the final `renderWidth` exactly (no width change between creation and pagination) — this is what fixes the reported bug.
- For auto-size mode (no format given), the WebView's starting width must be a reasonable non-zero default (`800`, matching `contentToImage`'s existing macOS default frame and the Puppeteer path's default viewport) — the *final* width used for pagination is still whatever the content naturally measures as within that budget, unchanged from today's behavior.
- The WebView's starting *height* must be small (e.g. `10`) — a large starting height causes `document.documentElement.clientHeight`/`scrollHeight` to report the placeholder height instead of true content height, per direct testing during diagnosis.
- Short-label's 4→5 page margin-overflow behavior is out of scope and must not change.

---

### Task 1: Create the WebView at its target width before loading content

**Files:**
- Modify: `darwin/Classes/SwiftWebcontentConverterPlugin.swift:451-583` (macOS `contentToPDF` case body, from reading `savedPath`/`format`/`margins` through the end of the `urlObservation` closure)

**Interfaces:**
- Consumes: `computePdfPageSlices`, `mergePdfPageSlices`, `capturePdfPageSlicesSequentially` — unchanged signatures, called the same way as today.
- Produces: no new public API — same `contentToPDF` platform-channel contract (`result(savedPath)` on success, `result(nil)` on failure).

- [ ] **Step 1: Replace the macOS `contentToPDF` case body**

In `darwin/Classes/SwiftWebcontentConverterPlugin.swift`, find the macOS branch of the `contentToPDF` case — it starts right after `#else` (following `#if os(iOS)` for the `contentToPDF` case) with the comment `// macOS PDF generation implementation`, and ends right before the matching `#endif` / `break` for that case. Replace the entire block with:

```swift
                // macOS PDF generation implementation
                let path = arguments!["savedPath"] as? String
                let savedPath = URL.init(string: path!)?.path
                let format = arguments!["format"] as? [String: Any]
                let margins = arguments!["margins"] as? [String: Double]

                print("format \(String(describing: format))")
                print("margins \(String(describing: margins))")

                guard let content = content else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "Content is required", details: nil))
                    return
                }

                let marginTop = CGFloat(inchToPx(margins?["top"] ?? 0.0))
                let marginBottom = CGFloat(inchToPx(margins?["bottom"] ?? 0.0))
                let marginLeft = CGFloat(inchToPx(margins?["left"] ?? 0.0))
                let marginRight = CGFloat(inchToPx(margins?["right"] ?? 0.0))
                let formatName = format?["name"] as? String

                // Determine the WebView's starting width UP FRONT, before any
                // content loads, so WebKit's initial layout pass resolves
                // percentage-based CSS widths (width: 50%, width: 100%, etc.)
                // against a definite containing block instead of collapsing
                // them to 0 — see
                // docs/superpowers/specs/2026-07-15-macos-pdf-zero-width-layout-bug-design.md.
                // When a PaperFormat is specified this is also the FINAL
                // render width (fully known from format + margins,
                // independent of content). In auto-size mode (no format),
                // there's no content-independent target width yet, so fall
                // back to the same 800px default contentToImage's macOS
                // branch and the Puppeteer path already use.
                let initialFormatWidthPx: Double?
                let initialFormatHeightPx: Double?
                if let formatName = formatName, !formatName.isEmpty {
                    if formatName == "custom" {
                        initialFormatWidthPx = inchToPx(format!["width"] as? Double ?? 1.0)
                        initialFormatHeightPx = inchToPx(format!["height"] as? Double ?? 1.0)
                    } else {
                        let paperFormat = PaperFormat.fromString(formatName)
                        initialFormatWidthPx = Double(paperFormat.widthPixels)
                        initialFormatHeightPx = Double(paperFormat.heightPixels)
                    }
                } else {
                    initialFormatWidthPx = nil
                    initialFormatHeightPx = nil
                }

                let initialRenderWidth = max(
                    1.0, (initialFormatWidthPx ?? 800.0) - Double(marginLeft) - Double(marginRight))

                self.webView = WKWebView(
                    frame: CGRect(x: 0, y: 0, width: initialRenderWidth, height: 10))
                self.webView.isHidden = false
                self.webView.loadHTMLString(content, baseURL: Bundle.main.resourceURL)
                self.webView.viewWithTag(100)

                urlObservation = webView.observe(
                    \.isLoading,
                    changeHandler: { (webView, change) in
                        print("macOS WebView finished loading")

                        // First, get the actual content size by evaluating JavaScript
                        self.webView.evaluateJavaScript(
                            "Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight)"
                        ) { (height, error) in

                            self.webView.evaluateJavaScript(
                                "Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth)"
                            ) { (width, error) in
                                // 🔧 AUTO HEIGHT & WIDTH - Get actual content dimensions
                                let contentWidth = width as? Double ?? CGFloat(PaperFormat.a4.widthPixels)  // Fallback to A4 width
                                let contentHeight = height as? Double ?? CGFloat(PaperFormat.a4.heightPixels)  // Fallback to A4 height

                                let pageWidthPx: Double
                                let pageHeightPx: Double
                                if let formatWidthPx = initialFormatWidthPx,
                                   let formatHeightPx = initialFormatHeightPx {
                                    pageWidthPx = formatWidthPx
                                    pageHeightPx = formatHeightPx
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

                                // Grow the WebView's frame to the full content height at
                                // the SAME width it was already loaded/laid-out at
                                // (renderWidth for a formatted request never changes here
                                // — only height grows to fit content), so every
                                // Y-coordinate in its frame maps 1:1 to a document
                                // Y-offset for the page slicing below, and the
                                // percentage-width layout already resolved correctly
                                // against the width set before load is undisturbed.
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
                            }
                        }
                    })
```

(This replaces the `var contentWidth`/`var contentHeight` from the current code with `let` — they're no longer reassigned anywhere in this block, since the format-branch no longer touches them and the auto-size branch only reads them.)

- [ ] **Step 2: Build the example app for macOS to confirm compilation**

Run: `cd example && flutter build macos --debug 2>&1 | tail -60`
Expected: `✓ Built build/macos/Build/Products/Debug/example.app` with no Swift compiler errors.

If this is a fresh worktree checkout, first copy the gitignored local-Chrome assets and install pods:
```bash
cp -R <path-to-a-checkout-with-them>/example/assets/.apps example/assets/
cd example/macos && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
```

- [ ] **Step 3: Verify the invoice repro case now produces 3 pages**

Add a temporary end-to-end test to `example/macos/RunnerTests/RunnerTests.swift` (reverted after verification — do not commit it):

```swift
import Cocoa
import FlutterMacOS
import XCTest
import PDFKit
import webcontent_converter

// TEMPORARY — added for manual verification, removed before committing.
extension RunnerTests {
  func testDiagnostic_zeroWidthFix_invoiceProducesThreePages() {
    let html = """
<html lang="en"><head>
<style>
body, p { margin: 0; padding: 0; font-family: sans-serif; }
p { line-height: 22px; }
.full-width { width: 100%; }
.inline-block { display: inline-block; }
.half { width: 50%; }
.left { float: left; }
.right { float: right; }
</style>
</head><body>
<div class="full-width inline-block">
  <div class="half left">
    <p>Store</p><p>Name: multi store name</p><p>Address: unknown</p>
    <p>Phone: 010464144</p><p>Email: multi.store@mylekha.app</p>
    <p>Date: Saturday, 26/Apr/2025 08:54</p><p>Invoice: S3519-1000066</p>
    <p>Reference: ......................</p>
  </div>
  <div class="half right">
    <p>Customer</p><p>Name: Walk-In</p><p>Address: ........................</p>
    <p>Phone: 0718887569</p><p>Email: ........................</p>
    <p>Payment: completed</p>
  </div>
</div>
<p>Note:</p>
<table width="100%">
""" + String(repeating: "<tr><td>Item</td><td>1.00</td><td>$1.00</td></tr>", count: 40) + """
</table>
</body></html>
"""
    let savedPath = "/tmp/zero_width_fix_verification.pdf"
    let plugin = SwiftWebcontentConverterPlugin()
    let call = FlutterMethodCall(
      methodName: "contentToPDF",
      arguments: [
        "content": html,
        "savedPath": savedPath,
        "duration": 2000.0,
        "format": ["name": "a4", "width": 8.27, "height": 11.7],
        "margins": ["top": 0.25, "bottom": 0.25, "left": 0.25, "right": 0.25],
      ]
    )
    let expectation = self.expectation(description: "zero-width-fix-verification")
    var pageCount: Int?
    plugin.handle(call) { result in
      if let path = result as? String, let doc = PDFDocument(url: URL(fileURLWithPath: path)) {
        pageCount = doc.pageCount
      }
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: 30)
    XCTAssertNotNil(pageCount, "contentToPDF should have produced a PDF")
    print("🔬 VERIFICATION page count: \(String(describing: pageCount))")
  }
}
```

Run: `cd example/macos && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests 2>&1 | tail -40`

Check the printed page count (search the xcresult console log via `xcrun xcresulttool get log --path <xcresult-path> --type console` if `print()` output doesn't appear directly in the `xcodebuild` stdout, or add a file-write diagnostic as a fallback — this was necessary during the original investigation for this exact plugin).

Expected: the synthetic fixture above (structurally equivalent to the real invoice repro: `.half.left`/`.half.right` at 50% width, a `width:100%` table) produces a page count consistent with its content actually fitting the page width (not 50%-collapsed) — verify by also checking `.half` elements' `getBoundingClientRect().width` is non-zero if you extend the test with the same layout-inspection JS used during diagnosis (`document.querySelectorAll('.half')` → `getBoundingClientRect()`).

- [ ] **Step 4: Verify the short-label case is unaffected (still exactly 1 page over budget → 5 pages)**

Using the same temporary-test pattern, run `contentToPDF` with `Demo.getShortLabelContent()`-equivalent content (4 `.label` divs, each `width: 1.0in; height: 1.0in`), `format: {name: "custom", width: 1.0, height: 1.0}`, `margins: {top: 0.01, bottom: 0.01, left: 0.01, right: 0.01}`. Expected: still 5 pages (unchanged — this is the confirmed-correct margin-overflow behavior, not something this fix touches).

- [ ] **Step 5: Revert the temporary test**

```bash
git checkout -- example/macos/RunnerTests/RunnerTests.swift
```

Confirm `git diff example/macos/RunnerTests/RunnerTests.swift` is empty before committing.

- [ ] **Step 6: Run the existing RunnerTests suite to confirm no regression**

Run: `cd example/macos && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=macOS' -only-testing:RunnerTests 2>&1 | tail -20`
Expected: all 9 existing tests still pass (the geometry and merge helper tests are unaffected by this change, since it only touches WebView creation timing, not `computePdfPageSlices`/`mergePdfPageSlices`).

- [ ] **Step 7: Commit**

```bash
git add darwin/Classes/SwiftWebcontentConverterPlugin.swift
git commit -m "fix: create macOS contentToPDF WebView at target width before loading content

Percentage-based CSS widths (width: 50%, width: 100%) were resolving to 0
because the WebView was created at a zero-size frame, content loaded
against that indeterminate containing block, and only resized afterward
— which does not re-resolve already-collapsed percentage widths. Sizing
the WebView correctly before load fixes pagination for any content using
percentage widths (e.g. a real invoice going from 6 pages down to the
expected 3)."
```

---

## Self-Review Notes

- **Spec coverage:** The design's "Chosen approach" section (compute geometry before WebView creation, small starting height, width-only-fixed-not-resized-for-formatted-case) is fully implemented in Task 1 Step 1. The "Non-goals" (short-label margin behavior, Khmer rendering, `contentToImage`, other platforms) are respected — no other files touched.
- **Placeholder scan:** None found — Step 1 has the complete replacement code; Steps 3-4 have concrete, runnable verification content and expected outcomes.
- **Scope check:** Single task, single file, tightly scoped — no decomposition needed.
- **Type consistency:** `initialFormatWidthPx`/`initialFormatHeightPx` are `Double?`, matching how they're consumed (`if let formatWidthPx = ..., let formatHeightPx = ...`). `pageWidthPx`/`pageHeightPx`/`renderWidth` keep the same names, types, and downstream usage (`computePdfPageSlices`, `capturePdfPageSlicesSequentially`, `mergePdfPageSlices`) as the code this replaces.

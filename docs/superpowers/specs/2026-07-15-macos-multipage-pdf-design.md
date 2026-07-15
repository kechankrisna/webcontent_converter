# macOS Multi-Page PDF Design

## Problem

On macOS, `WebcontentConverter.contentToPDF` (routed to the native Swift
plugin) always produces a single PDF page whose height equals the full
rendered content height — see `SwiftWebcontentConverterPlugin.swift:449-568`.
`PaperFormat` height (e.g. A4's 11.7in) is measured but never actually used
to size the page; only width is applied. There is no pagination: long
invoices/receipts come out as one very tall page instead of standard-size
pages (A4, Letter, etc.), unlike the Windows/Linux path
(`_contentToPDFViaPuppeteer` in `webcontent_converter_io.dart`) and the iOS
path (`exportAsPdfFromWebView`, which already paginates via
`UIPrintPageRenderer`).

## Goal

Make macOS `contentToPDF` emit a real multi-page PDF, where each page is
sized to the requested `PaperFormat` (minus margins), and content that
exceeds one page's height flows onto subsequent pages.

## Chosen approach: mechanical slicing + PDFKit merge

Confirmed with the user: CSS-print-aware pagination (respecting
`page-break-inside: avoid`, `@page`, orphans/widows) is **not** required.
Mechanical, fixed-height slicing is acceptable — content (e.g. a table row)
may be visually cut across a page boundary. This rules out needing the
AppKit print pipeline (`WKWebView.printOperation(with:)`) or routing macOS
through Puppeteer (which the project has deliberately moved away from on
desktop, per the recent `HeadlessInAppWebView` migration for
`contentToImage`).

`PDFKit` is already imported in `SwiftWebcontentConverterPlugin.swift` and
currently unused.

### Algorithm

1. Load `content` into a `WKWebView`, exactly as today.
2. Measure `scrollWidth`/`scrollHeight` via JS, exactly as today.
3. Resize the webview's frame to `(measuredWidth, measuredHeight)` — the
   full content, laid out with no internal scrolling — exactly as today.
   This makes every Y-coordinate in that frame equal to a document Y-offset,
   which is what makes rect-based slicing below possible.
4. Compute the fixed per-page geometry from the requested `PaperFormat` and
   margins:
   - `pageWidthPx = paperFormat.widthPixels`
   - `pageHeightPx = paperFormat.heightPixels`
   - `marginTopPx`, `marginBottomPx`, `marginLeftPx`, `marginRightPx` from
     the existing `margins` dict (already converted via `inchToPx`).
   - `contentSliceHeightPx = pageHeightPx - marginTopPx - marginBottomPx`
     (must be `> 0`; if margins exceed page height, clamp to a minimum of
     `1` and proceed rather than dividing by zero/negative).
5. `pageCount = max(1, ceil(measuredHeight / contentSliceHeightPx))`.
6. For `pageIndex` in `0..<pageCount`, sequentially (not concurrently — the
   existing GPU-crash-avoidance comments in this file indicate WKWebView
   rendering on macOS is fragile under concurrent load):
   - `sliceY = pageIndex * contentSliceHeightPx`
   - `sliceHeight = min(contentSliceHeightPx, measuredHeight - sliceY)`
     (last page is shorter than a full page).
   - Call `webView.createPDF(configuration:)` with
     `configuration.rect = CGRect(x: 0, y: sliceY, width: measuredWidth, height: sliceHeight)`.
   - The returned single-page PDF `Data` is wrapped with
     `PDFDocument(data:)` and its one page appended to an accumulating
     `PDFDocument`, at an origin offset so the slice lands inside a
     full-`pageHeightPx`-tall page with `marginTopPx` of blank space above
     it (mechanical margin application — no text/graphics are drawn in the
     margin itself).
7. After all pages are captured, write the accumulated `PDFDocument` to
   `savedPath` and return that path via the `result` callback, matching the
   existing success/failure contract.
8. On any per-slice `createPDF` failure, stop the loop and call
   `result(nil)` (matching today's single-shot failure behavior) rather
   than producing a partial PDF.

### Non-goals / explicitly out of scope

- CSS print-media pagination fidelity (page-break-inside, orphans/widows,
  `@page` rules) — not required per user decision.
- Changing `contentToPDFImage`'s macOS path (`flutter_inappwebview` /
  `HeadlessInAppWebView.createPdf`) — out of scope for this change; it may
  have the same single-page limitation but is a separate code path and a
  separate decision.
- Changing iOS, Windows, or Linux PDF generation — unaffected.
- Headers/footers/page numbers on generated pages.

### Risks accepted

- Table rows or paragraphs may be visually cut across a page boundary
  (explicitly accepted).
- Sequential `createPDF` calls mean generation time scales roughly linearly
  with page count; acceptable for the plugin's typical use case
  (receipts/invoices, low page counts).
- The `y`-offset cropping behavior of `WKPDFConfiguration.rect` against a
  webview resized to full content height is inferred from the identical,
  already-proven pattern used for `WKSnapshotConfiguration.rect` elsewhere
  in this file (image capture). This must be empirically verified against
  real multi-page content during implementation (Task 2's manual
  verification step covers this).

## Existing bug fixed as part of this change

Lines 504-505 currently compute `contentWidth` from the custom width, then
immediately overwrite it with a height+margin expression before it's used
for anything — dead, contradictory code. This is subsumed by the rewrite
described above, which stops using JS-measured height as the *page* height
entirely (it's only used to compute `pageCount`).

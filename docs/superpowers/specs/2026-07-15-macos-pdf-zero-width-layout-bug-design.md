# macOS contentToPDF Zero-Width Layout Bug: Design

## Problem

After the recent macOS multi-page pagination work
([2026-07-15-macos-multipage-pdf-design.md](2026-07-15-macos-multipage-pdf-design.md)),
`contentToPDF` on macOS produces *more pages than expected* for content that
uses percentage-based CSS widths (`width: 50%`, `width: 100%`, `<table
width="100%">`, etc.) — which is common, ordinary CSS, not exotic content.

Two concrete repro cases (from the example app's demo content):

- `Demo.getInvoiceContent()` with `PaperFormat.a4` + 0.25in margins:
  expected 3 pages, produced **6**.
- `Demo.getShortLabelContent()` with a 1×1in custom format + 0.01in
  margins: expected 4 pages, produced **5** (this one is unrelated — see
  "Known non-issue" below).

## Root cause (confirmed by direct measurement)

`SwiftWebcontentConverterPlugin.swift`'s macOS `contentToPDF` case:

1. Creates `self.webView = WKWebView()` — a **default, zero-size frame**.
2. Calls `loadHTMLString`, which triggers WebKit's **initial layout pass**
   against that zero/indeterminate-width containing block.
3. Only *afterward* — once `isLoading` flips false and JS-measured
   width/height come back — does it resize `self.webView.frame` to the
   correct print width (`renderWidth`, derived from the requested
   `PaperFormat` and margins).

Per the CSS box model, a percentage width (`width: 50%`) that has to
resolve against an **indeterminate-width** containing block computes to
`0` (CSS 2.1 §10.3.3). This was directly confirmed: the invoice content's
`.half.left` / `.half.right` columns (`width: 50%`, floated) both measured
`width: 0` and identical `x` position (i.e. stacked on top of each other
instead of side-by-side) when queried via `getBoundingClientRect()` after
the existing zero-frame→resize flow. With zero width, their text content
has nowhere to flow, so it wraps to roughly one word per line — inflating
the column's (and therefore the document's) total height severalfold.

Critically, **resizing `webView.frame` afterward does not fix this**.
WebKit does not appear to re-resolve already-computed 0%-width
descendants just because the containing `NSView`'s frame changed later —
this was verified directly: re-measuring `.half` elements' widths *after*
the resize-to-`renderWidth` step (which is exactly what today's code
does) still reports `width: 0`, `x: 15` for both columns.

**Direct proof of the fix:** building a *second* `WKWebView`, sized to the
correct final `renderWidth` (745px, for this A4+0.25in-margins case)
*before* `loadHTMLString` is ever called, gives:
- `.half` elements: `width: 357.5` each, at `x: 15` and `x: 372.5`
  (correctly side-by-side, not stacked)
- Content height: **2510px** — within 6% of an independent headless-Chrome
  measurement of the same HTML at the same width (2664px), and consistent
  with the pagination the user expects (`ceil(2510/1075) = 3` pages)

This also explains why the label content was unaffected (4→5 pages is a
separate, unrelated issue — see below): its CSS uses only fixed absolute
widths (`width: 1.0in`) throughout, never percentages, so it never
triggers the indeterminate-containing-block case.

`contentToImage`'s macOS branch does **not** have this bug — it already
creates its `WKWebView` with a fixed, non-zero starting frame
(`CGRect(x: 0, y: 0, width: 800, height: 300)`) before loading content.
`contentToPDF` is the only affected path.

### Ruled out during investigation

Before landing on the containing-block-width explanation, these
hypotheses were tested and rejected with direct evidence (kept here so a
future investigator doesn't re-tread the same ground):

- **Measurement-width timing** (content measured at a different width
  than final render): disproven — re-measuring at the *same* renderWidth
  before vs. after the existing resize gave identical heights (5830 both
  times), because the resize doesn't actually fix anything (see above).
- **`<meta name="viewport">` tag**: removing it made no difference
  (5830px unchanged).
- **Web font loading race** (`duration! / 10000` giving only ~0.2s to
  wait, vs. `printPreview`'s `duration! / 1000`): `document.fonts.status`
  was already `"loaded"` at the first measurement, and re-measuring after
  an explicit extra 4s wait gave an identical height.
- **Khmer-script font-weight mismatch** (only weights 100/200/300
  `@import`ed for "Noto Serif Khmer", body text renders at default 400):
  forcing `font-weight: 300` explicitly changed height by <1%. Forcing
  `font-family: 'Noto Sans', sans-serif !important` everywhere made
  height *worse*, not better.
- **Khmer script content itself**: stripping all Khmer characters did
  reduce height by ~33% (5830→3897), confirming Khmer text is *a*
  contributor to overall document height (likely just because Khmer glyph
  runs are visually wider/taller, unrelated to the width bug), but this
  alone doesn't explain the full gap — the zero-width containing-block
  bug affects percentage-width layout throughout the *entire* document
  (header section alone showed an even worse WebKit/Chromium ratio than
  the full document), independent of script.

## Known non-issue: short-label's 4→5 pages

Confirmed via the same measurement technique that WebKit and Chromium
agree exactly on this content's height (384px both) — there is no
rendering bug here. 4 labels × 96px = 384px of content, but each *page*
only has 94.08px of usable height after subtracting the 0.01in margins
(pageHeight 96px − marginTop 0.96px − marginBottom 0.96px). 4 × 94.08 =
376.32px < 384px, so the last ~7.68px of the 4th label legitimately spills
onto a 5th page. This is correct behavior given non-zero margins and is
**out of scope for this fix** (confirmed with the user — see the parent
session's decision to leave margin-driven pagination as-is).

## Chosen approach

Create the `WKWebView` at its **target render width** before calling
`loadHTMLString`, instead of the current zero-frame-then-measure-then-resize
sequence. Two cases:

1. **`PaperFormat` specified** (named format or `custom`): the target
   `renderWidth` is already computable from `format` + `margins` alone,
   with **no dependency on content** — this is exactly the geometry
   computation the multi-page pagination work already does (see
   `pageWidthPx`/`pageHeightPx`/`renderWidth` in the current code). Move
   that computation *before* WebView creation, and construct the WebView
   directly at `(renderWidth, <small placeholder height>)`.
2. **No format specified** (auto-size mode): there's no content-independent
   target width to use. Use a reasonable non-zero default starting width
   instead of zero — `800px`, matching both `contentToImage`'s existing
   macOS default frame width and the Puppeteer path's default viewport
   width (`DeviceViewport(width: 800, height: 1000)` in
   `webcontent_converter_io.dart`), so this mode is at least consistent
   with how the rest of the plugin already behaves, and no longer
   triggers the indeterminate-containing-block bug. The final auto-sized
   page width is still whatever the content's natural width measures as
   at that 800px available width (matching today's `contentWidth`
   JS-measurement semantics) — this isn't a "final" width the way the
   formatted case's `renderWidth` is, it's just a non-zero *starting*
   width so percentage children resolve sanely.

After the WebView is created at the correct (or reasonable-default, for
auto mode) width and content has loaded, measure height only (via
`Math.max(document.body.scrollHeight, document.body.offsetHeight,
document.documentElement.clientHeight, document.documentElement.scrollHeight,
document.documentElement.offsetHeight)`, unchanged from today) — no
JS-measured width dependency remains for the formatted case, since width
is already fixed. Keep the WebView's placeholder starting height **small**
(e.g. `10`, not `0` and not a large sentinel) during this measurement:
`document.documentElement.clientHeight`/`scrollHeight` are spec'd to
report `max(content, viewport)`, so a large starting height would make
those two components report the *placeholder* height back instead of the
true content height (this was directly observed while diagnosing: a
`20000`-tall placeholder made `Math.max(...)` report `20000` regardless of
actual content). A small placeholder avoids that pitfall without needing
to change the existing 5-component measurement JS.

Once height is measured, resize `webView.frame`'s **height only** (width
stays fixed at the already-correct render width throughout) to the
measured content height, then proceed with the existing pagination logic
(`computePdfPageSlices` / sequential `createPDF` capture /
`mergePdfPageSlices`) entirely unchanged — this fix only touches *how the
WebView is created and sized before pagination begins*, not the
pagination math itself, which was already reviewed and approved.

### Non-goals

- Fixing the short-label margin-overflow behavior (confirmed as
  correct/out of scope above).
- Fully explaining the residual Khmer-script height contribution (~33% of
  the original gap) — that's real content-rendering behavior (Khmer glyph
  metrics), not a plugin bug, and isn't blocking correct pagination once
  the width bug is fixed.
- Changing `contentToImage`'s macOS path — already creates its WebView at
  a fixed non-zero width and is unaffected by this specific bug.
- Changing iOS, Windows, or Linux paths.

### Risks / things to verify during implementation

- The `guard #available(macOS 11.0, *)` check currently happens *after*
  WebView creation; `WKWebView` itself has no such availability
  constraint, so this ordering is fine, but `WKPDFConfiguration`/`createPDF`
  usage must stay behind the existing availability guard.
- Auto-size mode's `pageWidthPx`/`pageHeightPx` computation (padding by
  margins so `computePdfPageSlices` always returns one slice) depends on
  `contentWidth`/`contentHeight` measured *after* the WebView exists —
  this ordering is preserved, just the WebView's *starting* width changes
  from 0 to 800.
- Re-verify with the same invoice/label repro content used during
  diagnosis that page counts now match expectations (3 pages for the
  invoice, still 5 for the label — unchanged/expected).

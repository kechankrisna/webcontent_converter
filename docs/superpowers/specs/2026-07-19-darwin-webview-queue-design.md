# Darwin (iOS/macOS) WebView Queue & Watchdog: Design

## Problem

`SwiftWebcontentConverterPlugin.swift` (shared by iOS and macOS via `#if
os()`) creates a brand-new `WKWebView` on every `contentToImage`,
`contentToPDF`, and `printPreview` call, with no concurrency control and no
timeout:

1. **Race condition.** `webView` and `urlObservation` are single mutable
   class fields
   ([SwiftWebcontentConverterPlugin.swift:13-14](../../../darwin/Classes/SwiftWebcontentConverterPlugin.swift#L13-L14)),
   reassigned on every call. Completion closures throughout the file read
   `self.webView` directly (not a locally captured reference), so if two
   calls overlap, the second call's reassignment of `self.webView` makes
   the *first* call's still-pending completion logic operate on the
   *second* call's WebView instance — the same class of bug already fixed
   on Android (see
   `docs/superpowers/specs/2026-07-19-android-webview-queue-design.md`).
   `printPreview` shares these exact same fields too — unlike Android/
   Windows, which give print preview its own dedicated WebView instance,
   Darwin has no isolation between any of the three operations today.
2. **No concurrency control.** A burst of calls spins up N full `WKWebView`
   instances concurrently, each clobbering the shared fields, compounding
   bug #1. There is no `TOO_MANY_REQUESTS` rejection at any queue depth —
   Darwin has no queue at all.
3. **No timeout.** Completion is driven by KVO on `webView.isLoading`, with
   no equivalent of Android's `onReceivedError` / Windows' `on_error`. If
   the load never settles (bad content, network error, hung JS) the
   `FlutterResult` and its WebView are held forever — there is no watchdog
   to recover.

Android and Windows already solve the equivalent problem: a FIFO job queue
with one busy slot so requests serialize instead of racing, a bounded queue
size, and a per-request watchdog timeout. This design ports that pattern to
Darwin, adapted for the fact that Darwin (unlike Android's now-shared
`SharedWebViewSession`) already constructs a fresh `WKWebView` per request —
so the fix here is serialization + timeout, not session reuse.

## Chosen approach

Add two new files to `darwin/Classes/`, direct ports of their Android
counterparts, shared by iOS and macOS like every other file in that folder:

- **`ConversionQueue.swift`** — `requestInFlight: Bool` +
  `[() -> Void]` FIFO, `startOrQueue(_:)`, `onRequestFinished()`,
  `isQueueFull()` (cap at 32 pending jobs, matching Android's
  `MAX_QUEUED_REQUESTS` / Windows' `kMaxQueuedRequests`).
- **`RequestWatchdog.swift`** — one-shot timeout: `arm(timeoutMs:
  onTimeout:)` / `disarm()`, backed by
  `Timer.scheduledTimer(withTimeInterval:repeats:)` on the main run loop
  (Darwin's equivalent of Android's `Handler.postDelayed` / Windows'
  `SetTimer`), main-thread only, matching the rest of the plugin.

`SwiftWebcontentConverterPlugin` gains one
`let conversionQueue = ConversionQueue(maxQueuedRequests: 32)` instance
property. `handle()` keeps its existing `switch` structure; the entire body
of each of the three cases (`contentToImage`, `contentToPDF`,
`printPreview` — all three included, matching Android, since Darwin has no
per-operation WebView isolation to justify carving printPreview out the way
Windows does) becomes the job closure passed to
`conversionQueue.startOrQueue { ... }`. The existing capture/export logic
inside each case (WKPDFConfiguration page-slicing, `UIPrintPageRenderer`,
snapshot fallback chains) is not rewritten — only wrapped.

### Per-job lifecycle

1. Existing argument validation stays where it is (fails synchronously,
   before the job is ever queued) and gains an `isQueueFull()` check
   feeding `TOO_MANY_REQUESTS` — currently entirely missing on Darwin.
2. `watchdog.arm(timeoutMs, onTimeout)` at job start, before creating the
   `WKWebView`. `timeoutMs = max(30_000, durationMs + 30_000)`, same
   formula as Android — chosen over Windows' flat per-operation values
   because Darwin's job shape (single job, no multi-attempt capture retry
   loop) is architecturally closer to Android's than to Windows'
   `ImageCaptureRequest`.
3. A local `completed = false` flag and local `finish(_ action: () ->
   Void)` helper (same shape as Android's) guard every completion path:
   no-ops if already completed, else disarms the watchdog, calls
   `conversionQueue.onRequestFinished()`, then runs `action()` — slot freed
   **before** resolving to Flutter, same ordering Android/Windows use to
   stop the next queued call from racing the one currently completing.
   Every existing `result(...)` call site within the case (success paths,
   fallback paths, nil-returning failure paths) is wrapped in
   `finish { result(...) }` instead of called bare.
4. The completion signal for "page is ready" switches from the current
   `webView.observe(\.isLoading)` KVO to a real `WKNavigationDelegate`
   assigned per-job:
   - `webView(_:didFinish:)` proceeds into the existing (unchanged)
     settle-delay / measurement / capture logic.
   - `webView(_:didFail:)` and `webView(_:didFailProvisionalNavigation:)`
     call `finish { result(FlutterError(code: "WEBVIEW_LOAD_ERROR", ...))
     }` — new behavior; today a failed load has no failure signal at all,
     only eventual watchdog timeout.
   This replaces KVO as the completion source entirely (not layered
   alongside it) — same firing point as today's `!webView.isLoading`
   check, just from the canonical WebKit API instead of an isLoading
   side-channel, and it's what makes a `didFail` counterpart available on
   the same object.
5. Watchdog firing → `finish { result(FlutterError(code: "TIMEOUT", ...))
   }`.
6. **`printPreview` on macOS specifically: the watchdog is disarmed
   immediately before calling `printOperation.run()`, not left armed for
   the rest of the job.** `NSPrintOperation.run()` (unlike iOS's
   `UIPrintInteractionController.present(animated:completionHandler:)`,
   which is asynchronous and returns immediately) runs its own nested
   event loop and does not return until the user dismisses the print
   panel — so on macOS, `result(nil)`/`onRequestFinished()` only fire
   after the dialog closes, both today and under this design (see "Where
   this diverges" below for why this isn't changed). Applying the
   standard `max(30s, duration+30s)` job watchdog across that entire
   window would false-positive `TIMEOUT` during completely normal user
   interaction with the system print dialog — disarming just before
   `run()` avoids that while leaving the surrounding queue-slot behavior
   unchanged from the rest of this design.

### New error handling (doesn't exist today)

| Condition | Error code |
|---|---|
| Queue full (32 pending) | `TOO_MANY_REQUESTS` |
| `didFail` / `didFailProvisionalNavigation` | `WEBVIEW_LOAD_ERROR` |
| Watchdog fires before completion | `TIMEOUT` |
| Existing capture/export failure paths (snapshot nil, PDF merge fails, etc.) | unchanged — out of scope |

## Where this diverges from Android/Windows

- Unlike Android, Darwin does **not** move to a long-lived, reused
  `WKWebView`. Android's `SharedWebViewSession` reuse was an explicit,
  separately-confirmed choice for Android; Darwin already constructs a
  fresh `WKWebView` per job today, and this design leaves that as-is — the
  queue's serialization guarantee (only one job's fields alive at a time)
  is what removes the race, independent of whether the WebView itself is
  reused.
- Unlike Windows, `printPreview` is **not** carved out into its own
  dedicated WebView/window bypassing the queue. Windows can do that because
  `PrintPreviewWindow` owns a fully independent native window; Darwin's
  `printPreview` shares `self.webView`/`urlObservation` with the other two
  operations today, so it needs the same serialization they do. (This
  mirrors the same reasoning that put Android's `printPreview` through its
  queue too, though Android additionally gives `printPreview` its own
  dedicated `WebView` instance for a print-adapter lifetime reason that
  doesn't apply here.)
- **iOS and macOS resolve `printPreview` at different points, and this
  design does not unify them.** iOS's `UIPrintInteractionController
  .present(animated:completionHandler:)` is asynchronous — it returns
  immediately, so `result(nil)` (called right after `createWebPrintJob`
  returns) already resolves at hand-off, matching Android/Windows'
  "resolve at hand-off to the OS print flow, not at print completion"
  semantics. macOS's `NSPrintOperation.run()` is synchronous — it runs its
  own nested event loop and blocks until the user dismisses the print
  panel — so `result(nil)` there only fires once the dialog closes, both
  today and under this design; changing that would mean touching the
  existing case logic/timing rather than purely wrapping it, which is out
  of scope (see Non-goals). The practical consequence: on macOS, queued
  `contentToImage`/`contentToPDF`/other `printPreview` calls wait until
  the user closes the print dialog. This is an accepted, explicit
  tradeoff of routing `printPreview` through the shared queue at all, not
  an oversight — see the watchdog-disarm step in the per-job lifecycle
  above for how the timeout policy accounts for it.

## Non-goals

- Changing Android, Windows, or Linux/web plugin code.
- Rewriting or restructuring the existing capture/export logic (snapshot
  fallback chains, `UIPrintPageRenderer` math, macOS PDF page-slicing) —
  only wrapping it with queue/watchdog/finish-once and swapping the
  completion signal from KVO to a navigation delegate.
- Fixing pre-existing code smells unrelated to the race/timeout problem
  (heavy iOS/macOS duplication within `handle()`, force-unwrapped
  arguments, the many `print()` debug statements) — noted during analysis,
  out of scope for this change.
- Changing the wire format / arguments of `contentToImage`, `contentToPDF`,
  or `printPreview` as seen from Dart.
- Introducing per-job request objects (`ImageCaptureJob`/`PdfConversionJob`
  style, matching Windows' `PdfConversionRequest`/`ImageCaptureRequest`
  pattern) — considered as an alternative approach and explicitly rejected
  in favor of wrapping the existing `handle()` structure, to keep the diff
  small and avoid re-touching the already-fragile capture logic.

## Testing

- **Unit tests** for `ConversionQueue` and `RequestWatchdog` — pure logic,
  no WebView/Flutter runtime required — added to
  `example/macos/RunnerTests/` (new `ConversionQueueTests.swift` /
  `RequestWatchdogTests.swift`, or appended to the existing
  `RunnerTests.swift`), following the precedent already set there by
  `testComputePdfPageSlices_*` / `testMergePdfPageSlices_*`. Cases: FIFO
  ordering, busy-slot serialization, `isQueueFull()` boundary, watchdog
  fires after timeout, `disarm()` prevents a stale fire, re-arming cancels
  the previous timer.
- **No new integration/UI tests** for the wrapped `handle()` cases
  themselves, matching the "wrap, don't rewrite" scope and the fact that
  the existing capture logic has no coverage today either. Manual
  verification: run each of `contentToImage`, `contentToPDF`, and
  `printPreview` via the `example/` app on both an iOS simulator and
  macOS; fire concurrent bursts (rapid taps / `Future.wait`) to confirm
  serialization instead of racing; construct an intentionally-hanging or
  invalid-content case to confirm both the new `WEBVIEW_LOAD_ERROR` fast
  path and the `TIMEOUT` watchdog path resolve cleanly instead of leaving
  the queue stuck.

## Risks / things to verify during implementation

- Confirm `WKNavigationDelegate` fully replaces the KVO completion signal
  without changing *when* "page ready" fires relative to today's behavior
  — the settle-delay/measurement logic downstream is unchanged and assumes
  the same trigger point.
- Confirm assigning a per-job `WKNavigationDelegate` (rather than one
  persistent delegate on the plugin instance) doesn't conflict with
  anything else in `FLWebView.swift` / `FLNativeViewFactory` — those own a
  *different* WKWebView instance (the embedded `embedWebView` widget), not
  `self.webView`, so no expected conflict, but worth confirming during
  implementation.
- Confirm the watchdog-disarm-before-`run()` step for macOS `printPreview`
  actually prevents a spurious `TIMEOUT` during a real (possibly
  multi-minute) user interaction with the print panel, and that
  `onRequestFinished()` still correctly fires once `run()` returns so the
  queue doesn't stay stuck if the user cancels rather than prints.
- Confirm `RequestWatchdog.disarm()` (a `Timer.invalidate()` call)
  reliably takes effect when called immediately before entering
  `NSPrintOperation.run()`'s nested/modal event loop, rather than the
  invalidation racing the nested loop's own setup — a real check rather
  than an assumption, since the failure mode (watchdog still fires despite
  `disarm()`) would surface as a spurious `TIMEOUT` while the user is
  legitimately still looking at the print panel.

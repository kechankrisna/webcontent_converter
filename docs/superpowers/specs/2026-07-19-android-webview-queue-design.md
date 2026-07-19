# Android WebView Queue & Lifecycle: Design

## Problem

`WebcontentConverterPlugin.kt` (Android) creates a brand-new `WebView` on
every `contentToImage`, `contentToPDF`, and `printPreview` call, with no
concurrency control and no cleanup:

1. **Race condition (confirmed bug).** `webView` is a single mutable class
   field, reassigned on every call
   ([WebcontentConverterPlugin.kt:52](../../../android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt#L52)).
   Every `WebViewClient.onPageFinished` closure captures and reads this
   outer field, not the `view` parameter it's handed. If two calls overlap
   (e.g. two `contentToImage` invocations fired back-to-back from Dart),
   the second call's reassignment of `webView` makes the *first* call's
   completion logic operate on the *second* call's WebView instance.
2. **WebView leak.** `WebView.destroy()` is never called anywhere in the
   file — not on reassignment, not in `onDetachedFromActivity` /
   `onDetachedFromEngine`. Every undestroyed WebView keeps its internal
   rendering threads and Chromium-side references alive, pinning whatever
   Context/Activity it was built with.
3. **No concurrency control.** A burst of calls spins up N full WebViews
   concurrently — each a real Chromium renderer — causing CPU/memory
   spikes and jank, and compounding bug #1.
4. **No timeout.** If `onPageFinished` never fires (bad content, hung JS,
   blocked resource load), the Flutter `Result` callback and its WebView
   are held forever.
5. **`printPreview` never resolves its `Result` at all.** Confirmed by
   reading the Dart call site
   (`webcontent_converter_io.dart:627`, `await _channel.invokeMethod('printPreview', ...)`)
   against the Android handler, which calls `createWebPrintJob(webView)`
   and returns without ever calling `result.success`/`result.error` — the
   awaited `Future` hangs forever on Android today.

The Windows implementation
(`windows/webcontent_converter_plugin.h/.cpp`,
`windows/webview2_session.h`, `windows/request_watchdog.h`) already solves
the equivalent problem there: a single long-lived, reused WebView2 session,
a FIFO job queue with one busy slot so requests serialize instead of racing,
a bounded queue size, and a per-request watchdog timeout. This design ports
that pattern to Android, adapted for Android's different failure modes (see
"Where this diverges from Windows" below).

## Chosen approach

Split the single Kotlin file into four focused pieces, mirroring the
Windows file boundaries:

- **`SharedWebViewSession.kt`** — owns the one long-lived `WebView`
  instance for the plugin's lifetime. `ensure(context)` lazily creates
  it; `resetForNextJob()` stops any in-flight load, detaches the previous
  job's `WebViewClient` (replacing it with a no-op one) so a late
  callback can't route into a job that already considers itself
  finished, and clears history. It deliberately does *not* navigate to
  `about:blank` first: the next job's own `loadDataWithBaseURL` call is
  itself a full-document navigation, which already gives that job a
  fresh `Document`/`window` — an intermediate blank-page round trip
  would add ordering risk (a stale `onPageFinished` firing) for no
  isolation benefit. `destroy()` runs only from `onDetachedFromEngine`
  (not on `onDetachedFromActivity`/config-change callbacks, which fire on
  every rotation — destroying a WebView built from the plugin's
  application `Context`, not the `Activity`, on every rotation would
  defeat the point of reusing it).
- **`RequestWatchdog.kt`** — direct Kotlin port of the Windows class:
  `arm(timeoutMs, onTimeout)` / `disarm()`, backed by
  `Handler(Looper.getMainLooper()).postDelayed` instead of `SetTimer`,
  one-shot, main-thread only (matching the rest of the plugin, which is
  already UI-thread-driven).
- **`ConversionQueue.kt`** — the FIFO: `requestInFlight: Boolean`,
  `pendingJobs: ArrayDeque<() -> Unit>`, `startOrQueue(job)`,
  `onRequestFinished()`, `isQueueFull()` (cap at 32 pending jobs, matching
  Windows' `kMaxQueuedRequests`).
- **`WebcontentConverterPlugin.kt`** — shrinks to: parse/validate
  arguments (including a content-size cap, raised to 100MB to match
  Windows' `kMaxContentSizeBytes`), reject with `TOO_MANY_REQUESTS` if the
  queue is full, otherwise build a job closure and hand it to
  `ConversionQueue.startOrQueue`.

`contentToImage` (both the WebView-based path and the `is_html2bitmap`
path), `contentToPDF`, and `printPreview` all become jobs submitted to the
same `ConversionQueue` — confirmed with the user that `printPreview`
should be included even though Windows keeps it separate (Windows can
because `PrintPreviewWindow` gets its own independent native window;
Android has no equivalent isolation, and `printPreview` shares the exact
same `webView` field and race as the other two methods today).

**`printPreview` does not use the shared/reused `SharedWebViewSession`.**
Android's `PrintDocumentAdapter` keeps pulling rendered pages from the
WebView it was created from *after* `printManager.print()` returns —
well past the point the job resolves its `Result` and frees the queue
slot. If `printPreview` reused the same shared WebView, the next queued
job's `resetForNextJob()` (stop load, clear history, navigate away) could
run while the OS was still mid-print, corrupting that job. Instead,
`printPreview`'s job creates its own dedicated `WebView` (own
`PrintPreviewWebView` instance, not `SharedWebViewSession`), still
serialized through the same `ConversionQueue` for ordering, but this
dedicated instance is only destroyed once a
`PrintJob.addOnPrintJobStateChangedListener` (or polling
`PrintJob.info.isCompleted`/`isFailed`/`isCancelled`) reports a terminal
state — independent of when the queue slot itself is freed. The queue
slot frees right after `printManager.print()` is invoked (same as
`contentToPDF`/`contentToImage` resolve on their own completion), so a
user leaving the system print dialog open doesn't block other
`contentToImage`/`contentToPDF` calls from proceeding against the shared
session in the meantime.

### Per-job lifecycle

1. `session.resetForNextJob()` — fresh `WebViewClient` for this job only.
2. `watchdog.arm(timeoutMs, onTimeout)`, armed immediately before
   `loadDataWithBaseURL`. `timeoutMs = max(30_000, durationMs + 30_000)`
   so callers requesting a longer settle `duration` still get proportional
   headroom before being treated as hung.
3. Existing load → `onPageFinished` → settle-delay → capture / export /
   print logic, unchanged in substance.
4. Exactly one completion path fires — success, failure,
   `WebViewClient.onReceivedError`, or watchdog timeout — guarded by a
   per-job `completed: Boolean` flag (matching
   `WebView2Session::completed_`) so a late callback after a timeout can't
   double-resolve the `Result`. Whichever path fires first calls
   `queue.onRequestFinished()` **before** resolving the Flutter `Result`,
   same ordering Windows uses to prevent the next queued call from racing
   the one currently completing.

### New error handling (doesn't exist today)

- `WebViewClient.onReceivedError` is currently unhandled; wiring it to
  fail the job immediately (instead of waiting for the watchdog) turns a
  broken/blocked resource load into a fast, clear error instead of a
  30s+ stall.
- `printPreview`'s job resolves `result.success(true)` right after
  `printManager.print()` is invoked successfully (matching Windows, which
  also resolves at hand-off to the OS print flow, not at print
  completion), or `result.error(...)` if `PrintManager` is unavailable or
  throws.
- The `is_html2bitmap` path moves off deprecated `AsyncTask` onto a
  coroutine on `Dispatchers.IO`, with its result posted back through the
  same completion path as the other jobs (so it participates in the same
  queue and watchdog).

### Where this diverges from Windows

Windows reuses one long-lived WebView2 *session* specifically because
repeated environment/controller creation on that platform was expensive
and reproducibly flaky (see `webview2_session.h`'s class comment).
Android's `WebView()` constructor doesn't share that flakiness — but per
the user's explicit choice, this design still reuses a single long-lived
`WebView` instance (not recreate-per-request), accepting the added
`resetForNextJob()` complexity in exchange for avoiding repeated WebView
construction cost on every call.

## Non-goals

- Changing iOS, macOS, Windows, or Linux/web plugin code.
- Adding JUnit test scaffolding (`ConversionQueue`/`RequestWatchdog` are
  pure logic and could be unit-tested, but there is no existing
  `android/src/test` setup in this plugin — confirmed with the user to
  keep validation manual-only for this change rather than standing up new
  test infrastructure).
- Changing the wire format / arguments of `contentToImage`, `contentToPDF`,
  or `printPreview` as seen from Dart.
- Fixing the deprecated `activity.window.windowManager.defaultDisplay`
  width/height lookup — noted during analysis but unrelated to the
  race/leak/queue problem this design addresses.

## Risks / things to verify during implementation

- `PrintJob` state listener availability: `addOnPrintJobStateChangedListener`
  needs verifying against the plugin's `minSdkVersion` (Print Framework is
  API 19+, but the listener API should be double-checked during
  implementation); if unavailable at the plugin's floor SDK, a polling
  fallback (`Handler.postDelayed` checking `PrintJob.info` state) achieves
  the same "don't destroy the dedicated WebView until the OS is done with
  it" goal.
- Real device/emulator check that firing `printPreview` immediately
  followed by another queued `contentToImage`/`contentToPDF` request
  doesn't corrupt either: the print job should still render correctly
  from its own dedicated WebView while the other request proceeds
  against the shared session.
- Manual verification plan (no automated Android tests exist for this
  plugin): run each of `contentToImage` (both paths), `contentToPDF`, and
  `printPreview` individually via the `example/` app; fire concurrent
  bursts (rapid taps / `Future.wait`) to confirm serialization instead of
  racing; watch the Android Studio memory profiler across repeated calls
  to confirm WebView instances aren't accumulating; and construct an
  intentionally-hanging content case to confirm the watchdog timeout path
  resolves cleanly instead of leaving the queue stuck.

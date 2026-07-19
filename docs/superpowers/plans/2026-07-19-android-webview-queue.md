# Android WebView Queue & Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the confirmed race condition, WebView leak, and hung `printPreview` in the Android `webcontent_converter` plugin by porting the Windows plugin's queue/watchdog/session-reuse pattern.

**Architecture:** Split `WebcontentConverterPlugin.kt` into a FIFO job queue (`ConversionQueue`), a one-shot timeout helper (`RequestWatchdog`), a reused long-lived WebView for `contentToImage`/`contentToPDF` (`SharedWebViewSession`), and a dedicated per-print-job WebView (`PrintPreviewWebView`). Every `contentToImage`, `contentToPDF`, and `printPreview` call becomes a job submitted to the same queue so only one runs at a time; each job is watchdog-guarded so a hang can't wedge the queue forever.

**Tech Stack:** Kotlin 1.8.22, Android (compileSdk 35, minSdk 21), `kotlinx.coroutines` (already used in this file), Flutter plugin `MethodChannel`.

**Spec:** [docs/superpowers/specs/2026-07-19-android-webview-queue-design.md](2026-07-19-android-webview-queue-design.md)

## Global Constraints

- Registered Android plugin package is `app.mylekha.webcontent_converter` (confirmed against `pubspec.yaml` and `AndroidManifest.xml`) — do not touch the sibling, unregistered `app.mylekha.client.webcontent_converter` package.
- Content-size cap: 100MB (`100L * 1024 * 1024` bytes), matching Windows' `kMaxContentSizeBytes`.
- Queue-full cap: 32 pending jobs, matching Windows' `kMaxQueuedRequests`.
- Watchdog timeout per job: `max(30_000ms, durationMs + 30_000ms)`.
- No JUnit test infrastructure exists for this plugin's Android code (`android/` has no `src/test`, no JUnit in `android/build.gradle`) — per the approved spec, validation for this plan is (a) a Kotlin/Gradle compile check via `cd example && flutter build apk --debug`, and (b) manual runs of the existing repro harnesses in `example/lib/main_*_repro_test.dart` on a connected device/emulator (an `emulator-5554` Android 16 emulator is already running in this environment). Do not add new test scaffolding.
- Don't change the Dart-facing method-channel argument shape for `contentToImage`, `contentToPDF`, or `printPreview`.
- Don't touch iOS/macOS/Windows/Linux/web plugin code.

---

### Task 1: `RequestWatchdog` — one-shot timeout helper

**Files:**
- Create: `android/src/main/kotlin/app/mylekha/webcontent_converter/RequestWatchdog.kt`

**Interfaces:**
- Produces: `class RequestWatchdog { fun arm(timeoutMs: Long, onTimeout: () -> Unit); fun disarm() }`

- [ ] **Step 1: Create the file**

```kotlin
package app.mylekha.webcontent_converter

import android.os.Handler
import android.os.Looper

// One-shot timeout for a single conversion job's whole lifecycle (load ->
// settle delay -> capture/export/print), not just the WebView load phase.
// Backed by Handler.postDelayed on the main thread. Not thread-safe; must
// be used from the UI thread only, matching the rest of this plugin.
class RequestWatchdog {
    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null

    // Schedules `onTimeout` to fire after `timeoutMs` unless disarm() is
    // called first. Re-arming an already-armed watchdog disarms the
    // previous timer first.
    fun arm(timeoutMs: Long, onTimeout: () -> Unit) {
        disarm()
        val runnable = Runnable { onTimeout() }
        pending = runnable
        handler.postDelayed(runnable, timeoutMs)
    }

    // Cancels a pending timeout, if any. Safe to call when not armed.
    fun disarm() {
        pending?.let { handler.removeCallbacks(it) }
        pending = null
    }
}
```

- [ ] **Step 2: Compile check**

```bash
cd example && flutter build apk --debug 2>&1 | tail -50
```
Expected: `BUILD SUCCESSFUL` (the new file isn't referenced by anything yet, so this only confirms it parses/compiles as valid Kotlin).

- [ ] **Step 3: Commit**

```bash
git add android/src/main/kotlin/app/mylekha/webcontent_converter/RequestWatchdog.kt
git commit -m "feat(android): add RequestWatchdog one-shot timeout helper"
```

---

### Task 2: `ConversionQueue` — FIFO job queue with one busy slot

**Files:**
- Create: `android/src/main/kotlin/app/mylekha/webcontent_converter/ConversionQueue.kt`

**Interfaces:**
- Produces: `class ConversionQueue(maxQueuedRequests: Int = 32) { fun isQueueFull(): Boolean; fun startOrQueue(job: () -> Unit); fun onRequestFinished() }`

- [ ] **Step 1: Create the file**

```kotlin
package app.mylekha.webcontent_converter

// FIFO job queue with a single busy slot, serializing every
// contentToImage, contentToPDF, and printPreview request so at most one
// runs at a time. Direct port of StartOrQueue/OnRequestFinished from the
// Windows plugin (windows/webcontent_converter_plugin.cpp) -- see that
// file's comments for why a busy caller queues instead of failing
// outright, and why the queue is capped rather than unbounded.
class ConversionQueue(private val maxQueuedRequests: Int = 32) {
    private var requestInFlight = false
    private val pendingJobs = ArrayDeque<() -> Unit>()

    // Backstop against unbounded queue growth from a caller stuck in a
    // loop. Normal bursts of calls stay well under this and just
    // queue/succeed instead of erroring.
    fun isQueueFull(): Boolean = pendingJobs.size >= maxQueuedRequests

    // Starts `job` now if the queue is idle, or queues it to run once the
    // current job (and everything already queued ahead of it) finishes,
    // in FIFO order (see onRequestFinished). Callers are expected to have
    // already checked isQueueFull() and rejected the request themselves
    // in that case -- this always runs or queues.
    fun startOrQueue(job: () -> Unit) {
        if (requestInFlight) {
            pendingJobs.addLast(job)
            return
        }
        requestInFlight = true
        job()
    }

    // Frees the busy slot and starts the next queued job, if any.
    fun onRequestFinished() {
        requestInFlight = false
        val next = pendingJobs.removeFirstOrNull() ?: return
        requestInFlight = true
        next()
    }
}
```

- [ ] **Step 2: Compile check**

```bash
cd example && flutter build apk --debug 2>&1 | tail -50
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add android/src/main/kotlin/app/mylekha/webcontent_converter/ConversionQueue.kt
git commit -m "feat(android): add ConversionQueue FIFO job queue"
```

---

### Task 3: `SharedWebViewSession` — reused WebView for contentToImage/contentToPDF

**Files:**
- Create: `android/src/main/kotlin/app/mylekha/webcontent_converter/SharedWebViewSession.kt`

**Interfaces:**
- Consumes: nothing new (only `android.content.Context`, `android.webkit.WebView`/`WebViewClient` from the platform SDK).
- Produces: `class SharedWebViewSession { fun ensure(context: Context): WebView; fun resetForNextJob(); fun destroy() }`

- [ ] **Step 1: Create the file**

```kotlin
package app.mylekha.webcontent_converter

import android.content.Context
import android.os.Build
import android.webkit.WebView
import android.webkit.WebViewClient

// Owns the single long-lived WebView reused across contentToImage
// (WebView path, not the is_html2bitmap path) and contentToPDF requests
// for the plugin's lifetime, instead of constructing a new WebView per
// call. NOT used by printPreview -- see PrintPreviewWebView's class
// comment for why that needs its own dedicated, non-reused instance.
//
// Built against `context` (the plugin's application Context), not the
// Activity, matching this plugin's existing WebView-construction pattern
// -- avoids tying this long-lived object to a shorter-lived Activity
// instance.
//
// Every request must call resetForNextJob() before installing its own
// WebViewClient and loading its content. resetForNextJob() only
// guarantees no stale WebViewClient/navigation from a *previous* job
// remains; it does not install the next job's client itself, since that
// client closes over the next job's own Result/watchdog, which this
// class has no visibility into.
class SharedWebViewSession {
    var webView: WebView? = null
        private set

    fun ensure(context: Context): WebView {
        webView?.let { return it }
        val created = WebView(context)
        created.settings.javaScriptEnabled = true
        created.settings.useWideViewPort = true
        created.settings.javaScriptCanOpenWindowsAutomatically = true
        created.settings.loadWithOverviewMode = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            WebView.enableSlowWholeDocumentDraw()
        }
        webView = created
        return created
    }

    fun resetForNextJob() {
        val view = webView ?: return
        view.stopLoading()
        // Detach the previous job's WebViewClient immediately so a late
        // callback (e.g. a delayed onReceivedError) can't route into a
        // job that already considers itself finished -- this is the
        // piece that fixes the original race, where the outer `webView`
        // field (not a per-job client) was what every callback read.
        view.webViewClient = WebViewClient()
        view.clearHistory()
    }

    fun destroy() {
        webView?.apply {
            stopLoading()
            webViewClient = WebViewClient()
            destroy()
        }
        webView = null
    }
}
```

- [ ] **Step 2: Compile check**

```bash
cd example && flutter build apk --debug 2>&1 | tail -50
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 3: Commit**

```bash
git add android/src/main/kotlin/app/mylekha/webcontent_converter/SharedWebViewSession.kt
git commit -m "feat(android): add SharedWebViewSession reused-WebView manager"
```

---

### Task 4: `PrintPreviewWebView` — dedicated WebView + PrintJob lifecycle for printPreview

**Files:**
- Create: `android/src/main/kotlin/app/mylekha/webcontent_converter/PrintPreviewWebView.kt`

**Interfaces:**
- Produces: `class PrintPreviewWebView(context: Context) { fun create(): WebView; fun startPrintJob(printManager: PrintManager, jobName: String); fun destroy() }`

- [ ] **Step 1: Create the file**

```kotlin
package app.mylekha.webcontent_converter

import android.content.Context
import android.print.PrintAttributes
import android.print.PrintJob
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient

// Dedicated, non-reused WebView + PrintJob lifecycle for printPreview.
//
// Unlike contentToImage/contentToPDF, printPreview cannot share
// SharedWebViewSession's single reused WebView: Android's
// PrintDocumentAdapter (from WebView.createPrintDocumentAdapter) keeps
// pulling rendered pages from the WebView it was created from *after*
// PrintManager.print() returns -- well past when this job's queue slot
// frees and the next queued contentToImage/contentToPDF job would
// otherwise reset the shared WebView out from under it. See
// docs/superpowers/specs/2026-07-19-android-webview-queue-design.md.
//
// destroy() is called either on failure (before a PrintJob ever starts)
// or automatically once the PrintJob reaches a terminal state
// (completed/failed/cancelled) via the listener installed in
// startPrintJob -- independent of when the plugin's queue slot itself
// is freed (that happens at hand-off, right after print() is called, so
// a user leaving the system print dialog open doesn't block other
// contentToImage/contentToPDF calls in the meantime).
class PrintPreviewWebView(private val context: Context) {
    private var webView: WebView? = null

    fun create(): WebView {
        val created = WebView(context)
        created.settings.javaScriptEnabled = true
        created.settings.useWideViewPort = true
        created.settings.javaScriptCanOpenWindowsAutomatically = true
        created.settings.loadWithOverviewMode = true
        webView = created
        return created
    }

    fun startPrintJob(printManager: PrintManager, jobName: String) {
        val view = webView ?: return
        val printAdapter = view.createPrintDocumentAdapter(jobName)
        val attributes = PrintAttributes.Builder()
            .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
            .build()
        val job = printManager.print(jobName, printAdapter, attributes)
        job.setOnPrintJobStateChangedListener(object : PrintJob.OnPrintJobStateChangedListener {
            override fun onPrintJobStateChanged(printJob: PrintJob) {
                if (printJob.isCompleted || printJob.isFailed || printJob.isCancelled) {
                    printJob.setOnPrintJobStateChangedListener(null)
                    destroy()
                }
            }
        })
    }

    fun destroy() {
        webView?.apply {
            stopLoading()
            webViewClient = WebViewClient()
            destroy()
        }
        webView = null
    }
}
```

- [ ] **Step 2: Compile check**

```bash
cd example && flutter build apk --debug 2>&1 | tail -50
```
Expected: `BUILD SUCCESSFUL`. If `PrintJob.setOnPrintJobStateChangedListener` or `OnPrintJobStateChangedListener` don't resolve, check the exact signature via the installed Android SDK sources (`compileSdkVersion 35`) — the one-argument listener overload is what's used here.

- [ ] **Step 3: Commit**

```bash
git add android/src/main/kotlin/app/mylekha/webcontent_converter/PrintPreviewWebView.kt
git commit -m "feat(android): add PrintPreviewWebView dedicated print lifecycle"
```

---

### Task 5: Wire `contentToImage` (both paths) through the queue

**Files:**
- Modify: `android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt`

**Interfaces:**
- Consumes: `RequestWatchdog` (Task 1), `ConversionQueue` (Task 2), `SharedWebViewSession` (Task 3).
- Produces: `WebcontentConverterPlugin.conversionQueue: ConversionQueue`, `.sharedSession: SharedWebViewSession`, `private fun requestTimeoutMs(durationMs: Double): Long`, `private fun runContentToImageJob(...)`, `private fun runHtml2BitmapJob(...)` — used by Tasks 6 and 7.

- [ ] **Step 1: Add imports**

In `WebcontentConverterPlugin.kt`, replace the existing import block (lines 1–40) with:

```kotlin
package app.mylekha.webcontent_converter

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.print.BitmapCallback
import android.print.inchToPx
import android.print.PaperFormat
import android.print.PdfPrinter
import android.print.PrintAttributes
import android.print.PrintManager
import android.util.Log
import android.view.View
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import com.izettle.html2bitmap.Html2Bitmap
import com.izettle.html2bitmap.Html2BitmapConfigurator
import com.izettle.html2bitmap.content.WebViewContent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import kotlin.math.absoluteValue
```

(This drops the now-unused `android.os.AsyncTask` import, added `WebResourceError`/`WebResourceRequest`/`withContext`.)

- [ ] **Step 2: Replace the class fields and add the companion object**

Replace:
```kotlin
class WebcontentConverterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var activity: Activity
    private lateinit var context: Context
    private lateinit var webView: WebView
```

With:
```kotlin
class WebcontentConverterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var activity: Activity
    private lateinit var context: Context
    // Still used by the not-yet-migrated contentToPDF/printPreview cases
    // until Tasks 6-7 replace them -- removed for good in Task 7 once
    // nothing references it anymore.
    private lateinit var webView: WebView
    private val sharedSession = SharedWebViewSession()
    private val conversionQueue = ConversionQueue(MAX_QUEUED_REQUESTS)

    companion object {
        private const val MAX_CONTENT_SIZE_BYTES = 100L * 1024 * 1024
        private const val MAX_QUEUED_REQUESTS = 32
    }

    private fun requestTimeoutMs(durationMs: Double): Long =
        maxOf(30_000L, durationMs.toLong() + 30_000L)
```

- [ ] **Step 3: Replace the `contentToImage` case**

Replace the entire `"contentToImage" -> { ... }` block (originally lines 115–261) with:

```kotlin
            "contentToImage" -> {
                if (content.toByteArray(Charsets.UTF_8).size > MAX_CONTENT_SIZE_BYTES) {
                    result.error("CONTENT_TOO_LARGE", "Content exceeds maximum size of 100MB", null)
                    return
                }
                if (conversionQueue.isQueueFull()) {
                    result.error(
                        "TOO_MANY_REQUESTS",
                        "Too many queued conversions (limit: $MAX_QUEUED_REQUESTS). Please wait for earlier ones to complete.",
                        null
                    )
                    return
                }
                if (is_html2bitmap) {
                    val bitmapWidth = arguments["bitmap_width"] as Double?
                    conversionQueue.startOrQueue {
                        runHtml2BitmapJob(content, bitmapWidth, duration!!, result)
                    }
                    return
                }
                conversionQueue.startOrQueue {
                    runContentToImageJob(content, format, margins, duration!!, result)
                }
            }
```

- [ ] **Step 4: Add the job functions**

Add these as new private methods on `WebcontentConverterPlugin` (anywhere below `onMethodCall`, e.g. right before `isWebViewAvailable`):

```kotlin
    private fun runContentToImageJob(
        content: String,
        format: Map<String, *>?,
        margins: Map<String, Double>?,
        duration: Double,
        result: Result
    ) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        val webView = sharedSession.ensure(context)
        sharedSession.resetForNextJob()

        val dwidth = activity.window.windowManager.defaultDisplay.width
        val dheight = activity.window.windowManager.defaultDisplay.height
        webView.layout(0, 0, dwidth, dheight)
        webView.setInitialScale(1)

        watchdog.arm(requestTimeoutMs(duration)) {
            finish { result.error("TIMEOUT", "contentToImage timed out", null) }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                val settleMs = (dheight / 1000).toInt() * 200
                Handler(Looper.getMainLooper()).postDelayed({
                    if (completed) return@postDelayed
                    if (format != null && format["name"] != null) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                            view.toPDFBitmap(format, margins, object : BitmapCallback {
                                override fun onSuccess(bitmapBytes: ByteArray) {
                                    finish { result.success(bitmapBytes) }
                                }
                                override fun onFailure() {
                                    finish {
                                        result.error("BITMAP_EXPORT_ERROR", "Failed to create bitmap from PDF", null)
                                    }
                                }
                            })
                        }
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                        view.evaluateJavascript(
                            "(function() { return [document.body.offsetWidth, document.body.offsetHeight]; })();"
                        ) { raw ->
                            if (completed) return@evaluateJavascript
                            val xy = JSONArray(raw)
                            val offsetWidth = xy[0].toString().toDouble()
                            val offsetHeight = xy[1].toString().toDouble()
                            val bitmap = view.toBitmap(offsetWidth, offsetHeight)
                            if (bitmap != null) {
                                finish { result.success(bitmap.toByteArray()) }
                            } else {
                                finish {
                                    result.error("BITMAP_EXPORT_ERROR", "Failed to measure content for bitmap", null)
                                }
                            }
                        }
                    }
                }, settleMs.toLong())
            }

            @Suppress("OVERRIDE_DEPRECATION")
            override fun onReceivedError(
                view: WebView,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                finish { result.error("WEBVIEW_LOAD_ERROR", description ?: "WebView failed to load content", null) }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                super.onReceivedError(view, request, error)
                if (request.isForMainFrame) {
                    finish {
                        result.error(
                            "WEBVIEW_LOAD_ERROR",
                            error.description?.toString() ?: "WebView failed to load content",
                            null
                        )
                    }
                }
            }
        }

        webView.loadDataWithBaseURL(null, content, "text/HTML", "UTF-8", null)
    }

    private fun runHtml2BitmapJob(
        content: String,
        bitmapWidth: Double?,
        duration: Double,
        result: Result
    ) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        watchdog.arm(requestTimeoutMs(duration)) {
            finish { result.error("TIMEOUT", "contentToImage (html2bitmap) timed out", null) }
        }

        CoroutineScope(Dispatchers.IO).launch {
            val bitmap = try {
                val builder = Html2Bitmap.Builder()
                builder.setContext(context)
                builder.setContent(WebViewContent.html(content))
                builder.setConfigurator(Html2BitmapConfigurator())
                if (bitmapWidth != null && bitmapWidth > 0) {
                    builder.setBitmapWidth(bitmapWidth.toInt())
                }
                builder.setStrictMode(true)
                builder.build().bitmap
            } catch (e: Exception) {
                Log.e("webcontent_converter", e.stackTraceToString())
                null
            }
            withContext(Dispatchers.Main) {
                if (bitmap != null) {
                    finish { result.success(bitmap.toByteArray()) }
                } else {
                    finish { result.error("webview.build", "Failed to generate bitmap", null) }
                }
            }
        }
    }
```

- [ ] **Step 5: Compile check**

```bash
cd example && flutter build apk --debug 2>&1 | tail -80
```
Expected: `BUILD SUCCESSFUL`. Note: `contentToPDF` and `printPreview` still reference the old `webView` field at this point — that's expected until Tasks 6–7 migrate them; do not remove the old field yet.

- [ ] **Step 6: Manual check — single contentToImage call**

```bash
cd example && flutter run -d emulator-5554 -t lib/main_image_repro_test.dart
```
Expected: app reaches a "done"/success state without crashing (check `adb logcat` for `webcontent_converter` tags if it hangs). Stop the run once confirmed (`q` in the `flutter run` terminal).

- [ ] **Step 7: Commit**

```bash
git add android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt
git commit -m "feat(android): route contentToImage through ConversionQueue/SharedWebViewSession"
```

---

### Task 6: Wire `contentToPDF` through the queue

**Files:**
- Modify: `android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt`

**Interfaces:**
- Consumes: `conversionQueue`, `sharedSession`, `requestTimeoutMs()` (all from Task 5).
- Produces: `private fun runContentToPdfJob(...)` — no later task depends on this directly.

- [ ] **Step 1: Replace the `contentToPDF` case**

Replace the entire `"contentToPDF" -> { ... }` block (originally lines 263–312) with:

```kotlin
            "contentToPDF" -> {
                if (content.toByteArray(Charsets.UTF_8).size > MAX_CONTENT_SIZE_BYTES) {
                    result.error("CONTENT_TOO_LARGE", "Content exceeds maximum size of 100MB", null)
                    return
                }
                if (conversionQueue.isQueueFull()) {
                    result.error(
                        "TOO_MANY_REQUESTS",
                        "Too many queued conversions (limit: $MAX_QUEUED_REQUESTS). Please wait for earlier ones to complete.",
                        null
                    )
                    return
                }
                val path = savedPath
                val pdfFormat = format
                val pdfMargins = margins
                if (path == null || pdfFormat == null || pdfMargins == null) {
                    result.error("INVALID_ARGUMENT", "savedPath, format, and margins are required", null)
                    return
                }
                conversionQueue.startOrQueue {
                    runContentToPdfJob(content, path, pdfFormat, pdfMargins, duration!!, result)
                }
            }
```

(This also fixes a latent crash: the original code used `savedPath!!`/`format!!`/`margins!!`, which would throw an unhandled `NullPointerException` — and never resolve `result` — if a caller omitted any of them.)

- [ ] **Step 2: Add the job function**

Add this new private method next to `runContentToImageJob`/`runHtml2BitmapJob`:

```kotlin
    private fun runContentToPdfJob(
        content: String,
        savedPath: String,
        format: Map<String, *>,
        margins: Map<String, Double>,
        duration: Double,
        result: Result
    ) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        val webView = sharedSession.ensure(context)
        sharedSession.resetForNextJob()

        val dwidth = activity.window.windowManager.defaultDisplay.width
        val dheight = activity.window.windowManager.defaultDisplay.height
        webView.layout(0, 0, dwidth, dheight)
        webView.setInitialScale(1)

        watchdog.arm(requestTimeoutMs(duration)) {
            finish { result.error("TIMEOUT", "contentToPDF timed out", null) }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                Handler(Looper.getMainLooper()).postDelayed({
                    if (completed) return@postDelayed
                    view.exportAsPdfFromWebView(savedPath, format, margins, object : PdfPrinter.Callback {
                        override fun onSuccess(filePath: String) {
                            finish { result.success(filePath) }
                        }
                        override fun onFailure() {
                            // Matches the pre-existing contract: failure resolves
                            // with a null path rather than a PlatformException.
                            finish { result.success(null) }
                        }
                    })
                }, duration.toLong())
            }

            @Suppress("OVERRIDE_DEPRECATION")
            override fun onReceivedError(
                view: WebView,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                finish { result.error("WEBVIEW_LOAD_ERROR", description ?: "WebView failed to load content", null) }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                super.onReceivedError(view, request, error)
                if (request.isForMainFrame) {
                    finish {
                        result.error(
                            "WEBVIEW_LOAD_ERROR",
                            error.description?.toString() ?: "WebView failed to load content",
                            null
                        )
                    }
                }
            }
        }

        webView.loadDataWithBaseURL(null, content, "text/HTML", "UTF-8", null)
    }
```

- [ ] **Step 3: Compile check**

```bash
cd example && flutter build apk --debug 2>&1 | tail -80
```
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Manual check — queue serialization under a burst**

```bash
cd example && flutter run -d emulator-5554 -t lib/main_queue_repro_test.dart
```
Expected: status ends at "ALL 10 REQUESTS SETTLED" with no crash. Cross-check with:
```bash
adb logcat -d | grep "QUEUE REPRO"
```
Expected: 10 `SUCCESS` lines (one per fired request), each with a distinct, existing file path — confirming the queue serialized them instead of racing on a shared WebView.

- [ ] **Step 5: Commit**

```bash
git add android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt
git commit -m "feat(android): route contentToPDF through ConversionQueue/SharedWebViewSession"
```

---

### Task 7: Wire `printPreview` through the queue, remove the old field, wire lifecycle cleanup

**Files:**
- Modify: `android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt`

**Interfaces:**
- Consumes: `conversionQueue`, `requestTimeoutMs()` (Task 5), `PrintPreviewWebView` (Task 4).

- [ ] **Step 1: Replace the `printPreview` case**

Replace the entire `"printPreview" -> { ... }` block (originally lines 313–350) with:

```kotlin
            "printPreview" -> {
                if (content.toByteArray(Charsets.UTF_8).size > MAX_CONTENT_SIZE_BYTES) {
                    result.error("CONTENT_TOO_LARGE", "Content exceeds maximum size of 100MB", null)
                    return
                }
                if (conversionQueue.isQueueFull()) {
                    result.error(
                        "TOO_MANY_REQUESTS",
                        "Too many queued conversions (limit: $MAX_QUEUED_REQUESTS). Please wait for earlier ones to complete.",
                        null
                    )
                    return
                }
                conversionQueue.startOrQueue {
                    runPrintPreviewJob(content, duration!!, result)
                }
            }
```

- [ ] **Step 2: Add the job function**

Add this new private method next to the other job functions:

```kotlin
    private fun runPrintPreviewJob(content: String, duration: Double, result: Result) {
        val watchdog = RequestWatchdog()
        var completed = false

        fun finish(action: () -> Unit) {
            if (completed) return
            completed = true
            watchdog.disarm()
            conversionQueue.onRequestFinished()
            action()
        }

        val printPreview = PrintPreviewWebView(context)
        val webView = printPreview.create()

        val dwidth = activity.window.windowManager.defaultDisplay.width
        val dheight = activity.window.windowManager.defaultDisplay.height
        webView.layout(0, 0, dwidth, dheight)
        webView.setInitialScale(1)

        watchdog.arm(requestTimeoutMs(duration)) {
            printPreview.destroy()
            finish { result.error("TIMEOUT", "printPreview timed out", null) }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String) {
                super.onPageFinished(view, url)
                Handler(Looper.getMainLooper()).postDelayed({
                    if (completed) return@postDelayed
                    val printManager = activity.getSystemService(Context.PRINT_SERVICE) as? PrintManager
                    if (printManager == null) {
                        printPreview.destroy()
                        finish { result.error("PRINT_UNAVAILABLE", "PrintManager unavailable", null) }
                        return@postDelayed
                    }
                    val jobName = "${activity.applicationContext.applicationInfo.name} print preview"
                    try {
                        printPreview.startPrintJob(printManager, jobName)
                        // Resolve at hand-off to the OS print flow, not at
                        // print completion -- matches the Windows plugin,
                        // which also resolves here. printPreview.destroy()
                        // for this successful case happens later, from
                        // PrintPreviewWebView's own PrintJob listener once
                        // the OS reports a terminal state.
                        finish { result.success(true) }
                    } catch (e: Exception) {
                        printPreview.destroy()
                        finish { result.error("PRINT_PREVIEW_FAILED", e.message, null) }
                    }
                }, duration.toLong())
            }

            @Suppress("OVERRIDE_DEPRECATION")
            override fun onReceivedError(
                view: WebView,
                errorCode: Int,
                description: String?,
                failingUrl: String?
            ) {
                super.onReceivedError(view, errorCode, description, failingUrl)
                printPreview.destroy()
                finish { result.error("WEBVIEW_LOAD_ERROR", description ?: "WebView failed to load content", null) }
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                super.onReceivedError(view, request, error)
                if (request.isForMainFrame) {
                    printPreview.destroy()
                    finish {
                        result.error(
                            "WEBVIEW_LOAD_ERROR",
                            error.description?.toString() ?: "WebView failed to load content",
                            null
                        )
                    }
                }
            }
        }

        webView.loadDataWithBaseURL(null, content, "text/HTML", "UTF-8", null)
    }
```

- [ ] **Step 3: Remove the now-dead `createWebPrintJob` helper**

Delete this method entirely (its logic is now inside `PrintPreviewWebView.startPrintJob`):
```kotlin
    private fun createWebPrintJob(webView: WebView) {

        // Get a PrintManager instance
        (activity?.getSystemService(Context.PRINT_SERVICE) as? PrintManager)?.let { printManager ->
            val applicationName = activity.applicationContext.applicationInfo.name;
            val jobName = "$applicationName print preview"

            // Get a print adapter instance
            val printAdapter = webView.createPrintDocumentAdapter(jobName)
            var printAttributes =
                PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4).build();
            // Create a print job with name and adapter instance
            printManager.print(
                jobName,
                printAdapter,
                printAttributes
            ).also { printJob ->

                // Save the job object for later status checking
//                printJobs += printJob
            }
        }
    }
```

- [ ] **Step 4: Remove the old `webView` field and fix up lifecycle methods**

Replace:
```kotlin
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        print("onAttachedToActivity")
        activity = binding.activity
        webView = WebView(activity.applicationContext)
        webView.minimumHeight = 1
        webView.minimumWidth = 1
    }
```

With:
```kotlin
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        sharedSession.ensure(context)
    }
```

Replace:
```kotlin
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
```

With:
```kotlin
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        sharedSession.destroy()
    }
```

(`sharedSession` is intentionally *not* destroyed in `onDetachedFromActivity`/config-change callbacks — those fire on every screen rotation, and destroying/recreating the shared WebView on each one would defeat the point of reusing it. It's built from `context`, the plugin's application Context, not the Activity, so keeping it alive across Activity changes doesn't leak an Activity.)

- [ ] **Step 5: Compile check**

```bash
cd example && flutter build apk --debug 2>&1 | tail -80
```
Expected: `BUILD SUCCESSFUL`, and no remaining references to a `webView` class field anywhere in the file (`grep -n "private lateinit var webView" android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt` should return nothing).

- [ ] **Step 6: Manual check — printPreview actually resolves**

```bash
cd example && flutter run -d emulator-5554 -t lib/main_printpreview_repro_test.dart
```
Expected: status becomes `printPreview returned: true` (previously this `await` hung forever — confirm it no longer does). Interact with the system print dialog (cancel or save-as-PDF) and confirm no crash in `adb logcat`.

- [ ] **Step 7: Commit**

```bash
git add android/src/main/kotlin/app/mylekha/webcontent_converter/WebcontentConverterPlugin.kt
git commit -m "feat(android): route printPreview through ConversionQueue/PrintPreviewWebView"
```

---

### Task 8: Full manual verification pass

**Files:** none (verification only).

- [ ] **Step 1: Concurrent burst across both PDF and image (shared-session contention)**

```bash
cd example && flutter run -d emulator-5554 -t lib/main_mixed_repro_test.dart
```
Expected: status reaches "ALL SETTLED"; `adb logcat -d | grep "MIXED REPRO"` shows `SUCCESS` for all 4 image + 4 PDF calls, no `FAILED`.

- [ ] **Step 2: Sustained repeated calls (leak/slowdown check)**

```bash
cd example && flutter run -d emulator-5554 -t lib/main_sustained_repro_test.dart
```
Expected: final summary shows a low/flat hang count across the first/middle/last thirds (not trending upward — an upward trend would indicate WebView instances or memory piling up). While this runs, open Android Studio's Memory Profiler attached to the `com.example.example` process and confirm the Java/native heap plateaus rather than climbing linearly over the 60 calls.

- [ ] **Step 3: Large content on both PDF and image paths**

```bash
cd example && flutter run -d emulator-5554 -t lib/main_large_content_repro_test.dart
```
Expected: status reaches `ALL DONE`.

- [ ] **Step 4: printPreview + concurrent contentToPDF (dedicated-WebView isolation check)**

Manually adapt `main_mixed_repro_test.dart`'s pattern for one run: fire `WebcontentConverter.printPreview(...)` unawaited, then immediately fire a `WebcontentConverter.contentToPDF(...)` call. Confirm via `adb logcat` that the PDF call completes successfully and isn't affected by the in-flight print job, and that the print preview dialog still renders the correct content (not blank/corrupted).

- [ ] **Step 5: Watchdog timeout path**

Temporarily point `main_printpreview_repro_test.dart` (or a scratch copy) at content that will never call back — e.g. content whose `<script>` throws before `document` finishes, or an artificially tiny watchdog for testing (temporarily lower `requestTimeoutMs`'s floor in code, run, then revert). Confirm the call rejects with a `TIMEOUT` error within the expected window instead of hanging, and that a subsequent normal call still succeeds afterward (proving the queue slot was correctly freed).

- [ ] **Step 6: Final full compile + commit checkpoint**

```bash
cd example && flutter build apk --debug 2>&1 | tail -50
```
Expected: `BUILD SUCCESSFUL`. No code changes in this task, so nothing to commit — this closes out the plan.

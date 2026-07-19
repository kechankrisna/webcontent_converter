package app.mylekha.webcontent_converter

import android.content.Context
import android.os.Handler
import android.os.Looper
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
// (completed/failed/cancelled), detected by polling -- independent of
// when the plugin's queue slot itself is freed (that happens at
// hand-off, right after print() is called, so a user leaving the system
// print dialog open doesn't block other contentToImage/contentToPDF
// calls in the meantime).
//
// android.print.PrintJob exposes no public listener API for state
// changes in the Android SDK (verified against compileSdk 35: PrintJob
// only has isQueued/isStarted/isBlocked/isCompleted/isFailed/isCancelled
// boolean accessors -- there is no addOnPrintJobStateChangedListener or
// OnPrintJobStateChangedListener callback available to a regular app).
// This uses the polling fallback the design doc calls out for exactly
// this situation: a Handler posts a delayed check of those terminal
// booleans until one is true.
class PrintPreviewWebView(private val context: Context) {
    private var webView: WebView? = null
    private val handler = Handler(Looper.getMainLooper())
    private var pollRunnable: Runnable? = null

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
        pollUntilTerminal(job)
    }

    private fun pollUntilTerminal(job: PrintJob) {
        val runnable = object : Runnable {
            override fun run() {
                if (job.isCompleted || job.isFailed || job.isCancelled) {
                    destroy()
                } else {
                    handler.postDelayed(this, POLL_INTERVAL_MS)
                }
            }
        }
        pollRunnable = runnable
        handler.postDelayed(runnable, POLL_INTERVAL_MS)
    }

    fun destroy() {
        pollRunnable?.let { handler.removeCallbacks(it) }
        pollRunnable = null
        webView?.apply {
            stopLoading()
            webViewClient = WebViewClient()
            destroy()
        }
        webView = null
    }

    companion object {
        private const val POLL_INTERVAL_MS = 500L
    }
}

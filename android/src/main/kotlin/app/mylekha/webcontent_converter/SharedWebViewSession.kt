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

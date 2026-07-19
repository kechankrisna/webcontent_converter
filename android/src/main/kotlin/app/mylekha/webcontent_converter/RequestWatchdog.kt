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

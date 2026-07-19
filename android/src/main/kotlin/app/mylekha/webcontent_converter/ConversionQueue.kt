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

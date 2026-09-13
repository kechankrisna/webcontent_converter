import Foundation

/// A FIFO job queue with one busy slot, so requests serialize instead of racing.
/// Direct port of Android's `ConversionQueue` / Windows' equivalent.
/// Shared by iOS and macOS in the same way every other file in `darwin/Classes/` is.
public class ConversionQueue {
    private let maxQueuedRequests: Int
    private var pendingJobs: [() -> Void] = []
    public private(set) var requestInFlight: Bool = false

    public init(maxQueuedRequests: Int) {
        self.maxQueuedRequests = maxQueuedRequests
    }

    public func isQueueFull() -> Bool {
        return pendingJobs.count >= maxQueuedRequests
    }

    public func startOrQueue(_ job: @escaping () -> Void) {
        if !requestInFlight {
            requestInFlight = true
            job()
        } else {
            pendingJobs.append(job)
        }
    }

    public func onRequestFinished() {
        requestInFlight = false
        guard !pendingJobs.isEmpty else { return }
        let nextJob = pendingJobs.removeFirst()
        requestInFlight = true
        nextJob()
    }
}
import Foundation

/// One-shot timeout: arm with a timeout and callback, disarm to cancel.
/// Backed by Timer.scheduledTimer on the main run loop — Darwin's equivalent
/// of Android's Handler.postDelayed / Windows' SetTimer.
/// Main-thread only, matching the rest of the plugin.
public class RequestWatchdog {
    private var timer: Timer?
    private var onTimeout: (() -> Void)?

    public init() {}

    public func arm(timeoutMs: Int64, onTimeout: @escaping () -> Void) {
        disarm() // cancel any previous timer first
        self.onTimeout = onTimeout
        let interval = TimeInterval(timeoutMs) / 1000.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.onTimeout?()
        }
    }

    public func disarm() {
        timer?.invalidate()
        timer = nil
        onTimeout = nil
    }

    deinit {
        disarm()
    }
}
#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_REQUEST_WATCHDOG_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_REQUEST_WATCHDOG_H_

#include <windows.h>

#include <functional>

namespace webcontent_converter {

// One-shot timeout helper for a single PdfConversionRequest/
// ImageCaptureRequest's whole lifecycle (not just its WebView2Session
// navigation phase -- see the callers for why that distinction matters: a
// request that hangs somewhere after navigation, e.g. PrintToPdf or
// Page.captureScreenshot never calling back, previously had nothing timing
// it out, which left the plugin's single busy slot -- and everything queued
// behind it -- stuck forever).
//
// Backed by a NULL-window SetTimer, matched back to the right instance via
// a small static registry, since SetTimer's TIMERPROC has no user-data
// parameter. Not thread-safe; must be used from the UI thread, matching the
// rest of this plugin.
class RequestWatchdog {
 public:
  RequestWatchdog() = default;
  ~RequestWatchdog();

  RequestWatchdog(const RequestWatchdog&) = delete;
  RequestWatchdog& operator=(const RequestWatchdog&) = delete;

  // Schedules `on_timeout` to fire after `timeout_ms` unless Disarm() is
  // called first. Re-arming an already-armed watchdog disarms the previous
  // timer first.
  void Arm(UINT timeout_ms, std::function<void()> on_timeout);

  // Cancels a pending timeout, if any. Safe to call when not armed.
  void Disarm();

 private:
  static void CALLBACK TimerProc(HWND, UINT, UINT_PTR id, DWORD);
  void OnTimeout();

  std::function<void()> on_timeout_;
  UINT_PTR timer_id_ = 0;
};

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_REQUEST_WATCHDOG_H_

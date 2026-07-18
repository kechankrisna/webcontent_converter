#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_IMAGE_CAPTURE_REQUEST_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_IMAGE_CAPTURE_REQUEST_H_

#include <windows.h>
#include <wrl.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "WebView2.h"
#include "request_watchdog.h"
#include "webview2_session.h"

namespace webcontent_converter {

// Drives a single content-to-image capture through a WebView2 instance (see
// WebView2Session): once the page is ready, measures the page's full
// scrollable content size, then captures it as PNG via the DevTools
// Protocol's Page.captureScreenshot with captureBeyondViewport -- the same
// technique Puppeteer's page.screenshot({fullPage: true}) uses.
//
// This is the second capture mechanism tried here. The first, a Win32
// PrintWindow(..., PW_RENDERFULLCONTENT) screen-scrape of WebView2's actual
// compositor/render-host child window, worked but only within the confines
// of whatever was actually on-screen: PrintWindow can only read back the
// portion of a child control that falls within its ancestor window's
// on-screen bounds, so content taller than the embedding app's own window
// had to be captured in scrolled, stitched-together tiles. That tiling
// depended on a fixed JS-side settle delay (scroll, wait, throwaway
// "warm-up" capture, wait again, real capture) to let WebView2's DWM-based
// readback catch up to the browser's actual render state, tuned against a
// slower, freshly-created-per-request WebView2 environment. Once
// environment/controller creation was moved out of the per-request path
// (see WebView2Session), everything after navigation started completing
// fast enough that those fixed delays stopped being enough, and long,
// multi-tile content came back with stale/misaligned tiles -- blank at the
// top, missing at the bottom.
//
// captureBeyondViewport sidesteps the whole problem: Page.captureScreenshot
// renders directly from the browser's own compositor into an image buffer,
// not a screen scrape, so it isn't bound by the parent window's on-screen
// size and needs no scrolling, tiling, or settle-delay tuning -- one
// request, one capture. (An earlier prototype of this plugin tried
// WebView2's CapturePreview API and this same DevTools Protocol call and
// both crashed inside the WebView2 runtime itself; that was under a
// different, since-removed architecture -- a fresh environment/controller
// per request, and at one point a dedicated host window instead of the
// app's own -- and did not reproduce when retried against the current
// persistent-session setup.)
//
// The WebView2Session is owned by whoever constructs this request (in
// practice, WebcontentConverterPlugin) and outlives it -- it's reused across
// every PDF/image request for the plugin's lifetime rather than being
// created and torn down per request, so this class only borrows it.
//
// Self-contained lifetime: construct with `new`, call `Start()`, and the
// object deletes itself via `on_complete` once the capture finishes or
// fails, following the same self-destruction contract as
// PdfConversionRequest.
class ImageCaptureRequest {
 public:
  // `session` must outlive this request (owned by the plugin).
  ImageCaptureRequest(
      WebView2Session* session, std::wstring content, double duration_ms,
      std::function<void(ImageCaptureRequest* self,
                          std::optional<std::vector<uint8_t>> image_bytes,
                          std::optional<std::string> error)>
          on_complete);

  // WebView2 gives no way to cancel an in-flight async call (ExecuteScript,
  // Page.captureScreenshot, etc.), so if RequestWatchdog's timeout -- or a
  // capture-attempt retry -- gives up on a call that's still outstanding,
  // its completion lambda (which captures `this`) can still fire later,
  // after this object is gone. alive_ is how those lambdas find out `this`
  // is no longer safe to touch: see the pattern used throughout the .cpp.
  ~ImageCaptureRequest() { *alive_ = false; }

  void Start();

 private:
  void OnReady(ICoreWebView2Environment* environment, ICoreWebView2* webview);
  void OnSizeMeasured(const std::wstring& size_json);
  // Issues a Page.captureScreenshot call and arms capture_watchdog_ around
  // it. Page.captureScreenshot (reached via the general-purpose
  // CallDevToolsProtocolMethod bridge, unlike PrintToPdf's dedicated WebView2
  // API) was observed to occasionally never invoke its completion callback
  // at all under rapid repeated navigation on a reused webview -- retrying
  // once from scratch consistently recovered when that happened in testing.
  void CaptureScreenshot();
  void OnScreenshotCaptured(HRESULT error_code, LPCWSTR result_json);

  void Fail(const std::string& message);

  std::wstring content_;
  double duration_ms_;
  std::function<void(ImageCaptureRequest*, std::optional<std::vector<uint8_t>>,
                      std::optional<std::string>)>
      on_complete_;

  // Borrowed; not owned. See class comment.
  WebView2Session* session_;
  // Borrowed from session_; valid only within this request's lifetime.
  ICoreWebView2* webview_ = nullptr;

  long content_width_ = 800;
  long content_height_ = 600;

  // Guards against a stale/late completion from a captureScreenshot attempt
  // that was already given up on and retried (or from the overall
  // watchdog's own Fail() racing a real completion) from being acted on
  // twice.
  bool completed_ = false;

  int capture_attempt_ = 0;

  // Covers this request's whole lifecycle (navigation through
  // Page.captureScreenshot), not just WebView2Session's own navigation-phase
  // timeout -- see RequestWatchdog's class comment for why that distinction
  // matters. Bounds the total time across all capture attempts.
  RequestWatchdog watchdog_;

  // Shorter, per-attempt timeout that triggers a retry of just the
  // Page.captureScreenshot call -- see CaptureScreenshot's comment.
  RequestWatchdog capture_watchdog_;

  // See the destructor comment. Shared (not just owned) because outstanding
  // WebView2 completion lambdas hold their own copy, keeping the flag alive
  // independent of `this`.
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
};

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_IMAGE_CAPTURE_REQUEST_H_

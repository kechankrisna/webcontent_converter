#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_WEBVIEW2_SESSION_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_WEBVIEW2_SESSION_H_

#include <windows.h>
#include <wrl.h>

#include <functional>
#include <string>

#include "WebView2.h"

namespace webcontent_converter {

// Bootstraps a private WebView2 environment/controller parented to the
// embedding app's own top-level window, and drives content through it for
// PdfConversionRequest and ImageCaptureRequest. Each request queries
// whichever versioned interface it specifically needs (e.g.
// ICoreWebView2Environment6, ICoreWebView2_7) off of what's handed to
// ReadyCallback.
//
// A dedicated, freshly-created private host window was tried instead of the
// app's own window (so nothing would ever need to be shown over the app's
// real UI), but WebView2 controller creation crashed inside the WebView2
// runtime itself (EmbeddedBrowserWebView.dll, access violation) when
// parented to it -- reproducibly, for both PrintToPdf and CapturePreview,
// regardless of that window's visibility/style. Parenting to the app's own
// already-established window is the configuration known to work.
//
// This session is long-lived: it's created once (lazily, on first use) and
// reused for every request for the rest of the plugin's lifetime, rather
// than being torn down and recreated per request. Creating a brand-new
// WebView2 browser environment/controller for every single conversion was
// tried first and proved fragile in practice -- repeated environment
// creation on the same parent HWND was flaky enough that earlier code tried
// papering over it with a growing artificial delay (1s, then 2s, then 5s)
// before each new creation, none of which reliably fixed it, because the
// delay was blocking the very UI-thread message pump that WebView2's own
// COM/IPC setup needs to progress. Reusing one environment/controller
// avoids that churn entirely: only the very first request pays the
// environment/controller creation cost, and every later request just
// navigates the existing webview to new content.
//
// Owned by WebcontentConverterPlugin, which serializes every PDF and image
// request through this single instance (only one request is ever in flight
// at a time), so none of the state below needs to handle concurrent
// requests.
class WebView2Session {
 public:
  using ReadyCallback = std::function<void(ICoreWebView2Environment*,
                                            ICoreWebView2*)>;
  using ErrorCallback = std::function<void(const std::string& message)>;

  explicit WebView2Session(HWND parent_window);

  // Destructor - ensures all COM resources and event handlers are released
  // Memory safety: All ComPtr members auto-decrement reference counts
  ~WebView2Session();

  // Non-copyable and non-movable (contains COM references)
  WebView2Session(const WebView2Session&) = delete;
  WebView2Session& operator=(const WebView2Session&) = delete;
  WebView2Session(WebView2Session&&) = delete;
  WebView2Session& operator=(WebView2Session&&) = delete;

  // Ensures the environment/controller exist -- creating them on first call,
  // or recreating them if the browser process previously crashed -- resets
  // the controller to its idle bounds/visibility, navigates to `content`,
  // and invokes `on_ready` once the page and its fonts have settled (or
  // `on_error` on failure/timeout). Safe to call again for the next request
  // once a prior call has completed.
  void EnsureAndNavigate(std::wstring content, double duration_ms,
                          ReadyCallback on_ready, ErrorCallback on_error);

  // Closes the controller and releases all COM references. Safe to call
  // more than once. Only used for real teardown (plugin shutdown, or
  // recovering from a crashed browser process) -- not after every request.
  void Close();

  ICoreWebView2Controller* controller() { return controller_.Get(); }

 private:
  void CreateEnvironmentAndController();
  HRESULT OnEnvironmentCreated(HRESULT result,
                                ICoreWebView2Environment* environment);
  HRESULT OnControllerCreated(HRESULT result,
                               ICoreWebView2Controller* controller);
  HRESULT OnNavigationCompleted(
      ICoreWebView2NavigationCompletedEventArgs* args);
  HRESULT OnProcessFailed(ICoreWebView2ProcessFailedEventArgs* args);
  // Serves pending_content_ from memory for navigations to the fixed
  // synthetic URL Navigate() always targets -- see StartNavigation's
  // comment for why there's no file (or NavigateToString) involved.
  HRESULT OnWebResourceRequested(
      ICoreWebView2* sender, ICoreWebView2WebResourceRequestedEventArgs* args);

  void StartNavigation();

  // Completes the in-flight request exactly once. Timing out an individual
  // request is the caller's responsibility now (see PdfConversionRequest/
  // ImageCaptureRequest's RequestWatchdog members, which cover their whole
  // lifecycle -- not just the navigation phase this class handles); this
  // guard just protects against something completing twice, e.g. a late
  // ProcessFailed after navigation already succeeded or failed.
  void CompleteReady();
  void CompleteError(const std::string& message);

  HWND parent_window_;
  std::wstring user_data_folder_;

  // State for whichever request is currently in flight. Only one request is
  // ever active at a time (enforced by the owning plugin), so this is
  // simply overwritten per call rather than queued.
  std::wstring pending_content_;
  double pending_duration_ms_ = 0;
  ReadyCallback on_ready_;
  ErrorCallback on_error_;
  bool completed_ = true;

  // False after the browser process reports failure via ProcessFailed;
  // EnsureAndNavigate tears down and recreates the environment/controller
  // when this is set, instead of trying to reuse a dead session.
  bool healthy_ = true;

  Microsoft::WRL::ComPtr<ICoreWebView2Environment> environment_;
  Microsoft::WRL::ComPtr<ICoreWebView2Controller> controller_;
  Microsoft::WRL::ComPtr<ICoreWebView2> webview_;
  EventRegistrationToken navigation_token_{};
  bool navigation_token_valid_ = false;
  EventRegistrationToken process_failed_token_{};
  bool process_failed_token_valid_ = false;
  EventRegistrationToken web_resource_requested_token_{};
  bool web_resource_requested_token_valid_ = false;
};

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_WEBVIEW2_SESSION_H_

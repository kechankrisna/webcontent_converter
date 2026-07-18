#include "webview2_session.h"

#include "WebView2EnvironmentOptions.h"
#include <cstdio>
#include <sstream>
#include <iomanip>
#include <shellapi.h>
#include <shlwapi.h>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;
using Microsoft::WRL::Make;

namespace webcontent_converter {

namespace {

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return std::string();
  int size = ::WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                    static_cast<int>(wide.size()), nullptr, 0,
                                    nullptr, nullptr);
  std::string result(size, '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                         result.data(), size, nullptr, nullptr);
  return result;
}

// Fixed synthetic URL every Navigate() call targets; the actual content
// behind it is served in-memory per request by OnWebResourceRequested, so
// this URL itself never needs to change. ".invalid" is the TLD RFC 2606
// reserves for exactly this kind of made-up address, so it can't collide
// with a real domain even though the page requests real https:// resources
// (fonts, CDN scripts) alongside it.
const wchar_t kContentUrl[] = L"https://webcontentconverter.invalid/content.html";

// Timestamped breadcrumb for the async milestones below, so a future stall
// is diagnosable from a DebugView/VS output capture -- or, since this app
// has no attached console, from this plain log file -- instead of another
// round of guessing at delay values.
void LogMilestone(const char* stage) {
  std::ostringstream oss;
  oss << "[webcontent_converter][t=" << ::GetTickCount64() << "] " << stage
      << "\n";
  ::OutputDebugStringA(oss.str().c_str());

  wchar_t temp_path[MAX_PATH];
  if (::GetTempPathW(MAX_PATH, temp_path)) {
    std::wstring log_path =
        std::wstring(temp_path) + L"webcontent_converter_diag.log";
    FILE* f = nullptr;
    if (_wfopen_s(&f, log_path.c_str(), L"a") == 0 && f) {
      fputs(oss.str().c_str(), f);
      fclose(f);
    }
  }
}

}  // namespace

WebView2Session::WebView2Session(HWND parent_window)
    : parent_window_(parent_window) {
  wchar_t temp_path[MAX_PATH];
  ::GetTempPathW(MAX_PATH, temp_path);
  std::wstringstream ss;
  ss << temp_path << L"webcontent_converter_" << ::GetCurrentProcessId();
  user_data_folder_ = ss.str();
}

WebView2Session::~WebView2Session() { Close(); }

void WebView2Session::EnsureAndNavigate(std::wstring content,
                                         double duration_ms,
                                         ReadyCallback on_ready,
                                         ErrorCallback on_error) {
  pending_content_ = std::move(content);
  pending_duration_ms_ = duration_ms;
  on_ready_ = std::move(on_ready);
  on_error_ = std::move(on_error);
  completed_ = false;

  if (!healthy_ && controller_) {
    // The browser process died since the last request; tear down and
    // recreate from scratch rather than trying to reuse a dead session.
    Close();
  }

  if (controller_) {
    LogMilestone("reusing existing controller");
    StartNavigation();
    return;
  }

  LogMilestone("creating new environment/controller");
  CreateEnvironmentAndController();
}

void WebView2Session::CreateEnvironmentAndController() {
  // Use a private user-data folder so this plugin's WebView2 instance never
  // collides with any other WebView2 usage in the embedding app.
  auto options = Make<CoreWebView2EnvironmentOptions>();

  HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
      nullptr, user_data_folder_.c_str(), options.Get(),
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [this](HRESULT result, ICoreWebView2Environment* environment) {
            return OnEnvironmentCreated(result, environment);
          })
          .Get());
  if (FAILED(hr)) {
    std::ostringstream oss;
    oss << "Failed to start WebView2 environment creation. HRESULT: 0x"
        << std::hex << hr;
    CompleteError(oss.str());
  }
}

HRESULT WebView2Session::OnEnvironmentCreated(
    HRESULT result, ICoreWebView2Environment* environment) {
  if (FAILED(result)) {
    std::ostringstream oss;
    oss << "WebView2 environment creation failed. HRESULT: 0x"
        << std::hex << result;
    CompleteError(oss.str());
    return S_OK;
  }

  if (!environment) {
    CompleteError("WebView2 environment is null. Is the WebView2 Runtime installed?");
    return S_OK;
  }

  LogMilestone("environment created");
  environment_ = environment;

  HRESULT hr = environment_->CreateCoreWebView2Controller(
      parent_window_,
      Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
          [this](HRESULT result, ICoreWebView2Controller* controller) {
            return OnControllerCreated(result, controller);
          })
          .Get());
  if (FAILED(hr)) {
    std::ostringstream oss;
    oss << "Failed to start WebView2 controller creation. HRESULT: 0x"
        << std::hex << hr;
    CompleteError(oss.str());
  }
  return S_OK;
}

HRESULT WebView2Session::OnControllerCreated(
    HRESULT result, ICoreWebView2Controller* controller) {
  if (FAILED(result)) {
    std::ostringstream oss;
    oss << "WebView2 controller creation failed. HRESULT: 0x"
        << std::hex << result;
    CompleteError(oss.str());
    return S_OK;
  }

  if (!controller) {
    CompleteError("WebView2 controller is null");
    return S_OK;
  }

  LogMilestone("controller created");
  controller_ = controller;

  // Kept hidden and tiny (1x1) for the controller's whole lifetime unless a
  // request resizes it. Neither capture path needs on-screen visibility:
  // PrintToPdf never did, and ImageCaptureRequest now captures via the
  // DevTools Protocol's Page.captureScreenshot, which renders directly from
  // the browser's compositor rather than screen-scraping -- see
  // ImageCaptureRequest's class comment for why that replaced the earlier
  // PrintWindow-based approach, which did need visibility and was sensitive
  // to exactly when it was granted.
  RECT bounds{0, 0, 1, 1};
  controller_->put_Bounds(bounds);
  controller_->put_IsVisible(FALSE);

  // This controller is a child window layered directly on top of the
  // embedding app's own rendered content (see the class comment on why it
  // has to be parented there). If the WebView2 surface has any
  // transparency -- its default background is unset/transparent unless
  // the page itself sets an opaque one -- PrintWindow's full-content
  // capture blends in whatever is visually behind it, i.e. the app's own
  // Flutter UI, into the captured image. Forcing an opaque white
  // background here means capture always reflects only the page, no
  // matter what the page's own CSS does or doesn't set.
  ComPtr<ICoreWebView2Controller2> controller2;
  if (SUCCEEDED(controller_.As(&controller2))) {
    COREWEBVIEW2_COLOR opaque_white{255, 255, 255, 255};
    controller2->put_DefaultBackgroundColor(opaque_white);
  }

  ComPtr<ICoreWebView2> webview;
  if (FAILED(controller_->get_CoreWebView2(&webview)) || !webview) {
    CompleteError("Failed to get the CoreWebView2 instance");
    return S_OK;
  }
  webview_ = webview;

  // Registered once for the session's whole lifetime (not per request).
  HRESULT hr = webview_->add_NavigationCompleted(
      Callback<ICoreWebView2NavigationCompletedEventHandler>(
          [this](ICoreWebView2*,
                 ICoreWebView2NavigationCompletedEventArgs* args) {
            return OnNavigationCompleted(args);
          })
          .Get(),
      &navigation_token_);
  if (SUCCEEDED(hr)) {
    navigation_token_valid_ = true;
  }

  hr = webview_->add_ProcessFailed(
      Callback<ICoreWebView2ProcessFailedEventHandler>(
          [this](ICoreWebView2*, ICoreWebView2ProcessFailedEventArgs* args) {
            return OnProcessFailed(args);
          })
          .Get(),
      &process_failed_token_);
  if (SUCCEEDED(hr)) {
    process_failed_token_valid_ = true;
  }

  // Serves pending_content_ from memory instead of Navigate()-ing to a file
  // on disk -- see StartNavigation's comment for the full rationale. Filter
  // + handler are registered once here, for the session's whole lifetime,
  // same as NavigationCompleted/ProcessFailed above.
  webview_->AddWebResourceRequestedFilter(
      kContentUrl, COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT);
  hr = webview_->add_WebResourceRequested(
      Callback<ICoreWebView2WebResourceRequestedEventHandler>(
          [this](ICoreWebView2* sender,
                 ICoreWebView2WebResourceRequestedEventArgs* args) {
            return OnWebResourceRequested(sender, args);
          })
          .Get(),
      &web_resource_requested_token_);
  if (SUCCEEDED(hr)) {
    web_resource_requested_token_valid_ = true;
  }

  // Real DevTools Protocol clients (Puppeteer included) always enable the
  // Page domain before issuing Page.* commands -- it's what keeps the
  // browser's frame-lifecycle bookkeeping in sync, which commands like
  // Page.captureScreenshot (used by ImageCaptureRequest) appear to depend on
  // to reliably respond at all under rapid repeated navigation on a reused
  // webview: without this, captureScreenshot was observed to occasionally
  // never invoke its completion callback. Fire-and-forget (best-effort,
  // logged but not gated on) since this only needs to happen once per
  // webview, not per request, and shouldn't hold up navigation if it's ever
  // slow to respond itself.
  webview_->CallDevToolsProtocolMethod(
      L"Page.enable", L"{}",
      Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
          [](HRESULT hr, LPCWSTR) {
            if (FAILED(hr)) {
              std::ostringstream oss;
              oss << "Page.enable failed. HRESULT: 0x" << std::hex << hr;
              LogMilestone(oss.str().c_str());
            }
            return S_OK;
          })
          .Get());

  healthy_ = true;
  StartNavigation();
  return S_OK;
}

void WebView2Session::StartNavigation() {
  // Reset to the idle 1x1 footprint before navigating; visibility itself is
  // left alone here -- see the class/controller-creation comments on why it
  // stays TRUE for the controller's whole lifetime rather than being
  // toggled per-request.
  RECT bounds{0, 0, 1, 1};
  controller_->put_Bounds(bounds);

  // Always navigates to the same fixed URL; OnWebResourceRequested serves
  // whatever pending_content_ currently is from memory when WebView2 asks
  // for it. Two things this deliberately avoids:
  //  - NavigateToString(), which hard-fails (E_INVALIDARG) for htmlContent
  //    over ~2MB -- real-world HTML with embedded images/fonts hits that
  //    easily.
  //  - Writing content to a temp file and Navigate()-ing to a file:// URI
  //    (an earlier version of this code did exactly that to work around the
  //    above): it works, but touches disk on every single request for no
  //    reason, and file:// is a slightly different security context than
  //    the https:// origin real pages normally load under. Serving from
  //    memory over a synthetic https:// origin avoids both the size limit
  //    and the disk write.
  LogMilestone("start navigation");
  HRESULT hr = webview_->Navigate(kContentUrl);
  if (FAILED(hr)) {
    std::ostringstream oss;
    oss << "Failed to start navigation. HRESULT: 0x" << std::hex << hr;
    CompleteError(oss.str());
  }
}

HRESULT WebView2Session::OnWebResourceRequested(
    ICoreWebView2*, ICoreWebView2WebResourceRequestedEventArgs* args) {
  ComPtr<ICoreWebView2WebResourceRequest> request;
  if (FAILED(args->get_Request(&request)) || !request) return S_OK;

  LPWSTR uri = nullptr;
  HRESULT hr = request->get_Uri(&uri);
  bool matches = SUCCEEDED(hr) && uri && wcscmp(uri, kContentUrl) == 0;
  if (uri) ::CoTaskMemFree(uri);
  if (!matches) return S_OK;

  std::string utf8_content = WideToUtf8(pending_content_);
  ComPtr<IStream> stream;
  stream.Attach(::SHCreateMemStream(
      reinterpret_cast<const BYTE*>(utf8_content.data()),
      static_cast<UINT>(utf8_content.size())));
  if (!stream) return S_OK;

  // no-store/no-cache: this URL is reused for every request with different
  // content behind it, so the browser must never serve a cached response
  // instead of asking us again.
  ComPtr<ICoreWebView2WebResourceResponse> response;
  hr = environment_->CreateWebResourceResponse(
      stream.Get(), 200, L"OK",
      L"Content-Type: text/html; charset=utf-8\r\n"
      L"Cache-Control: no-store, no-cache, must-revalidate",
      &response);
  if (FAILED(hr) || !response) return S_OK;

  args->put_Response(response.Get());
  return S_OK;
}

HRESULT WebView2Session::OnNavigationCompleted(
    ICoreWebView2NavigationCompletedEventArgs* args) {
  BOOL success = FALSE;
  args->get_IsSuccess(&success);
  if (!success) {
    CompleteError("Content failed to load in WebView2");
    return S_OK;
  }

  LogMilestone("navigation completed");

  // Wait the requested settle duration, then for web fonts to finish
  // loading, before handing control back -- mirroring the
  // `await Future.delayed(duration); await document.fonts.ready;` sequence
  // used on the other platforms for content whose rendering depends on more
  // than just fonts (e.g. delayed script-driven layout). WebView2 awaits a
  // script that evaluates to a Promise before invoking the handler.
  long long duration_ms = pending_duration_ms_ > 0
                               ? static_cast<long long>(pending_duration_ms_)
                               : 0;
  std::wstring script =
      L"(function(){ return new Promise(function(resolve){ "
      L"setTimeout(function(){ "
      L"var ready = (document.fonts && document.fonts.ready) ? "
      L"document.fonts.ready : Promise.resolve(); "
      L"ready.then(function(){ resolve(true); }); }, " +
      std::to_wstring(duration_ms) + L"); }); })();";

  webview_->ExecuteScript(
      script.c_str(),
      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
          [this](HRESULT, LPCWSTR) {
            CompleteReady();
            return S_OK;
          })
          .Get());
  return S_OK;
}

HRESULT WebView2Session::OnProcessFailed(
    ICoreWebView2ProcessFailedEventArgs* args) {
  healthy_ = false;
  LogMilestone("process failed");
  if (!completed_) {
    CompleteError("WebView2 browser process failed");
  }
  return S_OK;
}

void WebView2Session::CompleteReady() {
  if (completed_) return;
  completed_ = true;
  LogMilestone("request ready");
  auto on_ready = std::move(on_ready_);
  on_ready_ = nullptr;
  on_error_ = nullptr;
  if (on_ready) on_ready(environment_.Get(), webview_.Get());
}

void WebView2Session::CompleteError(const std::string& message) {
  if (completed_) return;
  completed_ = true;
  LogMilestone(("request failed: " + message).c_str());
  auto on_error = std::move(on_error_);
  on_ready_ = nullptr;
  on_error_ = nullptr;
  if (on_error) on_error(message);
}

void WebView2Session::Close() {
  // Unregister event handlers before cleanup
  if (navigation_token_valid_ && webview_) {
    webview_->remove_NavigationCompleted(navigation_token_);
    navigation_token_valid_ = false;
  }
  if (process_failed_token_valid_ && webview_) {
    webview_->remove_ProcessFailed(process_failed_token_);
    process_failed_token_valid_ = false;
  }
  if (web_resource_requested_token_valid_ && webview_) {
    webview_->remove_WebResourceRequested(web_resource_requested_token_);
    web_resource_requested_token_valid_ = false;
  }

  // Close and release COM objects in proper order
  // CRITICAL: Make controller invisible BEFORE closing to help WebView2 cleanup faster
  if (controller_) {
    // Hide the controller to release visual resources immediately
    controller_->put_IsVisible(FALSE);

    // Close the controller (synchronous call but triggers async cleanup)
    controller_->Close();

    // Release the COM pointer
    controller_.Reset();
  }

  // Release webview and environment after controller is fully closed
  if (webview_) {
    webview_.Reset();
  }

  if (environment_) {
    environment_.Reset();
  }
}

}  // namespace webcontent_converter

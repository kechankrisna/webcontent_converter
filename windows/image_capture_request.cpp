#include "image_capture_request.h"

#include <wincrypt.h>

#include <cstdio>
#include <cwchar>
#include <sstream>

using Microsoft::WRL::Callback;

namespace webcontent_converter {

namespace {

// Page.captureScreenshot occasionally never calls back at all (see
// CaptureScreenshot's comment); this bounds how long a single attempt waits
// before giving up on it and trying again, fresh. Kept short (rather than,
// say, several seconds) because a successful call -- even for the largest
// content seen in testing -- consistently returns in well under 500ms; when
// it doesn't return around that fast, it isn't going to.
constexpr UINT kCaptureAttemptTimeoutMs = 2000;
constexpr int kMaxCaptureAttempts = 3;

// Covers this request's whole lifecycle -- see RequestWatchdog's class
// comment for why that's more than just the navigation phase. Comfortably
// fits kMaxCaptureAttempts attempts at kCaptureAttemptTimeoutMs each, plus
// room for navigation/measurement and very tall full-page content
// legitimately taking a while.
constexpr UINT kRequestTimeoutMs =
    kCaptureAttemptTimeoutMs * kMaxCaptureAttempts + 10000;

// Pulls a numeric field out of a flat JSON object we generated ourselves
// (e.g. `{"width":812,"height":1400}`), so this doesn't need to pull in a
// JSON library just to read two numbers back out of WebView2's own
// ExecuteScript result.
long ExtractJsonNumber(const std::wstring& json, const wchar_t* key) {
  std::wstring needle = std::wstring(L"\"") + key + L"\":";
  auto pos = json.find(needle);
  if (pos == std::wstring::npos) return 0;
  pos += needle.size();
  return std::wcstol(json.c_str() + pos, nullptr, 10);
}

// Pulls a string field's raw value out of a JSON object returned by the
// DevTools Protocol (e.g. `{"data":"iVBORw0K..."}`). Base64 never contains
// `"` or `\`, so this doesn't need to handle JSON escaping.
std::wstring ExtractJsonString(const std::wstring& json, const wchar_t* key) {
  std::wstring needle = std::wstring(L"\"") + key + L"\":\"";
  auto pos = json.find(needle);
  if (pos == std::wstring::npos) return L"";
  pos += needle.size();
  auto end = json.find(L'"', pos);
  if (end == std::wstring::npos) return L"";
  return json.substr(pos, end - pos);
}

bool Base64Decode(const std::wstring& base64, std::vector<uint8_t>* out) {
  DWORD out_len = 0;
  if (!::CryptStringToBinaryW(base64.c_str(), static_cast<DWORD>(base64.size()),
                               CRYPT_STRING_BASE64, nullptr, &out_len,
                               nullptr, nullptr)) {
    return false;
  }
  out->resize(out_len);
  if (!::CryptStringToBinaryW(base64.c_str(), static_cast<DWORD>(base64.size()),
                               CRYPT_STRING_BASE64, out->data(), &out_len,
                               nullptr, nullptr)) {
    return false;
  }
  out->resize(out_len);
  return true;
}

// Temporary diagnostic aid, shares the same log file WebView2Session writes
// to.
void LogTileDiag(const std::string& message) {
  wchar_t temp_path[MAX_PATH];
  if (!::GetTempPathW(MAX_PATH, temp_path)) return;
  std::wstring log_path =
      std::wstring(temp_path) + L"webcontent_converter_diag.log";
  FILE* f = nullptr;
  if (_wfopen_s(&f, log_path.c_str(), L"a") == 0 && f) {
    std::ostringstream oss;
    oss << "[image_capture][t=" << ::GetTickCount64() << "] " << message
        << "\n";
    fputs(oss.str().c_str(), f);
    fclose(f);
  }
}

}  // namespace

ImageCaptureRequest::ImageCaptureRequest(
    WebView2Session* session, std::wstring content, double duration_ms,
    std::function<void(ImageCaptureRequest*, std::optional<std::vector<uint8_t>>,
                        std::optional<std::string>)>
        on_complete)
    : content_(std::move(content)),
      duration_ms_(duration_ms),
      on_complete_(std::move(on_complete)),
      session_(session) {}

void ImageCaptureRequest::Start() {
  watchdog_.Arm(kRequestTimeoutMs, [this]() { Fail("Request timed out"); });
  auto alive = alive_;
  session_->EnsureAndNavigate(
      content_, duration_ms_,
      [this, alive](ICoreWebView2Environment* environment,
                    ICoreWebView2* webview) {
        if (!*alive) return;
        OnReady(environment, webview);
      },
      [this, alive](const std::string& message) {
        if (!*alive) return;
        Fail(message);
      });
}

void ImageCaptureRequest::OnReady(ICoreWebView2Environment*,
                                   ICoreWebView2* webview) {
  webview_ = webview;

  auto alive = alive_;
  webview_->ExecuteScript(
      // Hides Chromium's own scrollbar chrome before anything is measured
      // or captured. Without this, resizing the controller to exactly the
      // measured content size leaves just enough of a margin for Chromium
      // to decide a scrollbar is still needed (a circular sizing quirk --
      // the measurement itself doesn't account for the scrollbar it then
      // renders), and that scrollbar gets baked directly into the
      // Page.captureScreenshot output. Applied before measuring so the
      // measurement reflects the no-scrollbar state too.
      L"(function(){ "
      L"var style = document.createElement('style'); "
      L"style.textContent = '::-webkit-scrollbar { width: 0px !important; "
      L"height: 0px !important; background: transparent !important; } "
      L"html { scrollbar-width: none !important; }'; "
      L"document.head.appendChild(style); "
      L"var w = Math.max(document.body.scrollWidth, document.body.offsetWidth, "
      L"document.documentElement.scrollWidth, document.documentElement.offsetWidth); "
      L"var h = Math.max(document.body.scrollHeight, document.body.offsetHeight, "
      L"document.documentElement.scrollHeight, document.documentElement.offsetHeight); "
      L"return {width: w, height: h}; })();",
      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
          [this, alive](HRESULT error_code, LPCWSTR result_json) {
            if (!*alive) return S_OK;
            if (FAILED(error_code) || !result_json) {
              Fail("Failed to measure content size");
              return S_OK;
            }
            OnSizeMeasured(result_json);
            return S_OK;
          })
          .Get());
}

void ImageCaptureRequest::OnSizeMeasured(const std::wstring& size_json) {
  content_width_ = ExtractJsonNumber(size_json, L"width");
  content_height_ = ExtractJsonNumber(size_json, L"height");
  if (content_width_ <= 0) content_width_ = 800;
  if (content_height_ <= 0) content_height_ = 600;

  // Unlike the PrintWindow approach this replaced, Page.captureScreenshot
  // renders directly from the browser's compositor rather than scraping the
  // screen, so the controller doesn't need to stay within the embedding
  // app's on-screen bounds -- it can just be sized to the full content.
  RECT bounds{0, 0, content_width_, content_height_};
  session_->controller()->put_Bounds(bounds);

  {
    std::ostringstream oss;
    oss << "measured content_width=" << content_width_
        << " content_height=" << content_height_;
    LogTileDiag(oss.str());
  }

  // Settle wait after the resize: forced reflow, a resize event, a few
  // animation frames, then a short floor -- same idea as the delay that
  // used to exist per-tile, just once now since there's only one capture.
  auto alive = alive_;
  webview_->ExecuteScript(
      L"(function(){ return new Promise(function(resolve){ "
      L"void document.body.offsetHeight; "
      L"window.dispatchEvent(new Event('resize')); "
      L"var framesLeft = 4; "
      L"function nextFrame(){ "
      L"if (framesLeft-- <= 0) { setTimeout(resolve, 150); return; } "
      L"requestAnimationFrame(nextFrame); } "
      L"nextFrame(); }); })();",
      Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
          [this, alive](HRESULT, LPCWSTR) {
            if (!*alive) return S_OK;
            CaptureScreenshot();
            return S_OK;
          })
          .Get());
}

void ImageCaptureRequest::CaptureScreenshot() {
  capture_attempt_++;

  // No captureBeyondViewport/clip/fromSurface: OnSizeMeasured already
  // resizes the controller (and therefore the browser's viewport) to
  // exactly the full content size before this ever runs, so there's no
  // "beyond the viewport" left to capture -- a plain screenshot of the
  // current viewport already covers the whole page. captureBeyondViewport
  // is a newer, more involved CDP code path (it coordinates off-screen
  // rendering) than a bare capture, and was the leading suspect for why
  // Page.captureScreenshot would intermittently never call back at all
  // (not slow, just silent) even with several seconds between requests --
  // ruling out request timing/rapid-navigation as the cause. Simplifying to
  // the plain call removes the dependency on that code path entirely.
  std::wstring params = L"{\"format\":\"png\"}";

  {
    std::ostringstream oss;
    oss << "calling Page.captureScreenshot, attempt " << capture_attempt_;
    LogTileDiag(oss.str());
  }

  // Still keep a per-attempt watchdog + retry as a backstop even after the
  // above: a successful call consistently returns in well under 500ms in
  // testing, so giving up and retrying quickly costs little if it's ever
  // still needed, and costs nothing when it isn't.
  capture_watchdog_.Arm(kCaptureAttemptTimeoutMs, [this]() {
    std::ostringstream oss;
    oss << "capture attempt " << capture_attempt_ << " timed out";
    LogTileDiag(oss.str());
    if (capture_attempt_ < kMaxCaptureAttempts) {
      CaptureScreenshot();
    } else {
      Fail("Page.captureScreenshot did not respond after " +
           std::to_string(kMaxCaptureAttempts) + " attempts");
    }
  });

  // alive_ is essential here specifically: unlike ExecuteScript calls (whose
  // worst case is just a slow page), a stuck captureScreenshot attempt gets
  // abandoned by capture_watchdog_ and retried while the original call is
  // still outstanding -- WebView2 has no way to cancel it -- so its
  // eventual, late completion is expected, not just theoretical. Without
  // this guard, that late callback would call into a `this` that may
  // already have been destroyed (the retry, or a full request timeout,
  // completed and freed it first).
  auto alive = alive_;
  webview_->CallDevToolsProtocolMethod(
      L"Page.captureScreenshot", params.c_str(),
      Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
          [this, alive](HRESULT error_code, LPCWSTR result_json) {
            if (!*alive) return S_OK;
            OnScreenshotCaptured(error_code, result_json);
            return S_OK;
          })
          .Get());
}

void ImageCaptureRequest::OnScreenshotCaptured(HRESULT error_code,
                                                LPCWSTR result_json) {
  if (completed_) return;  // Stale callback from an already-retried attempt.
  capture_watchdog_.Disarm();

  {
    std::ostringstream oss;
    oss << "captureScreenshot returned hr=0x" << std::hex << error_code;
    LogTileDiag(oss.str());
  }

  if (FAILED(error_code) || !result_json) {
    Fail("Page.captureScreenshot failed");
    return;
  }

  std::wstring base64_data = ExtractJsonString(result_json, L"data");
  if (base64_data.empty()) {
    Fail("Page.captureScreenshot returned no image data");
    return;
  }

  std::vector<uint8_t> png_bytes;
  if (!Base64Decode(base64_data, &png_bytes)) {
    Fail("Failed to decode captured screenshot data");
    return;
  }

  completed_ = true;
  watchdog_.Disarm();

  auto on_complete = std::move(on_complete_);
  // `this` may be destroyed synchronously inside on_complete; see
  // PdfConversionRequest for the same self-destruction contract.
  if (on_complete) on_complete(this, std::move(png_bytes), std::nullopt);
}

void ImageCaptureRequest::Fail(const std::string& message) {
  if (completed_) return;
  completed_ = true;
  capture_watchdog_.Disarm();
  watchdog_.Disarm();
  auto on_complete = std::move(on_complete_);
  if (on_complete) on_complete(this, std::nullopt, message);
}

}  // namespace webcontent_converter

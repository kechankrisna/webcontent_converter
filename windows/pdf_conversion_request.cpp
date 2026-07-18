#include "pdf_conversion_request.h"

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

namespace webcontent_converter {

namespace {

// Covers this request's whole lifecycle -- see RequestWatchdog's class
// comment for why that's more than just the navigation phase.
constexpr UINT kRequestTimeoutMs = 20000;

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

}  // namespace

PdfConversionRequest::PdfConversionRequest(
    WebView2Session* session, std::wstring content, std::wstring saved_path,
    double duration_ms, PageSettings settings,
    std::function<void(PdfConversionRequest*, std::optional<std::string>,
                        std::optional<std::string>)>
        on_complete)
    : content_(std::move(content)),
      duration_ms_(duration_ms),
      saved_path_(std::move(saved_path)),
      settings_(settings),
      on_complete_(std::move(on_complete)),
      session_(session) {}

void PdfConversionRequest::Start() {
  watchdog_.Arm(kRequestTimeoutMs, [this]() { Fail("Request timed out"); });
  auto alive = alive_;
  session_->EnsureAndNavigate(
      content_, duration_ms_,
      [this, alive](ICoreWebView2Environment* environment,
                    ICoreWebView2* webview) {
        if (!*alive) return;
        StartPrint(environment, webview);
      },
      [this, alive](const std::string& message) {
        if (!*alive) return;
        Fail(message);
      });
}

void PdfConversionRequest::StartPrint(ICoreWebView2Environment* environment,
                                       ICoreWebView2* webview) {
  // CreatePrintSettings requires ICoreWebView2Environment6, which needs a
  // reasonably current WebView2 Runtime (roughly Edge 108+).
  ComPtr<ICoreWebView2Environment6> environment6;
  if (FAILED(environment->QueryInterface(IID_PPV_ARGS(&environment6)))) {
    Fail("The installed WebView2 Runtime is too old to support PDF export "
         "(ICoreWebView2Environment6 unavailable)");
    return;
  }

  // PrintToPdf lives on ICoreWebView2_7.
  ComPtr<ICoreWebView2_7> webview7;
  if (FAILED(webview->QueryInterface(IID_PPV_ARGS(&webview7)))) {
    Fail("The installed WebView2 Runtime is too old to support PDF export "
         "(ICoreWebView2_7 unavailable)");
    return;
  }

  ComPtr<ICoreWebView2PrintSettings> print_settings;
  if (FAILED(environment6->CreatePrintSettings(&print_settings)) ||
      !print_settings) {
    Fail("Failed to create WebView2 print settings");
    return;
  }

  // Validate page dimensions (minimum 0.01 inches for width and height)
  if (settings_.page_width_in < 0.01 || settings_.page_height_in < 0.01) {
    Fail("Page dimensions too small (minimum 0.01 inches required)");
    return;
  }

  // Validate that margins haven't consumed the whole page. A flat 1-inch
  // floor here would reject legitimate small-format labels (e.g. a 1x1.5in
  // thermal label) outright, so this uses the same floor as the page
  // dimension check above rather than an arbitrary absolute minimum.
  double content_width = settings_.page_width_in - settings_.margin_left_in - settings_.margin_right_in;
  double content_height = settings_.page_height_in - settings_.margin_top_in - settings_.margin_bottom_in;
  if (content_width < 0.01 || content_height < 0.01) {
    Fail("Content area too small after applying margins");
    return;
  }

  print_settings->put_PageWidth(settings_.page_width_in);
  print_settings->put_PageHeight(settings_.page_height_in);
  print_settings->put_MarginTop(settings_.margin_top_in);
  print_settings->put_MarginBottom(settings_.margin_bottom_in);
  print_settings->put_MarginLeft(settings_.margin_left_in);
  print_settings->put_MarginRight(settings_.margin_right_in);
  print_settings->put_ShouldPrintBackgrounds(TRUE);
  print_settings->put_ScaleFactor(1.0);

  auto alive = alive_;
  HRESULT hr = webview7->PrintToPdf(
      saved_path_.c_str(), print_settings.Get(),
      Callback<ICoreWebView2PrintToPdfCompletedHandler>(
          [this, alive](HRESULT error_code, BOOL is_successful) {
            if (!*alive) return S_OK;
            return OnPrintCompleted(error_code, is_successful);
          })
          .Get());
  if (FAILED(hr)) {
    Fail("Failed to start PrintToPdf");
  }
}

HRESULT PdfConversionRequest::OnPrintCompleted(HRESULT error_code,
                                                BOOL is_successful) {
  if (FAILED(error_code) || !is_successful) {
    Fail("WebView2 PrintToPdf failed");
    return S_OK;
  }

  watchdog_.Disarm();

  // Memory safety: Extract all data BEFORE triggering self-destruction
  auto on_complete = std::move(on_complete_);
  std::string saved_path_utf8 = WideToUtf8(saved_path_);

  // `this` may be destroyed synchronously inside on_complete (it owns this
  // request and is expected to delete it once it has the result), so nothing
  // below may touch members of `this` again. The WebView2 session itself is
  // owned by the plugin and outlives this request -- it is not closed here.
  if (on_complete) on_complete(this, saved_path_utf8, std::nullopt);
  return S_OK;
}

void PdfConversionRequest::Fail(const std::string& message) {
  watchdog_.Disarm();
  auto on_complete = std::move(on_complete_);

  // Same self-destruction caveat as OnPrintCompleted: no member access after
  // invoking on_complete. The WebView2 session is owned by the plugin and
  // outlives this request.
  if (on_complete) on_complete(this, std::nullopt, message);
}

}  // namespace webcontent_converter

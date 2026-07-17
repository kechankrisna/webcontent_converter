#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PDF_CONVERSION_REQUEST_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PDF_CONVERSION_REQUEST_H_

#include <windows.h>
#include <wrl.h>

#include <functional>
#include <memory>
#include <optional>
#include <string>

#include "WebView2.h"
#include "request_watchdog.h"
#include "webview2_session.h"

namespace webcontent_converter {

// Drives a single content-to-PDF conversion through a shared, invisible
// WebView2 instance (see WebView2Session), then exports via the WebView2
// PrintToPdf API using the requested page size and margins.
//
// The session is owned by whoever constructs this request (in practice,
// WebcontentConverterPlugin) and outlives it -- it's reused across every
// PDF/image request for the plugin's lifetime rather than being created and
// torn down per request, so this class only borrows it.
//
// Self-contained lifetime: construct with `new`, call `Start()`, and the
// object deletes itself via `on_complete` once the conversion finishes or
// fails. Every internal callback invokes `on_complete` (if at all) as the
// very last statement in its call chain, so it is safe for `on_complete` to
// destroy `this`.
class PdfConversionRequest {
 public:
  struct PageSettings {
    double page_width_in;
    double page_height_in;
    double margin_top_in;
    double margin_bottom_in;
    double margin_left_in;
    double margin_right_in;
  };

  // `session` must outlive this request (owned by the plugin). `on_complete`
  // receives `this` as its first argument so the caller can find and
  // release the specific request that just finished; see the class comment
  // for why that's safe to do by destroying `this` from within it.
  PdfConversionRequest(
      WebView2Session* session, std::wstring content, std::wstring saved_path,
      double duration_ms, PageSettings settings,
      std::function<void(PdfConversionRequest* self,
                          std::optional<std::string> result_path,
                          std::optional<std::string> error)>
          on_complete);

  // WebView2 gives no way to cancel an in-flight async call (PrintToPdf,
  // ExecuteScript, etc.), so if RequestWatchdog's timeout gives up on this
  // request while one is still outstanding, that call's completion lambda
  // -- which captures `this` -- can still fire later, after this object is
  // gone. alive_ is how those lambdas find out `this` is no longer safe to
  // touch: see the pattern used in Start()/StartPrint().
  ~PdfConversionRequest() { *alive_ = false; }

  void Start();

 private:
  void StartPrint(ICoreWebView2Environment* environment,
                   ICoreWebView2* webview);
  HRESULT OnPrintCompleted(HRESULT error_code, BOOL is_successful);

  void Fail(const std::string& message);

  std::wstring content_;
  double duration_ms_;
  std::wstring saved_path_;
  PageSettings settings_;
  std::function<void(PdfConversionRequest*, std::optional<std::string>,
                      std::optional<std::string>)>
      on_complete_;

  // Borrowed; not owned. See class comment.
  WebView2Session* session_;

  // Covers this request's whole lifecycle (navigation through PrintToPdf),
  // not just WebView2Session's own navigation-phase timeout -- see
  // RequestWatchdog's class comment for why that distinction matters.
  RequestWatchdog watchdog_;

  // See the destructor comment. Shared (not just owned) because outstanding
  // WebView2 completion lambdas hold their own copy, keeping the flag alive
  // independent of `this`.
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
};

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PDF_CONVERSION_REQUEST_H_

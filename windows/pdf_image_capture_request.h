#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PDF_IMAGE_CAPTURE_REQUEST_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PDF_IMAGE_CAPTURE_REQUEST_H_

#include <windows.h>
#include <wrl.h>

#include <winrt/base.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "pdf_conversion_request.h"
#include "request_watchdog.h"
#include "webview2_session.h"

namespace webcontent_converter {

// contentToImage's format-aware path: generates a PDF at the requested
// paper size via PdfConversionRequest (the same paper-geometry-correct
// pipeline contentToPDF uses), then rasterizes it back to PNG bytes via the
// WinRT Windows.Data.Pdf API (PdfDocument/PdfPage::RenderToStreamAsync).
// See
// docs/superpowers/specs/2026-07-21-windows-content-to-image-paper-format-design.md
// for the full design, including why this replaced an earlier attempt that
// loaded the PDF into WebView2's own built-in viewer and screenshotted it:
// that approach turned out to apply its own uncontrollable auto-zoom to the
// rendered page (not a toolbar-chrome problem as originally anticipated),
// which a real PDF rasterizer sidesteps entirely by rendering directly to
// a caller-specified pixel size.
//
// Multi-page documents are stitched into one tall image, one page per
// vertical slot at the paper's pixel size, mirroring the Android
// implementation's PdfRenderer-based bitmap stitching (see
// android/.../PdfPrinter.kt's convertPdfToBitmapBytes) so a multi-page
// invoice has the same shape on both platforms.
//
// This is the first use of C++/WinRT (and coroutines) in this plugin --
// scoped to just this file and this plugin's own CMake target (see
// windows/CMakeLists.txt) rather than the whole app. Windows.Data.Pdf and
// Windows.Storage.Streams types used here are agile/free-threaded, so no
// apartment marshaling is needed around them; RasterizeAsync only marshals
// back to the originating (UI) thread right before touching `this` /
// resolving the Flutter result, since the coroutine may otherwise resume on
// a thread-pool thread after a co_await.
//
// Self-contained lifetime: construct with `new`, call Start(), and the
// object deletes itself via on_complete once finished or failed, same
// contract as PdfConversionRequest/ImageCaptureRequest.
class PdfImageCaptureRequest {
 public:
  PdfImageCaptureRequest(
      WebView2Session* session, std::wstring content, double duration_ms,
      PdfConversionRequest::PageSettings settings,
      std::function<void(PdfImageCaptureRequest* self,
                          std::optional<std::vector<uint8_t>> png_bytes,
                          std::optional<std::string> error)>
          on_complete);
  ~PdfImageCaptureRequest();

  PdfImageCaptureRequest(const PdfImageCaptureRequest&) = delete;
  PdfImageCaptureRequest& operator=(const PdfImageCaptureRequest&) = delete;

  void Start();

 private:
  void OnPdfGenerated(std::optional<std::string> saved_path,
                       std::optional<std::string> error);

  // Loads temp_pdf_path_ via Windows.Data.Pdf, renders every page to
  // page_width_px_ x page_height_px_, and hands off to FinishStitching --
  // or Fail()s -- once done. fire_and_forget: nothing awaits this directly,
  // matching the rest of this plugin's callback-based async style; alive_
  // guards every access to `this` after a co_await in case the request is
  // abandoned (timeout) while this is still running.
  winrt::fire_and_forget RasterizeAsync();

  void FinishStitching();
  void CleanupTempFile();

  void Succeed(std::vector<uint8_t> png_bytes);
  void Fail(const std::string& message);

  std::wstring content_;
  double duration_ms_;
  PdfConversionRequest::PageSettings settings_;
  std::function<void(PdfImageCaptureRequest*,
                      std::optional<std::vector<uint8_t>>,
                      std::optional<std::string>)>
      on_complete_;

  // Borrowed; not owned -- the plugin's shared session, same one
  // contentToPDF/contentToImage already use. Only needed for the PDF
  // generation phase (PdfConversionRequest); rasterization doesn't touch
  // WebView2 at all.
  WebView2Session* session_;

  std::unique_ptr<PdfConversionRequest> pdf_request_;
  std::wstring temp_pdf_path_;

  int page_count_ = 0;
  int page_width_px_ = 0;
  int page_height_px_ = 0;
  std::vector<std::vector<uint8_t>> page_pngs_;

  // Covers this request's whole lifecycle (PDF generation through
  // rasterizing every page).
  RequestWatchdog watchdog_;

  bool completed_ = false;

  // Guards against a stray coroutine resumption touching `this` after the
  // request has already timed out/failed and been torn down by its owner.
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
};

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PDF_IMAGE_CAPTURE_REQUEST_H_

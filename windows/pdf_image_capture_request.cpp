#define NOMINMAX
#include "pdf_image_capture_request.h"

#include <objidl.h>
#include <shlwapi.h>
// gdiplus.h must come after objidl.h/windows.h, and needs NOMINMAX above
// since its templates collide with the min/max macros windows.h defines.
#include <gdiplus.h>

#include <winrt/Windows.Data.Pdf.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>

#include <cmath>
#include <sstream>

#include "png_encoder.h"

using Microsoft::WRL::ComPtr;

namespace webcontent_converter {

namespace {

// Rendered pixel size for a given paper format -- matches the Android
// implementation's own PdfRenderer-based bitmap dimensions (PdfPrinter.kt
// maps paper inches to pixels at 96 DPI), so a given PaperFormat produces
// the same pixel dimensions on both platforms.
constexpr double kImageDpi = 96.0;

// Covers PDF generation plus rasterizing every page. Flat (not scaled by
// page count) since, unlike the WebView2-viewer approach this replaced,
// there's no per-page navigation/settle delay here -- Windows.Data.Pdf
// renders each page as a single direct call.
constexpr UINT kBaseTimeoutMs = 60000;

}  // namespace

PdfImageCaptureRequest::PdfImageCaptureRequest(
    WebView2Session* session, std::wstring content, double duration_ms,
    PdfConversionRequest::PageSettings settings,
    std::function<void(PdfImageCaptureRequest*,
                        std::optional<std::vector<uint8_t>>,
                        std::optional<std::string>)>
        on_complete)
    : content_(std::move(content)),
      duration_ms_(duration_ms),
      settings_(settings),
      on_complete_(std::move(on_complete)),
      session_(session) {}

PdfImageCaptureRequest::~PdfImageCaptureRequest() {
  *alive_ = false;
  CleanupTempFile();
}

void PdfImageCaptureRequest::Start() {
  wchar_t temp_dir[MAX_PATH];
  ::GetTempPathW(MAX_PATH, temp_dir);
  std::wstringstream ss;
  ss << temp_dir << L"webcontent_converter_image_" << ::GetCurrentProcessId()
     << L"_" << ::GetTickCount64() << L".pdf";
  temp_pdf_path_ = ss.str();

  watchdog_.Arm(kBaseTimeoutMs, [this]() { Fail("Request timed out"); });

  auto alive = alive_;
  pdf_request_ = std::make_unique<PdfConversionRequest>(
      session_, content_, temp_pdf_path_, duration_ms_, settings_,
      [this, alive](PdfConversionRequest*,
                    std::optional<std::string> saved_path,
                    std::optional<std::string> error) {
        if (!*alive) return;
        OnPdfGenerated(saved_path, error);
      });
  pdf_request_->Start();
}

void PdfImageCaptureRequest::OnPdfGenerated(
    std::optional<std::string> saved_path, std::optional<std::string> error) {
  pdf_request_.reset();

  if (!saved_path) {
    Fail(error.value_or("Failed to generate PDF for image conversion"));
    return;
  }

  page_width_px_ =
      static_cast<int>(std::lround(settings_.page_width_in * kImageDpi));
  page_height_px_ =
      static_cast<int>(std::lround(settings_.page_height_in * kImageDpi));
  if (page_width_px_ <= 0 || page_height_px_ <= 0) {
    Fail("Invalid page dimensions for image conversion");
    return;
  }

  RasterizeAsync();
}

winrt::fire_and_forget PdfImageCaptureRequest::RasterizeAsync() {
  auto alive = alive_;
  winrt::apartment_context ui_thread;

  std::vector<std::vector<uint8_t>> rendered_pages;
  std::optional<std::string> error_message;

  try {
    auto file = co_await winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(
        temp_pdf_path_);
    auto pdf_document =
        co_await winrt::Windows::Data::Pdf::PdfDocument::LoadFromFileAsync(file);

    uint32_t count = pdf_document.PageCount();
    if (count == 0) {
      error_message = "Generated PDF has no pages";
    } else {
      page_count_ = static_cast<int>(count);
      for (uint32_t i = 0; i < count; i++) {
        auto page = pdf_document.GetPage(i);

        winrt::Windows::Data::Pdf::PdfPageRenderOptions options;
        options.DestinationWidth(static_cast<uint32_t>(page_width_px_));
        options.DestinationHeight(static_cast<uint32_t>(page_height_px_));

        winrt::Windows::Storage::Streams::InMemoryRandomAccessStream stream;
        co_await page.RenderToStreamAsync(stream, options);

        winrt::Windows::Storage::Streams::DataReader reader(
            stream.GetInputStreamAt(0));
        uint32_t size = static_cast<uint32_t>(stream.Size());
        co_await reader.LoadAsync(size);
        std::vector<uint8_t> bytes(size);
        reader.ReadBytes(bytes);

        rendered_pages.push_back(std::move(bytes));
      }
    }
  } catch (const winrt::hresult_error& ex) {
    std::ostringstream oss;
    oss << "Failed to rasterize PDF. HRESULT: 0x" << std::hex
        << static_cast<uint32_t>(ex.code());
    error_message = oss.str();
  } catch (const std::exception& ex) {
    error_message = std::string("Failed to rasterize PDF: ") + ex.what();
  }

  // Everything above runs free-threaded (Windows.Data.Pdf/Streams types are
  // agile); marshal back to the originating thread before touching `this`
  // or resolving the Flutter result.
  co_await ui_thread;
  if (!*alive) co_return;

  if (error_message) {
    Fail(*error_message);
    co_return;
  }

  page_pngs_ = std::move(rendered_pages);
  FinishStitching();
}

void PdfImageCaptureRequest::FinishStitching() {
  EnsureGdiplusStarted();

  Gdiplus::Bitmap combined(page_width_px_, page_height_px_ * page_count_,
                            PixelFormat32bppARGB);
  if (combined.GetLastStatus() != Gdiplus::Ok) {
    Fail("Failed to allocate combined image canvas");
    return;
  }

  Gdiplus::Graphics graphics(&combined);
  graphics.Clear(Gdiplus::Color(255, 255, 255, 255));

  for (int i = 0; i < page_count_; i++) {
    ComPtr<IStream> page_stream;
    page_stream.Attach(::SHCreateMemStream(
        page_pngs_[i].data(), static_cast<UINT>(page_pngs_[i].size())));
    if (!page_stream) {
      Fail("Failed to create memory stream for page " +
           std::to_string(i + 1));
      return;
    }
    Gdiplus::Bitmap page_bitmap(page_stream.Get());
    if (page_bitmap.GetLastStatus() != Gdiplus::Ok) {
      Fail("Failed to decode rendered image for page " +
           std::to_string(i + 1));
      return;
    }
    graphics.DrawImage(&page_bitmap, 0, i * page_height_px_, page_width_px_,
                        page_height_px_);
  }

  HBITMAP hbitmap = nullptr;
  if (combined.GetHBITMAP(Gdiplus::Color(255, 255, 255, 255), &hbitmap) !=
          Gdiplus::Ok ||
      !hbitmap) {
    Fail("Failed to finalize combined image");
    return;
  }

  std::vector<uint8_t> png_bytes;
  bool encoded = EncodeHBitmapAsPng(hbitmap, &png_bytes);
  ::DeleteObject(hbitmap);
  if (!encoded) {
    Fail("Failed to encode combined image as PNG");
    return;
  }

  Succeed(std::move(png_bytes));
}

void PdfImageCaptureRequest::CleanupTempFile() {
  if (temp_pdf_path_.empty()) return;
  ::DeleteFileW(temp_pdf_path_.c_str());
}

void PdfImageCaptureRequest::Succeed(std::vector<uint8_t> png_bytes) {
  if (completed_) return;
  completed_ = true;
  watchdog_.Disarm();
  CleanupTempFile();
  auto on_complete = std::move(on_complete_);
  if (on_complete) on_complete(this, std::move(png_bytes), std::nullopt);
}

void PdfImageCaptureRequest::Fail(const std::string& message) {
  if (completed_) return;
  completed_ = true;
  watchdog_.Disarm();
  CleanupTempFile();
  auto on_complete = std::move(on_complete_);
  if (on_complete) on_complete(this, std::nullopt, message);
}

}  // namespace webcontent_converter

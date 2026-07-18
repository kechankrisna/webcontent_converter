#define NOMINMAX
#include "png_encoder.h"

#include <objidl.h>
#include <shlwapi.h>
#include <wrl.h>
// gdiplus.h must come after objidl.h/windows.h, and needs NOMINMAX above
// since its templates collide with the min/max macros windows.h defines.
#include <gdiplus.h>

#include <mutex>

using Microsoft::WRL::ComPtr;

namespace webcontent_converter {

namespace {

void EnsureGdiplusStarted() {
  static std::once_flag once;
  std::call_once(once, [] {
    Gdiplus::GdiplusStartupInput startup_input;
    ULONG_PTR token;
    Gdiplus::GdiplusStartup(&token, &startup_input, nullptr);
    // Intentionally never call GdiplusShutdown: this plugin may perform
    // capture requests for the lifetime of the process, and there's no
    // reliable single point to shut GDI+ down before process exit.
  });
}

bool GetPngEncoderClsid(CLSID* clsid) {
  UINT num_encoders = 0;
  UINT size = 0;
  Gdiplus::GetImageEncodersSize(&num_encoders, &size);
  if (size == 0) return false;

  std::vector<uint8_t> buffer(size);
  auto* image_codec_info =
      reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
  Gdiplus::GetImageEncoders(num_encoders, size, image_codec_info);

  for (UINT i = 0; i < num_encoders; ++i) {
    if (wcscmp(image_codec_info[i].MimeType, L"image/png") == 0) {
      *clsid = image_codec_info[i].Clsid;
      return true;
    }
  }
  return false;
}

}  // namespace

bool EncodeHBitmapAsPng(HBITMAP bitmap, std::vector<uint8_t>* out_png_bytes) {
  EnsureGdiplusStarted();

  Gdiplus::Bitmap gdi_bitmap(bitmap, nullptr);
  if (gdi_bitmap.GetLastStatus() != Gdiplus::Ok) return false;

  CLSID png_clsid;
  if (!GetPngEncoderClsid(&png_clsid)) return false;

  ComPtr<IStream> stream;
  if (FAILED(::CreateStreamOnHGlobal(nullptr, TRUE, &stream)) || !stream) {
    return false;
  }

  if (gdi_bitmap.Save(stream.Get(), &png_clsid, nullptr) != Gdiplus::Ok) {
    return false;
  }

  STATSTG stat{};
  if (FAILED(stream->Stat(&stat, STATFLAG_NONAME)) ||
      stat.cbSize.QuadPart == 0) {
    return false;
  }

  LARGE_INTEGER zero{};
  stream->Seek(zero, STREAM_SEEK_SET, nullptr);

  out_png_bytes->resize(static_cast<size_t>(stat.cbSize.QuadPart));
  ULONG bytes_read = 0;
  HRESULT hr = stream->Read(out_png_bytes->data(),
                             static_cast<ULONG>(out_png_bytes->size()),
                             &bytes_read);
  return SUCCEEDED(hr) && bytes_read == out_png_bytes->size();
}

}  // namespace webcontent_converter

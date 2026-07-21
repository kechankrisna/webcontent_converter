#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PNG_ENCODER_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PNG_ENCODER_H_

#include <windows.h>

#include <cstdint>
#include <vector>

namespace webcontent_converter {

// Idempotent, never paired with a shutdown call -- see the .cpp comment.
// Exposed (not just used internally by EncodeHBitmapAsPng below) so callers
// that need to construct/manipulate Gdiplus::Bitmap objects directly can
// ensure GDI+ is ready first.
void EnsureGdiplusStarted();

// Encodes a GDI bitmap (as produced by PrintWindow into a memory DC) as PNG
// bytes, via GDI+. Returns false if GDI+ isn't available or encoding fails.
bool EncodeHBitmapAsPng(HBITMAP bitmap, std::vector<uint8_t>* out_png_bytes);

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PNG_ENCODER_H_

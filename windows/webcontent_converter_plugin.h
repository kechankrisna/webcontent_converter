#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_WEBCONTENT_CONVERTER_PLUGIN_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_WEBCONTENT_CONVERTER_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <deque>
#include <functional>
#include <memory>

#include "image_capture_request.h"
#include "pdf_conversion_request.h"
#include "print_preview_window.h"
#include "webview2_session.h"

namespace webcontent_converter {

class WebcontentConverterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  WebcontentConverterPlugin(flutter::PluginRegistrarWindows* registrar);
  ~WebcontentConverterPlugin() override;

  WebcontentConverterPlugin(const WebcontentConverterPlugin&) = delete;
  WebcontentConverterPlugin& operator=(const WebcontentConverterPlugin&) =
      delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleContentToPdf(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleContentToImage(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandlePrintPreview(
      const flutter::EncodableMap& args,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Clean up old temporary WebView2 folders (older than 1 day)
  static void CleanupOldTempFolders();

  // Lazily creates session_ on first use (a valid parent HWND is only known
  // once a request comes in).
  WebView2Session* EnsureSession(HWND parent_window);

  // Starts `job` now if the shared session is idle, or queues it to run once
  // the current request (and everything already queued ahead of it)
  // finishes, in FIFO order (see OnRequestFinished). Callers are expected to
  // have already checked IsQueueFull() and rejected with TOO_MANY_REQUESTS
  // themselves in that case -- this always runs or queues.
  void StartOrQueue(std::function<void()> job);

  // Backstop against unbounded queue growth from a caller stuck in a loop.
  // Normal bursts of calls stay well under this and just queue/succeed
  // instead of erroring.
  bool IsQueueFull() const;

  // Frees the busy slot and starts the next queued job, if any.
  void OnRequestFinished();

  flutter::PluginRegistrarWindows* registrar_;

  // Shared across every PDF and image request for the plugin's lifetime --
  // see the class comment on WebView2Session for why requests no longer get
  // their own environment/controller.
  std::unique_ptr<WebView2Session> session_;

  // WebView2 controllers can't safely run concurrently on the shared
  // session (they'd fight over the same controller/parent HWND), so PDF and
  // image requests share a single busy slot rather than being throttled
  // independently, and calls that arrive while busy queue up in
  // pending_jobs_ (see StartOrQueue) instead of failing outright. At most
  // one of the two unique_ptrs below is populated at a time; each deletes
  // itself via its completion callback, which also calls OnRequestFinished.
  // print preview does NOT go through this -- see PrintPreviewWindow's
  // class comment for why it gets its own independent window/session
  // instead of contending for this shared one.
  bool request_in_flight_ = false;
  std::deque<std::function<void()>> pending_jobs_;
  std::unique_ptr<PdfConversionRequest> active_pdf_request_;
  std::unique_ptr<ImageCaptureRequest> active_image_request_;
};

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_WEBCONTENT_CONVERTER_PLUGIN_H_

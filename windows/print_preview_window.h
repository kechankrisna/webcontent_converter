#ifndef PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PRINT_PREVIEW_WINDOW_H_
#define PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PRINT_PREVIEW_WINDOW_H_

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

// Opens print preview in a genuine standalone top-level popup window --
// its own title bar, its own WebView2 environment/controller -- rather
// than taking over the embedding app's own window content the way reusing
// the plugin's shared, normally-invisible WebView2Session (the one
// PdfConversionRequest/ImageCaptureRequest use) would. Loads `content`
// into it, then calls ShowPrintUI(COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER)
// -- WebView2's equivalent of a page calling window.print() -- to show
// Edge's in-page print-preview UI once the page is visible.
//
// Deliberately doesn't reuse the plugin's shared session/controller: this
// window needs to stay open and visible independently of whatever the
// shared session is doing for other requests, and reusing it would mean
// the next PDF/image conversion yanks the preview's content (and the
// window it's shown in) out from under the user mid-preview. Because of
// that, this also doesn't participate in WebcontentConverterPlugin's
// StartOrQueue busy-slot mechanism -- nothing here contends with PDF/image
// requests, so there's nothing to serialize against.
//
// Self-contained lifetime, but on two different signals unlike the other
// Request classes in this plugin: `on_complete` fires once ShowPrintUI has
// been requested (or the request fails before getting that far) -- not
// once the user closes the popup, matching WebView2's own fire-and-forget
// ShowPrintUI contract -- while `this` itself isn't destroyed until the
// popup window actually closes (or creation/navigation fails outright, in
// which case there's no window to wait for). Construct with `new` and call
// Start(); never delete manually.
class PrintPreviewWindow {
 public:
  PrintPreviewWindow(
      std::wstring content, double duration_ms,
      std::function<void(PrintPreviewWindow* self, bool success,
                          std::optional<std::string> error)>
          on_complete);
  ~PrintPreviewWindow();

  PrintPreviewWindow(const PrintPreviewWindow&) = delete;
  PrintPreviewWindow& operator=(const PrintPreviewWindow&) = delete;

  void Start();

  // Registered as the window class's procedure; not part of the public
  // API otherwise. Public only because RegisterClassW needs its address.
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam,
                                   LPARAM lparam);

 private:
  void OnReady(ICoreWebView2Environment* environment, ICoreWebView2* webview);
  void OnResize(int width, int height);
  void OnWindowClosed();
  void OnCommand(int command_id);

  // Paints one of the owner-drawn toolbar buttons -- see CreateToolbarButtons
  // for why they're owner-drawn rather than plain BS_PUSHBUTTON.
  void OnDrawItem(DRAWITEMSTRUCT* draw_item);

  void Succeed();
  void Fail(const std::string& message);

  // Toolbar (Reload / Print), mirroring PrintPreviewWindowMacOS's toolbar --
  // see that class's comment for why Reload/Print are exposed as explicit
  // buttons rather than a right-click context menu (WebView2, like WKWebView,
  // doesn't expose one through a stable public API here).
  void CreateToolbarButtons();
  void PositionToolbarButtons(int width);

  // Re-requests the same content_ from OnWebResourceRequested's in-memory
  // handler (see webview2_session.cpp) by reloading the fixed synthetic URL
  // -- no re-navigation plumbing needed since that handler already serves
  // whatever content the session was last given.
  void ReloadWebView();

  // Re-invokes ShowPrintUI on demand; used both for the initial auto-print
  // once the page settles and for the toolbar's Print button. Returns
  // whether the print UI was successfully requested.
  bool ShowPrintDialog();

  std::wstring content_;
  double duration_ms_;
  std::function<void(PrintPreviewWindow*, bool, std::optional<std::string>)>
      on_complete_;
  bool completed_ = false;

  HWND hwnd_ = nullptr;
  HWND reload_button_ = nullptr;
  HWND print_button_ = nullptr;
  HFONT icon_font_ = nullptr;
  std::unique_ptr<WebView2Session> session_;

  // Cached from OnReady so the Print toolbar button can re-invoke ShowPrintUI
  // without re-querying the interface each time.
  Microsoft::WRL::ComPtr<ICoreWebView2_16> webview16_;

  // Covers window/environment/controller creation through the ShowPrintUI
  // call itself -- not the user's time spent with the preview open
  // afterward, which isn't observable (see class comment).
  RequestWatchdog watchdog_;

  // WebView2 gives no way to cancel an in-flight async call, so if the
  // watchdog gives up while one is still outstanding, that call's
  // completion lambda -- which captures `this` -- can still fire later,
  // after this object is gone. Shared (not just owned) because those
  // lambdas hold their own copy, keeping the flag alive independent of
  // `this`.
  std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
};

}  // namespace webcontent_converter

#endif  // PACKAGES_WEBCONTENT_CONVERTER_WINDOWS_PRINT_PREVIEW_WINDOW_H_

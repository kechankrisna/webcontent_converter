#include "print_preview_window.h"

using Microsoft::WRL::ComPtr;

namespace webcontent_converter {

namespace {

constexpr wchar_t kWindowClassName[] = L"webcontent_converter_print_preview";

// Covers window/environment/controller creation through the ShowPrintUI
// call itself -- not the user's time spent with the preview open
// afterward, which isn't observable (see class comment).
constexpr UINT kRequestTimeoutMs = 15000;

void EnsureWindowClassRegistered() {
  static bool registered = false;
  if (registered) return;

  WNDCLASSW wc{};
  wc.lpfnWndProc = PrintPreviewWindow::WndProc;
  wc.hInstance = ::GetModuleHandleW(nullptr);
  wc.lpszClassName = kWindowClassName;
  wc.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
  wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
  ::RegisterClassW(&wc);
  registered = true;
}

}  // namespace

PrintPreviewWindow::PrintPreviewWindow(
    std::wstring content, double duration_ms,
    std::function<void(PrintPreviewWindow*, bool, std::optional<std::string>)>
        on_complete)
    : content_(std::move(content)),
      duration_ms_(duration_ms),
      on_complete_(std::move(on_complete)) {}

PrintPreviewWindow::~PrintPreviewWindow() { *alive_ = false; }

void PrintPreviewWindow::Start() {
  EnsureWindowClassRegistered();

  hwnd_ = ::CreateWindowExW(
      0, kWindowClassName, L"Print Preview", WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT, CW_USEDEFAULT, 900, 1100, nullptr, nullptr,
      ::GetModuleHandleW(nullptr), this);

  if (!hwnd_) {
    Fail("Failed to create print preview window");
    delete this;
    return;
  }

  ::ShowWindow(hwnd_, SW_SHOW);
  ::UpdateWindow(hwnd_);

  session_ = std::make_unique<WebView2Session>(hwnd_);

  watchdog_.Arm(kRequestTimeoutMs, [this]() {
    Fail("Request timed out");
    ::DestroyWindow(hwnd_);
  });

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
        watchdog_.Disarm();
        Fail(message);
        ::DestroyWindow(hwnd_);
      });
}

void PrintPreviewWindow::OnReady(ICoreWebView2Environment* environment,
                                  ICoreWebView2* webview) {
  watchdog_.Disarm();

  ICoreWebView2Controller* controller = session_->controller();
  if (controller) {
    RECT client_rect{};
    ::GetClientRect(hwnd_, &client_rect);
    controller->put_Bounds(client_rect);
    controller->put_IsVisible(TRUE);
  }

  // ShowPrintUI lives on ICoreWebView2_16, which needs a reasonably current
  // WebView2 Runtime (roughly Edge 111+).
  ComPtr<ICoreWebView2_16> webview16;
  if (FAILED(webview->QueryInterface(IID_PPV_ARGS(&webview16)))) {
    Fail("The installed WebView2 Runtime is too old to support print "
         "preview (ICoreWebView2_16 unavailable)");
    ::DestroyWindow(hwnd_);
    return;
  }

  // WebView2's equivalent of a page calling window.print(). BROWSER shows
  // Edge's own in-page print-preview UI (page thumbnails, printer/paper
  // controls, Print/Cancel) in place of the current page content.
  HRESULT hr = webview16->ShowPrintUI(COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER);
  if (FAILED(hr)) {
    Fail("Failed to open the print preview");
    ::DestroyWindow(hwnd_);
    return;
  }

  Succeed();
  // The window stays open for the user to interact with the preview;
  // OnWindowClosed (via WM_DESTROY) cleans up once they close it.
}

void PrintPreviewWindow::OnResize(int width, int height) {
  if (!session_) return;
  ICoreWebView2Controller* controller = session_->controller();
  if (!controller) return;
  RECT bounds{0, 0, width, height};
  controller->put_Bounds(bounds);
}

void PrintPreviewWindow::OnWindowClosed() {
  *alive_ = false;
  watchdog_.Disarm();
  // Closes the controller/environment before this object (and hwnd_ along
  // with it) goes away.
  session_.reset();
  delete this;
}

void PrintPreviewWindow::Succeed() {
  if (completed_) return;
  completed_ = true;
  auto on_complete = std::move(on_complete_);
  if (on_complete) on_complete(this, true, std::nullopt);
}

void PrintPreviewWindow::Fail(const std::string& message) {
  if (completed_) return;
  completed_ = true;
  auto on_complete = std::move(on_complete_);
  if (on_complete) on_complete(this, false, message);
}

// static
LRESULT CALLBACK PrintPreviewWindow::WndProc(HWND hwnd, UINT msg,
                                              WPARAM wparam, LPARAM lparam) {
  if (msg == WM_CREATE) {
    auto* create_struct = reinterpret_cast<CREATESTRUCTW*>(lparam);
    ::SetWindowLongPtrW(
        hwnd, GWLP_USERDATA,
        reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams));
    return 0;
  }

  auto* self = reinterpret_cast<PrintPreviewWindow*>(
      ::GetWindowLongPtrW(hwnd, GWLP_USERDATA));

  switch (msg) {
    case WM_SIZE:
      if (self) self->OnResize(LOWORD(lparam), HIWORD(lparam));
      return 0;
    case WM_DESTROY:
      // Deletes `self`; nothing below may touch it again.
      if (self) self->OnWindowClosed();
      return 0;
    default:
      return ::DefWindowProcW(hwnd, msg, wparam, lparam);
  }
}

}  // namespace webcontent_converter

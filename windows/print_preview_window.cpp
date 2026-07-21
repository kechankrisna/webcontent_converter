#include "print_preview_window.h"

#include <wchar.h>

using Microsoft::WRL::ComPtr;

namespace webcontent_converter {

namespace {

constexpr wchar_t kWindowClassName[] = L"webcontent_converter_print_preview";

// Covers window/environment/controller creation through the ShowPrintUI
// call itself -- not the user's time spent with the preview open
// afterward, which isn't observable (see class comment).
constexpr UINT kRequestTimeoutMs = 15000;

// width_/height_ <= 0 means the caller didn't request a specific size (see
// HandlePrintPreview); ComputeDefaultSize fills in the primary monitor's
// full work area size in that case, falling back to a fixed size only if
// screen info is ever unavailable. The same work area is also used to
// center the window (see Start()) -- CW_USEDEFAULT's cascading placement
// otherwise gives a different, non-deterministic position each time a
// window is created, which combined with a screen-sized window can push
// part of it off-screen.
constexpr double kFallbackWidth = 1200.0;
constexpr double kFallbackHeight = 1100.0;
constexpr double kScreenFitRatio = 1.0;

RECT GetWorkAreaRect() {
  RECT work_area{};
  if (::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0) &&
      work_area.right > work_area.left && work_area.bottom > work_area.top) {
    return work_area;
  }
  return RECT{0, 0, static_cast<LONG>(kFallbackWidth),
              static_cast<LONG>(kFallbackHeight)};
}

void ComputeDefaultSize(const RECT& work_area, double* width,
                         double* height) {
  *width = (work_area.right - work_area.left) * kScreenFitRatio;
  *height = (work_area.bottom - work_area.top) * kScreenFitRatio;
}

// Toolbar strip reserved at the top of the window for the Reload/Print
// buttons; the WebView2 controller's bounds start below it instead of at
// y=0, mirroring PrintPreviewWindowMacOS's NSToolbar (which occupies its own
// space above the WKWebView's content area rather than overlapping it).
constexpr int kToolbarHeight = 40;
constexpr int kButtonSize = 32;
constexpr int kButtonMargin = 4;
constexpr int kButtonSpacing = 4;

constexpr int kReloadButtonId = 1001;
constexpr int kPrintButtonId = 1002;

// Refresh / Print glyph codepoints, identical between "Segoe Fluent Icons"
// (Windows 11's Fluent-branded icon font) and its predecessor "Segoe MDL2
// Assets" (Windows 10) -- only the face name differs between the two, so one
// glyph table serves both (see ResolveIconFontFace).
constexpr wchar_t kReloadGlyph[] = {static_cast<wchar_t>(0xE72C), 0};
constexpr wchar_t kPrintGlyph[] = {static_cast<wchar_t>(0xE749), 0};

// Window property names used to attach ad hoc state to the plain BUTTON
// child windows below via SetPropW rather than a subclass-specific struct --
// simplest option here since it's just two flags per button.
constexpr wchar_t kOriginalProcProp[] = L"wcc_original_wndproc";
constexpr wchar_t kHotProp[] = L"wcc_hot";

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

// Windows 11 ships the Fluent-branded "Segoe Fluent Icons" as the successor
// to "Segoe MDL2 Assets"; Windows 10 (WebView2's own OS floor) only has the
// latter. CreateFontW never fails outright for a missing face -- it silently
// substitutes a fallback font via the font mapper -- so face availability
// has to be checked explicitly rather than trusting CreateFontW's return.
bool IsFontFaceInstalled(const wchar_t* face_name) {
  HDC hdc = ::GetDC(nullptr);
  LOGFONTW lf{};
  lf.lfCharSet = DEFAULT_CHARSET;
  wcsncpy_s(lf.lfFaceName, face_name, LF_FACESIZE - 1);
  bool found = false;
  ::EnumFontFamiliesExW(
      hdc, &lf,
      [](const LOGFONTW*, const TEXTMETRICW*, DWORD, LPARAM lparam) -> int {
        *reinterpret_cast<bool*>(lparam) = true;
        return 0;  // stop enumeration -- one match is enough
      },
      reinterpret_cast<LPARAM>(&found), 0);
  ::ReleaseDC(nullptr, hdc);
  return found;
}

const wchar_t* ResolveIconFontFace() {
  return IsFontFaceInstalled(L"Segoe Fluent Icons") ? L"Segoe Fluent Icons"
                                                     : L"Segoe MDL2 Assets";
}

// Fluent's hover/pressed states are conceptually "an overlay of the
// foreground color at low opacity" rather than a fixed hardcoded shade --
// that's what keeps them looking right against light or dark surfaces alike.
// Approximated here without real alpha blending: pick black or white as the
// overlay based on the base color's own luminance, then blend toward it.
COLORREF ApplyOverlayTint(COLORREF base, int alpha_0_255) {
  int r = GetRValue(base), g = GetGValue(base), b = GetBValue(base);
  int luminance = (r * 299 + g * 587 + b * 114) / 1000;
  int overlay = luminance > 128 ? 0 : 255;
  auto blend = [&](int channel) {
    return static_cast<BYTE>(
        (channel * (255 - alpha_0_255) + overlay * alpha_0_255) / 255);
  };
  return RGB(blend(r), blend(g), blend(b));
}

// Subclass proc shared by both toolbar buttons -- adds hover ("hot") state
// tracking on top of the stock BUTTON window proc, which has no owner-draw
// notification for mouse-over the way it does for pressed (ODS_SELECTED).
// Pressed/focus state doesn't need tracking here since DRAWITEMSTRUCT's
// itemState already reports both for owner-draw buttons.
LRESULT CALLBACK ToolbarButtonProc(HWND hwnd, UINT msg, WPARAM wparam,
                                   LPARAM lparam) {
  auto original =
      reinterpret_cast<WNDPROC>(::GetPropW(hwnd, kOriginalProcProp));

  switch (msg) {
    case WM_MOUSEMOVE:
      if (!::GetPropW(hwnd, kHotProp)) {
        ::SetPropW(hwnd, kHotProp, reinterpret_cast<HANDLE>(1));
        TRACKMOUSEEVENT tme{sizeof(tme), TME_LEAVE, hwnd, 0};
        ::TrackMouseEvent(&tme);
        ::InvalidateRect(hwnd, nullptr, FALSE);
      }
      break;
    case WM_MOUSELEAVE:
      ::RemovePropW(hwnd, kHotProp);
      ::InvalidateRect(hwnd, nullptr, FALSE);
      break;
    case WM_ERASEBKGND:
      // WM_DRAWITEM (owner-draw) repaints the whole button every time;
      // erasing first would just add a visible flash beforehand.
      return 1;
    case WM_NCDESTROY: {
      LRESULT result = original ? ::CallWindowProcW(original, hwnd, msg,
                                                      wparam, lparam)
                                 : ::DefWindowProcW(hwnd, msg, wparam, lparam);
      ::RemovePropW(hwnd, kHotProp);
      ::RemovePropW(hwnd, kOriginalProcProp);
      return result;
    }
  }

  return original ? ::CallWindowProcW(original, hwnd, msg, wparam, lparam)
                   : ::DefWindowProcW(hwnd, msg, wparam, lparam);
}

}  // namespace

PrintPreviewWindow::PrintPreviewWindow(
    std::wstring content, double duration_ms, double width, double height,
    std::function<void(PrintPreviewWindow*, bool, std::optional<std::string>)>
        on_complete)
    : content_(std::move(content)),
      duration_ms_(duration_ms),
      width_(width),
      height_(height),
      on_complete_(std::move(on_complete)) {}

PrintPreviewWindow::~PrintPreviewWindow() { *alive_ = false; }

void PrintPreviewWindow::Start() {
  EnsureWindowClassRegistered();

  RECT work_area = GetWorkAreaRect();

  double effective_width = width_;
  double effective_height = height_;
  if (effective_width <= 0 || effective_height <= 0) {
    ComputeDefaultSize(work_area, &effective_width, &effective_height);
  }

  // Centered on the work area rather than CW_USEDEFAULT: that cascades a
  // different offset per window instance, which combined with a
  // screen-sized window can leave part of it off-screen -- see
  // GetWorkAreaRect's comment. Matches PrintPreviewWindowMacOS's
  // window.center() for the same consistent, deterministic placement.
  int work_width = work_area.right - work_area.left;
  int work_height = work_area.bottom - work_area.top;
  int x = work_area.left +
          (work_width - static_cast<int>(effective_width)) / 2;
  int y = work_area.top +
          (work_height - static_cast<int>(effective_height)) / 2;

  hwnd_ = ::CreateWindowExW(
      0, kWindowClassName, L"Print Preview", WS_OVERLAPPEDWINDOW, x, y,
      static_cast<int>(effective_width), static_cast<int>(effective_height),
      nullptr, nullptr, ::GetModuleHandleW(nullptr), this);

  if (!hwnd_) {
    Fail("Failed to create print preview window");
    delete this;
    return;
  }

  ::ShowWindow(hwnd_, SW_SHOW);
  ::UpdateWindow(hwnd_);

  CreateToolbarButtons();
  RECT initial_client_rect{};
  ::GetClientRect(hwnd_, &initial_client_rect);
  PositionToolbarButtons(initial_client_rect.right - initial_client_rect.left);

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
    RECT bounds{0, kToolbarHeight, client_rect.right, client_rect.bottom};
    controller->put_Bounds(bounds);
    controller->put_IsVisible(TRUE);
  }

  // ShowPrintUI lives on ICoreWebView2_16, which needs a reasonably current
  // WebView2 Runtime (roughly Edge 111+). Cached so the toolbar's Print
  // button can re-invoke it later without re-querying the interface.
  if (FAILED(webview->QueryInterface(IID_PPV_ARGS(&webview16_)))) {
    Fail("The installed WebView2 Runtime is too old to support print "
         "preview (ICoreWebView2_16 unavailable)");
    ::DestroyWindow(hwnd_);
    return;
  }

  if (!ShowPrintDialog()) {
    Fail("Failed to open the print preview");
    ::DestroyWindow(hwnd_);
    return;
  }

  Succeed();
  // The window stays open for the user to interact with the preview;
  // OnWindowClosed (via WM_DESTROY) cleans up once they close it.
}

bool PrintPreviewWindow::ShowPrintDialog() {
  if (!webview16_) return false;
  // WebView2's equivalent of a page calling window.print(). BROWSER shows
  // Edge's own in-page print-preview UI (page thumbnails, printer/paper
  // controls, Print/Cancel) in place of the current page content. Also used
  // by the toolbar's Print button to re-invoke the same UI on demand.
  return SUCCEEDED(
      webview16_->ShowPrintUI(COREWEBVIEW2_PRINT_DIALOG_KIND_BROWSER));
}

void PrintPreviewWindow::ReloadWebView() {
  if (!session_) return;
  ICoreWebView2Controller* controller = session_->controller();
  if (!controller) return;
  ComPtr<ICoreWebView2> webview;
  if (FAILED(controller->get_CoreWebView2(&webview)) || !webview) return;
  // Re-requests the fixed synthetic content URL; OnWebResourceRequested
  // (webview2_session.cpp) serves content_ from memory again, same as the
  // initial load -- no separate re-navigation path needed.
  webview->Reload();
}

void PrintPreviewWindow::CreateToolbarButtons() {
  if (!icon_font_) {
    icon_font_ = ::CreateFontW(
        -20, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_DONTCARE, ResolveIconFontFace());
  }

  // BS_OWNERDRAW (rather than BS_PUSHBUTTON) hands all painting to
  // OnDrawItem below -- a flat, borderless, rounded-rect icon button with
  // hover/pressed feedback, matching the Fluent styling Windows 11's own
  // command-bar icon buttons use, which the stock 3D-bordered push button
  // look doesn't. WS_TABSTOP keeps them keyboard-reachable, matching that
  // same focus-visible expectation (see the ODS_FOCUS handling below).
  constexpr DWORD kButtonStyle =
      WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_OWNERDRAW;

  reload_button_ = ::CreateWindowExW(
      0, L"BUTTON", kReloadGlyph, kButtonStyle, 0, 0, kButtonSize, kButtonSize,
      hwnd_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(kReloadButtonId)),
      ::GetModuleHandleW(nullptr), nullptr);
  print_button_ = ::CreateWindowExW(
      0, L"BUTTON", kPrintGlyph, kButtonStyle, 0, 0, kButtonSize, kButtonSize,
      hwnd_, reinterpret_cast<HMENU>(static_cast<INT_PTR>(kPrintButtonId)),
      ::GetModuleHandleW(nullptr), nullptr);

  for (HWND button : {reload_button_, print_button_}) {
    if (!button) continue;
    if (icon_font_) {
      ::SendMessageW(button, WM_SETFONT, reinterpret_cast<WPARAM>(icon_font_),
                     TRUE);
    }
    // Hover ("hot") tracking isn't something the stock BUTTON proc reports
    // for owner-draw buttons on its own -- see ToolbarButtonProc.
    WNDPROC original = reinterpret_cast<WNDPROC>(::SetWindowLongPtrW(
        button, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(ToolbarButtonProc)));
    ::SetPropW(button, kOriginalProcProp, reinterpret_cast<HANDLE>(original));
  }
}

void PrintPreviewWindow::PositionToolbarButtons(int width) {
  if (!reload_button_ || !print_button_) return;
  int x = width - kButtonMargin - kButtonSize;
  ::MoveWindow(print_button_, x, kButtonMargin, kButtonSize, kButtonSize,
               TRUE);
  x -= (kButtonSize + kButtonSpacing);
  ::MoveWindow(reload_button_, x, kButtonMargin, kButtonSize, kButtonSize,
               TRUE);
}

void PrintPreviewWindow::OnResize(int width, int height) {
  PositionToolbarButtons(width);
  if (!session_) return;
  ICoreWebView2Controller* controller = session_->controller();
  if (!controller) return;
  RECT bounds{0, kToolbarHeight, width, height};
  controller->put_Bounds(bounds);
}

void PrintPreviewWindow::OnCommand(int command_id) {
  switch (command_id) {
    case kReloadButtonId:
      ReloadWebView();
      break;
    case kPrintButtonId:
      ShowPrintDialog();
      break;
    default:
      break;
  }
}

void PrintPreviewWindow::OnDrawItem(DRAWITEMSTRUCT* draw_item) {
  bool pressed = (draw_item->itemState & ODS_SELECTED) != 0;
  bool hot = ::GetPropW(draw_item->hwndItem, kHotProp) != nullptr;

  // Idle state is left exactly at the window's own background color rather
  // than a hardcoded white/black -- since the surrounding toolbar strip
  // isn't itself dark-mode-aware, matching it exactly (whatever it is) reads
  // as a flat, borderless icon button; hover/pressed then layer a subtle
  // tint on top of that same base rather than jumping to unrelated colors.
  COLORREF base = ::GetSysColor(COLOR_WINDOW);
  COLORREF fill = pressed  ? ApplyOverlayTint(base, 70)
                 : hot     ? ApplyOverlayTint(base, 35)
                           : base;
  COLORREF text_color = ::GetSysColor(COLOR_WINDOWTEXT);

  HBRUSH brush = ::CreateSolidBrush(fill);
  HGDIOBJ old_brush = ::SelectObject(draw_item->hDC, brush);
  HGDIOBJ old_pen =
      ::SelectObject(draw_item->hDC, ::GetStockObject(NULL_PEN));
  ::RoundRect(draw_item->hDC, draw_item->rcItem.left, draw_item->rcItem.top,
              draw_item->rcItem.right, draw_item->rcItem.bottom, 6, 6);
  ::SelectObject(draw_item->hDC, old_pen);
  ::SelectObject(draw_item->hDC, old_brush);
  ::DeleteObject(brush);

  wchar_t glyph[4]{};
  ::GetWindowTextW(draw_item->hwndItem, glyph, 4);

  ::SetBkMode(draw_item->hDC, TRANSPARENT);
  ::SetTextColor(draw_item->hDC, text_color);
  HGDIOBJ old_font = ::SelectObject(draw_item->hDC, icon_font_);
  RECT text_rect = draw_item->rcItem;
  ::DrawTextW(draw_item->hDC, glyph, -1, &text_rect,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  ::SelectObject(draw_item->hDC, old_font);

  if (draw_item->itemState & ODS_FOCUS) {
    ::DrawFocusRect(draw_item->hDC, &draw_item->rcItem);
  }
}

void PrintPreviewWindow::OnWindowClosed() {
  *alive_ = false;
  watchdog_.Disarm();
  if (icon_font_) {
    ::DeleteObject(icon_font_);
    icon_font_ = nullptr;
  }
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
    case WM_COMMAND:
      if (self) self->OnCommand(LOWORD(wparam));
      return 0;
    case WM_DRAWITEM: {
      auto* draw_item = reinterpret_cast<DRAWITEMSTRUCT*>(lparam);
      if (self && draw_item &&
          (draw_item->CtlID == kReloadButtonId ||
           draw_item->CtlID == kPrintButtonId)) {
        self->OnDrawItem(draw_item);
        return TRUE;
      }
      return ::DefWindowProcW(hwnd, msg, wparam, lparam);
    }
    case WM_DESTROY:
      // Deletes `self`; nothing below may touch it again.
      if (self) self->OnWindowClosed();
      return 0;
    default:
      return ::DefWindowProcW(hwnd, msg, wparam, lparam);
  }
}

}  // namespace webcontent_converter

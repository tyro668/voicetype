#include "flutter_window.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"

#include <dwmapi.h>
#include <shellapi.h>

// macOS keyCode values -> Windows VK mapping.
// macOS keycodes are what the Flutter settings layer uses (from the Dart-side
// _macKeyCodeMap in main_screen.dart). The native side must accept these codes
// when registering hotkeys and echo them back when the hotkey fires.
static const std::map<int, UINT> kMacToWinVK = {
    {120, VK_F2},     // F2
    {99,  VK_F3},     // F3
    {118, VK_F4},     // F4
    {96,  VK_F5},     // F5
    {97,  VK_F6},     // F6
    {98,  VK_F7},     // F7
    {100, VK_F8},     // F8
    {101, VK_F9},     // F9
    {109, VK_F10},    // F10
    {103, VK_F11},    // F11
    {111, VK_F12},    // F12
    {49,  VK_SPACE},  // Space
    {36,  VK_RETURN}, // Enter/Return
    {53,  VK_ESCAPE}, // Escape
    {48,  VK_TAB},    // Tab
    // macOS keyCode 63 (Fn) has no Windows equivalent; skipped.
};

// Overlay window dimensions.
static const int kOverlayWidth  = 280;
static const int kOverlayHeight = 56;

const wchar_t* FlutterWindow::kOverlayClassName = L"VOICETYPE_OVERLAY_WND";
bool FlutterWindow::overlay_class_registered_ = false;

// ---------------------------------------------------------------------------
// FlutterWindow
// ---------------------------------------------------------------------------

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary
  // surface creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  SetupMethodChannel();

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  HandleUnregisterHotkey();
  DestroyOverlayWindow();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  switch (message) {
    case WM_HOTKEY: {
      if (static_cast<int>(wparam) == kHotkeyId &&
          registered_mac_key_code_ >= 0 && method_channel_) {
        // Capture the last foreground window before this hotkey came in.
        // (The OS typically switches focus so we grab it here.)
        HWND fg = GetForegroundWindow();
        if (fg && fg != hwnd && fg != overlay_hwnd_) {
          last_foreground_hwnd_ = fg;
        }

        flutter::EncodableMap payload;
        payload[flutter::EncodableValue("keyCode")] =
            flutter::EncodableValue(registered_mac_key_code_);
        payload[flutter::EncodableValue("type")] =
            flutter::EncodableValue(std::string("down"));
        payload[flutter::EncodableValue("isRepeat")] =
            flutter::EncodableValue(false);
        method_channel_->InvokeMethod(
            "onGlobalKeyEvent",
            std::make_unique<flutter::EncodableValue>(
                flutter::EncodableValue(payload)));

        // RegisterHotKey only fires on key-press; there is no WM_HOTKEY for
        // key-release. Send a synthetic 'up' event immediately after so the
        // Flutter side can toggle tap-to-talk / complete hold-to-talk logic.
        payload[flutter::EncodableValue("type")] =
            flutter::EncodableValue(std::string("up"));
        method_channel_->InvokeMethod(
            "onGlobalKeyEvent",
            std::make_unique<flutter::EncodableValue>(
                flutter::EncodableValue(payload)));
      }
      return 0;
    }

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

// ---------------------------------------------------------------------------
// MethodChannel setup
// ---------------------------------------------------------------------------

void FlutterWindow::SetupMethodChannel() {
  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.voicetype/overlay",
          &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();

        if (method == "showOverlay") {
          flutter::EncodableMap args;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            args = *map;
          }
          HandleShowOverlay(args);
          result->Success();

        } else if (method == "hideOverlay") {
          HandleHideOverlay();
          result->Success();

        } else if (method == "updateOverlay") {
          flutter::EncodableMap args;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            args = *map;
          }
          HandleUpdateOverlay(args);
          result->Success();

        } else if (method == "showMainWindow") {
          HandleShowMainWindow();
          result->Success();

        } else if (method == "insertText") {
          std::string text;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("text"));
            if (it != map->end()) {
              if (const auto* s =
                      std::get_if<std::string>(&it->second)) {
                text = *s;
              }
            }
          }
          HandleInsertText(text);
          result->Success();

        } else if (method == "checkAccessibility") {
          // Windows doesn't require explicit accessibility permission.
          result->Success(flutter::EncodableValue(true));

        } else if (method == "requestAccessibility") {
          result->Success(flutter::EncodableValue(true));

        } else if (method == "checkInputMonitoring") {
          result->Success(flutter::EncodableValue(true));

        } else if (method == "requestInputMonitoring") {
          result->Success(flutter::EncodableValue(true));

        } else if (method == "openSoundInput") {
          // Open Windows Sound settings.
          ShellExecuteW(nullptr, L"open",
                        L"ms-settings:sound", nullptr, nullptr, SW_SHOW);
          result->Success();

        } else if (method == "openMicrophonePrivacy") {
          ShellExecuteW(nullptr, L"open",
                        L"ms-settings:privacy-microphone",
                        nullptr, nullptr, SW_SHOW);
          result->Success();

        } else if (method == "openAccessibilityPrivacy") {
          ShellExecuteW(nullptr, L"open",
                        L"ms-settings:easeofaccess",
                        nullptr, nullptr, SW_SHOW);
          result->Success();

        } else if (method == "openInputMonitoringPrivacy") {
          // No direct Windows equivalent; open Privacy settings.
          ShellExecuteW(nullptr, L"open",
                        L"ms-settings:privacy",
                        nullptr, nullptr, SW_SHOW);
          result->Success();

        } else if (method == "registerHotkey") {
          int mac_key_code = -1;
          int modifiers = 0;
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("keyCode"));
            if (it != map->end()) {
              if (const auto* v = std::get_if<int>(&it->second)) {
                mac_key_code = *v;
              }
            }
            it = map->find(flutter::EncodableValue("modifiers"));
            if (it != map->end()) {
              if (const auto* v = std::get_if<int>(&it->second)) {
                modifiers = *v;
              }
            }
          }
          bool ok = HandleRegisterHotkey(mac_key_code, modifiers);
          result->Success(flutter::EncodableValue(ok));

        } else if (method == "unregisterHotkey") {
          HandleUnregisterHotkey();
          result->Success();

        } else {
          result->NotImplemented();
        }
      });
}

// ---------------------------------------------------------------------------
// Handler implementations
// ---------------------------------------------------------------------------

void FlutterWindow::HandleShowMainWindow() {
  HWND hwnd = GetHandle();
  if (hwnd) {
    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
  }
}

void FlutterWindow::HandleInsertText(const std::string& text) {
  if (text.empty()) return;

  // Run clipboard insertion on a background thread so the platform thread
  // (and hence the Flutter message loop) is not blocked by the Sleep needed
  // to let SetForegroundWindow take effect.
  struct InsertArgs {
    std::wstring wtext;
    HWND target;
  };

  // Convert UTF-8 to UTF-16 on the calling thread.
  int wlen = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
  if (wlen <= 0) return;
  std::wstring wtext(wlen - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, &wtext[0], wlen);

  auto* args = new InsertArgs{std::move(wtext), last_foreground_hwnd_};

  HANDLE thread = CreateThread(
      nullptr, 0,
      [](LPVOID param) -> DWORD {
        auto* a = static_cast<InsertArgs*>(param);
        FlutterWindow::InsertTextBackground(a->wtext, a->target);
        delete a;
        return 0;
      },
      args, 0, nullptr);
  if (thread) CloseHandle(thread);
}

// static
void FlutterWindow::InsertTextBackground(const std::wstring& wtext,
                                         HWND target_hwnd) {
  // Write text to clipboard.
  if (!OpenClipboard(nullptr)) return;
  EmptyClipboard();

  SIZE_T byte_size = (wtext.size() + 1) * sizeof(wchar_t);
  HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, byte_size);
  if (!hMem) {
    CloseClipboard();
    return;
  }
  wchar_t* pMem = static_cast<wchar_t*>(GlobalLock(hMem));
  if (pMem) {
    wmemcpy(pMem, wtext.c_str(), wtext.size() + 1);
    GlobalUnlock(hMem);
    SetClipboardData(CF_UNICODETEXT, hMem);
  }
  CloseClipboard();

  // Activate the target window then send Ctrl+V.
  if (target_hwnd && IsWindow(target_hwnd)) {
    SetForegroundWindow(target_hwnd);
    Sleep(80);  // Wait for window activation to complete.
  }

  INPUT inputs[4] = {};
  inputs[0].type = INPUT_KEYBOARD; inputs[0].ki.wVk = VK_CONTROL;
  inputs[1].type = INPUT_KEYBOARD; inputs[1].ki.wVk = 'V';
  inputs[2].type = INPUT_KEYBOARD; inputs[2].ki.wVk = 'V';
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
  inputs[3].type = INPUT_KEYBOARD; inputs[3].ki.wVk = VK_CONTROL;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;
  SendInput(4, inputs, sizeof(INPUT));
}

bool FlutterWindow::HandleRegisterHotkey(int mac_key_code, int modifiers) {
  // Remove any previously registered hotkey first.
  HandleUnregisterHotkey();

  UINT vk = MacKeyCodeToWinVK(mac_key_code);
  if (vk == 0) {
    // Unknown / unsupported key (e.g., macOS Fn key).
    return false;
  }

  HWND hwnd = GetHandle();
  if (!hwnd) return false;

  // modifiers from the Flutter side are macOS Carbon modifiers; ignore them
  // on Windows and register with no modifiers so any press triggers it.
  BOOL ok = ::RegisterHotKey(hwnd, kHotkeyId, 0, vk);
  if (ok) {
    registered_mac_key_code_ = mac_key_code;
  }
  return ok == TRUE;
}

void FlutterWindow::HandleUnregisterHotkey() {
  if (registered_mac_key_code_ >= 0) {
    HWND hwnd = GetHandle();
    if (hwnd) {
      ::UnregisterHotKey(hwnd, kHotkeyId);
    }
    registered_mac_key_code_ = -1;
  }
}

// ---------------------------------------------------------------------------
// Overlay window
// ---------------------------------------------------------------------------

void FlutterWindow::HandleShowOverlay(const flutter::EncodableMap& args) {
  auto get_str = [&](const char* key, const std::string& def) -> std::string {
    auto it = args.find(flutter::EncodableValue(std::string(key)));
    if (it != args.end()) {
      if (const auto* s = std::get_if<std::string>(&it->second)) return *s;
    }
    return def;
  };
  auto get_double = [&](const char* key, double def) -> double {
    auto it = args.find(flutter::EncodableValue(std::string(key)));
    if (it != args.end()) {
      if (const auto* d = std::get_if<double>(&it->second)) return *d;
    }
    return def;
  };

  overlay_state_    = get_str("state", "recording");
  overlay_duration_ = get_str("duration", "00:00");
  overlay_level_    = get_double("level", 0.0);

  if (!overlay_hwnd_) {
    CreateOverlayWindow();
  }
  if (overlay_hwnd_) {
    PositionOverlay();
    ShowWindow(overlay_hwnd_, SW_SHOWNOACTIVATE);
    InvalidateRect(overlay_hwnd_, nullptr, TRUE);
  }
}

void FlutterWindow::HandleHideOverlay() {
  if (overlay_hwnd_) {
    ShowWindow(overlay_hwnd_, SW_HIDE);
  }
}

void FlutterWindow::HandleUpdateOverlay(const flutter::EncodableMap& args) {
  auto get_str = [&](const char* key, const std::string& def) -> std::string {
    auto it = args.find(flutter::EncodableValue(std::string(key)));
    if (it != args.end()) {
      if (const auto* s = std::get_if<std::string>(&it->second)) return *s;
    }
    return def;
  };
  auto get_double = [&](const char* key, double def) -> double {
    auto it = args.find(flutter::EncodableValue(std::string(key)));
    if (it != args.end()) {
      if (const auto* d = std::get_if<double>(&it->second)) return *d;
    }
    return def;
  };

  overlay_state_    = get_str("state", overlay_state_);
  overlay_duration_ = get_str("duration", overlay_duration_);
  overlay_level_    = get_double("level", overlay_level_);

  if (overlay_hwnd_) {
    InvalidateRect(overlay_hwnd_, nullptr, TRUE);
  }
}

void FlutterWindow::CreateOverlayWindow() {
  HINSTANCE hInstance = GetModuleHandle(nullptr);

  if (!overlay_class_registered_) {
    WNDCLASSEXW wc = {};
    wc.cbSize        = sizeof(wc);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = OverlayWndProc;
    wc.hInstance     = hInstance;
    wc.hCursor       = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = nullptr;
    wc.lpszClassName = kOverlayClassName;
    RegisterClassExW(&wc);
    overlay_class_registered_ = true;
  }

  overlay_hwnd_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_LAYERED | WS_EX_TOOLWINDOW,
      kOverlayClassName, L"VoiceType Overlay",
      WS_POPUP,
      0, 0, kOverlayWidth, kOverlayHeight,
      nullptr, nullptr, hInstance, this);

  if (overlay_hwnd_) {
    // Semi-transparent background: alpha = 220/255 (~86%).
    SetLayeredWindowAttributes(overlay_hwnd_, 0, 220, LWA_ALPHA);
  }
}

void FlutterWindow::DestroyOverlayWindow() {
  if (overlay_hwnd_) {
    DestroyWindow(overlay_hwnd_);
    overlay_hwnd_ = nullptr;
  }
}

void FlutterWindow::PositionOverlay() {
  HMONITOR monitor = MonitorFromWindow(GetHandle(), MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = {};
  mi.cbSize = sizeof(mi);
  GetMonitorInfoW(monitor, &mi);
  RECT work = mi.rcWork;

  int x = work.left + (work.right - work.left - kOverlayWidth) / 2;
  int y = work.top + 80;
  SetWindowPos(overlay_hwnd_, HWND_TOPMOST, x, y, kOverlayWidth, kOverlayHeight,
               SWP_NOACTIVATE);
}

void FlutterWindow::PaintOverlay() {
  PAINTSTRUCT ps;
  HDC hdc = BeginPaint(overlay_hwnd_, &ps);

  RECT rc;
  GetClientRect(overlay_hwnd_, &rc);

  // Background: dark rounded rectangle.
  HBRUSH bgBrush = CreateSolidBrush(RGB(30, 30, 30));
  FillRect(hdc, &rc, bgBrush);
  DeleteObject(bgBrush);

  // Accent bar: colour depends on state.
  COLORREF accentColor = RGB(99, 179, 237); // default blue
  if (overlay_state_ == "recording") {
    accentColor = RGB(252, 92, 101);  // red
  } else if (overlay_state_ == "transcribing" ||
             overlay_state_ == "enhancing") {
    accentColor = RGB(69, 183, 209);  // cyan
  } else if (overlay_state_ == "transcribe_failed") {
    accentColor = RGB(255, 165, 0);   // orange
  }
  RECT accentRect = {0, 0, 4, rc.bottom};
  HBRUSH accentBrush = CreateSolidBrush(accentColor);
  FillRect(hdc, &accentRect, accentBrush);
  DeleteObject(accentBrush);

  // Text label.
  std::wstring label;
  if (overlay_state_ == "recording") {
    label = L"● REC  " + std::wstring(overlay_duration_.begin(), overlay_duration_.end());
  } else if (overlay_state_ == "transcribing") {
    label = L"⏳ Transcribing...";
  } else if (overlay_state_ == "enhancing") {
    label = L"✨ Enhancing...";
  } else if (overlay_state_ == "transcribe_failed") {
    label = L"✗ Transcription failed";
  } else if (overlay_state_ == "starting") {
    label = L"◎ Starting...";
  } else {
    label = std::wstring(overlay_state_.begin(), overlay_state_.end());
  }

  SetBkMode(hdc, TRANSPARENT);
  SetTextColor(hdc, RGB(240, 240, 240));

  HFONT hFont = CreateFontW(
      18, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
      CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
  HFONT oldFont = static_cast<HFONT>(SelectObject(hdc, hFont));

  RECT textRect = {12, 0, rc.right - 12, rc.bottom};
  DrawTextW(hdc, label.c_str(), -1, &textRect,
            DT_SINGLELINE | DT_VCENTER | DT_LEFT);

  SelectObject(hdc, oldFont);
  DeleteObject(hFont);

  EndPaint(overlay_hwnd_, &ps);
}

LRESULT CALLBACK FlutterWindow::OverlayWndProc(HWND hwnd, UINT msg,
                                                WPARAM wparam,
                                                LPARAM lparam) noexcept {
  FlutterWindow* self = nullptr;
  if (msg == WM_NCCREATE) {
    CREATESTRUCT* cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    self = reinterpret_cast<FlutterWindow*>(cs->lpCreateParams);
    SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  } else {
    self = reinterpret_cast<FlutterWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  }

  if (self && msg == WM_PAINT) {
    self->PaintOverlay();
    return 0;
  }
  if (msg == WM_ERASEBKGND) return 1;

  return DefWindowProc(hwnd, msg, wparam, lparam);
}

// ---------------------------------------------------------------------------
// Key code mapping
// ---------------------------------------------------------------------------

UINT FlutterWindow::MacKeyCodeToWinVK(int mac_key_code) {
  auto it = kMacToWinVK.find(mac_key_code);
  if (it != kMacToWinVK.end()) {
    return it->second;
  }
  return 0;
}

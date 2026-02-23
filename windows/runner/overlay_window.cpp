#include "overlay_window.h"

#include <cmath>
#include <algorithm>
#include <cstring>

// ============================================================================
// GDI+ 初始化
// ============================================================================

ULONG_PTR OverlayWindow::gdiplus_token_ = 0;
bool OverlayWindow::gdiplus_initialized_ = false;

bool OverlayWindow::InitGdiPlus() {
  if (gdiplus_initialized_) return true;
  Gdiplus::GdiplusStartupInput input;
  Gdiplus::Status status = Gdiplus::GdiplusStartup(&gdiplus_token_, &input, nullptr);
  gdiplus_initialized_ = (status == Gdiplus::Ok);
  return gdiplus_initialized_;
}

void OverlayWindow::ShutdownGdiPlus() {
  if (gdiplus_initialized_) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_initialized_ = false;
  }
}

// ============================================================================
// 窗口类名
// ============================================================================

static constexpr const wchar_t kOverlayClassName[] = L"VoiceTypeOverlay";

// ============================================================================
// 构造 / 析构
// ============================================================================

OverlayWindow::OverlayWindow() {
  InitGdiPlus();
}

OverlayWindow::~OverlayWindow() {
  Destroy();
}

// ============================================================================
// 创建窗口
// ============================================================================

bool OverlayWindow::Create() {
  if (hwnd_) return true;

  if (!class_registered_) {
    WNDCLASSEX wc = {};
    wc.cbSize = sizeof(WNDCLASSEX);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = kOverlayClassName;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = nullptr;  // 完全由我们自绘

    if (!RegisterClassEx(&wc)) {
      return false;
    }
    class_registered_ = true;
  }

  // WS_EX_LAYERED: 分层窗口，支持透明
  // WS_EX_TOPMOST: 始终置顶
  // WS_EX_TOOLWINDOW: 不在任务栏显示
  // WS_EX_TRANSPARENT: 鼠标事件穿透（不拦截点击）
  // WS_EX_NOACTIVATE: 不抢夺焦点
  DWORD ex_style = WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW |
                   WS_EX_NOACTIVATE;
  DWORD style = WS_POPUP;

  hwnd_ = CreateWindowEx(
      ex_style,
      kOverlayClassName,
      L"VoiceType Overlay",
      style,
      0, 0, kOverlayWidth, kOverlayHeight,
      nullptr,  // 无父窗口，独立于主窗口
      nullptr,
      GetModuleHandle(nullptr),
      this);

  if (!hwnd_) return false;

  // 设置完全透明初始值（后续通过 UpdateLayeredWindow 绘制）
  SetLayeredWindowAttributes(hwnd_, 0, 255, LWA_ALPHA);

  return true;
}

// ============================================================================
// 显示 / 隐藏 / 更新
// ============================================================================

void OverlayWindow::Show(const std::string& state, const std::string& duration, double level) {
  if (!hwnd_) Create();
  if (!hwnd_) return;

  {
    std::lock_guard<std::mutex> lock(state_mutex_);
    state_ = ParseState(state);
    int len = MultiByteToWideChar(CP_UTF8, 0, duration.c_str(), -1, nullptr, 0);
    if (len > 0) {
      duration_.resize(len - 1);
      MultiByteToWideChar(CP_UTF8, 0, duration.c_str(), -1, &duration_[0], len);
    }
    level_ = level;
    visible_ = true;
  }

  PositionOnScreen();
  RenderToLayeredWindow();
  ShowWindow(hwnd_, SW_SHOWNOACTIVATE);

  if (state_ == OverlayState::kRecording) {
    StartPulseAnimation();
  }
}

void OverlayWindow::Hide() {
  if (!hwnd_) return;

  {
    std::lock_guard<std::mutex> lock(state_mutex_);
    state_ = OverlayState::kHidden;
    visible_ = false;
  }

  StopPulseAnimation();
  ShowWindow(hwnd_, SW_HIDE);
}

void OverlayWindow::Update(const std::string& state, const std::string& duration, double level) {
  if (!hwnd_) return;

  OverlayState new_state;
  {
    std::lock_guard<std::mutex> lock(state_mutex_);
    new_state = ParseState(state);
    OverlayState old_state = state_;
    state_ = new_state;
    int len = MultiByteToWideChar(CP_UTF8, 0, duration.c_str(), -1, nullptr, 0);
    if (len > 0) {
      duration_.resize(len - 1);
      MultiByteToWideChar(CP_UTF8, 0, duration.c_str(), -1, &duration_[0], len);
    }
    level_ = level;

    // 状态切换时管理动画
    if (old_state != new_state) {
      if (new_state == OverlayState::kRecording) {
        StartPulseAnimation();
      } else {
        StopPulseAnimation();
      }
    }
  }

  // 更新音量柱
  if (new_state == OverlayState::kRecording) {
    double clamped = (std::max)(0.0, (std::min)(1.0, level));
    for (int i = 0; i < kBarCount; i++) {
      double phase = static_cast<double>(i) / (std::max)(kBarCount - 1, 1);
      double shaped = clamped * (0.6 + 0.4 * (1.0 - std::abs(phase - 0.5) * 2.0));
      bar_heights_[i] = static_cast<float>(shaped);
    }
  }

  RenderToLayeredWindow();
}

// ============================================================================
// 分层窗口绘制 (UpdateLayeredWindow)
// ============================================================================

void OverlayWindow::RenderToLayeredWindow() {
  if (!hwnd_) return;

  // 创建兼容 DC 和位图
  HDC screen_dc = GetDC(nullptr);
  HDC mem_dc = CreateCompatibleDC(screen_dc);

  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = kOverlayWidth;
  bmi.bmiHeader.biHeight = -kOverlayHeight;  // top-down
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  bmi.bmiHeader.biCompression = BI_RGB;

  void* bits = nullptr;
  HBITMAP bmp = CreateDIBSection(mem_dc, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
  HBITMAP old_bmp = (HBITMAP)SelectObject(mem_dc, bmp);

  // 使用 GDI+ 绘制
  {
    Gdiplus::Graphics g(mem_dc);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

    // 清除背景（完全透明）
    g.Clear(Gdiplus::Color(0, 0, 0, 0));

    // 绘制圆角矩形背景（半透明深色）
    {
      Gdiplus::GraphicsPath path;
      int r = kCornerRadius;
      int w = kOverlayWidth;
      int h = kOverlayHeight;
      path.AddArc(0, 0, r * 2, r * 2, 180, 90);
      path.AddArc(w - r * 2, 0, r * 2, r * 2, 270, 90);
      path.AddArc(w - r * 2, h - r * 2, r * 2, r * 2, 0, 90);
      path.AddArc(0, h - r * 2, r * 2, r * 2, 90, 90);
      path.CloseFigure();

      // 深色半透明背景
      Gdiplus::SolidBrush bg_brush(Gdiplus::Color(220, 26, 26, 38));
      g.FillPath(&bg_brush, &path);

      // 细边框
      Gdiplus::Pen border_pen(Gdiplus::Color(40, 255, 255, 255), 1.0f);
      g.DrawPath(&border_pen, &path);
    }

    std::lock_guard<std::mutex> lock(state_mutex_);

    // 1) 状态圆点
    Gdiplus::Color dot_color = GetDotColor();
    int dot_size = 10;
    int dot_x = 16;
    int dot_y = (kOverlayHeight - dot_size) / 2;

    // 脉冲动画：调整 alpha
    if (state_ == OverlayState::kRecording) {
      dot_color = Gdiplus::Color(
          static_cast<BYTE>(dot_alpha_ * 255),
          dot_color.GetR(), dot_color.GetG(), dot_color.GetB());
    }

    Gdiplus::SolidBrush dot_brush(dot_color);
    g.FillEllipse(&dot_brush, dot_x, dot_y, dot_size, dot_size);

    // 2) 时间标签（仅录音状态显示）
    int text_x = dot_x + dot_size + 8;
    if (state_ == OverlayState::kRecording) {
      Gdiplus::FontFamily font_family(L"Consolas");
      Gdiplus::Font font(&font_family, 13, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
      Gdiplus::SolidBrush text_brush(Gdiplus::Color(255, 255, 255, 255));
      Gdiplus::PointF pt(static_cast<Gdiplus::REAL>(text_x),
                         static_cast<Gdiplus::REAL>((kOverlayHeight - 16) / 2));
      g.DrawString(duration_.c_str(), -1, &font, pt, &text_brush);
      text_x += 52;
    }

    // 3) 音量条（仅录音状态显示）
    if (state_ == OverlayState::kRecording) {
      int bar_start_x = text_x + 4;
      int bar_width = 4;
      int bar_gap = 3;
      int min_bar_h = 4;
      int max_bar_h = 18;

      for (int i = 0; i < kBarCount; i++) {
        int h = min_bar_h + static_cast<int>((max_bar_h - min_bar_h) * bar_heights_[i]);
        int x = bar_start_x + i * (bar_width + bar_gap);
        int y = (kOverlayHeight - h) / 2;

        Gdiplus::GraphicsPath bar_path;
        int br = 2;  // bar corner radius
        bar_path.AddArc(x, y, br * 2, br * 2, 180, 90);
        bar_path.AddArc(x + bar_width - br * 2, y, br * 2, br * 2, 270, 90);
        bar_path.AddArc(x + bar_width - br * 2, y + h - br * 2, br * 2, br * 2, 0, 90);
        bar_path.AddArc(x, y + h - br * 2, br * 2, br * 2, 90, 90);
        bar_path.CloseFigure();

        Gdiplus::SolidBrush bar_brush(Gdiplus::Color(200, 255, 255, 255));
        g.FillPath(&bar_brush, &bar_path);
      }
      text_x = bar_start_x + kBarCount * (bar_width + bar_gap) + 8;
    }

    // 4) 状态文字
    {
      std::wstring status = GetStatusText();
      Gdiplus::FontFamily font_family(L"Microsoft YaHei");
      Gdiplus::Font font(&font_family, 12, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
      Gdiplus::SolidBrush text_brush(Gdiplus::Color(150, 255, 255, 255));
      Gdiplus::PointF pt(static_cast<Gdiplus::REAL>(text_x),
                         static_cast<Gdiplus::REAL>((kOverlayHeight - 14) / 2));
      g.DrawString(status.c_str(), -1, &font, pt, &text_brush);
    }
  }

  // UpdateLayeredWindow 实现真正的 per-pixel alpha
  POINT pt_src = {0, 0};
  SIZE sz = {kOverlayWidth, kOverlayHeight};
  BLENDFUNCTION blend = {};
  blend.BlendOp = AC_SRC_OVER;
  blend.SourceConstantAlpha = 255;
  blend.AlphaFormat = AC_SRC_ALPHA;

  POINT pt_dst;
  RECT rc;
  GetWindowRect(hwnd_, &rc);
  pt_dst.x = rc.left;
  pt_dst.y = rc.top;

  UpdateLayeredWindow(hwnd_, screen_dc, &pt_dst, &sz, mem_dc, &pt_src, 0, &blend, ULW_ALPHA);

  SelectObject(mem_dc, old_bmp);
  DeleteObject(bmp);
  DeleteDC(mem_dc);
  ReleaseDC(nullptr, screen_dc);
}

// ============================================================================
// 窗口消息处理
// ============================================================================

LRESULT CALLBACK OverlayWindow::WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  OverlayWindow* self = nullptr;

  if (msg == WM_CREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    self = static_cast<OverlayWindow*>(cs->lpCreateParams);
    SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  } else {
    self = reinterpret_cast<OverlayWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  }

  if (self) {
    return self->HandleMessage(hwnd, msg, wparam, lparam);
  }

  return DefWindowProc(hwnd, msg, wparam, lparam);
}

LRESULT OverlayWindow::HandleMessage(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam) {
  switch (msg) {
    case WM_HOTKEY:
      if (hotkey_callback_) {
        hotkey_callback_(registered_key_code_, "down", false, hotkey_user_data_);
        // Win32 RegisterHotKey 只有 down 事件，没有 up 事件
        // 对于 tapToTalk 模式，我们只发 down；pushToTalk 需要 keyboard hook
      }
      return 0;

    case WM_DESTROY:
      UnregisterGlobalHotkey();
      return 0;

    // 阻止窗口获取焦点
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;

    case WM_NCHITTEST:
      return HTTRANSPARENT;  // 鼠标穿透
  }

  return DefWindowProc(hwnd, msg, wparam, lparam);
}

// ============================================================================
// 全局热键
// ============================================================================

bool OverlayWindow::RegisterGlobalHotkey(int key_code, int modifiers) {
  UnregisterGlobalHotkey();

  if (!hwnd_) {
    if (!Create()) return false;
  }

  registered_key_code_ = key_code;

  // 注册系统级全局热键
  UINT win_modifiers = 0;
  if (modifiers & 0x01) win_modifiers |= MOD_SHIFT;
  if (modifiers & 0x02) win_modifiers |= MOD_CONTROL;
  if (modifiers & 0x04) win_modifiers |= MOD_ALT;
  // MOD_NOREPEAT 防止重复触发
  win_modifiers |= MOD_NOREPEAT;

  BOOL ok = ::RegisterHotKey(hwnd_, registered_hotkey_id_, win_modifiers, key_code);
  return ok != FALSE;
}

void OverlayWindow::UnregisterGlobalHotkey() {
  if (hwnd_) {
    ::UnregisterHotKey(hwnd_, registered_hotkey_id_);
  }
}

bool OverlayWindow::HandleHotkeyMessage(WPARAM wparam, LPARAM lparam) {
  if (static_cast<int>(wparam) == registered_hotkey_id_) {
    if (hotkey_callback_) {
      hotkey_callback_(registered_key_code_, "down", false, hotkey_user_data_);
    }
    return true;
  }
  return false;
}

void OverlayWindow::SetHotkeyCallback(HotkeyCallback callback, void* user_data) {
  hotkey_callback_ = callback;
  hotkey_user_data_ = user_data;
}

// ============================================================================
// 文本插入（剪贴板 + 模拟 Ctrl+V）
// ============================================================================

void OverlayWindow::InsertText(const std::string& text) {
  // 保存旧的剪贴板内容
  std::wstring old_clipboard;
  if (OpenClipboard(nullptr)) {
    HANDLE h = GetClipboardData(CF_UNICODETEXT);
    if (h) {
      wchar_t* data = static_cast<wchar_t*>(GlobalLock(h));
      if (data) {
        old_clipboard = data;
        GlobalUnlock(h);
      }
    }
    CloseClipboard();
  }

  // 将新文本写入剪贴板
  int wlen = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
  if (wlen > 0 && OpenClipboard(nullptr)) {
    EmptyClipboard();
    HGLOBAL hg = GlobalAlloc(GMEM_MOVEABLE, wlen * sizeof(wchar_t));
    if (hg) {
      wchar_t* dest = static_cast<wchar_t*>(GlobalLock(hg));
      MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, dest, wlen);
      GlobalUnlock(hg);
      SetClipboardData(CF_UNICODETEXT, hg);
    }
    CloseClipboard();
  }

  // 短暂延迟后模拟 Ctrl+V
  Sleep(50);

  INPUT inputs[4] = {};
  // Ctrl down
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = VK_CONTROL;
  // V down
  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = 'V';
  // V up
  inputs[2].type = INPUT_KEYBOARD;
  inputs[2].ki.wVk = 'V';
  inputs[2].ki.dwFlags = KEYEVENTF_KEYUP;
  // Ctrl up
  inputs[3].type = INPUT_KEYBOARD;
  inputs[3].ki.wVk = VK_CONTROL;
  inputs[3].ki.dwFlags = KEYEVENTF_KEYUP;

  SendInput(4, inputs, sizeof(INPUT));

  // 延迟后恢复旧的剪贴板
  Sleep(200);

  if (!old_clipboard.empty() && OpenClipboard(nullptr)) {
    EmptyClipboard();
    size_t cb_size = (old_clipboard.size() + 1) * sizeof(wchar_t);
    HGLOBAL hg = GlobalAlloc(GMEM_MOVEABLE, cb_size);
    if (hg) {
      wchar_t* dest = static_cast<wchar_t*>(GlobalLock(hg));
      memcpy(dest, old_clipboard.c_str(), cb_size);
      GlobalUnlock(hg);
      SetClipboardData(CF_UNICODETEXT, hg);
    }
    CloseClipboard();
  }
}

// ============================================================================
// 脉冲动画
// ============================================================================

void CALLBACK OverlayWindow::PulseTimerProc(HWND hwnd, UINT msg, UINT_PTR id, DWORD time) {
  OverlayWindow* self = reinterpret_cast<OverlayWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (!self) return;

  if (self->dot_fading_out_) {
    self->dot_alpha_ -= 0.05f;
    if (self->dot_alpha_ <= 0.4f) {
      self->dot_alpha_ = 0.4f;
      self->dot_fading_out_ = false;
    }
  } else {
    self->dot_alpha_ += 0.05f;
    if (self->dot_alpha_ >= 1.0f) {
      self->dot_alpha_ = 1.0f;
      self->dot_fading_out_ = true;
    }
  }

  self->RenderToLayeredWindow();
}

void OverlayWindow::StartPulseAnimation() {
  StopPulseAnimation();
  dot_alpha_ = 1.0f;
  dot_fading_out_ = true;
  if (hwnd_) {
    pulse_timer_id_ = SetTimer(hwnd_, 100, 50, PulseTimerProc);  // ~20fps
  }
}

void OverlayWindow::StopPulseAnimation() {
  if (pulse_timer_id_ && hwnd_) {
    KillTimer(hwnd_, pulse_timer_id_);
    pulse_timer_id_ = 0;
  }
  dot_alpha_ = 1.0f;
}

// ============================================================================
// 屏幕定位
// ============================================================================

void OverlayWindow::PositionOnScreen() {
  if (!hwnd_) return;

  // 获取主显示器工作区域（排除任务栏）
  RECT work_area;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);

  int screen_width = work_area.right - work_area.left;
  int x = work_area.left + (screen_width - kOverlayWidth) / 2;
  int y = work_area.bottom - kOverlayHeight - 80;  // 距底部80px

  SetWindowPos(hwnd_, HWND_TOPMOST, x, y, kOverlayWidth, kOverlayHeight,
               SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

// ============================================================================
// 状态辅助
// ============================================================================

OverlayState OverlayWindow::ParseState(const std::string& state_str) {
  if (state_str == "starting") return OverlayState::kStarting;
  if (state_str == "recording") return OverlayState::kRecording;
  if (state_str == "transcribing") return OverlayState::kTranscribing;
  if (state_str == "enhancing") return OverlayState::kEnhancing;
  if (state_str == "transcribe_failed") return OverlayState::kFailed;
  return OverlayState::kHidden;
}

Gdiplus::Color OverlayWindow::GetDotColor() const {
  switch (state_) {
    case OverlayState::kStarting:
      return Gdiplus::Color(255, 255, 204, 0);       // 黄色
    case OverlayState::kRecording:
      return Gdiplus::Color(255, 255, 59, 48);        // 红色
    case OverlayState::kTranscribing:
      return Gdiplus::Color(255, 107, 99, 255);       // 紫色
    case OverlayState::kEnhancing:
      return Gdiplus::Color(255, 79, 199, 158);       // 绿色
    case OverlayState::kFailed:
      return Gdiplus::Color(255, 255, 59, 48);        // 红色
    default:
      return Gdiplus::Color(0, 0, 0, 0);
  }
}

std::wstring OverlayWindow::GetStatusText() const {
  switch (state_) {
    case OverlayState::kStarting:
      return L"\x9EA6\x514B\x98CE\x542F\x52A8\x4E2D";  // 麦克风启动中
    case OverlayState::kRecording:
      return L"\x5F55\x97F3\x4E2D";                      // 录音中
    case OverlayState::kTranscribing:
      return L"\x8BED\x97F3\x8F6C\x6362\x4E2D";          // 语音转换中
    case OverlayState::kEnhancing:
      return L"\x6587\x5B57\x6574\x7406\x4E2D";          // 文字整理中
    case OverlayState::kFailed:
      return L"\x8BED\x97F3\x8F6C\x5F55\x5931\x8D25";    // 语音转录失败
    default:
      return L"";
  }
}

// ============================================================================
// 销毁
// ============================================================================

void OverlayWindow::Destroy() {
  StopPulseAnimation();
  UnregisterGlobalHotkey();

  if (hwnd_) {
    DestroyWindow(hwnd_);
    hwnd_ = nullptr;
  }

  if (class_registered_) {
    UnregisterClass(kOverlayClassName, GetModuleHandle(nullptr));
    class_registered_ = false;
  }
}

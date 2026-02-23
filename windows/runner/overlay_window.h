#ifndef RUNNER_OVERLAY_WINDOW_H_
#define RUNNER_OVERLAY_WINDOW_H_

#include <windows.h>
#include <gdiplus.h>
#include <string>
#include <mutex>

#pragma comment(lib, "gdiplus.lib")

// 录音状态枚举
enum class OverlayState {
  kStarting,      // 麦克风启动中 (黄色)
  kRecording,     // 录音中 (红色)
  kTranscribing,  // 语音转换中 (紫色)
  kEnhancing,     // 文字整理中 (绿色)
  kFailed,        // 转录失败 (红色)
  kHidden         // 隐藏状态
};

// 独立于主窗口的录音指示器悬浮窗
// 使用 WS_EX_LAYERED + WS_EX_TOPMOST + WS_EX_TOOLWINDOW 实现透明、置顶、不出现在任务栏
class OverlayWindow {
 public:
  OverlayWindow();
  ~OverlayWindow();

  // 禁止拷贝
  OverlayWindow(const OverlayWindow&) = delete;
  OverlayWindow& operator=(const OverlayWindow&) = delete;

  // 创建窗口（注册窗口类并创建 HWND，不立即显示）
  bool Create();

  // 显示/隐藏
  void Show(const std::string& state, const std::string& duration, double level);
  void Hide();

  // 更新状态
  void Update(const std::string& state, const std::string& duration, double level);

  // 全局热键
  bool RegisterGlobalHotkey(int key_code, int modifiers);
  void UnregisterGlobalHotkey();

  // 处理 WM_HOTKEY 消息的回调（由 FlutterWindow 转发）
  bool HandleHotkeyMessage(WPARAM wparam, LPARAM lparam);

  // 热键事件回调
  using HotkeyCallback = void (*)(int key_code, const char* type, bool is_repeat, void* user_data);
  void SetHotkeyCallback(HotkeyCallback callback, void* user_data);

  // 文本插入
  void InsertText(const std::string& text);

  // 销毁窗口
  void Destroy();

  HWND GetHandle() const { return hwnd_; }

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);
  LRESULT HandleMessage(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam);

  // 绘制
  void Render();
  void RenderToLayeredWindow();

  // 解析状态字符串
  OverlayState ParseState(const std::string& state_str);
  Gdiplus::Color GetDotColor() const;
  std::wstring GetStatusText() const;

  // 动画定时器
  static void CALLBACK PulseTimerProc(HWND hwnd, UINT msg, UINT_PTR id, DWORD time);
  void StartPulseAnimation();
  void StopPulseAnimation();

  // 窗口居中定位到屏幕底部
  void PositionOnScreen();

  // GDI+ 初始化
  static bool InitGdiPlus();
  static void ShutdownGdiPlus();

  HWND hwnd_ = nullptr;
  bool class_registered_ = false;

  // GDI+ token
  static ULONG_PTR gdiplus_token_;
  static bool gdiplus_initialized_;

  // 状态
  OverlayState state_ = OverlayState::kHidden;
  std::wstring duration_ = L"00:00";
  double level_ = 0.0;
  bool visible_ = false;
  std::mutex state_mutex_;

  // 脉冲动画
  UINT_PTR pulse_timer_id_ = 0;
  float dot_alpha_ = 1.0f;
  bool dot_fading_out_ = true;

  // 热键
  int registered_hotkey_id_ = 1;
  int registered_key_code_ = 0;
  HotkeyCallback hotkey_callback_ = nullptr;
  void* hotkey_user_data_ = nullptr;

  // 窗口尺寸
  static constexpr int kOverlayWidth = 280;
  static constexpr int kOverlayHeight = 44;
  static constexpr int kCornerRadius = 22;

  // 条形音量指示器
  static constexpr int kBarCount = 6;
  float bar_heights_[kBarCount] = {};
};

#endif  // RUNNER_OVERLAY_WINDOW_H_

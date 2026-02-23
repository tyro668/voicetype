#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
    static constexpr UINT kOverlayWidth = 360;
    static constexpr UINT kOverlayHeight = 56;

    static FlutterWindow* instance_;

    bool SetupMethodChannel();
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    bool RegisterGlobalHotkey(int key_code);
    void UnregisterGlobalHotkey();
    static LRESULT CALLBACK LowLevelKeyboardProc(int n_code, WPARAM wparam,
                                                 LPARAM lparam);
    void EmitGlobalKeyEvent(int key_code, const std::string& type,
                            bool is_repeat);

    void EnsureOverlayWindow();
    void ShowOverlay(const std::string& state, const std::string& duration,
                                         double level, const std::string& state_label);
    void UpdateOverlay(const std::string& state, const std::string& duration,
                                             double level, const std::string& state_label);
    void HideOverlay();
    void PositionOverlayWindow();
    void PaintOverlay(HDC hdc);
    static LRESULT CALLBACK OverlayWndProc(HWND hwnd, UINT message,
                                           WPARAM wparam,
                                           LPARAM lparam) noexcept;

    void ShowMainWindowNative();
    void InsertTextAtCursor(const std::wstring& text);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
        method_channel_;

    HHOOK keyboard_hook_ = nullptr;
    int hotkey_key_code_ = VK_F2;
    bool hotkey_enabled_ = false;
    bool hotkey_is_down_ = false;

    HWND overlay_window_ = nullptr;
    std::string overlay_state_ = "idle";
    std::string overlay_state_label_;
    std::string overlay_duration_ = "00:00";
    double overlay_level_ = 0.0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_

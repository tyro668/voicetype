#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"
#include "overlay_window.h"

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
  // 设置 MethodChannel 处理器
  void SetupMethodChannel();

  // 热键回调（静态，因为 Win32 API 需要函数指针）
  static void OnHotkeyEvent(int key_code, const char* type, bool is_repeat, void* user_data);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // MethodChannel for communicating with Flutter
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

  // 独立悬浮窗
  std::unique_ptr<OverlayWindow> overlay_window_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_

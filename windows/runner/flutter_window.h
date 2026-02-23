#pragma once

#include "win32_window.h"

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <map>

// A window that does the following things:
// - Owns Flutter-related resources so that they live until the app ends.
// - Implements the com.voicetype/overlay MethodChannel for Windows-specific
//   features: global hotkeys, overlay window, and text insertion.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window,
                         UINT const message,
                         WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Sets up the MethodChannel and its handler.
  void SetupMethodChannel();

  // MethodChannel handlers.
  void HandleShowOverlay(const flutter::EncodableMap& args);
  void HandleHideOverlay();
  void HandleUpdateOverlay(const flutter::EncodableMap& args);
  void HandleShowMainWindow();
  void HandleInsertText(const std::string& text);
  bool HandleRegisterHotkey(int mac_key_code, int modifiers);
  void HandleUnregisterHotkey();

  // Overlay window management.
  void CreateOverlayWindow();
  void DestroyOverlayWindow();
  void PaintOverlay();
  void PositionOverlay();

  // Text insertion helpers.
  static void InsertTextBackground(const std::wstring& wtext, HWND target_hwnd);

  // Maps macOS key codes (as used by Flutter settings) to Windows VK codes.
  static UINT MacKeyCodeToWinVK(int mac_key_code);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The MethodChannel for overlay/hotkey/text features.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;

  // Overlay window handle.
  HWND overlay_hwnd_ = nullptr;
  static const wchar_t* kOverlayClassName;

  // Current overlay state.
  std::string overlay_state_;
  std::string overlay_duration_;
  double overlay_level_ = 0.0;

  // Registered hotkey ID and macOS keycode (to echo back to Flutter).
  static const int kHotkeyId = 1;
  int registered_mac_key_code_ = -1;

  // Last foreground window before VoiceType became active.
  HWND last_foreground_hwnd_ = nullptr;

  // Tracks whether the overlay class has been registered.
  static bool overlay_class_registered_;

  // Static WndProc for overlay window.
  static LRESULT CALLBACK OverlayWndProc(HWND hwnd, UINT msg, WPARAM wparam,
                                          LPARAM lparam) noexcept;
};

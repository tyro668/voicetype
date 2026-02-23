#include "flutter_window.h"

#include <optional>
#include <string>
#include <thread>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // 创建悬浮窗
  overlay_window_ = std::make_unique<OverlayWindow>();

  // 设置 MethodChannel
  SetupMethodChannel();

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
  if (overlay_window_) {
    overlay_window_->Destroy();
    overlay_window_.reset();
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

// ============================================================================
// MethodChannel 设置
// ============================================================================

void FlutterWindow::SetupMethodChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) return;

  method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "com.voicetype/overlay",
      &flutter::StandardMethodCodec::GetInstance());

  // 设置热键回调
  overlay_window_->SetHotkeyCallback(OnHotkeyEvent, this);

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

        const auto& method = call.method_name();

        // ── showOverlay ──
        if (method == "showOverlay") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            std::string state = "recording";
            std::string duration = "00:00";
            double level = 0.0;

            auto it_state = args->find(flutter::EncodableValue("state"));
            if (it_state != args->end()) {
              if (auto* s = std::get_if<std::string>(&it_state->second)) state = *s;
            }
            auto it_dur = args->find(flutter::EncodableValue("duration"));
            if (it_dur != args->end()) {
              if (auto* s = std::get_if<std::string>(&it_dur->second)) duration = *s;
            }
            auto it_level = args->find(flutter::EncodableValue("level"));
            if (it_level != args->end()) {
              if (auto* d = std::get_if<double>(&it_level->second)) level = *d;
            }

            overlay_window_->Show(state, duration, level);
          }
          result->Success();
          return;
        }

        // ── hideOverlay ──
        if (method == "hideOverlay") {
          overlay_window_->Hide();
          result->Success();
          return;
        }

        // ── updateOverlay ──
        if (method == "updateOverlay") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            std::string state = "recording";
            std::string duration = "00:00";
            double level = 0.0;

            auto it_state = args->find(flutter::EncodableValue("state"));
            if (it_state != args->end()) {
              if (auto* s = std::get_if<std::string>(&it_state->second)) state = *s;
            }
            auto it_dur = args->find(flutter::EncodableValue("duration"));
            if (it_dur != args->end()) {
              if (auto* s = std::get_if<std::string>(&it_dur->second)) duration = *s;
            }
            auto it_level = args->find(flutter::EncodableValue("level"));
            if (it_level != args->end()) {
              if (auto* d = std::get_if<double>(&it_level->second)) level = *d;
            }

            overlay_window_->Update(state, duration, level);
          }
          result->Success();
          return;
        }

        // ── showMainWindow ──
        if (method == "showMainWindow") {
          HWND hwnd = GetHandle();
          if (hwnd) {
            ShowWindow(hwnd, SW_RESTORE);
            SetForegroundWindow(hwnd);
          }
          result->Success();
          return;
        }

        // ── insertText ──
        if (method == "insertText") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = args->find(flutter::EncodableValue("text"));
            if (it != args->end()) {
              if (auto* text = std::get_if<std::string>(&it->second)) {
                // 在新线程中执行（因为有 Sleep 操作）
                std::string text_copy = *text;
                std::thread([this, text_copy]() {
                  overlay_window_->InsertText(text_copy);
                }).detach();
              }
            }
          }
          result->Success();
          return;
        }

        // ── registerHotkey ──
        if (method == "registerHotkey") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            int key_code = 0;
            int modifiers = 0;

            auto it_key = args->find(flutter::EncodableValue("keyCode"));
            if (it_key != args->end()) {
              if (auto* v = std::get_if<int32_t>(&it_key->second)) key_code = *v;
            }
            auto it_mod = args->find(flutter::EncodableValue("modifiers"));
            if (it_mod != args->end()) {
              if (auto* v = std::get_if<int32_t>(&it_mod->second)) modifiers = *v;
            }

            bool ok = overlay_window_->RegisterGlobalHotkey(key_code, modifiers);
            result->Success(flutter::EncodableValue(ok));
          } else {
            result->Success(flutter::EncodableValue(false));
          }
          return;
        }

        // ── unregisterHotkey ──
        if (method == "unregisterHotkey") {
          overlay_window_->UnregisterGlobalHotkey();
          result->Success();
          return;
        }

        // ── checkAccessibility (Windows 不需要，始终返回 true) ──
        if (method == "checkAccessibility") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        // ── requestAccessibility (Windows 不需要) ──
        if (method == "requestAccessibility") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        // ── checkInputMonitoring (Windows 不需要) ──
        if (method == "checkInputMonitoring") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        // ── requestInputMonitoring (Windows 不需要) ──
        if (method == "requestInputMonitoring") {
          result->Success(flutter::EncodableValue(true));
          return;
        }

        // ── open* settings (Windows: no-op) ──
        if (method == "openSoundInput" || method == "openMicrophonePrivacy" ||
            method == "openAccessibilityPrivacy" || method == "openInputMonitoringPrivacy") {
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}

// ============================================================================
// 热键回调（静态）
// ============================================================================

void FlutterWindow::OnHotkeyEvent(int key_code, const char* type, bool is_repeat, void* user_data) {
  auto* self = static_cast<FlutterWindow*>(user_data);
  if (!self || !self->method_channel_) return;

  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("keyCode")] = flutter::EncodableValue(key_code);
  payload[flutter::EncodableValue("type")] = flutter::EncodableValue(std::string(type));
  payload[flutter::EncodableValue("isRepeat")] = flutter::EncodableValue(is_repeat);

  self->method_channel_->InvokeMethod(
      "onGlobalKeyEvent",
      std::make_unique<flutter::EncodableValue>(payload));
}

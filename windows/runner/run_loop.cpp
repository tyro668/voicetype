#include "run_loop.h"

#include <windows.h>
#include <flutter/flutter_engine.h>

RunLoop::RunLoop() {}

RunLoop::~RunLoop() {}

void RunLoop::Run() {
  running_ = true;
  MSG message;
  while (running_ && GetMessage(&message, nullptr, 0, 0)) {
    TranslateMessage(&message);
    DispatchMessage(&message);
  }
  running_ = false;
}

void RunLoop::Stop() {
  running_ = false;
  PostQuitMessage(0);
}

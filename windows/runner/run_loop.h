#pragma once

#include <windows.h>
#include <functional>

// A runloop that will service events for Flutter instances on the current
// thread.
class RunLoop {
 public:
  RunLoop();
  ~RunLoop();

  // Prevent copying.
  RunLoop(RunLoop const &) = delete;
  RunLoop &operator=(RunLoop const &) = delete;

  // Runs the loop until |Stop| is called.
  void Run();

  // Stops a running loop.
  void Stop();

 private:
  bool running_ = false;
};

import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func performClose(_ sender: Any?) {
    orderOut(nil)
  }

  override func close() {
    orderOut(nil)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // 计算窗口尺寸: min(屏幕 * 4/5, 1200x800)
    if let screen = NSScreen.main {
      let screenSize = screen.visibleFrame.size
      let w = min(screenSize.width * 4.0 / 5.0, 1200)
      let h = min(screenSize.height * 4.0 / 5.0, 800)
      let x = screen.visibleFrame.origin.x + (screenSize.width - w) / 2.0
      let y = screen.visibleFrame.origin.y + (screenSize.height - h) / 2.0
      self.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    } else {
      self.setFrame(self.frame, display: true)
      self.center()
    }

    self.title = ""
    self.titleVisibility = .hidden

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

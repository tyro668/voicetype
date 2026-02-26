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
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.title = ""
    self.titleVisibility = .hidden
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

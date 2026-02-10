import Cocoa
import Carbon.HIToolbox
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var overlayPanel: NSPanel?
  var overlayContentView: OverlayView?
  var methodChannel: FlutterMethodChannel?
  var globalMonitor: Any?
  var localMonitor: Any?
  var statusItem: NSStatusItem?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 关闭主窗口不退出应用，让录音 overlay 可以独立存在
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 获取 FlutterViewController 并注册 MethodChannel
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    methodChannel = FlutterMethodChannel(
      name: "com.voicetype/overlay",
      binaryMessenger: controller.engine.binaryMessenger
    )

    setupStatusItem()
    mainFlutterWindow?.isReleasedWhenClosed = false

    methodChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "showOverlay":
        if let args = call.arguments as? [String: Any] {
          self?.showOverlay(args: args)
        }
        result(nil)
      case "hideOverlay":
        self?.hideOverlay()
        result(nil)
      case "updateOverlay":
        if let args = call.arguments as? [String: Any] {
          self?.updateOverlay(args: args)
        }
        result(nil)
      case "showMainWindow":
        self?.showMainWindow()
        result(nil)
      case "insertText":
        if let args = call.arguments as? [String: Any],
           let text = args["text"] as? String {
          self?.insertTextAtCursor(text)
        }
        result(nil)
      case "checkAccessibility":
        let trusted = AXIsProcessTrusted()
        result(trusted)
      case "requestAccessibility":
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        result(trusted)
      case "openSoundInput":
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension?input") {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      case "openMicrophonePrivacy":
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone") {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      case "openAccessibilityPrivacy":
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    ensureAccessibilityPermission()
    NSLog("[hotkey] accessibility trusted: %d", AXIsProcessTrusted())

    // 注册全局快捷键监听（即使主窗口不在前台也能触发）
    setupGlobalHotkey(controller: controller)
  }

  func setupStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      if #available(macOS 11.0, *) {
        button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VoiceType")
      } else {
        button.title = "VT"
      }
    }
    let menu = NSMenu()
    let openItem = NSMenuItem(
      title: "打开",
      action: #selector(showMainWindowFromStatusItem),
      keyEquivalent: ""
    )
    openItem.target = self
    menu.addItem(openItem)
    menu.addItem(NSMenuItem.separator())
    let quitItem = NSMenuItem(
      title: "退出",
      action: #selector(quitFromStatusItem),
      keyEquivalent: ""
    )
    quitItem.target = self
    menu.addItem(quitItem)
    item.menu = menu
    statusItem = item
  }

  func ensureAccessibilityPermission() {
    if AXIsProcessTrusted() {
      return
    }
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  @objc func showMainWindowFromStatusItem() {
    showMainWindow()
  }

  @objc func quitFromStatusItem() {
    NSApp.terminate(nil)
  }

  func setupGlobalHotkey(controller: FlutterViewController) {
    // 全局快捷键监听 - 即使 app 不在前台也能触发
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      if self?.methodChannel == nil {
        NSLog("[hotkey] global event but methodChannel is nil")
        return
      }
      NSLog("[hotkey] global keyCode=%d type=%@ repeat=%d", event.keyCode, event.type == .keyDown ? "down" : "up", event.isARepeat)
      self?.methodChannel?.invokeMethod("onGlobalKeyEvent", arguments: [
        "keyCode": event.keyCode,
        "type": event.type == .keyDown ? "down" : "up",
        "isRepeat": event.isARepeat,
      ])
    }

    // 本地快捷键监听 - app 在前台时
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      if self?.methodChannel == nil {
        NSLog("[hotkey] local event but methodChannel is nil")
        return event
      }
      NSLog("[hotkey] local keyCode=%d type=%@ repeat=%d", event.keyCode, event.type == .keyDown ? "down" : "up", event.isARepeat)
      self?.methodChannel?.invokeMethod("onGlobalKeyEvent", arguments: [
        "keyCode": event.keyCode,
        "type": event.type == .keyDown ? "down" : "up",
        "isRepeat": event.isARepeat,
      ])
      return event
    }
  }

  func showOverlay(args: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if self.overlayPanel == nil {
        self.createOverlayPanel()
      }

      let state = args["state"] as? String ?? "recording"
      let duration = args["duration"] as? String ?? "00:00"
      let level = args["level"] as? Double ?? 0.0

      self.overlayContentView?.update(state: state, duration: duration, level: level)
      self.overlayPanel?.orderFront(nil)
      self.positionOverlay()
    }
  }

  func hideOverlay() {
    DispatchQueue.main.async { [weak self] in
      self?.overlayPanel?.orderOut(nil)
    }
  }

  func updateOverlay(args: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      let state = args["state"] as? String ?? "recording"
      let duration = args["duration"] as? String ?? "00:00"
      let level = args["level"] as? Double ?? 0.0
      self?.overlayContentView?.update(state: state, duration: duration, level: level)
    }
  }

  func showMainWindow() {
    mainFlutterWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func insertTextAtCursor(_ text: String) {
    let pasteboard = NSPasteboard.general
    let previousString = pasteboard.string(forType: .string)
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    sendPasteShortcut()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      pasteboard.clearContents()
      if let prev = previousString {
        pasteboard.setString(prev, forType: .string)
      }
    }
  }

  func sendPasteShortcut() {
    guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
    let keyV = CGKeyCode(kVK_ANSI_V)

    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
    keyDown?.flags = .maskCommand
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
    keyUp?.flags = .maskCommand

    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }

  func createOverlayPanel() {
    let panelWidth: CGFloat = 280
    let panelHeight: CGFloat = 56

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
      styleMask: [.nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    panel.isFloatingPanel = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true

    let contentView = OverlayView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
    panel.contentView = contentView

    overlayPanel = panel
    overlayContentView = contentView
  }

  func positionOverlay() {
    guard let panel = overlayPanel, let screen = NSScreen.main else { return }
    let screenFrame = screen.visibleFrame
    let panelFrame = panel.frame
    let x = screenFrame.midX - panelFrame.width / 2
    let y = screenFrame.origin.y + 80
    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }

  deinit {
    if let monitor = globalMonitor {
      NSEvent.removeMonitor(monitor)
    }
    if let monitor = localMonitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}

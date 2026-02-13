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
  var eventTap: CFMachPort?
  var eventTapSource: CFRunLoopSource?
  var hotKeyRef: EventHotKeyRef?
  var hotKeyHandler: EventHandlerRef?
  var registeredHotKeyCode: UInt32 = UInt32(kVK_F2)
  var lastActiveApp: NSRunningApplication?
  private lazy var logFileURL: URL = {
    let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
    let logsDir = libraryDir?.appendingPathComponent("Logs")
    if let logsDir = logsDir {
      try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
      return logsDir.appendingPathComponent("voicetype.log")
    }
    return URL(fileURLWithPath: "/tmp/voicetype.log")
  }()

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
      case "registerHotkey":
        if let args = call.arguments as? [String: Any],
           let keyCode = args["keyCode"] as? Int {
          let modifiers = args["modifiers"] as? Int ?? 0
          self?.log("[hotkey] method registerHotkey keyCode=\(keyCode) modifiers=\(modifiers)")
          let ok = self?.registerHotkey(
            keyCode: UInt32(keyCode),
            modifiers: UInt32(modifiers)
          ) ?? false
          self?.log("[hotkey] method registerHotkey result ok=\(ok)")
          result(ok)
        } else {
          self?.log("[hotkey] method registerHotkey invalid args=\(String(describing: call.arguments))")
          result(false)
        }
      case "unregisterHotkey":
        self?.unregisterHotkey()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    ensureAccessibilityPermission()
    log("[hotkey] accessibility trusted: \(AXIsProcessTrusted())")

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

  func log(_ message: String) {
    NSLog("%@", message)
    let formatter = ISO8601DateFormatter()
    let line = "[\(formatter.string(from: Date()))] \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if !FileManager.default.fileExists(atPath: logFileURL.path) {
      FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }
    if let handle = try? FileHandle(forWritingTo: logFileURL) {
      handle.seekToEndOfFile()
      handle.write(data)
      try? handle.close()
    }
  }

  @objc func showMainWindowFromStatusItem() {
    showMainWindow()
  }

  @objc func quitFromStatusItem() {
    NSApp.terminate(nil)
  }

  func setupGlobalHotkey(controller: FlutterViewController) {
    if setupCarbonHotkey() {
      log("[hotkey] using Carbon hotkey")
    } else if setupEventTap() {
      log("[hotkey] using CGEventTap")
    }

    setupNSEventFallbackMonitors()
  }

  func setupNSEventFallbackMonitors() {
    if globalMonitor != nil && localMonitor != nil {
      return
    }

    // 兜底：NSEvent 全局/本地监听
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
      if self?.hotKeyRef != nil {
        return
      }
      self?.captureActiveApplication()
      if self?.methodChannel == nil {
        self?.log("[hotkey] global event but methodChannel is nil")
        return
      }

      let eventType: String
      if event.type == .keyDown {
        eventType = "down"
      } else if event.type == .keyUp {
        eventType = "up"
      } else if event.type == .flagsChanged && UInt32(event.keyCode) == self?.registeredHotKeyCode {
        eventType = event.modifierFlags.contains(.function) ? "down" : "up"
        self?.log(
          "[hotkey] global flagsChanged keyCode=\(event.keyCode) function=\(event.modifierFlags.contains(.function)) rawFlags=\(event.modifierFlags.rawValue)",
        )
      } else {
        return
      }

      self?.log("[hotkey] global keyCode=\(event.keyCode) type=\(eventType) repeat=\(event.isARepeat)")
      self?.methodChannel?.invokeMethod("onGlobalKeyEvent", arguments: [
        "keyCode": event.keyCode,
        "type": eventType,
        "isRepeat": event.type == .flagsChanged ? false : event.isARepeat,
      ])
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
      if self?.hotKeyRef != nil {
        return event
      }
      self?.captureActiveApplication()
      if self?.methodChannel == nil {
        self?.log("[hotkey] local event but methodChannel is nil")
        return event
      }

      let eventType: String
      if event.type == .keyDown {
        eventType = "down"
      } else if event.type == .keyUp {
        eventType = "up"
      } else if event.type == .flagsChanged && UInt32(event.keyCode) == self?.registeredHotKeyCode {
        eventType = event.modifierFlags.contains(.function) ? "down" : "up"
        self?.log(
          "[hotkey] local flagsChanged keyCode=\(event.keyCode) function=\(event.modifierFlags.contains(.function)) rawFlags=\(event.modifierFlags.rawValue)",
        )
      } else {
        return event
      }

      self?.log("[hotkey] local keyCode=\(event.keyCode) type=\(eventType) repeat=\(event.isARepeat)")
      self?.methodChannel?.invokeMethod("onGlobalKeyEvent", arguments: [
        "keyCode": event.keyCode,
        "type": eventType,
        "isRepeat": event.type == .flagsChanged ? false : event.isARepeat,
      ])
      return event
    }

    log("[hotkey] NSEvent fallback monitors enabled")
  }

  func setupCarbonHotkey() -> Bool {
    if hotKeyHandler == nil {
      let eventTypes = [
        EventTypeSpec(
          eventClass: OSType(kEventClassKeyboard),
          eventKind: UInt32(kEventHotKeyPressed)
        ),
        EventTypeSpec(
          eventClass: OSType(kEventClassKeyboard),
          eventKind: UInt32(kEventHotKeyReleased)
        ),
      ]

      let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      let status = InstallEventHandler(
        GetEventDispatcherTarget(),
        { _, event, userData in
          guard let userData = userData else {
            return noErr
          }
          let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
          delegate.captureActiveApplication()
          let kind = GetEventKind(event)
          let type = kind == UInt32(kEventHotKeyPressed) ? "down" : "up"

          delegate.methodChannel?.invokeMethod("onGlobalKeyEvent", arguments: [
            "keyCode": delegate.registeredHotKeyCode,
            "type": type,
            "isRepeat": false,
          ])
          return noErr
        },
        eventTypes.count,
        eventTypes,
        refcon,
        &hotKeyHandler
      )

      if status != noErr {
        log("[hotkey] failed to install Carbon handler: \(status)")
        return false
      }
    }

    return registerHotkey(keyCode: registeredHotKeyCode, modifiers: 0)
  }

  @discardableResult
  func registerHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
    registeredHotKeyCode = keyCode

    // Fn 键不走 Carbon：直接使用 EventTap + NSEvent 兜底
    if keyCode == UInt32(kVK_Function) {
      if let hotKeyRef = hotKeyRef {
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
      }

      let tapOK = setupEventTap()
      setupNSEventFallbackMonitors()
      if tapOK {
        log("[hotkey] fn key uses CGEventTap path")
      } else {
        log("[hotkey] fn key CGEventTap unavailable, relying on NSEvent fallback")
      }

      let monitorOK = (globalMonitor != nil || localMonitor != nil)
      return tapOK || monitorOK
    }

    if let hotKeyRef = hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }

    let hotKeyID = EventHotKeyID(signature: fourCharCode("VTYP"), id: 1)
    let status = RegisterEventHotKey(
      keyCode,
      modifiers,
      hotKeyID,
      GetEventDispatcherTarget(),
      0,
      &hotKeyRef
    )

    if status != noErr {
      log("[hotkey] failed to register Carbon hotkey: \(status)")
      // Fn 等按键无法通过 Carbon 注册时，回退到 CGEventTap
      let fallbackOK = setupEventTap()
      setupNSEventFallbackMonitors()
      if fallbackOK {
        log("[hotkey] fallback to CGEventTap for keyCode=\(keyCode)")
      } else {
        log("[hotkey] fallback to CGEventTap failed for keyCode=\(keyCode)")
      }
      let monitorOK = (globalMonitor != nil || localMonitor != nil)
      return fallbackOK || monitorOK
    }

    log("[hotkey] registered Carbon hotkey keyCode=\(keyCode) modifiers=\(modifiers)")
    return true
  }

  func unregisterHotkey() {
    if let hotKeyRef = hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }

  func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8 {
      result = (result << 8) + OSType(char)
    }
    return result
  }

  @discardableResult
  func setupEventTap() -> Bool {
    if eventTap != nil {
      return true
    }

    let mask =
      (1 << CGEventType.keyDown.rawValue) |
      (1 << CGEventType.keyUp.rawValue) |
      (1 << CGEventType.flagsChanged.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, refcon in
      guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
      }

      let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()

      if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = delegate.eventTap {
          CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
      }

      guard delegate.methodChannel != nil else {
        return Unmanaged.passUnretained(event)
      }

      // Carbon 热键可用时，不再通过 EventTap 转发，避免重复触发
      if delegate.hotKeyRef != nil {
        return Unmanaged.passUnretained(event)
      }

      delegate.captureActiveApplication()
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
      let eventType: String
      if type == .keyDown {
        eventType = "down"
      } else if type == .keyUp {
        eventType = "up"
      } else if type == .flagsChanged && UInt32(keyCode) == delegate.registeredHotKeyCode {
        let fnPressed = event.flags.contains(.maskSecondaryFn)
        delegate.log(
          "[hotkey] eventTap flagsChanged keyCode=\(keyCode) maskSecondaryFn=\(fnPressed) rawFlags=\(event.flags.rawValue)",
        )
        eventType = fnPressed ? "down" : "up"
      } else {
        return Unmanaged.passUnretained(event)
      }

      delegate.log(
        "[hotkey] eventTap dispatch keyCode=\(keyCode) type=\(eventType) repeat=\(type == .flagsChanged ? false : isRepeat)",
      )

      delegate.methodChannel?.invokeMethod("onGlobalKeyEvent", arguments: [
        "keyCode": keyCode,
        "type": eventType,
        "isRepeat": type == .flagsChanged ? false : isRepeat,
      ])

      return Unmanaged.passUnretained(event)
    }

    let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .listenOnly,
      eventsOfInterest: CGEventMask(mask),
      callback: callback,
      userInfo: refcon
    ) else {
      log("[hotkey] failed to create CGEventTap")
      return false
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    eventTap = tap
    eventTapSource = source
    return true
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
    if insertTextViaAccessibility(text) {
      log("[insert] success via accessibility")
      return
    }
    log("[insert] accessibility insert failed, fallback to paste")
    let pasteboard = NSPasteboard.general
    let previousString = pasteboard.string(forType: .string)
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    if let targetApp = lastActiveApp,
       targetApp.bundleIdentifier != Bundle.main.bundleIdentifier {
      targetApp.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      self.sendPasteShortcut()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      pasteboard.clearContents()
      if let prev = previousString {
        pasteboard.setString(prev, forType: .string)
      }
    }
  }

  func insertTextViaAccessibility(_ text: String) -> Bool {
    guard AXIsProcessTrusted() else {
      log("[insert] accessibility not trusted")
      return false
    }

    let systemWide = AXUIElementCreateSystemWide()
    var focusedElement: AnyObject?
    let focusedResult = AXUIElementCopyAttributeValue(
      systemWide,
      kAXFocusedUIElementAttribute as CFString,
      &focusedElement
    )
    if focusedResult != .success {
      log("[insert] no focused element, status=\(focusedResult.rawValue)")
      return false
    }

    guard let target = focusedElement else {
      log("[insert] focused element is nil")
      return false
    }

    let insertResult = AXUIElementSetAttributeValue(
      target as! AXUIElement,
      kAXSelectedTextAttribute as CFString,
      text as CFTypeRef
    )

    if insertResult == .success {
      return true
    }

    let valueResult = AXUIElementSetAttributeValue(
      target as! AXUIElement,
      kAXValueAttribute as CFString,
      text as CFTypeRef
    )

    if valueResult == .success {
      return true
    }

    log("[insert] AX insert failed selected=\(insertResult.rawValue) value=\(valueResult.rawValue)")
    return false
  }

  func captureActiveApplication() {
    if let frontmost = NSWorkspace.shared.frontmostApplication {
      if frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
        lastActiveApp = frontmost
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

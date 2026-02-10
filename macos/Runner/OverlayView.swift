import Cocoa

class OverlayView: NSView {
  private let backgroundView = NSVisualEffectView()
  private let dotView = NSView()
  private var barViews: [NSView] = []
  private let statusLabel = NSTextField(labelWithString: "")
  private let durationLabel = NSTextField(labelWithString: "00:00")
  private var pulseTimer: Timer?
  private var dotScale: CGFloat = 1.0
  private var lastLevel: CGFloat = 0.0
  private var waveLayer: CAShapeLayer?

  override init(frame: NSRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupViews()
  }

  private func setupViews() {
    wantsLayer = true

    // 背景毛玻璃效果
    backgroundView.frame = bounds
    backgroundView.autoresizingMask = [.width, .height]
    backgroundView.material = .hudWindow
    backgroundView.state = .active
    backgroundView.blendingMode = .behindWindow
    backgroundView.wantsLayer = true
    backgroundView.layer?.cornerRadius = bounds.height / 2
    backgroundView.layer?.masksToBounds = true
    addSubview(backgroundView)

    // 深色背景叠加
    let darkOverlay = NSView(frame: bounds)
    darkOverlay.wantsLayer = true
    darkOverlay.layer?.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.85).cgColor
    darkOverlay.layer?.cornerRadius = bounds.height / 2
    darkOverlay.layer?.masksToBounds = true
    darkOverlay.autoresizingMask = [.width, .height]
    addSubview(darkOverlay)

    // 录音红点
    let dotSize: CGFloat = 10
    dotView.frame = NSRect(x: 20, y: (bounds.height - dotSize) / 2, width: dotSize, height: dotSize)
    dotView.wantsLayer = true
    dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
    dotView.layer?.cornerRadius = dotSize / 2
    addSubview(dotView)

    // 时间标签
    durationLabel.frame = NSRect(x: 40, y: (bounds.height - 20) / 2, width: 56, height: 20)
    durationLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .medium)
    durationLabel.textColor = .white
    durationLabel.alignment = .left
    addSubview(durationLabel)

    // 音量柱状条
    let barStartX: CGFloat = 98
    let barWidth: CGFloat = 4
    let barGap: CGFloat = 3
    let barCount = 6
    for i in 0..<barCount {
      let bar = NSView(frame: NSRect(x: barStartX + CGFloat(i) * (barWidth + barGap), y: 14, width: barWidth, height: 8))
      bar.wantsLayer = true
      bar.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.8).cgColor
      bar.layer?.cornerRadius = 2
      addSubview(bar)
      barViews.append(bar)
    }

    // 状态标签
    let barEndX = barStartX + CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap
    statusLabel.frame = NSRect(x: barEndX + 12, y: (bounds.height - 18) / 2, width: 120, height: 18)
    statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
    statusLabel.textColor = NSColor.white.withAlphaComponent(0.6)
    statusLabel.alignment = .left
    addSubview(statusLabel)

    startPulse()
  }

  func update(state: String, duration: String, level: Double) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.durationLabel.stringValue = duration
      self.lastLevel = CGFloat(max(0.0, min(1.0, level)))

      if state == "starting" {
        self.statusLabel.stringValue = "麦克风启动中"
        self.dotView.layer?.backgroundColor = NSColor.systemYellow.cgColor
        self.dotView.isHidden = false
        self.durationLabel.isHidden = true
        self.barViews.forEach { $0.isHidden = true }
        self.stopWaveAnimation()
        self.stopSpinAnimation()
        self.stopPulse()
      } else if state == "recording" {
        self.statusLabel.stringValue = "录音中"
        self.dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        self.dotView.isHidden = false
        self.durationLabel.isHidden = false
        self.barViews.forEach { $0.isHidden = false }
        self.stopWaveAnimation()
        self.stopSpinAnimation()
        self.startPulse()
        self.updateBars(level: self.lastLevel)
      } else if state == "transcribing" {
        self.statusLabel.stringValue = "语音转换中"
        self.dotView.layer?.backgroundColor = NSColor(
          red: 0.42, green: 0.39, blue: 1.0, alpha: 1.0
        ).cgColor
        self.dotView.isHidden = false
        self.durationLabel.isHidden = true
        self.barViews.forEach { $0.isHidden = true }
        self.stopPulse()
        self.stopSpinAnimation()
        // 转录时显示波纹动画
        self.startWaveAnimation()
      } else if state == "enhancing" {
        self.statusLabel.stringValue = "文字整理中"
        self.dotView.layer?.backgroundColor = NSColor(
          red: 0.31, green: 0.78, blue: 0.62, alpha: 1.0
        ).cgColor
        self.dotView.isHidden = false
        self.durationLabel.isHidden = true
        self.barViews.forEach { $0.isHidden = true }
        self.stopPulse()
        self.stopSpinAnimation()
        self.startWaveAnimation()
      } else if state == "transcribe_failed" {
        self.statusLabel.stringValue = "语音转录失败"
        self.dotView.layer?.backgroundColor = NSColor.systemRed.cgColor
        self.dotView.isHidden = false
        self.durationLabel.isHidden = true
        self.barViews.forEach { $0.isHidden = true }
        self.stopWaveAnimation()
        self.stopSpinAnimation()
        self.stopPulse()
      } else {
        self.barViews.forEach { $0.isHidden = true }
        self.stopWaveAnimation()
        self.stopSpinAnimation()
        self.stopPulse()
      }
    }
  }

  private func updateBars(level: CGFloat) {
    let minHeight: CGFloat = 4
    let maxHeight: CGFloat = 18
    for (index, bar) in barViews.enumerated() {
      let phase = CGFloat(index) / CGFloat(max(barViews.count - 1, 1))
      let shaped = level * (0.6 + 0.4 * (1.0 - abs(phase - 0.5) * 2.0))
      let height = minHeight + (maxHeight - minHeight) * shaped
      var frame = bar.frame
      frame.size.height = height
      frame.origin.y = (bounds.height - height) / 2
      bar.animator().frame = frame
    }
  }

  private func startPulse() {
    stopPulse()
    pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        self.dotView.animator().alphaValue = self.dotScale > 1.0 ? 1.0 : 0.4
      }
      self.dotScale = self.dotScale > 1.0 ? 1.0 : 1.3
    }
  }

  private func stopPulse() {
    pulseTimer?.invalidate()
    pulseTimer = nil
    dotView.alphaValue = 1.0
  }

  private func startSpinAnimation() {
    guard let layer = dotView.layer else { return }
    let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
    rotation.fromValue = 0
    rotation.toValue = Double.pi * 2
    rotation.duration = 1.0
    rotation.repeatCount = .infinity
    layer.add(rotation, forKey: "spin")
  }

  private func stopSpinAnimation() {
    dotView.layer?.removeAnimation(forKey: "spin")
  }

  private func startWaveAnimation() {
    stopWaveAnimation()
    let center = CGPoint(x: dotView.frame.midX, y: dotView.frame.midY)
    let startRadius: CGFloat = 6
    let endRadius: CGFloat = 16

    let wave = CAShapeLayer()
    wave.fillColor = NSColor.clear.cgColor
    wave.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor
    wave.lineWidth = 1.5
    wave.path = CGPath(ellipseIn: CGRect(
      x: center.x - startRadius,
      y: center.y - startRadius,
      width: startRadius * 2,
      height: startRadius * 2
    ), transform: nil)

    layer?.addSublayer(wave)
    waveLayer = wave

    let scale = CABasicAnimation(keyPath: "transform.scale")
    scale.fromValue = 1.0
    scale.toValue = endRadius / startRadius
    scale.duration = 1.0

    let opacity = CABasicAnimation(keyPath: "opacity")
    opacity.fromValue = 0.8
    opacity.toValue = 0.0
    opacity.duration = 1.0

    let group = CAAnimationGroup()
    group.animations = [scale, opacity]
    group.duration = 1.0
    group.repeatCount = .infinity
    wave.add(group, forKey: "wave")
  }

  private func stopWaveAnimation() {
    waveLayer?.removeAllAnimations()
    waveLayer?.removeFromSuperlayer()
    waveLayer = nil
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.clear.setFill()
    dirtyRect.fill()
  }
}

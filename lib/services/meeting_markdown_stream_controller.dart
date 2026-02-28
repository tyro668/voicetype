import 'dart:async';

/// 将高频 chunk 流聚合为低频可渲染快照，减少 UI 抖动。
class MeetingMarkdownStreamController {
  final Duration minInterval;

  final StringBuffer _buffer = StringBuffer();
  final StreamController<String> _snapshotController =
      StreamController<String>.broadcast();

  Timer? _flushTimer;
  bool _closed = false;

  MeetingMarkdownStreamController({
    this.minInterval = const Duration(milliseconds: 80),
  });

  Stream<String> get snapshots => _snapshotController.stream;

  String get currentText => _buffer.toString();

  void addChunk(String chunk) {
    if (_closed || chunk.isEmpty) return;
    _buffer.write(chunk);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_closed) return;
    if (_flushTimer?.isActive == true) return;
    _flushTimer = Timer(minInterval, _emitSnapshot);
  }

  void _emitSnapshot() {
    if (_closed) return;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_buffer.toString());
    }
  }

  void flushNow() {
    _flushTimer?.cancel();
    _emitSnapshot();
  }

  void complete() {
    if (_closed) return;
    flushNow();
    _closed = true;
    _snapshotController.close();
  }

  void dispose() {
    if (_closed) return;
    _flushTimer?.cancel();
    _closed = true;
    _snapshotController.close();
  }
}

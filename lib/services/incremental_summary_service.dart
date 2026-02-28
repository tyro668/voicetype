import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import '../models/ai_enhance_config.dart';
import '../models/merged_note.dart';
import 'ai_enhance_service.dart';
import 'log_service.dart';
import 'token_stats_service.dart';

/// 增量摘要服务 — 在会议录制过程中递进式维护一份"运行中摘要"。
///
/// 每隔 [_updateInterval] 次合并纪要更新时触发一次 LLM 调用，
/// 将"当前摘要 + 最新全文"发给 LLM 产出更新后的摘要。
class IncrementalSummaryService {
  final AiEnhanceConfig _aiConfig;
  final String _dictionarySuffix;

  /// 当前运行中摘要
  String _currentSummary = '';
  String get currentSummary => _currentSummary;

  /// 是否正在更新摘要
  bool _isUpdating = false;
  bool get isUpdating => _isUpdating;

  /// 触发频率控制：每 N 次合并触发一次增量更新
  int _mergeCountSinceLastUpdate = 0;
  static const int _updateInterval = 3;

  /// 当更新进行中时，缓存最新一次待处理全文，确保不会丢更新。
  String? _pendingFullText;

  /// Prompt 缓存
  String? _summaryPromptCache;
  String? _incrementalPromptCache;

  /// 摘要更新事件流
  final StreamController<String> _onSummaryUpdated =
      StreamController<String>.broadcast();
  Stream<String> get onSummaryUpdated => _onSummaryUpdated.stream;

  /// 摘要流式分块事件
  final StreamController<String> _onSummaryChunk =
      StreamController<String>.broadcast();
  Stream<String> get onSummaryChunk => _onSummaryChunk.stream;

  /// 摘要更新开始事件（用于通知 UI 清空上一轮流式缓冲）
  final StreamController<void> _onSummaryUpdateStarted =
      StreamController<void>.broadcast();
  Stream<void> get onSummaryUpdateStarted => _onSummaryUpdateStarted.stream;

  IncrementalSummaryService({
    required AiEnhanceConfig aiConfig,
    String dictionarySuffix = '',
  }) : _aiConfig = aiConfig,
       _dictionarySuffix = dictionarySuffix;

  /// 当合并纪要有新产出时调用。
  /// [note] 本次合并产出的 MergedNote，[fullMergedText] 合并器的 currentFullText。
  Future<void> onMergeCompleted(MergedNote note, String fullMergedText) async {
    if (fullMergedText.trim().isEmpty) return;

    var shouldUpdate = false;
    if (_currentSummary.isEmpty) {
      // 首次摘要不做频率限制，确保录制中尽快产出可见结果。
      shouldUpdate = true;
    } else {
      _mergeCountSinceLastUpdate++;
      shouldUpdate = _mergeCountSinceLastUpdate >= _updateInterval;
    }

    if (!shouldUpdate) return;
    _mergeCountSinceLastUpdate = 0;

    if (_isUpdating) {
      _pendingFullText = fullMergedText;
      return;
    }

    await _runUpdate(fullMergedText);
  }

  /// 会议结束时做最终更新：将尾部新增内容整合到摘要中。
  /// 如果当前无摘要，则做全量生成。
  Future<String> finalUpdate(String fullText) async {
    if (fullText.trim().isEmpty) return _currentSummary;

    if (_isUpdating) {
      _pendingFullText = fullText;
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 300));
        return _isUpdating;
      });
      return _currentSummary;
    }

    await _runUpdate(fullText);
    return _currentSummary;
  }

  Future<void> _runUpdate(String fullText) async {
    _isUpdating = true;
    try {
      if (!_onSummaryUpdateStarted.isClosed) {
        _onSummaryUpdateStarted.add(null);
      }
      final clippedText = _clipForSummary(fullText);
      if (_currentSummary.isEmpty) {
        _currentSummary = await _generateFreshSummary(clippedText);
      } else {
        _currentSummary = await _updateSummary(_currentSummary, clippedText);
      }
      if (_currentSummary.trim().isNotEmpty) {
        _onSummaryUpdated.add(_currentSummary);
      }
    } catch (e) {
      await LogService.error(
        'INCREMENTAL_SUMMARY',
        'update summary failed: $e',
      );
    } finally {
      _isUpdating = false;
    }

    final pending = _pendingFullText;
    _pendingFullText = null;
    if (pending != null && pending.trim().isNotEmpty && pending != fullText) {
      await _runUpdate(pending);
    }
  }

  String _clipForSummary(String text) {
    const maxChars = 12000;
    if (text.length <= maxChars) return text;
    return text.substring(text.length - maxChars);
  }

  /// 首次生成摘要 — 使用标准 meeting_summary_prompt
  Future<String> _generateFreshSummary(String content) async {
    if (content.trim().isEmpty) return '';

    await LogService.info(
      'INCREMENTAL_SUMMARY',
      'generating fresh summary, content length=${content.length}',
    );

    final summaryPrompt = await _loadSummaryPrompt();

    final config = _aiConfig.copyWith(
      prompt: summaryPrompt + _dictionarySuffix,
    );
    final summary = await _streamSummaryResult(
      config,
      content,
      timeout: const Duration(seconds: 60),
    );

    await LogService.info(
      'INCREMENTAL_SUMMARY',
      'fresh summary generated, length=${summary.length}',
    );
    return summary;
  }

  /// 增量更新摘要 — 传入当前摘要 + 最新全文
  Future<String> _updateSummary(
    String currentSummary,
    String latestFullText,
  ) async {
    if (latestFullText.trim().isEmpty) return currentSummary;

    await LogService.info(
      'INCREMENTAL_SUMMARY',
      'updating summary, current=${currentSummary.length}, new content=${latestFullText.length}',
    );

    final template = await _loadIncrementalSummaryPrompt();
    final incrementalPrompt = template
        .replaceAll('{current_summary}', currentSummary)
        .replaceAll('{new_content}', latestFullText);

    // 增量模式：将 incrementalPrompt 作为 system prompt，
    // user message 仅触发执行
    final config = _aiConfig.copyWith(
      prompt: incrementalPrompt + _dictionarySuffix,
    );

    final summary = await _streamSummaryResult(
      config,
      '请根据上述信息更新会议摘要。',
      timeout: const Duration(seconds: 60),
    );

    await LogService.info(
      'INCREMENTAL_SUMMARY',
      'summary updated, length=${summary.length}',
    );

    return summary.isNotEmpty ? summary : currentSummary;
  }

  Future<String> _streamSummaryResult(
    AiEnhanceConfig config,
    String input, {
    required Duration timeout,
  }) async {
    final enhancer = AiEnhanceService(config);
    final buffer = StringBuffer();
    try {
      await for (final chunk in enhancer.enhanceStream(
        input,
        timeout: timeout,
      )) {
        if (chunk.isEmpty) continue;
        buffer.write(chunk);
        if (!_onSummaryChunk.isClosed) {
          _onSummaryChunk.add(chunk);
        }
      }
    } catch (e) {
      await LogService.error(
        'INCREMENTAL_SUMMARY',
        'enhanceStream failed, falling back to enhance(): $e',
      );
      final fallback = await enhancer.enhance(input, timeout: timeout);
      if (fallback.text.trim().isNotEmpty) {
        buffer.write(fallback.text.trim());
        if (!_onSummaryChunk.isClosed) {
          _onSummaryChunk.add(fallback.text.trim());
        }
      }
      if (fallback.promptTokens > 0 || fallback.completionTokens > 0) {
        await TokenStatsService.instance.addMeetingTokens(
          promptTokens: fallback.promptTokens,
          completionTokens: fallback.completionTokens,
        );
      }
    }

    return buffer.toString().trim();
  }

  /// 重置状态
  void reset() {
    _currentSummary = '';
    _mergeCountSinceLastUpdate = 0;
    _isUpdating = false;
    _pendingFullText = null;
  }

  Future<String> _loadSummaryPrompt() async {
    if (_summaryPromptCache != null) return _summaryPromptCache!;
    try {
      _summaryPromptCache = await rootBundle.loadString(
        'assets/prompts/meeting_summary_prompt.md',
      );
    } catch (_) {
      _summaryPromptCache =
          '你是会议记录助手。请根据以下会议记录生成简洁的会议摘要。\n\n'
          '## 输出格式\n'
          '1. **会议主题**：一句话概括\n'
          '2. **关键讨论点**：要点列表\n'
          '3. **决议/行动项**：如有，列出具体责任人和时间节点\n'
          '4. **待跟进事项**：如有\n\n'
          '## 要求\n'
          '- 用简洁的中文输出\n'
          '- 只提取关键信息，不重复原文\n'
          '- 忽略寒暄和无关内容\n';
    }
    return _summaryPromptCache!;
  }

  Future<String> _loadIncrementalSummaryPrompt() async {
    if (_incrementalPromptCache != null) return _incrementalPromptCache!;
    try {
      _incrementalPromptCache = await rootBundle.loadString(
        'assets/prompts/meeting_incremental_summary_prompt.md',
      );
    } catch (_) {
      _incrementalPromptCache =
          '你是会议记录助手。请根据当前的会议摘要和新增内容，更新会议摘要。\n\n'
          '## 当前摘要\n{current_summary}\n\n'
          '## 新增会议内容\n{new_content}\n\n'
          '## 输出格式\n'
          '1. **会议主题**：一句话概括（如主题有变化则更新）\n'
          '2. **关键讨论点**：整合新旧要点列表\n'
          '3. **决议/行动项**：如有，列出具体责任人和时间节点\n'
          '4. **待跟进事项**：如有\n\n'
          '## 要求\n'
          '- 整合新旧内容，而非简单追加\n'
          '- 删除已被后续讨论推翻的旧结论\n'
          '- 保持简洁，只提取关键信息\n'
          '- 忽略寒暄和无关内容\n';
    }
    return _incrementalPromptCache!;
  }

  /// 释放资源
  void dispose() {
    _onSummaryUpdated.close();
    _onSummaryChunk.close();
    _onSummaryUpdateStarted.close();
  }
}

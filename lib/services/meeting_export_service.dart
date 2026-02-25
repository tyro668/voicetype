import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/meeting.dart';

/// 会议记录导出服务
class MeetingExportService {
  /// 导出为纯文本
  static String exportAsText(MeetingRecord meeting, List<MeetingSegment> segments) {
    final sb = StringBuffer();
    sb.writeln('会议记录: ${meeting.title}');
    sb.writeln('日期: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.createdAt)}');
    sb.writeln('时长: ${meeting.formattedDuration}');
    sb.writeln('=' * 50);

    if (meeting.summary != null && meeting.summary!.isNotEmpty) {
      sb.writeln();
      sb.writeln('📋 会议摘要:');
      sb.writeln(meeting.summary);
      sb.writeln();
      sb.writeln('─' * 50);
    }

    for (final seg in segments) {
      final text = seg.displayText;
      if (text == null || text.isEmpty) continue;
      sb.writeln();
      sb.writeln('[${seg.formattedTimestamp}] 分段 ${seg.segmentIndex + 1}');
      sb.writeln(text);
    }

    return sb.toString();
  }

  /// 导出为 Markdown
  static String exportAsMarkdown(MeetingRecord meeting, List<MeetingSegment> segments) {
    final sb = StringBuffer();
    sb.writeln('# ${meeting.title}');
    sb.writeln();
    sb.writeln('- **日期**: ${DateFormat('yyyy-MM-dd HH:mm').format(meeting.createdAt)}');
    sb.writeln('- **时长**: ${meeting.formattedDuration}');
    sb.writeln();

    if (meeting.summary != null && meeting.summary!.isNotEmpty) {
      sb.writeln('## 会议摘要');
      sb.writeln();
      sb.writeln(meeting.summary);
      sb.writeln();
    }

    sb.writeln('## 会议内容');
    sb.writeln();

    for (final seg in segments) {
      final text = seg.displayText;
      if (text == null || text.isEmpty) continue;
      sb.writeln('### [${seg.formattedTimestamp}] 分段 ${seg.segmentIndex + 1}');
      sb.writeln();
      sb.writeln(text);
      sb.writeln();
    }

    return sb.toString();
  }

  /// 获取全部转写文本（拼接所有分段）
  static String getFullText(List<MeetingSegment> segments) {
    final texts = <String>[];
    for (final seg in segments) {
      final text = seg.displayText;
      if (text != null && text.isNotEmpty) {
        texts.add(text);
      }
    }
    return texts.join('\n\n');
  }

  /// 复制到剪贴板
  static Future<void> copyToClipboard(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
  }
}

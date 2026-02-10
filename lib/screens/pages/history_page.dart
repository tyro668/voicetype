import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/recording_provider.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final recording = context.watch<RecordingProvider>();
    final history = recording.history;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 24, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Text(
                '历史记录',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (history.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.grey.shade400),
                  tooltip: '清空全部',
                  onPressed: () => _confirmClearAll(context, recording),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // 列表
          Expanded(
            child: history.isEmpty
                ? _buildEmpty()
                : _buildList(context, recording, history),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '暂无历史记录',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            '使用快捷键开始录音，转录结果将显示在这里',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, RecordingProvider recording,
      List history) {
    return ListView.builder(
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        final number = history.length - index;
        final dateStr = DateFormat('M月d日 HH:mm').format(item.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：编号 + 时间 + 操作按钮
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#$number',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  // 复制按钮
                  _ActionIcon(
                    icon: Icons.copy_outlined,
                    tooltip: '复制',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已复制到剪贴板'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  // 删除按钮
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    tooltip: '删除',
                    color: Colors.red.shade300,
                    onTap: () => recording.removeHistory(index),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 文本内容
              SelectableText(
                item.text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearAll(
      BuildContext context, RecordingProvider recording) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要删除所有历史记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              recording.clearAllHistory();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color ?? Colors.grey.shade400),
        ),
      ),
    );
  }
}

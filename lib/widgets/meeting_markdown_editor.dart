import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'meeting_markdown_view.dart';

class MeetingMarkdownEditor extends StatefulWidget {
  final TextEditingController controller;
  final String emptyHint;
  final bool enableDictionaryMenu;
  final Future<void> Function(String selectedText)? onAddToDictionary;
  final ScrollController? scrollController;
  final MeetingMarkdownDensity density;

  const MeetingMarkdownEditor({
    super.key,
    required this.controller,
    required this.emptyHint,
    this.enableDictionaryMenu = true,
    this.onAddToDictionary,
    this.scrollController,
    this.density = MeetingMarkdownDensity.compact,
  });

  @override
  State<MeetingMarkdownEditor> createState() => _MeetingMarkdownEditorState();
}

class _MeetingMarkdownEditorState extends State<MeetingMarkdownEditor> {
  bool _previewMode = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 工具栏
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 标题
                      _buildTextButton(
                        label: 'H1',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        onTap: () => _insertLinePrefix('# '),
                      ),
                      _buildTextButton(
                        label: 'H2',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        onTap: () => _insertLinePrefix('## '),
                      ),
                      _buildTextButton(
                        label: 'H3',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        onTap: () => _insertLinePrefix('### '),
                      ),
                      _buildDivider(cs),
                      // 行内格式
                      _buildInsertButton(
                        icon: Icons.format_bold,
                        tooltip: l10n.edit,
                        onTap: () => _wrapSelection('**'),
                      ),
                      _buildInsertButton(
                        icon: Icons.format_italic,
                        tooltip: l10n.edit,
                        onTap: () => _wrapSelection('*'),
                      ),
                      _buildInsertButton(
                        icon: Icons.format_strikethrough,
                        tooltip: l10n.edit,
                        onTap: () => _wrapSelection('~~'),
                      ),
                      _buildInsertButton(
                        icon: Icons.code,
                        tooltip: l10n.edit,
                        onTap: () => _wrapSelection('`'),
                      ),
                      _buildDivider(cs),
                      // 列表
                      _buildInsertButton(
                        icon: Icons.format_list_bulleted,
                        tooltip: l10n.edit,
                        onTap: () => _insertLinePrefix('- '),
                      ),
                      _buildInsertButton(
                        icon: Icons.format_list_numbered,
                        tooltip: l10n.edit,
                        onTap: () => _insertLinePrefix('1. '),
                      ),
                      _buildInsertButton(
                        icon: Icons.checklist,
                        tooltip: l10n.edit,
                        onTap: () => _insertLinePrefix('- [ ] '),
                      ),
                      _buildDivider(cs),
                      // 块级元素
                      _buildInsertButton(
                        icon: Icons.format_quote,
                        tooltip: l10n.edit,
                        onTap: () => _insertLinePrefix('> '),
                      ),
                      _buildInsertButton(
                        icon: Icons.horizontal_rule,
                        tooltip: l10n.edit,
                        onTap: () => _insertBlock('\n---\n'),
                      ),
                      _buildInsertButton(
                        icon: Icons.data_object,
                        tooltip: l10n.edit,
                        onTap: () => _insertCodeBlock(),
                      ),
                      _buildInsertButton(
                        icon: Icons.link,
                        tooltip: l10n.edit,
                        onTap: () => _insertLink(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
                segments: [
                  ButtonSegment<bool>(value: false, label: Text(l10n.edit)),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(l10n.promptPreview),
                  ),
                ],
                selected: {_previewMode},
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  setState(() => _previewMode = value.first);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _previewMode
              ? SingleChildScrollView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(14),
                  child: MeetingMarkdownView(
                    markdown: widget.controller.text,
                    emptyHint: widget.emptyHint,
                    density: widget.density,
                  ),
                )
              : TextField(
                  controller: widget.controller,
                  scrollController: widget.scrollController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                    height: 1.8,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.emptyHint,
                    hintStyle: TextStyle(color: cs.outline),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  contextMenuBuilder: widget.enableDictionaryMenu
                      ? (context, editableTextState) {
                          final selectedText = _getSelectedText();
                          final builtinItems =
                              editableTextState.contextMenuButtonItems;
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: [
                              ...builtinItems,
                              if (selectedText.isNotEmpty &&
                                  widget.onAddToDictionary != null)
                                ContextMenuButtonItem(
                                  label: l10n.addToDictionary,
                                  onPressed: () {
                                    ContextMenuController.removeAny();
                                    widget.onAddToDictionary!(selectedText);
                                  },
                                ),
                            ],
                          );
                        }
                      : null,
                ),
        ),
      ],
    );
  }

  // ──────────────── Toolbar helpers ────────────────

  Widget _buildInsertButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    double iconSize = 14,
  }) {
    return SizedBox(
      height: 28,
      width: 28,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: iconSize),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildTextButton({
    required String label,
    required VoidCallback onTap,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 28,
      width: 28,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: cs.onSurfaceVariant,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        height: 16,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ──────────────── Edit actions ────────────────

  /// 在当前行首插入前缀（如 `# `, `- `, `> `）
  void _insertLinePrefix(String prefix) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;
    final safeCursor = cursor.clamp(0, text.length);

    // 找到当前行起始位置
    final lineStart = text.lastIndexOf(
      '\n',
      safeCursor > 0 ? safeCursor - 1 : 0,
    );
    final insertPos = lineStart == -1 ? 0 : lineStart + 1;

    final newText = text.replaceRange(insertPos, insertPos, prefix);
    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: safeCursor + prefix.length),
      composing: TextRange.empty,
    );
  }

  /// 用标记包裹选中文字（如 `**`, `*`, `` ` ``, `~~`）
  void _wrapSelection(String marker) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid) return;

    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);

    if (start == end) {
      // 无选中：插入占位
      final snippet = '$marker$marker';
      final newText = text.replaceRange(start, end, snippet);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + marker.length),
        composing: TextRange.empty,
      );
    } else {
      // 有选中：包裹
      final selected = text.substring(start, end);
      final wrapped = '$marker$selected$marker';
      final newText = text.replaceRange(start, end, wrapped);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: start + marker.length,
          extentOffset: end + marker.length,
        ),
        composing: TextRange.empty,
      );
    }
  }

  /// 在光标处插入一段独立文本块（前后确保空行）
  void _insertBlock(String block) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;
    final safeCursor = cursor.clamp(0, text.length);

    final newText = text.replaceRange(safeCursor, safeCursor, block);
    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: safeCursor + block.length),
      composing: TextRange.empty,
    );
  }

  /// 插入代码块
  void _insertCodeBlock() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start = (selection.isValid ? selection.start : text.length).clamp(
      0,
      text.length,
    );
    final end = (selection.isValid ? selection.end : text.length).clamp(
      0,
      text.length,
    );

    if (start == end) {
      const block = '\n```\n\n```\n';
      final newText = text.replaceRange(start, end, block);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 4), // 光标在 ``` 后
        composing: TextRange.empty,
      );
    } else {
      final selected = text.substring(start, end);
      final block = '\n```\n$selected\n```\n';
      final newText = text.replaceRange(start, end, block);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + block.length),
        composing: TextRange.empty,
      );
    }
  }

  /// 插入链接
  void _insertLink() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final start = (selection.isValid ? selection.start : text.length).clamp(
      0,
      text.length,
    );
    final end = (selection.isValid ? selection.end : text.length).clamp(
      0,
      text.length,
    );

    if (start == end) {
      const snippet = '[](url)';
      final newText = text.replaceRange(start, end, snippet);
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 1), // 光标在 [ 后
        composing: TextRange.empty,
      );
    } else {
      final selected = text.substring(start, end);
      final snippet = '[$selected](url)';
      final newText = text.replaceRange(start, end, snippet);
      // 选中 url 部分方便替换
      final urlStart = start + selected.length + 3;
      widget.controller.value = widget.controller.value.copyWith(
        text: newText,
        selection: TextSelection(
          baseOffset: urlStart,
          extentOffset: urlStart + 3,
        ),
        composing: TextRange.empty,
      );
    }
  }

  String _getSelectedText() {
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.isCollapsed) return '';
    final text = widget.controller.text;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (start >= end) return '';
    return text.substring(start, end).trim();
  }
}

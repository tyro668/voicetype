import 'package:flutter/material.dart';
import 'package:flutter_smooth_markdown/flutter_smooth_markdown.dart';

import '../l10n/app_localizations.dart';

enum MeetingMarkdownDensity { compact, regular }

class MeetingMarkdownView extends StatefulWidget {
  final String markdown;
  final String? emptyHint;
  final bool selectable;
  final EdgeInsetsGeometry padding;
  final MeetingMarkdownDensity density;
  final Stream<String>? stream;
  final Widget? loadingWidget;

  /// 右键菜单「加入词典」回调。提供后，选中文字右键会出现该选项。
  final Future<void> Function(String selectedText)? onAddToDictionary;

  const MeetingMarkdownView({
    super.key,
    required this.markdown,
    this.emptyHint,
    this.selectable = true,
    this.padding = EdgeInsets.zero,
    this.density = MeetingMarkdownDensity.regular,
    this.stream,
    this.loadingWidget,
    this.onAddToDictionary,
  });

  @override
  State<MeetingMarkdownView> createState() => _MeetingMarkdownViewState();
}

class _MeetingMarkdownViewState extends State<MeetingMarkdownView> {
  String _selectedText = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textSize = widget.density == MeetingMarkdownDensity.compact
        ? 13.0
        : 14.0;

    if (widget.stream == null && widget.markdown.trim().isEmpty) {
      return Padding(
        padding: widget.padding,
        child: Text(
          widget.emptyHint ?? '',
          style: TextStyle(color: cs.outline, fontSize: textSize),
        ),
      );
    }

    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      paragraphStyle: TextStyle(
        fontSize: textSize,
        color: cs.onSurface,
        height: 1.7,
      ),
      h1Style: TextStyle(
        fontSize: textSize + 7,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      h2Style: TextStyle(
        fontSize: textSize + 5,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      h3Style: TextStyle(
        fontSize: textSize + 3,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      listBulletStyle: TextStyle(fontSize: textSize, color: cs.onSurface),
      blockquoteStyle: TextStyle(
        fontSize: textSize,
        color: cs.onSurfaceVariant,
      ),
      blockquoteDecoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: cs.outlineVariant)),
      ),
      codeBlockStyle: TextStyle(
        fontSize: textSize - 1,
        color: cs.onSurface,
        fontFamily: 'monospace',
      ),
      inlineCodeStyle: TextStyle(
        fontSize: textSize - 1,
        color: cs.onSurface,
        fontFamily: 'monospace',
      ),
      codeBlockDecoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    final hasDictMenu =
        widget.onAddToDictionary != null &&
        widget.selectable &&
        widget.stream == null;

    if (hasDictMenu) {
      final rendered = _renderMarkdownWidget(widget.markdown, styleSheet);
      return Padding(
        padding: widget.padding,
        child: _wrapWithDictionaryMenu(rendered),
      );
    }

    final child = widget.stream != null
        ? StreamMarkdown(
            stream: widget.stream!,
            selectable: widget.selectable,
            styleSheet: styleSheet,
            loadingWidget: widget.loadingWidget,
          )
        : SmoothMarkdown(
            data: widget.markdown,
            selectable: widget.selectable,
            styleSheet: styleSheet,
          );

    return Padding(padding: widget.padding, child: child);
  }

  Widget _renderMarkdownWidget(String data, MarkdownStyleSheet styleSheet) {
    final parser = MarkdownParser();
    final nodes = parser.parse(data);
    final renderer = MarkdownRenderer(styleSheet: styleSheet);
    final renderContext = MarkdownRenderContext(selectable: true);
    return renderer.render(nodes, context: renderContext);
  }

  Widget _wrapWithDictionaryMenu(Widget child) {
    final l10n = AppLocalizations.of(context)!;
    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedText = content?.plainText ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final builtinItems = selectableRegionState.contextMenuButtonItems;
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: [
            ...builtinItems,
            if (_selectedText.isNotEmpty)
              ContextMenuButtonItem(
                label: l10n.addToDictionary,
                onPressed: () {
                  ContextMenuController.removeAny();
                  widget.onAddToDictionary!(_selectedText);
                },
              ),
          ],
        );
      },
      child: child,
    );
  }
}

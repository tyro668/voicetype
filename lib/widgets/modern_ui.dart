import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ModernPageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const ModernPageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(cs.primary.withValues(alpha: 0.08), cs.surface),
            Color.alphaBlend(
              cs.primary.withValues(alpha: 0.03),
              cs.surfaceContainerLow,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.18),
                  cs.primary.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
            ),
            child: Icon(icon, color: cs.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

class ModernSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry margin;

  const ModernSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.backgroundColor,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            Color.alphaBlend(
              cs.primary.withValues(alpha: 0.022),
              cs.surface.withValues(alpha: 0.96),
            ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ModernSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  const ModernSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconSize = compact ? 16.0 : 18.0;
    final titleSize = compact ? 15.0 : 17.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, size: iconSize, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13,
                    height: 1.45,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class ModernSearchInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const ModernSearchInput({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ShadInput(
      controller: controller,
      onChanged: onChanged,
      placeholder: Text(hintText),
      leading: Icon(Icons.search, size: 18, color: cs.onSurfaceVariant),
      trailing: controller.text.isEmpty
          ? null
          : GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
            ),
    );
  }
}

class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const ModernEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ModernSurfaceCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          backgroundColor: Color.alphaBlend(
            cs.primary.withValues(alpha: 0.04),
            cs.surfaceContainerLow.withValues(alpha: 0.9),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.82),
                      cs.surfaceContainerHighest,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, color: cs.primary, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

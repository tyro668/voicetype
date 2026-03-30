import 'package:flutter/material.dart';
import '../../widgets/modern_ui.dart';
import 'prompt_workshop_page.dart';

/// Container page for "智能增强" (AI Enhancement).
/// 词典已迁移到主导航的独立页面。
class AiEnhanceHubPage extends StatelessWidget {
  const AiEnhanceHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: ModernSurfaceCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ModernSectionHeader(
                    icon: Icons.tips_and_updates_outlined,
                    title: '增强工作台',
                    subtitle: '在同一处管理提示词模板、预览结果并调试增强输出。',
                    compact: true,
                  ),
                  SizedBox(height: 14),
                  Expanded(child: PromptWorkshopPage()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

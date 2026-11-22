import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/ui/legal/legal_documents.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Màn hình đọc Điều khoản sử dụng / Chính sách quyền riêng tư.
///
/// Không phải hộp thoại "bấm đồng ý cho xong": nội dung đọc được đầy đủ, có
/// ngày cập nhật và số phiên bản để người dùng đối chiếu về sau.
class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    this.initialTab = LegalTab.terms,
    this.showAcceptAction = false,
  });

  final LegalTab initialTab;
  final bool showAcceptAction;

  static Future<bool?> open(
    BuildContext context, {
    LegalTab tab = LegalTab.terms,
    bool showAcceptAction = false,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LegalScreen(
          initialTab: tab,
          showAcceptAction: showAcceptAction,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == LegalTab.terms ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.readLegal),
          bottom: const TabBar(
            tabs: [
              Tab(text: AppStrings.legalTabTerms),
              Tab(text: AppStrings.legalTabPrivacy),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LegalBody(document: LegalDocs.terms),
            _LegalBody(document: LegalDocs.privacy),
          ],
        ),
        bottomNavigationBar: showAcceptAction
            ? SafeArea(
                minimum: const EdgeInsets.all(AppSpace.lg),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Tôi đã đọc và đồng ý'),
                ),
              )
            : null,
      ),
    );
  }
}

enum LegalTab { terms, privacy }

class _LegalBody extends StatelessWidget {
  const _LegalBody({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.lg,
        AppSpace.xxl,
      ),
      children: [
        Text(document.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            const Icon(
              LucideIcons.calendarClock,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              '${AppStrings.legalUpdatedAt} · v${LegalDocs.version}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            document.summary,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        for (final section in document.sections) ...[
          Text(
            section.heading,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          for (final paragraph in section.paragraphs) ...[
            Text(
              paragraph,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
          const SizedBox(height: AppSpace.lg),
        ],
      ],
    );
  }
}

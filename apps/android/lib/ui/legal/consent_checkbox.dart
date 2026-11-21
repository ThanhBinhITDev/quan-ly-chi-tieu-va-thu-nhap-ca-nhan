import 'package:material_ui/material_ui.dart';

import 'package:android/core/session/consent_store.dart';
import 'package:android/ui/legal/legal_documents.dart';
import 'package:android/ui/legal/legal_screen.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ô xác nhận đã đọc điều khoản + hai liên kết mở văn bản đầy đủ.
///
/// Ba yêu cầu về mặt pháp lý, và cách đáp ứng:
///   1. **Không đánh dấu sẵn** — người dùng phải chủ động tích. Đồng ý mặc
///      định không phải là đồng ý (Nghị định 13/2023/NĐ-CP).
///   2. **Đọc được trước khi đồng ý** — mỗi điều khoản mở được toàn văn, không
///      phải "bấm đồng ý rồi mới xem".
///   3. **Biết mình đồng ý phiên bản nào** — số phiên bản hiện ngay cạnh liên
///      kết, và được lưu lại kèm thời điểm đồng ý.
class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: enabled ? () => onChanged(!value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: value,
                      onChanged:
                          enabled ? (next) => onChanged(next ?? false) : null,
                      side: BorderSide(
                        color: hasError ? AppColors.expense : AppColors.divider,
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${AppStrings.consentPrefix} ',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            _LegalLink(
                              label: AppStrings.termsOfUse,
                              tab: LegalTab.terms,
                            ),
                            Text(
                              ' ${AppStrings.consentAnd} ',
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            _LegalLink(
                              label: AppStrings.privacyPolicy,
                              tab: LegalTab.privacy,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v${LegalDocs.version} · ${LegalDocs.updatedAt}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.expense,
              ),
            ),
          ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.tab});

  final String label;
  final LegalTab tab;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => LegalScreen.open(context, tab: tab),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Ghi nhận sự đồng ý của người dùng kèm phiên bản điều khoản.
Future<void> recordConsent(WidgetRef ref, {String? version}) async {
  await ref
      .read(consentStoreProvider)
      .accept(version ?? LegalDocs.version);
  ref.invalidate(acceptedConsentProvider);
}

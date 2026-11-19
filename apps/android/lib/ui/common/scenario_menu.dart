import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/domain/models.dart';
import 'package:android/providers.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Chọn kịch bản dữ liệu (mẫu / trống / lỗi / offline) để thử giao diện.
///
/// Hiển thị dạng icon gọn trong AppBar để không chiếm chỗ trên máy nhỏ.
class ScenarioMenu extends ConsumerWidget {
  const ScenarioMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Chỉ có ý nghĩa khi đang xem dữ liệu mẫu; chế độ mạng thì ẩn đi.
    if (!ref.watch(demoModeProvider)) return const SizedBox.shrink();
    final current = ref.watch(scenarioProvider);
    return PopupMenuButton<DemoScenario>(
      tooltip: AppStrings.scenarioLabel,
      initialValue: current,
      onSelected: (scenario) {
        ref.read(scenarioProvider.notifier).select(scenario);
      },
      position: PopupMenuPosition.under,
      itemBuilder: (context) => <PopupMenuEntry<DemoScenario>>[
        PopupMenuItem(
          value: DemoScenario.ready,
          child: _ScenarioRow(
            label: AppStrings.scenarioReady,
            selected: current == DemoScenario.ready,
          ),
        ),
        PopupMenuItem(
          value: DemoScenario.empty,
          child: _ScenarioRow(
            label: AppStrings.scenarioEmpty,
            selected: current == DemoScenario.empty,
          ),
        ),
        PopupMenuItem(
          value: DemoScenario.error,
          child: _ScenarioRow(
            label: AppStrings.scenarioError,
            selected: current == DemoScenario.error,
          ),
        ),
        PopupMenuItem(
          value: DemoScenario.offline,
          child: _ScenarioRow(
            label: AppStrings.scenarioOffline,
            selected: current == DemoScenario.offline,
          ),
        ),
      ],
      child: Semantics(
        button: true,
        label: '${AppStrings.scenarioLabel}: ${_label(current)}',
        child: Container(
          margin: const EdgeInsets.only(right: AppSpace.md),
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.neutralSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            current == DemoScenario.offline
                ? LucideIcons.cloudOff
                : LucideIcons.slidersHorizontal,
            size: 18,
            color: current == DemoScenario.offline
                ? AppColors.warning
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _label(DemoScenario scenario) {
    switch (scenario) {
      case DemoScenario.ready:
        return AppStrings.scenarioReady;
      case DemoScenario.empty:
        return AppStrings.scenarioEmpty;
      case DemoScenario.error:
        return AppStrings.scenarioError;
      case DemoScenario.offline:
        return AppStrings.scenarioOffline;
    }
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
        if (selected)
          const Icon(LucideIcons.check, size: 16, color: AppColors.primary),
      ],
    );
  }
}

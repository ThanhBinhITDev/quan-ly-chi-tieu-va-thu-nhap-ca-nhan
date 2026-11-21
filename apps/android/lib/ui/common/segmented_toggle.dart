import 'package:material_ui/material_ui.dart';

import 'package:android/ui/theme.dart';

/// Nút chuyển hai chế độ dạng viên thuốc, đặt trong AppBar.
///
/// Không dùng `SegmentedButton` của M3: nó có chiều cao tối thiểu 40px và
/// padding ngang lớn, nhét hai nhãn tiếng Việt vào AppBar là tràn tiêu đề.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  }) : assert(segments.length == 2, 'Chỉ hỗ trợ hai chế độ');

  /// 0 hoặc 1 — chỉ số của đoạn đang chọn.
  final int value;
  final List<String> segments;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < segments.length; index++)
            Semantics(
              button: true,
              selected: value == index,
              child: GestureDetector(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: value == index
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: value == index
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    segments[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          value == index ? FontWeight.w700 : FontWeight.w500,
                      color: value == index
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

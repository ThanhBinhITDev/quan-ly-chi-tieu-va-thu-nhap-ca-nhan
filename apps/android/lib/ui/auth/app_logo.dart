import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/ui/theme.dart';

/// Logo app. Ảnh là icon 1024×1024 trong `assets/brand/`; nếu asset hỏng thì
/// hiện biểu tượng ví để màn hình không bị trống.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.09),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.asset(
          'assets/brand/app-icon-round.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: AppColors.primarySoft,
            child: Icon(
              LucideIcons.wallet,
              size: size * 0.5,
              color: AppColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

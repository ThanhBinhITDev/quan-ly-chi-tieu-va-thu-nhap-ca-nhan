import 'package:material_ui/material_ui.dart';

/// Bảng màu Student Finance (lấy từ logo, thêm các tông trung tính hiện đại).
class AppColors {
  static const primary = Color(0xFF2D7C3D);
  static const primaryDark = Color(0xFF1F5E2C);
  static const primarySoft = Color(0xFFDDEFE0);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF3F6F3);
  static const textPrimary = Color(0xFF121A15);
  static const textSecondary = Color(0xFF66736B);
  static const divider = Color(0xFFE5EBE6);
  static const expense = Color(0xFFD13B3B);
  static const expenseSoft = Color(0xFFFCE8E8);
  static const income = Color(0xFF2D7C3D);
  static const incomeSoft = Color(0xFFE2F2E5);
  static const warning = Color(0xFF9E5B0A);
  static const warningSoft = Color(0xFFFFF0D6);
  static const neutralSoft = Color(0xFFEBF0EC);

  /// Bảng màu cho biểu đồ cơ cấu chi tiêu.
  static const chartPalette = <Color>[
    Color(0xFF2D7C3D),
    Color(0xFF5FA86B),
    Color(0xFFB46A12),
    Color(0xFF3B6FB6),
    Color(0xFFC63939),
    Color(0xFF8A6BB8),
  ];
}

class AppRadius {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 28;
  static const double pill = 999;
}

class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryDark,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    error: AppColors.expense,
    onError: Colors.white,
    outline: AppColors.divider,
    outlineVariant: AppColors.divider,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Chuyển cảnh mượt cho mọi `Navigator.push` trong app (hồ sơ, điều khoản,
    // cắt ảnh). Một chỗ khai báo, tất cả màn hình hưởng chung.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FadeThroughTransitions(),
        TargetPlatform.iOS: _FadeThroughTransitions(),
        TargetPlatform.macOS: _FadeThroughTransitions(),
      },
    ),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.divider,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.35,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          size: 22,
        );
      }),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: AppSpace.lg,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 4,
      shape: StadiumBorder(),
    ),
  );
}

/// Chuyển cảnh "fade through" kiểu Material 3: màn mới mờ dần và nhích lên
/// nhẹ, màn cũ đứng yên. Nhẹ hơn `CupertinoPageTransitionsBuilder` và không
/// gây cảm giác trượt ngang khi màn trước không có quan hệ ngang hàng.
class _FadeThroughTransitions extends PageTransitionsBuilder {
  const _FadeThroughTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

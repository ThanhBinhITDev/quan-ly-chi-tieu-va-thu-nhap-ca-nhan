import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:android/ui/theme.dart';

/// Nền chuyển động nhẹ phía sau màn hình đăng nhập.
///
/// Vì sao vẽ tay thay vì dùng ảnh: một ảnh nền 1080×2400 sẽ nặng vài trăm KB
/// và không co giãn theo màn hình. Hai vòng tròn mờ + gradient vẽ bằng
/// `CustomPainter` nhẹ hơn nhiều, sắc nét ở mọi độ phân giải, và chuyển động
/// rất chậm để không gây mỏi mắt.
///
/// Tôn trọng `MediaQuery.disableAnimations`: người bật "giảm chuyển động" trong
/// cài đặt hệ điều hành sẽ thấy nền tĩnh.
class AnimatedAuthBackground extends StatefulWidget {
  const AnimatedAuthBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AnimatedAuthBackground> createState() => _AnimatedAuthBackgroundState();
}

class _AnimatedAuthBackgroundState extends State<AnimatedAuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _controller.stop();
      _controller.value = 0.25;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.background)),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => CustomPaint(
                painter: _BlobPainter(t: _controller.value),
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({required this.t});

  /// Tiến trình 0..1 của vòng lặp chuyển động.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t * 2 * math.pi;
    // Hai vòng tròn bơi ngược pha. Bán kính tính theo cạnh nhỏ để máy tính
    // bảng và điện thoại đều có tỉ lệ giống nhau.
    final unit = size.shortestSide;

    _blob(
      canvas,
      center: Offset(
        size.width * (0.18 + 0.06 * math.sin(angle)),
        size.height * (0.12 + 0.04 * math.cos(angle)),
      ),
      radius: unit * 0.55,
      color: AppColors.primary.withValues(alpha: 0.16),
    );
    _blob(
      canvas,
      center: Offset(
        size.width * (0.88 + 0.05 * math.cos(angle + 1)),
        size.height * (0.86 + 0.05 * math.sin(angle + 1)),
      ),
      radius: unit * 0.62,
      color: AppColors.primaryDark.withValues(alpha: 0.10),
    );
  }

  void _blob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) => oldDelegate.t != t;
}

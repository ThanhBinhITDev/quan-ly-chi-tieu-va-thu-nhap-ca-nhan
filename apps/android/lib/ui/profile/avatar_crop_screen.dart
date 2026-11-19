import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Cắt ảnh đại diện thành khung vuông.
///
/// Vì sao tự vẽ thay vì dùng `image_cropper`: package đó kéo theo thư viện
/// Android/iOS gốc (uCrop) và bắt buộc sửa `MainActivity`. Nhu cầu ở đây chỉ là
/// "chọn vùng vuông", nên một `GestureDetector` + `package:image` gọn hơn,
/// không thêm native code, và chạy được trong widget test.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.bytes});

  final Uint8List bytes;

  /// Mở màn hình cắt, trả JPEG đã cắt (512×512) hoặc `null` nếu huỷ.
  static Future<Uint8List?> open(
    BuildContext context, {
    required Uint8List bytes,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => AvatarCropScreen(bytes: bytes)),
    );
  }

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  ui.Image? _decoded;
  Object? _decodeError;

  /// Tỉ lệ phóng thêm so với mức "vừa khung" (1.0 = vừa khít).
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _zoomStart = 1;
  Offset _panStart = Offset.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final decoded = await decodeImageFromList(widget.bytes);
      if (!mounted) return;
      setState(() => _decoded = decoded);
    } catch (error) {
      if (!mounted) return;
      setState(() => _decodeError = error);
    }
  }

  @override
  void dispose() {
    _decoded?.dispose();
    super.dispose();
  }

  /// Kích thước khung cắt trên màn hình.
  double _frameSize(BoxConstraints constraints) {
    // Chừa chỗ cho nút bấm và tiêu đề; khung luôn vuông.
    final maxSide = constraints.maxWidth - 48;
    final maxHeight = constraints.maxHeight - 200;
    return (maxSide < maxHeight ? maxSide : maxHeight).clamp(160.0, 360.0);
  }

  void _resetView() {
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
    });
  }

  /// Dịch chuyển bị giới hạn để ảnh không hở mép khung.
  Offset _clampPan(Offset pan, double frame, double zoom) {
    final image = _decoded;
    if (image == null) return Offset.zero;
    final scale = _baseScale(frame) * zoom;
    final overflowX = (image.width * scale - frame) / 2;
    final overflowY = (image.height * scale - frame) / 2;
    return Offset(
      pan.dx.clamp(-overflowX, overflowX),
      pan.dy.clamp(-overflowY, overflowY),
    );
  }

  /// Tỉ lệ để ảnh phủ kín khung (cover), tính theo cạnh nhỏ hơn.
  double _baseScale(double frame) {
    final image = _decoded!;
    return frame / (image.width < image.height ? image.width : image.height);
  }

  Future<void> _apply() async {
    final image = _decoded;
    if (image == null) return;
    setState(() => _busy = true);
    try {
      final frame = _frameSizeOfContext();
      final scale = _baseScale(frame) * _zoom;
      // Đổi khung hiển thị sang toạ độ pixel của ảnh gốc.
      final cropSide = frame / scale;
      final x0 = image.width / 2 - (frame / 2 - _pan.dx) / scale;
      final y0 = image.height / 2 - (frame / 2 - _pan.dy) / scale;

      final source = img.decodeImage(widget.bytes);
      if (source == null) {
        throw StateError('Không đọc được ảnh.');
      }
      // `copyCrop` cần toạ độ nguyên trong biên ảnh.
      final left = x0.round().clamp(0, source.width - 1);
      final top = y0.round().clamp(0, source.height - 1);
      final side = cropSide.round().clamp(
            1,
            (source.width - left) < (source.height - top)
                ? source.width - left
                : source.height - top,
          );

      var cropped = img.copyCrop(
        source,
        x: left,
        y: top,
        width: side,
        height: side,
      );
      // 512 đủ nét cho avatar 96dp trên màn hình mật độ cao, mà vẫn nhỏ
      // (~50 KB) để gửi base64 qua JSON.
      cropped = img.copyResize(
        cropped,
        width: 512,
        height: 512,
        interpolation: img.Interpolation.average,
      );
      final jpeg = img.encodeJpg(cropped, quality: 88);
      if (!mounted) return;
      Navigator.of(context).pop(Uint8List.fromList(jpeg));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double _frame = 0;

  double _frameSizeOfContext() => _frame;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1512),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(AppStrings.cropTitle),
        actions: [
          TextButton(
            onPressed: _busy ? null : _resetView,
            child: const Text(
              'Đặt lại',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frame = _frameSize(constraints);
            _frame = frame;
            final image = _decoded;
            return Column(
              children: [
                const SizedBox(height: AppSpace.md),
                Text(
                  AppStrings.cropHint,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: AppSpace.lg),
                Expanded(
                  child: Center(
                    child: image == null
                        ? _placeholder()
                        : GestureDetector(
                            onScaleStart: (details) {
                              _zoomStart = _zoom;
                              _panStart = _pan;
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                _zoom = (_zoomStart * details.scale)
                                    .clamp(1.0, 6.0);
                                final next = _panStart + details.focalPointDelta;
                                _pan = _clampPan(next, frame, _zoom);
                              });
                            },
                            child: SizedBox(
                              width: frame,
                              height: frame,
                              child: ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ColoredBox(
                                      color: Colors.black,
                                      child: Transform.translate(
                                        offset: _pan,
                                        child: Transform.scale(
                                          scale:
                                              _baseScale(frame) * _zoom,
                                          child: Center(
                                            child: RawImage(
                                              image: image,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CropFramePainter(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        child: const Text(AppStrings.cropCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: (_busy || image == null) ? null : _apply,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(AppStrings.cropApply),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder() {
    if (_decodeError != null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.imageOff, color: Colors.white54, size: 40),
            SizedBox(height: AppSpace.md),
            Text(
              'Không đọc được ảnh này. Chọn ảnh khác nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return const CircularProgressIndicator(color: Colors.white);
  }
}

/// Viền trắng + lưới mờ để thấy vùng ảnh sẽ lấy.
class _CropFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      border,
    );

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white24;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_CropFramePainter oldDelegate) => false;
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Ảnh gửi lên server bị chặn ở 512KB, nhưng nén tới đúng mức đó thì ảnh
/// nhoè. Giữ 400KB để còn biên an toàn, phần dư do base64 làm phình lên
/// khoảng 4/3 khi gửi.
const int photoTargetBytes = 400 * 1024;
const int photoMaxSide = 1440;

/// Trần cứng server chấp nhận. Vượt thì từ chối ngay trên máy, đừng để mất
/// một vòng mạng mới biết.
const int photoHardLimitBytes = 512 * 1024;

/// Nén ảnh chạy trong isolate riêng: ảnh 5MP giải mã + mã hoá lại mất vài
/// trăm ms, làm trên luồng UI thì khung hình đứng.
Uint8List compressPhoto(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;

  var image = img.bakeOrientation(decoded);
  if (image.width > photoMaxSide || image.height > photoMaxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: photoMaxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: photoMaxSide, interpolation: img.Interpolation.average);
  }

  var quality = 82;
  var encoded = img.encodeJpg(image, quality: quality);
  // Hạ dần chất lượng thay vì thu nhỏ thêm: ở 1440px chất lượng 60 vẫn đọc
  // được chữ trên hoá đơn, còn thu nhỏ nữa thì mất chi tiết.
  while (encoded.length > photoTargetBytes && quality > 45) {
    quality -= 10;
    encoded = img.encodeJpg(image, quality: quality);
  }
  return Uint8List.fromList(encoded);
}

/// Ảnh đã chọn và nén xong, sẵn sàng gửi.
class PickedPhoto {
  const PickedPhoto({required this.bytes, this.mime = 'image/jpeg'});

  final Uint8List bytes;

  /// Luôn JPEG sau khi nén — khai đúng mime thật, vì server đối chiếu chữ ký
  /// tệp với `photo_mime` và trả RULE_VIOLATION nếu lệch.
  final String mime;

  int get sizeBytes => bytes.lengthInBytes;
}

/// Chọn ảnh từ camera hoặc thư viện rồi nén về mức gửi được.
///
/// Trả `null` khi người dùng huỷ. Hai lối tách riêng vì "chụp lúc đang ăn"
/// và "lục lại ảnh cũ" là hai tình huống khác hẳn nhau.
///
/// Ném [PhotoTooLargeException] khi ảnh vẫn quá lớn sau khi nén — hiếm, chỉ
/// xảy ra với ảnh đã ở mức nén tối đa mà vẫn nặng.
Future<PickedPhoto?> pickAndCompressPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.camera, color: AppColors.primary),
            title: const Text(AppStrings.recordPhotoTake),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(LucideIcons.images, color: AppColors.primary),
            title: const Text(AppStrings.recordPhotoPick),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    // Không để image_picker nén: nó trả JPEG chất lượng cố định, còn ta cần
    // kiểm dung lượng thật rồi hạ dần cho vừa.
    maxWidth: 2000,
  );
  if (picked == null) return null;

  final raw = await picked.readAsBytes();
  // Nén ở isolate: ảnh 5MP mất vài trăm ms, đủ để khung hình đứng.
  final bytes = await compute(compressPhoto, raw);
  if (bytes.lengthInBytes > photoHardLimitBytes) {
    throw const PhotoTooLargeException();
  }
  return PickedPhoto(bytes: bytes);
}

class PhotoTooLargeException implements Exception {
  const PhotoTooLargeException();

  @override
  String toString() => AppStrings.recordReceiptTooLarge;
}

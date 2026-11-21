import 'dart:math';

/// Sinh UUID v4 ở client.
///
/// API yêu cầu client tự sinh `id` để tạo bản ghi được khi offline và gửi lại
/// nhiều lần mà không sinh trùng (idempotent theo khoá chính).
String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  // Đặt version = 4 và variant = 10xx theo RFC 4122.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
    buffer.write(hex(bytes[i]));
  }
  return buffer.toString();
}
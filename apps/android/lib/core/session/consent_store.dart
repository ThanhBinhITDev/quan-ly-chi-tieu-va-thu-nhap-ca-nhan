import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ghi nhớ người dùng đã đồng ý phiên bản điều khoản nào.
///
/// Không lưu "đã đồng ý = true" mà lưu **số phiên bản**. Khi nội dung pháp lý
/// thay đổi, số phiên bản tăng lên, app tự thấy khác và hỏi lại — không thể
/// lặng lẽ áp điều khoản mới lên người dùng cũ.
class ConsentStore {
  ConsentStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kVersion = 'sf.consent.version';
  static const _kAcceptedAt = 'sf.consent.accepted_at';

  Future<String?> acceptedVersion() => _storage.read(key: _kVersion);

  Future<DateTime?> acceptedAt() async {
    final raw = await _storage.read(key: _kAcceptedAt);
    return DateTime.tryParse(raw ?? '');
  }

  Future<void> accept(String version, {DateTime? at}) async {
    await _storage.write(key: _kVersion, value: version);
    await _storage.write(
      key: _kAcceptedAt,
      value: (at ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _kVersion);
    await _storage.delete(key: _kAcceptedAt);
  }
}

final consentStoreProvider = Provider<ConsentStore>((ref) => ConsentStore());

/// Phiên bản điều khoản người dùng đã đồng ý, `null` = chưa đồng ý lần nào.
final acceptedConsentProvider =
    FutureProvider<String?>((ref) => ref.watch(consentStoreProvider).acceptedVersion());

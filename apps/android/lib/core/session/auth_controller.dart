import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/core/config/app_config.dart';
import 'package:android/core/error/app_exception.dart';
import 'package:android/data/remote/api_client.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/remote/finance_api.dart';
import 'package:android/data/session/session_store.dart';

/// Khoá hạ tầng dùng chung. Tách riêng để test có thể thay bằng bản giả.
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(store: ref.watch(sessionStoreProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    store: ref.watch(sessionStoreProvider),
    authApi: ref.watch(authApiProvider),
    // Chỉ debug build mới nhận token tiêm từ `--dart-define`.
    forcedToken: kDebugMode ? AppConfig.devAccessToken : null,
  );
});

final financeApiProvider = Provider<FinanceApi>((ref) {
  return FinanceApi(ref.watch(apiClientProvider));
});

/// Trạng thái đăng nhập.
///
/// `null` = chưa đăng nhập. Có phiên = đã đăng nhập và được phép gọi API.
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    // Không có Supabase cũng không có dev login: chưa thể đăng nhập thật.
    if (!AppConfig.canSignIn) return null;
    // Đường tắt cho dev: chỉ có hiệu lực ở debug build, và chỉ khi được tiêm
    // tường minh bằng `--dart-define=DEV_ACCESS_TOKEN=...`. Release bỏ qua.
    if (kDebugMode && AppConfig.devAccessToken.isNotEmpty) {
      return AuthSession(
        accessToken: AppConfig.devAccessToken,
        refreshToken: '',
        // Token dev không có `exp`; đặt xa để ApiClient không cố refresh.
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
    }
    final session = await ref.watch(sessionStoreProvider).read();
    if (session == null) return null;
    // Phiên dev login không có refresh token: hết hạn thì phải đăng nhập lại.
    if (session.refreshToken.isEmpty) {
      if (session.isExpiringSoon) {
        await ref.watch(sessionStoreProvider).clear();
        return null;
      }
      return session;
    }
    // Phiên đã quá hạn và không gia hạn được thì coi như chưa đăng nhập.
    if (session.isExpiringSoon) {
      try {
        return await ref.watch(authApiProvider).refresh(session.refreshToken);
      } on AppException {
        await ref.watch(sessionStoreProvider).clear();
        return null;
      }
    }
    return session;
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    final api = ref.read(authApiProvider);
    state = await AsyncValue.guard(
      () => AppConfig.hasDevLogin
          ? api.signInDev(email: email, password: password)
          : api.signIn(email: email, password: password),
    );
  }

  /// Trả về `true` nếu Supabase đã trả phiên ngay (không cần xác nhận email).
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final session = await ref.read(authApiProvider).signUp(
            email: email,
            password: password,
            displayName: displayName,
          );
      state = AsyncValue.data(session);
      return session != null;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authApiProvider).signOut();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// `true` khi đã có phiên đăng nhập hợp lệ.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).value != null;
});
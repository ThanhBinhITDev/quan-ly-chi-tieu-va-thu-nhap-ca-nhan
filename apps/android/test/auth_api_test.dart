import 'dart:convert';
import 'dart:typed_data';

import 'package:android/core/error/app_exception.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/session/session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trả về phản hồi cố định, không chạm mạng. Nhờ vậy kiểm được cách app dịch
/// lỗi của Supabase mà không cần credential thật.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryStore extends SessionStore {
  AuthSession? saved;

  @override
  Future<AuthSession?> read() async => saved;

  @override
  Future<void> write(AuthSession session) async => saved = session;

  @override
  Future<void> clear() async => saved = null;
}

AuthApi _apiReturning(int status, Map<String, dynamic> body) {
  final dio = Dio()..httpClientAdapter = _FixedAdapter(status, body);
  return AuthApi(store: _MemoryStore(), dio: dio);
}

Future<AppException> _capture(Future<void> Function() action) async {
  try {
    await action();
  } on AppException catch (error) {
    return error;
  }
  throw StateError('Không có lỗi nào được ném ra');
}

void main() {
  test('sai mật khẩu báo đúng câu tiếng Việt', () async {
    final api = _apiReturning(400, {
      'code': 400,
      'error_code': 'invalid_credentials',
      'msg': 'Invalid login credentials',
    });

    final error = await _capture(
      () => api.signIn(email: 'a@b.com', password: 'sai-mat-khau'),
    );

    expect(error.code, ApiErrorCode.unauthenticated);
    expect(error.message, 'Email hoặc mật khẩu không đúng.');
  });

  test('anon key sai được nói rõ là lỗi cấu hình', () async {
    final api = _apiReturning(401, {
      'message': 'Invalid API key',
      'hint': 'Double check your Supabase anon key.',
    });

    final error = await _capture(
      () => api.signIn(email: 'a@b.com', password: 'matkhau123'),
    );

    expect(error.message, contains('Cấu hình Supabase'));
  });

  test('email chưa xác nhận được hướng dẫn kiểm tra hộp thư', () async {
    final api = _apiReturning(400, {
      'error_code': 'email_not_confirmed',
      'msg': 'Email not confirmed',
    });

    final error = await _capture(
      () => api.signIn(email: 'a@b.com', password: 'matkhau123'),
    );

    expect(error.message, contains('chưa xác nhận'));
  });

  test('đăng nhập thành công lưu phiên vào store', () async {
    final store = _MemoryStore();
    final dio = Dio()
      ..httpClientAdapter = _FixedAdapter(200, {
        'access_token': 'access-abc',
        'refresh_token': 'refresh-xyz',
        'expires_in': 3600,
        'user': {'id': 'user-1', 'email': 'a@b.com'},
      });
    final api = AuthApi(store: store, dio: dio);

    final session = await api.signIn(email: 'a@b.com', password: 'matkhau123');

    expect(session.accessToken, 'access-abc');
    expect(store.saved?.refreshToken, 'refresh-xyz');
    expect(session.userId, 'user-1');
    expect(session.expiresAt.isAfter(DateTime.now()), isTrue);
  });

  test('đăng ký cần xác nhận email thì trả null, không lưu phiên', () async {
    final store = _MemoryStore();
    final dio = Dio()
      ..httpClientAdapter = _FixedAdapter(200, {
        'id': 'user-2',
        'email': 'moi@b.com',
        'session': null,
      });
    final api = AuthApi(store: store, dio: dio);

    final session = await api.signUp(
      email: 'moi@b.com',
      password: 'matkhau123',
    );

    expect(session, isNull);
    expect(store.saved, isNull);
  });
}
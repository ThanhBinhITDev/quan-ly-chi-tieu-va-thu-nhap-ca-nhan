import 'dart:convert';
import 'dart:typed_data';

import 'package:android/data/remote/api_client.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/remote/finance_api.dart';
import 'package:android/data/session/session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ghi lại header của request để kiểm token được tiêm đúng cách.
class _CapturingAdapter implements HttpClientAdapter {
  String? authorization;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    authorization = options.headers['Authorization'] as String?;
    return ResponseBody.fromString(
      jsonEncode(<dynamic>[]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Store rỗng: mô phỏng máy chưa từng đăng nhập Supabase.
class _EmptyStore extends SessionStore {
  @override
  Future<AuthSession?> read() async => null;

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  test('forcedToken được gắn vào header dù secure storage trống', () async {
    final adapter = _CapturingAdapter();
    final store = _EmptyStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(
      store: store,
      authApi: AuthApi(store: store),
      dio: dio,
      forcedToken: 'token-dev',
    );

    await FinanceApi(client).wallets();

    expect(adapter.calls, 1);
    expect(adapter.authorization, 'Bearer token-dev');
  });

  test('không có forcedToken thì không gắn header khi chưa đăng nhập', () async {
    final adapter = _CapturingAdapter();
    final store = _EmptyStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(
      store: store,
      authApi: AuthApi(store: store),
      dio: dio,
    );

    await FinanceApi(client).wallets();

    expect(adapter.authorization, isNull);
  });
}
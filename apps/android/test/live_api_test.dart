import 'dart:io';

import 'package:android/core/error/app_exception.dart';
import 'package:android/data/remote/api_client.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/remote/finance_api.dart';
import 'package:android/data/session/session_store.dart';
import 'package:android/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test chạy với API thật, chỉ bật khi có biến môi trường:
///
/// ```
/// SF_LIVE_TOKEN=<jwt> flutter test test/live_api_test.dart
/// ```
/// Không có token thì bỏ qua, để `flutter test` thường vẫn xanh trên máy
/// không bật API.
class _FixedSessionStore extends SessionStore {
  _FixedSessionStore(this.token);

  final String token;

  @override
  Future<AuthSession?> read() async => AuthSession(
        accessToken: token,
        refreshToken: 'khong-dung',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  final token = Platform.environment['SF_LIVE_TOKEN'];
  final skip = token == null || token.isEmpty
      ? 'Cần SF_LIVE_TOKEN để chạy với API thật'
      : null;

  late FinanceApi api;
  setUpAll(() {
    final store = _FixedSessionStore(token ?? '');
    final client = ApiClient(store: store, authApi: AuthApi(store: store));
    api = FinanceApi(client);
  });

  test('GET /v1/me trả hồ sơ đọc được', () async {
    final me = await api.me();
    expect(me.id, isNotEmpty);
    expect(me.currency, 'VND');
    expect(me.plan, isNotEmpty);
  }, skip: skip);

  test('GET /v1/wallets trả danh sách ví', () async {
    final wallets = await api.wallets();
    expect(wallets, isNotEmpty);
    expect(wallets.first.id, hasLength(36));
  }, skip: skip);

  test('GET /v1/wallets trả balance do server tính', () async {
    final wallets = await api.wallets();
    // Ví chưa có giao dịch thì balance = initial_balance, nên chỉ cần không null.
    for (final wallet in wallets) {
      expect(wallet.balance, isNotNull);
      expect(wallet.isDeleted, isFalse);
    }
  }, skip: skip);

  test('GET /v1/wallets/summary khớp tổng của danh sách ví', () async {
    final wallets = await api.wallets();
    final summary = await api.walletSummary();

    expect(summary.wallets, hasLength(wallets.length));
    final expected = wallets.fold<int>(0, (sum, w) => sum + (w.balance ?? 0));
    expect(summary.totalBalance, expected);
    expect(summary.byType.keys, everyElement(isNotEmpty));
  }, skip: skip);

  test('GET /v1/categories đọc được', () async {
    final categories = await api.categories();
    expect(categories, isNotNull);
  }, skip: skip);

  test('GET /v1/transactions giới hạn đúng số dòng', () async {
    final rows = await api.transactions(limit: 2);
    expect(rows.length, lessThanOrEqualTo(2));
    for (final row in rows) {
      expect(row.amount, greaterThan(0));
      expect(row.isDeleted, isFalse);
    }
  }, skip: skip);

  test('GET /v1/budgets/progress khớp shape', () async {
    final items = await api.budgetProgress();
    for (final item in items) {
      expect(item.budgetId, hasLength(36));
      expect(item.amount, greaterThanOrEqualTo(0));
      expect(item.usedPct, isA<double>());
    }
  }, skip: skip);

  test('GET /v1/reports/month-summary khớp shape', () async {
    final now = DateTime.now();
    final summary = await api.monthSummary(year: now.year, month: now.month);
    expect(summary.periodStart, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(summary.expense, greaterThanOrEqualTo(0));
    expect(summary.budgetUsedPct, isA<double>());
  }, skip: skip);

  test('gọi API không có token thì 401 thành AppException', () async {
    final client = ApiClient(
      store: _FixedSessionStore(''),
      authApi: AuthApi(store: _FixedSessionStore('')),
    );
    expect(
      () => FinanceApi(client).me(),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', ApiErrorCode.unauthenticated),
      ),
    );
  }, skip: skip);

  test('base URL luôn là http(s) hợp lệ', () {
    expect(AppConfig.apiBaseUrl, matches(RegExp(r'^https?://.+$')));
  });
}
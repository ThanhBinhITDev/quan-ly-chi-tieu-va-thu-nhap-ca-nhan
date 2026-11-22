import 'dart:convert';
import 'dart:typed_data';

import 'package:android/data/api_finance_repository.dart';
import 'package:android/data/remote/api_client.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/remote/finance_api.dart';
import 'package:android/data/session/session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore extends SessionStore {
  @override
  Future<AuthSession?> read() async => AuthSession(
        accessToken: 'token-gia',
        refreshToken: 'refresh-gia',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

/// Máy chủ giả tôn trọng `limit` và `before`, để kiểm tra việc đi theo
/// cursor thật chứ không chỉ kiểm tra lời gọi đầu tiên.
class _PagingAdapter implements HttpClientAdapter {
  _PagingAdapter(this.rows);

  final List<Map<String, dynamic>> rows;

  /// Mốc `before` của từng lời gọi, để khẳng định đã phân trang.
  final List<DateTime?> cursors = [];
  final List<int> limits = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    ResponseBody json(Object? value) => ResponseBody.fromString(
          jsonEncode(value),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    if (path == '/v1/categories') {
      return json({
        'items': [
          {'id': 'cat-food', 'name': 'Ăn uống', 'kind': 'expense'},
        ],
      });
    }
    if (path == '/v1/wallets') {
      return json({
        'items': [
          {'id': 'wallet-cash', 'name': 'Tiền mặt', 'balance': 100000},
        ],
      });
    }
    if (path == '/v1/transactions') {
      final rawLimit = options.queryParameters['limit'];
      final limit = int.tryParse('$rawLimit') ?? 50;
      final rawBefore = options.queryParameters['before'];
      final before = rawBefore == null ? null : DateTime.parse('$rawBefore');
      limits.add(limit);
      cursors.add(before);

      // Giảm dần theo `occurred_at`, giống server.
      final sorted = [...rows]
        ..sort((a, b) => (b['occurred_at'] as String)
            .compareTo(a['occurred_at'] as String));
      final page = sorted
          .where(
            (row) =>
                before == null ||
                DateTime.parse(row['occurred_at'] as String).isBefore(before),
          )
          .take(limit)
          .toList();
      return json(page);
    }
    return ResponseBody.fromString(
      jsonEncode({'error': {'code': 'NOT_FOUND', 'message': 'không có'}}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _row(String id, DateTime at, int amount) => {
      'id': id,
      'amount': amount,
      'type': 'expense',
      'category_id': 'cat-food',
      'wallet_id': 'wallet-cash',
      'note': '',
      'rev': 1,
      'occurred_at': at.toUtc().toIso8601String(),
      'occurred_on':
          '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}',
      'has_receipt': false,
      'created_at': at.toUtc().toIso8601String(),
      'updated_at': at.toUtc().toIso8601String(),
      'deleted_at': null,
    };

ApiFinanceRepository _repo(HttpClientAdapter adapter) {
  final store = _MemoryStore();
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
    ..httpClientAdapter = adapter;
  return ApiFinanceRepository(
    FinanceApi(
      ApiClient(store: store, authApi: AuthApi(store: store), dio: dio),
    ),
  );
}

void main() {
  test('chỉ lấy giao dịch trong tháng, bỏ khoản tháng khác', () async {
    final adapter = _PagingAdapter([
      _row('a', DateTime(2026, 10, 31, 23), 1000),
      _row('b', DateTime(2026, 11, 1, 0), 2000),
      _row('c', DateTime(2026, 11, 15, 12), 3000),
      _row('d', DateTime(2026, 11, 30, 23), 4000),
      _row('e', DateTime(2026, 12, 1, 0), 5000),
    ]);
    final items = await _repo(adapter).getTransactionsInMonth(2026, 11);

    expect(items.map((i) => i.id).toSet(), {'b', 'c', 'd'});
    // Khoản 1/11 00:00 và 30/11 23:59 phải nằm trong tháng — đây là hai ca
    // biên mà so sánh sai một phía sẽ làm rơi mất.
    expect(items.map((i) => i.amount).reduce((a, b) => a + b), 9000);
  });

  test('tháng nhiều hơn một trang thì đi tiếp bằng cursor', () async {
    // 250 khoản trong tháng 11 nhiều hơn trần 200 của server.
    final rows = [
      for (var day = 1; day <= 30; day++)
        for (var i = 0; i < 9; i++)
          _row('t-$day-$i', DateTime(2026, 11, day, 8 + i % 10), 1000),
    ];
    final adapter = _PagingAdapter(rows);
    final items = await _repo(adapter).getTransactionsInMonth(2026, 11);

    expect(items.length, rows.length);
    expect(adapter.cursors.length, greaterThan(1),
        reason: 'phải có ít nhất hai lượt gọi vì server chặn 200');
    expect(adapter.limits.every((limit) => limit <= 200), isTrue,
        reason: 'server trả 400 nếu limit > 200');
  });

  test('tháng trống thì trả rỗng và dừng ngay, không quét thêm', () async {
    final adapter = _PagingAdapter([]);
    final items = await _repo(adapter).getTransactionsInMonth(2026, 11);
    expect(items, isEmpty);
    expect(adapter.cursors.length, 1);
  });

  test('mốc before đầu tiên là đầu tháng sau', () async {
    final adapter = _PagingAdapter([]);
    await _repo(adapter).getTransactionsInMonth(2026, 2);
    // Gửi lên là UTC, và DateTime.parse giữ đúng dạng đó — so sánh theo mốc
    // tuyệt đối, không so theo giờ địa phương.
    expect(
      adapter.cursors.single!.toUtc(),
      DateTime(2026, 3).toUtc(),
    );
  });
}

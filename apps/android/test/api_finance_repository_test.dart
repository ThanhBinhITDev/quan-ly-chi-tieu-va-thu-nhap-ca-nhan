import 'dart:convert';
import 'dart:typed_data';

import 'package:android/data/api_finance_repository.dart';
import 'package:android/data/remote/api_client.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/remote/finance_api.dart';
import 'package:android/data/session/session_store.dart';
import 'package:android/domain/models.dart';
import 'package:android/domain/transaction_input.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

/// Trả JSON cố định theo đường dẫn, không chạm mạng. Dùng để khoá lại việc
/// ghép nhiều endpoint thành một `DashboardData` mà không cần API thật.
class _RouteAdapter implements HttpClientAdapter {
  _RouteAdapter(this.routes);

  final Map<String, Object?> routes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    for (final entry in routes.entries) {
      if (path == entry.key) {
        return ResponseBody.fromString(
          jsonEncode(entry.value),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
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

ApiFinanceRepository _repository(Map<String, Object?> routes) {
  final store = _MemoryStore();
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
    ..httpClientAdapter = _RouteAdapter(routes);
  final client = ApiClient(
    store: store,
    authApi: AuthApi(store: store),
    dio: dio,
  );
  return ApiFinanceRepository(FinanceApi(client));
}

void main() {
  final now = DateTime.now();
  final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

  test('dashboard lấy "Số dư hiện tại" từ tổng số dư ví, không phải ngân sách',
      () async {
    final repo = _repository({
      '/v1/reports/month-summary': {
        'period': {'start': monthStart, 'end': monthStart, 'days_left': 5},
        'income': 3000000,
        'expense': 1850000,
        // remaining của ngân sách: KHÔNG được dùng làm số dư.
        'remaining': 1150000,
        'daily_limit': 230000,
        'budget': {'total': 3000000, 'used_pct': 61.7},
        'by_category': <Object>[],
        'by_day': <Object>[],
        'computed_at': '2026-11-19T18:35:58.218Z',
      },
      '/v1/budgets/progress': {'items': <Object>[]},
      '/v1/transactions': <Object>[],
      '/v1/wallets/summary': {
        'wallets': [
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'name': 'Tien mat',
            'type': 'cash',
            'is_archived': false,
            'balance': -135000,
          },
          {
            'id': '33333333-3333-4333-8333-333333333333',
            'name': 'Nhay coc',
            'type': 'bank',
            'is_archived': false,
            'balance': 465000,
          },
        ],
        'total_balance': 330000,
        'by_type': {'cash': -135000, 'bank': 465000},
        'computed_at': '2026-11-19T18:35:58.218Z',
      },
    });

    final dashboard = await repo.getDashboard();

    expect(dashboard.summary.balance, 330000);
    expect(dashboard.summary.balance, isNot(1150000));
    expect(dashboard.summary.income, 3000000);
    expect(dashboard.summary.expense, 1850000);
    expect(dashboard.summary.dailyLimit, 230000);
    expect(dashboard.isEmpty, isFalse);
  });

  test('warmUp nạp danh mục và tên ví thật cho form', () async {
    final repo = _repository({
      '/v1/categories': [
        {
          'id': 'cat_food',
          'user_id': null,
          'name': 'Ăn uống',
          'type': 'expense',
          'is_system': true,
          'sort_order': 1,
          'rev': 1,
          'deleted_at': null,
        },
      ],
      '/v1/wallets': [
        {
          'id': '22222222-2222-4222-8222-222222222222',
          'name': 'Tien mat',
          'type': 'cash',
          'initial_balance': 0,
          'balance': -135000,
          'rev': 1,
          'is_archived': false,
          'deleted_at': null,
        },
      ],
    });

    await repo.warmUp();

    expect(repo.wallets, ['Tien mat']);
    expect(repo.categories.map((c) => c.name), ['Ăn uống']);
  });

  test('giao dịch hiện tên danh mục dù chưa ai gọi warmUp', () async {
    // Lỗi thật gặp trên máy: mở tab Giao dịch đầu tiên thì mọi dòng là
    // "Khác", vì cache danh mục chỉ được nạp khi vào form nhập liệu.
    final repo = _repository({
      '/v1/categories': [
        {
          'id': '5b000000-0000-4000-8000-000000000001',
          'user_id': null,
          'name': 'Ăn uống',
          'type': 'expense',
          'is_system': false,
          'sort_order': 1,
          'rev': 1,
          'deleted_at': null,
        },
      ],
      '/v1/wallets': [
        {
          'id': '5a000000-0000-4000-8000-000000000001',
          'name': 'Tiền mặt',
          'type': 'cash',
          'initial_balance': 0,
          'balance': 0,
          'rev': 1,
          'is_archived': false,
          'deleted_at': null,
        },
      ],
      '/v1/transactions': [
        {
          'id': '5d000000-0000-4000-8000-000000000022',
          'wallet_id': '5a000000-0000-4000-8000-000000000001',
          'category_id': '5b000000-0000-4000-8000-000000000001',
          'type': 'expense',
          'amount': 35000,
          'to_wallet_id': null,
          'note': 'Cà phê sáng nay',
          'occurred_at': '2026-11-20T01:15:00.000Z',
          'occurred_on': '2026-11-20',
          'source': 'manual',
          'rev': 1,
          'created_at': '2026-11-19T20:36:05.387Z',
          'updated_at': '2026-11-19T20:36:05.387Z',
          'deleted_at': null,
        },
      ],
    });

    final rows = await repo.getTransactions();

    expect(rows.single.category.name, 'Ăn uống');
    expect(rows.single.wallet, 'Tiền mặt');
  });

  test('tạo, sửa rồi xoá ví đều đi qua API và cập nhật cache', () async {
    // Màn "Ví của tôi" phụ thuộc đúng chuỗi này: id do client sinh, rev phải
    // là rev + 1 khi sửa, và cache tên ví phải đổi theo để form nhập liệu
    // không còn hiện tên cũ.
    final backend = FakeBackend();
    final store = MemorySessionStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
      ..httpClientAdapter = backend;
    final repo = ApiFinanceRepository(
      FinanceApi(
        ApiClient(store: store, authApi: AuthApi(store: store), dio: dio),
      ),
    );

    await repo.warmUp();
    expect(repo.wallets, ['Tiền mặt']);

    final created = await repo.createWallet(
      name: 'Ví Momo',
      type: 'ewallet',
      initialBalance: 250000,
    );
    expect(created.name, 'Ví Momo');
    expect(created.balance, 250000);
    expect(repo.wallets, ['Tiền mặt', 'Ví Momo']);
    expect(backend.calls, contains('POST /v1/wallets'));

    final updated = await repo.updateWallet(
      id: created.id,
      rev: created.rev,
      name: 'Ví Momo đổi tên',
      initialBalance: 400000,
    );
    expect(updated.name, 'Ví Momo đổi tên');
    // Sửa số dư ban đầu thì số dư hiện tại cũng phải nhích theo, nếu không
    // trang chủ vẫn hiện số cũ.
    expect(updated.initialBalance, 400000);
    expect(updated.balance, 400000);
    expect(repo.wallets, contains('Ví Momo đổi tên'));
    // rev gửi lên phải là rev + 1 để server phát hiện xung đột hai máy.
    expect(updated.rev, created.rev + 1);

    await repo.deleteWallet(updated.id, rev: updated.rev + 1);
    expect(repo.wallets, ['Tiền mặt']);
    expect(backend.calls.where((c) => c.startsWith('DELETE /v1/wallets/')),
        isNotEmpty);
  });

  test('sửa giao dịch gửi body PATCH đúng hợp đồng UpdateTransactionDto',
      () async {
    // Lỗi thật đã xảy ra: create và update dùng chung một body, nên PATCH gửi
    // `id` và `remove_receipt` — hai khóa `UpdateTransactionDto` không có.
    // Server bật `forbidNonWhitelisted`, nên mọi lần bấm "Lưu" ở màn sửa đều
    // 400 và người dùng chỉ thấy "lưu thất bại".
    final backend = FakeBackend(
      transactions: [
        {
          'id': '5d000000-0000-4000-8000-0000000000aa',
          'wallet_id': '5a000000-0000-4000-8000-000000000001',
          'category_id': '5b000000-0000-4000-8000-000000000001',
          'type': 'expense',
          'amount': 35000,
          'note': 'Cà phê',
          'to_wallet_id': null,
          'occurred_at': '2026-11-20T01:15:00.000Z',
          'occurred_on': '2026-11-20',
          'rev': 1,
          'deleted_at': null,
        },
      ],
    );
    final store = MemorySessionStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
      ..httpClientAdapter = backend;
    final repo = ApiFinanceRepository(
      FinanceApi(
        ApiClient(store: store, authApi: AuthApi(store: store), dio: dio),
      ),
    );

    final items = await repo.getTransactions();
    await repo.updateTransaction(
      items.single.id,
      NewTransaction(
        amount: 42000,
        type: TransactionType.expense,
        category: items.single.category,
        wallet: items.single.wallet,
        note: 'Cà phê sửa',
        occurredAt: items.single.occurredAt!,
      ),
      rev: items.single.rev,
    );

    final patch = backend.lastTransactionPatchBody;
    expect(patch, isNotNull);
    // `id` không có trong UpdateTransactionDto.
    expect(patch!.containsKey('id'), isFalse);
    expect(patch.containsKey('remove_receipt'), isFalse);
    expect(patch['amount'], 42000);
    expect(patch['note'], 'Cà phê sửa');
    expect(patch['rev'], items.single.rev + 1);
  });

  test('tạo giao dịch không gửi remove_receipt, nhưng gửi id do client sinh',
      () async {
    final backend = FakeBackend();
    final store = MemorySessionStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
      ..httpClientAdapter = backend;
    final repo = ApiFinanceRepository(
      FinanceApi(
        ApiClient(store: store, authApi: AuthApi(store: store), dio: dio),
      ),
    );
    await repo.warmUp();

    await repo.addTransaction(
      NewTransaction(
        amount: 20000,
        type: TransactionType.expense,
        category: const CategoryItem(id: '5b000000-0000-4000-8000-000000000001', name: 'Ăn uống'),
        wallet: 'Tiền mặt',
        note: 'Bún',
        occurredAt: DateTime(2026, 11, 21, 8),
        removeReceipt: true,
      ),
    );

    final body = backend.lastTransactionBody!;
    expect(body['id'], isA<String>());
    expect(body.containsKey('remove_receipt'), isFalse);
    expect(body['amount'], 20000);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/remote/api_client.dart';
import 'package:android/data/remote/auth_api.dart';
import 'package:android/data/remote/finance_api.dart';
import 'package:android/data/session/session_store.dart';
import 'package:android/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Máy chủ giả ở tầng HTTP: trả JSON và **ghi lại thay đổi** như API thật.
///
/// Vì app chỉ còn một đường dữ liệu (API thật), test giao diện phải đi qua
/// tầng này thay vì một repository giả. Nhờ vậy test còn bắt được lỗi ghép
/// JSON ↔ model, thứ mà repository giả che mất.
class FakeBackend implements HttpClientAdapter {
  FakeBackend({
    this.income = 3000000,
    this.expense = 35000,
    this.budgetTotal = 3000000,
    this.remaining = 1150000,
    this.dailyLimit = 230000,
    this.daysLeft = 11,
    this.previousExpense = 0,
    this.deltaPct,
    this.hasBudget = true,
    List<Map<String, dynamic>>? wallets,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? transactions,
    List<Map<String, dynamic>>? notifications,
    List<Map<String, dynamic>>? goals,
    List<Map<String, dynamic>>? budgets,
    Map<String, int>? expenseByCategory,
  }) : wallets = wallets ?? [_defaultWallet()],
       expenseByCategory = expenseByCategory ?? {},
       budgets = budgets ?? [_defaultBudget(budgetTotal)],
       categories = categories ?? [_defaultCategory()],
       transactions = transactions ?? [],
       notifications = notifications ?? [],
       goals = goals ?? [_defaultGoal()];

  /// Mô phỏng mất mạng: mọi request ném lỗi kết nối.
  bool offline = false;

  /// Mô phỏng máy chủ lỗi: mọi request trả [failStatus].
  bool failAll = false;
  int failStatus = 500;

  int income;
  int expense;
  int budgetTotal;
  int remaining;
  int dailyLimit;
  int daysLeft;
  int previousExpense;
  int? deltaPct;
  bool hasBudget;

  final List<Map<String, dynamic>> wallets;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> notifications;

  /// Mục tiêu tiết kiệm trả cho thẻ thử thách ở trang chủ.
  final List<Map<String, dynamic>> goals;

  /// Ngân sách đang áp dụng, trả cho `GET /v1/budgets?active=true`.
  final List<Map<String, dynamic>> budgets;

  /// Nhật ký lời gọi, dạng `GET /v1/wallets`. Test dùng để khẳng định
  /// "đã gọi đúng endpoint" thay vì chỉ nhìn giao diện.
  final List<String> calls = [];

  /// Body của lần POST giao dịch gần nhất, để kiểm dữ liệu gửi lên.
  Map<String, dynamic>? lastTransactionBody;

  /// Body của lần PATCH giao dịch gần nhất. Tách khỏi [lastTransactionBody]
  /// để test khẳng định đúng hợp đồng của từng endpoint.
  Map<String, dynamic>? lastTransactionPatchBody;

  /// Body của lần POST/PATCH ngân sách gần nhất.
  Map<String, dynamic>? lastBudgetBody;

  /// Chi tiêu theo danh mục để hũ danh mục có số riêng.
  final Map<String, int> expenseByCategory;

  Map<String, int> get _expenseByCategory => expenseByCategory;

  String _categoryName(String? id) {
    for (final category in categories) {
      if (category['id'] == id) return category['name'] as String;
    }
    return 'Danh mục';
  }

  /// Tham số `year`/`month` của mỗi lần gọi báo cáo tháng.
  final List<Map<String, int>> monthSummaryQueries = [];

  static Map<String, dynamic> _defaultWallet() => {
    'id': '5a000000-0000-4000-8000-000000000001',
    'name': 'Tiền mặt',
    'type': 'cash',
    'initial_balance': 800000,
    'balance': 485000,
    'rev': 1,
    'is_archived': false,
    'deleted_at': null,
  };

  static Map<String, dynamic> _defaultGoal() => {
    'id': '5d000000-0000-4000-8000-000000000001',
    'name': 'Mua laptop',
    'target_amount': 500000,
    'saved_amount': 150000,
    'progress_pct': 30.0,
    'is_completed': false,
    'rev': 1,
    'deadline': null,
    'icon': 'trophy',
  };

  static Map<String, dynamic> _defaultBudget(int amount) => {
    'id': '5c000000-0000-4000-8000-000000000001',
    'category_id': null,
    'amount': amount,
    'period': 'month',
    'start_date': '2026-11-01',
    'end_date': null,
    'rev': 1,
  };

  static Map<String, dynamic> _defaultCategory() => {
    'id': '5b000000-0000-4000-8000-000000000001',
    'name': 'Ăn uống',
    'type': 'expense',
    'is_system': false,
    'rev': 1,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    calls.add('${options.method} $path');

    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'mất mạng (test)',
      );
    }
    if (failAll) {
      return _json({
        'error': {'code': 'INTERNAL', 'message': 'Máy chủ gặp sự cố.'},
      }, status: failStatus);
    }

    // Chi tiết / sửa / xóa một giao dịch. Đặt trước `switch` vì đường dẫn có id.
    if (path.startsWith('/v1/transactions/')) {
      final id = path.substring('/v1/transactions/'.length);
      final index = transactions.indexWhere((t) => t['id'] == id);
      if (index < 0) {
        return _json({
          'error': {'code': 'NOT_FOUND', 'message': 'Không tìm thấy giao dịch'},
        }, status: 404);
      }
      if (options.method == 'PATCH') {
        final body = (options.data as Map).cast<String, dynamic>();
        lastTransactionBody = body;
        lastTransactionPatchBody = body;
        final current = transactions[index];
        transactions[index] = {
          ...current,
          // `null` gửi rõ ràng = xóa trắng, giống COALESCE phía server.
          for (final entry in body.entries)
            if (entry.key != 'rev') entry.key: entry.value,
          'rev': ((current['rev'] as num?) ?? 1).toInt() + 1,
          'updated_at': _nowIso(),
        };
        return _json(transactions[index]);
      }
      if (options.method == 'DELETE') {
        transactions.removeAt(index);
        return _json({'ok': true});
      }
      return _json(transactions[index]);
    }

    switch (path) {
      case '/v1/me':
        return _json({
          'id': '55555555-5555-4555-8555-555555555555',
          'display_name': 'Tài khoản Test',
          'plan': 'free',
          'currency': 'VND',
          'timezone': 'Asia/Ho_Chi_Minh',
          'email': 'demo@example.com',
          'has_avatar': false,
        });
      case '/v1/categories':
        return _json(categories);
      case '/v1/wallets':
        if (options.method == 'POST') {
          final body = (options.data as Map).cast<String, dynamic>();
          final created = {
            ...body,
            'rev': 1,
            'is_archived': false,
            'deleted_at': null,
            // Ví mới chưa có giao dịch: số dư hiện tại = số dư ban đầu.
            'balance': body['initial_balance'] ?? 0,
          };
          wallets.add(created);
          return _json(created);
        }
        return _json(wallets);
      case '/v1/wallets/summary':
        return _json({
          'wallets': [
            for (final w in wallets)
              {
                'id': w['id'],
                'name': w['name'],
                'type': w['type'],
                'is_archived': w['is_archived'] ?? false,
                'balance': w['balance'] ?? 0,
              },
          ],
          'total_balance': wallets.fold<int>(
            0,
            (sum, w) => sum + ((w['balance'] as num?) ?? 0).toInt(),
          ),
          'by_type': <String, int>{},
          'computed_at': _nowIso(),
        });
      case '/v1/budgets':
        if (options.method == 'POST') {
          final body = (options.data as Map).cast<String, dynamic>();
          lastBudgetBody = body;
          final created = {...body, 'end_date': null, 'rev': 1};
          budgets.add(created);
          return _json(created);
        }
        return _json(budgets);
      case '/v1/budgets/progress':
        // Sinh từ danh sách ngân sách, giống server: hũ danh mục chỉ tính chi
        // của đúng danh mục đó, hũ "Tổng" tính toàn bộ chi trong tháng.
        if (!hasBudget) return _json({'items': <Object>[]});
        return _json({
          'items': [
            for (final b in budgets)
              () {
                final isTotal = b['category_id'] == null;
                final amount = (b['amount'] as num).toInt();
                final spent = isTotal
                    ? expense
                    : _expenseByCategory[b['category_id']] ?? 0;
                return {
                  'budget_id': b['id'],
                  'name': isTotal
                      ? 'Ngân sách tháng'
                      : _categoryName(b['category_id'] as String?),
                  'amount': amount,
                  'spent': spent,
                  'remaining': amount - spent,
                  'used_pct': amount == 0 ? 0.0 : spent / amount * 100,
                  'status': 'ok',
                  'days_left': daysLeft,
                  'category_id': b['category_id'],
                };
              }(),
          ],
        });
      case '/v1/transactions':
        if (options.method == 'POST') {
          final body = (options.data as Map).cast<String, dynamic>();
          lastTransactionBody = body;
          final created = {
            ...body,
            'rev': 1,
            'occurred_on': _todayIso(),
            'created_at': _nowIso(),
            'updated_at': _nowIso(),
            'deleted_at': null,
          };
          transactions.insert(0, created);
          return _json(created);
        }
        // Tôn trọng `limit` và `before` như server thật: lịch phân trang theo
        // tháng, nếu máy giả trả hết một lượt thì test phân trang không có
        // nghĩa gì — nó sẽ xanh dù code phân trang sai.
        final rawLimit = options.queryParameters['limit'];
        final limit = int.tryParse('$rawLimit') ?? 50;
        final rawBefore = options.queryParameters['before'];
        final before = rawBefore == null ? null : DateTime.tryParse('$rawBefore');
        final sorted = [...transactions]..sort((a, b) {
            final at = '${a['occurred_at']}';
            final bt = '${b['occurred_at']}';
            return bt.compareTo(at);
          });
        final page = sorted
            .where(
              (row) =>
                  before == null ||
                  DateTime.parse('${row['occurred_at']}').isBefore(before),
            )
            .take(limit)
            .toList();
        return _json(page);
      case '/v1/reports/month-summary':
        monthSummaryQueries.add({
          'year': int.tryParse('${options.queryParameters['year']}') ?? 0,
          'month': int.tryParse('${options.queryParameters['month']}') ?? 0,
        });
        return _json({
          'period': {
            'start': _monthStartIso(),
            'end': _todayIso(),
            'days_left': daysLeft,
          },
          'income': income,
          'expense': expense,
          'remaining': remaining,
          'daily_limit': dailyLimit,
          'budget': {
            'total': budgetTotal,
            'used_pct': budgetTotal == 0 ? 0.0 : (expense / budgetTotal) * 100,
          },
          'previous': {'expense': previousExpense, 'delta_pct': deltaPct},
          'by_category': [
            if (expense > 0)
              {
                'id': '5b000000-0000-4000-8000-000000000001',
                'name': 'Ăn uống',
                'total': expense,
                'pct': 100.0,
              },
          ],
          'by_day': [
            if (expense > 0) {'date': _todayIso(), 'total': expense},
          ],
          'computed_at': _nowIso(),
        });
      case '/v1/goals':
        return _json({'items': goals, 'count': goals.length});
      case '/v1/notifications':
        return _json({
          'items': notifications,
          'unread_count': notifications
              .where((n) => n['read_at'] == null)
              .length,
        });
      case '/v1/notifications/unread-count':
        return _json({
          'unread_count': notifications
              .where((n) => n['read_at'] == null)
              .length,
        });
      case '/v1/notifications/read-all':
        var updated = 0;
        for (final n in notifications) {
          if (n['read_at'] == null) {
            n['read_at'] = _nowIso();
            updated++;
          }
        }
        return _json({'updated': updated});
    }

    // POST /v1/notifications/<id>/read
    final readMatch = RegExp(r'^/v1/notifications/([^/]+)/read$')
        .firstMatch(path);
    if (readMatch != null) {
      final id = readMatch.group(1);
      final item = notifications.firstWhere(
        (n) => n['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (item.isEmpty) {
        return _json({
          'error': {'code': 'NOT_FOUND', 'message': 'Không tìm thấy.'},
        }, status: 404);
      }
      item['read_at'] = _nowIso();
      return _json(item);
    }

    // PATCH /v1/budgets/<id>
    final budgetMatch = RegExp(r'^/v1/budgets/([^/]+)$').firstMatch(path);
    if (budgetMatch != null) {
      final id = budgetMatch.group(1);
      final index = budgets.indexWhere((b) => b['id'] == id);
      if (index < 0) {
        return _json({
          'error': {
            'code': 'NOT_FOUND',
            'message': 'Không tìm thấy ngân sách.',
          },
        }, status: 404);
      }
      final body = (options.data as Map).cast<String, dynamic>();
      lastBudgetBody = body;
      final updated = {...budgets[index], ...body};
      updated['rev'] = ((budgets[index]['rev'] as num).toInt()) + 1;
      budgets[index] = updated;
      return _json(updated);
    }

    // PATCH /v1/goals/<id>
    final goalMatch = RegExp(r'^/v1/goals/([^/]+)$').firstMatch(path);
    if (goalMatch != null) {
      final id = goalMatch.group(1);
      final index = goals.indexWhere((g) => g['id'] == id);
      if (index < 0) {
        return _json({
          'error': {'code': 'NOT_FOUND', 'message': 'Không tìm thấy mục tiêu.'},
        }, status: 404);
      }
      final body = (options.data as Map).cast<String, dynamic>();
      final updated = {...goals[index], ...body};
      final target = (updated['target_amount'] as num).toInt();
      final saved = (updated['saved_amount'] as num).toInt();
      updated['progress_pct'] = target == 0
          ? 0.0
          : (saved / target * 100).clamp(0, 100).toDouble();
      updated['rev'] = ((goals[index]['rev'] as num).toInt()) + 1;
      goals[index] = updated;
      return _json(updated);
    }

    // PATCH/DELETE /v1/wallets/<id>
    final walletMatch = RegExp(r'^/v1/wallets/([^/]+)$').firstMatch(path);
    if (walletMatch != null) {
      final id = walletMatch.group(1);
      final index = wallets.indexWhere((w) => w['id'] == id);
      if (index < 0) {
        return _json({
          'error': {'code': 'NOT_FOUND', 'message': 'Không tìm thấy ví.'},
        }, status: 404);
      }
      if (options.method == 'DELETE') {
        final removed = wallets.removeAt(index);
        removed['deleted_at'] = _nowIso();
        return _json(removed);
      }
      final body = (options.data as Map).cast<String, dynamic>();
      final updated = {...wallets[index], ...body};
      // API tính lại số dư theo số dư ban đầu mới, giao dịch giữ nguyên.
      final delta =
          ((body['initial_balance'] as num?)?.toInt() ?? 0) -
          ((wallets[index]['initial_balance'] as num?)?.toInt() ?? 0);
      updated['balance'] = ((wallets[index]['balance'] as num?) ?? 0) + delta;
      wallets[index] = updated;
      return _json(updated);
    }

    return _json({
      'error': {'code': 'NOT_FOUND', 'message': 'Không có endpoint $path.'},
    }, status: 404);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _json(Object? body, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _monthStartIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  }
}

/// Store trong bộ nhớ: phiên dev không có refresh token nên [ApiClient]
/// không cố gia hạn và không chạm secure storage.
class MemorySessionStore extends SessionStore {
  @override
  Future<AuthSession?> read() async => AuthSession(
    accessToken: 'token-gia',
    refreshToken: '',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );

  @override
  Future<void> write(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

/// Đã đăng nhập sẵn, để test vào thẳng app mà không đi qua form.
class SignedInController extends AuthController {
  @override
  Future<AuthSession?> build() async => AuthSession(
    accessToken: 'token-gia',
    refreshToken: '',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
}

/// App thật với API giả và phiên đăng nhập giả.
///
/// Trả cả widget thay vì danh sách override vì Riverpod 3 không export kiểu
/// `Override`; gói sẵn ở đây giữ test ngắn và không phải nhắc lại 3 override.
Widget testApp(FakeBackend backend) {
  final store = MemorySessionStore();
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000'))
    ..httpClientAdapter = backend;
  return ProviderScope(
    overrides: [
      financeApiProvider.overrideWithValue(
        FinanceApi(
          ApiClient(
            store: store,
            authApi: AuthApi(store: store),
            dio: dio,
          ),
        ),
      ),
      authControllerProvider.overrideWith(SignedInController.new),
    ],
    child: const StudentFinanceApp(),
  );
}

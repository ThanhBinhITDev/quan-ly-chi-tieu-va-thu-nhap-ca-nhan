import 'dart:convert';

import 'package:android/data/remote/dto.dart';
import 'package:flutter_test/flutter_test.dart';

/// JSON dưới đây chép nguyên văn từ API local đang chạy, không phải tự bịa.
/// Mục đích: khoá lại shape thật để đổi API là test đỏ ngay.
void main() {
  group('WalletDto', () {
    test('đọc đúng danh sách ví thật', () {
      const raw = '''
[{"id":"22222222-2222-4222-8222-222222222222","name":"Tien mat",
  "type":"cash","initial_balance":0,"balance":-135000,"color":null,
  "icon":null,"is_archived":false,"rev":1,"deleted_at":null},
 {"id":"33333333-3333-4333-8333-333333333333","name":"Nhay coc",
  "type":"bank","initial_balance":500000,"balance":430000,"color":null,
  "icon":null,"is_archived":false,"rev":3,"deleted_at":null}]''';
      final list = (jsonDecode(raw) as List)
          .map((e) => WalletDto.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(list, hasLength(2));
      expect(list[1].name, 'Nhay coc');
      expect(list[1].initialBalance, 500000);
      // `balance` là số dư server tính, khác initial_balance.
      expect(list[1].balance, 430000);
      expect(list[1].balance, isNot(equals(list[1].initialBalance)));
      expect(list[1].rev, 3);
      expect(list[0].isArchived, isFalse);
      expect(list[0].isDeleted, isFalse);
    });

    test('ví đã xoá mềm được nhận ra', () {
      const raw = '''
{"id":"44444444-4444-4444-8444-4444444444dd","name":"Thu mass assign",
 "type":"cash","initial_balance":0,"balance":0,"color":null,"icon":null,
 "is_archived":false,"rev":2,"deleted_at":"2026-11-19T18:36:34.845Z"}''';
      final dto = WalletDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      expect(dto.isDeleted, isTrue);
      expect(dto.deletedAt?.toUtc(), DateTime.utc(2026, 11, 19, 18, 36, 34, 845));
      expect(dto.rev, 2);
    });

    test('thiếu balance thì lùi về initial_balance, không nổ', () {
      final dto = WalletDto.fromJson(const {
        'id': 'w1',
        'name': 'Ví',
        'type': 'cash',
        'initial_balance': 120000,
        'rev': 1,
      });

      expect(dto.balance, 120000);
      expect(dto.isDeleted, isFalse);
    });

    test('đọc đúng tổng hợp số dư thật của /v1/wallets/summary', () {
      const raw = '''
{"wallets":[{"id":"22222222-2222-4222-8222-222222222222","name":"Tien mat",
  "type":"cash","is_archived":false,"balance":-135000},
 {"id":"33333333-3333-4333-8333-333333333333","name":"Nhay coc","type":"bank",
  "is_archived":false,"balance":430000}],
 "total_balance":295000,"by_type":{"cash":-135000,"bank":430000},
 "computed_at":"2026-11-19T18:35:58.218Z"}''';
      final dto = WalletBalanceSummaryDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      expect(dto.totalBalance, 295000);
      expect(dto.byType['cash'], -135000);
      expect(dto.byType['bank'], 430000);
      expect(dto.wallets, hasLength(2));
      expect(dto.computedAt.toUtc(), DateTime.utc(2026, 11, 19, 18, 35, 58, 218));
    });
  });

  group('CategoryDto', () {
    test('đọc đúng danh mục thật kèm deleted_at', () {
      const raw = '''
{"id":"aaaa1111-1111-4111-8111-111111111111",
 "user_id":"11111111-1111-4111-8111-111111111111","name":"Test cat",
 "type":"expense","icon":"tag","color":"#ffffff","parent_id":null,
 "is_system":false,"sort_order":0,"rev":2,
 "deleted_at":"2026-11-19T18:36:19.696Z"}''';
      final dto = CategoryDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      expect(dto.name, 'Test cat');
      expect(dto.isSystem, isFalse);
      expect(dto.rev, 2);
      expect(dto.isDeleted, isTrue);
      expect(
        dto.deletedAt?.toUtc(),
        DateTime.utc(2026, 11, 19, 18, 36, 19, 696),
      );
    });

    test('danh mục hệ thống chưa xoá có deletedAt null', () {
      final dto = CategoryDto.fromJson(const {
        'id': 'cat_food',
        'user_id': null,
        'name': 'Ăn uống',
        'type': 'expense',
        'is_system': true,
        'sort_order': 1,
        'rev': 1,
        'deleted_at': null,
      });

      expect(dto.isSystem, isTrue);
      expect(dto.isDeleted, isFalse);
    });
  });

  group('TransactionDto', () {
    test('đọc đúng một giao dịch thật', () {
      const raw = '''
{"id":"44444444-4444-4444-8444-444444444446",
 "wallet_id":"33333333-3333-4333-8333-333333333333","category_id":null,
 "type":"expense","amount":35000,"to_wallet_id":null,"note":"An sang",
 "occurred_at":"2026-11-19T18:30:00.000Z","occurred_on":"2026-11-20",
 "source":"manual","rev":1,"created_at":"2026-11-19T14:22:31.946Z",
 "updated_at":"2026-11-19T14:22:31.946Z","deleted_at":null}''';
      final dto = TransactionDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      expect(dto.type, ApiTransactionType.expense);
      expect(dto.amount, 35000);
      expect(dto.occurredOn, '2026-11-20');
      expect(dto.occurredAt.toUtc(), DateTime.utc(2026, 11, 19, 18, 30));
      expect(dto.isDeleted, isFalse);
    });

    test('giao dịch đã xoá mềm được nhận ra', () {
      const raw = '''
{"id":"1","wallet_id":"2","category_id":null,"type":"income","amount":1,
 "to_wallet_id":null,"note":null,"occurred_at":"2026-11-19T18:30:00.000Z",
 "occurred_on":"2026-11-20","rev":1,"deleted_at":"2026-11-19T18:40:00.000Z"}''';
      final dto = TransactionDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      expect(dto.isDeleted, isTrue);
      expect(dto.type, ApiTransactionType.income);
    });
  });

  group('BudgetProgressDto', () {
    test('used_pct là số nguyên vẫn đọc thành double', () {
      const raw = '''
{"budget_id":"bbbb1111-1111-4111-8111-111111111111","category_id":null,
 "name":"Tổng","amount":500000,"spent":170000,"remaining":330000,
 "used_pct":34,"status":"ok","days_left":11}''';
      final dto = BudgetProgressDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      expect(dto.name, 'Tổng');
      expect(dto.usedPct, 34.0);
      expect(dto.categoryId, isNull);
      expect(dto.status, 'ok');
    });
  });

  group('MonthSummaryDto', () {
    test('đọc đúng báo cáo tháng thật', () {
      const raw = '''
{"period":{"start":"2026-11-01","end":"2026-11-30","days_left":12},
 "income":0,"expense":170000,"remaining":330000,"daily_limit":27500,
 "budget":{"total":500000,"used_pct":34},"by_category":[],
 "by_day":[{"date":"2026-11-19","total":100000},
           {"date":"2026-11-20","total":70000}],
 "computed_at":"2026-11-19T17:16:06.663Z"}''';
      final dto = MonthSummaryDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );

      expect(dto.periodStart, '2026-11-01');
      expect(dto.daysLeft, 12);
      expect(dto.expense, 170000);
      expect(dto.dailyLimit, 27500);
      expect(dto.budgetUsedPct, 34.0);
      expect(dto.byDay, hasLength(2));
      expect(dto.byDay.last.total, 70000);
    });
  });

  group('MeDto', () {
    test('đọc đúng hồ sơ thật, phone null vẫn qua', () {
      const raw = '''
{"id":"11111111-1111-4111-8111-111111111111","email":"Test@Example.com",
 "phone":null,"display_name":"Binh Test","plan":"free","plan_expires_at":null,
 "currency":"VND","timezone":"Asia/Ho_Chi_Minh","onboarded_at":null,
 "created_at":"Thu Nov 19 2026 21:16:55 GMT+0700 (Indochina Time)"}''';
      final dto = MeDto.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(dto.displayName, 'Binh Test');
      expect(dto.plan, 'free');
      expect(dto.phone, isNull);
      expect(dto.currency, 'VND');
    });
  });
}
# 06 — Cấu trúc mã nguồn Flutter (Android + Web)

**Phiên bản:** 2.0 · **Ngày:** 2026-11-16 · **Trạng thái:** phạm vi thu về Android + Web (Q4). iOS dùng SwiftUI, xem [05](05-ios-structure.md).

Mục tiêu: chia lớp rõ ràng để ba người cùng làm không giẫm chân nhau, và để thay backend/AI sau này không phải sửa UI.

> **Phạm vi 2.0:** file này **chỉ còn Android và Web**. iOS tách riêng sang [05 — Cấu trúc iOS](05-ios-structure.md) vì dùng SwiftUI native (Liquid Glass). Mọi thứ dưới đây là Flutter.

---

## 1. Chọn công nghệ

| Thành phần | Chọn | Lý do | Phương án bị loại |
|---|---|---|---|
| Quản lý trạng thái | **Riverpod 2** | Không cần `BuildContext`, test được không cần widget, hỗ trợ `AsyncValue` sẵn cho trạng thái loading/lỗi | BLoC: nhiều mã lặp; Provider: khó test hơn; setState: không scale |
| Điều hướng | **go_router** | Khai báo tập trung, deep link cho thông báo đẩy | Navigator 1.0: khó quản lý |
| CSDL local | **drift** | Sinh mã từ SQL, type-safe, hỗ trợ reactive stream, có migration | sqflite: viết SQL thủ công, dễ sai; Isar: ít người dùng hơn |
| Gọi HTTP | **dio** | Interceptor cho token, retry, log | http: thiếu interceptor |
| Biểu đồ | **fl_chart** | Đủ loại cần dùng, cộng đồng lớn | syncfusion: giấy phép phức tạp |
| Định dạng tiền | **intl** | Chuẩn, có `NumberFormat.currency` | Tự viết: dễ sai dấu phân cách |
| Kiểm thử | **flutter_test + mocktail** | Có sẵn, mocktail không cần sinh mã | mockito: cần build_runner |

**Không dùng** `freezed` cho toàn bộ model ở MVP — `build_runner` chậm, thêm một lớp phức tạp. Chỉ dùng cho model có union (trạng thái đồng bộ, kết quả API).

---

## 2. Cây thư mục

```
lib/
├── main.dart
├── app.dart                          # MaterialApp, theme, router
│
├── core/                             # dùng chung, không biết gì về nghiệp vụ
│   ├── constants/
│   │   ├── app_config.dart           # URL API, khóa công khai
│   │   ├── limits.dart               # 3 ví, 10 danh mục, 10 lượt AI
│   │   └── strings_vi.dart           # toàn bộ chuỗi tiếng Việt
│   ├── theme/
│   │   ├── app_theme.dart            # light + dark
│   │   ├── app_colors.dart
│   │   └── app_text_styles.dart
│   ├── utils/
│   │   ├── money_formatter.dart      # 35000 → "35.000 đ"
│   │   ├── date_helper.dart          # ngày VN, kỳ tháng
│   │   └── result.dart               # Result<T> cho lỗi có kiểu
│   ├── error/
│   │   ├── app_exception.dart        # ValidationException, NetworkException...
│   │   └── error_mapper.dart         # code API → câu tiếng Việt
│   └── extensions/
│       └── context_ext.dart
│
├── data/                             # tầng dữ liệu
│   ├── local/
│   │   ├── database.dart             # AppDatabase (drift)
│   │   ├── tables/
│   │   │   ├── transactions_table.dart
│   │   │   ├── wallets_table.dart
│   │   │   ├── categories_table.dart
│   │   │   ├── budgets_table.dart
│   │   │   └── sync_queue_table.dart
│   │   ├── daos/
│   │   │   ├── transaction_dao.dart
│   │   │   ├── wallet_dao.dart
│   │   │   ├── category_dao.dart
│   │   │   ├── budget_dao.dart
│   │   │   └── sync_queue_dao.dart
│   │   └── seed/
│   │       └── default_categories.dart
│   │
│   ├── remote/
│   │   ├── api_client.dart           # dio + interceptor
│   │   ├── auth_api.dart
│   │   ├── transaction_api.dart
│   │   ├── wallet_api.dart
│   │   ├── budget_api.dart
│   │   ├── summary_api.dart          # /month-summary, /budget-progress
│   │   └── sync_api.dart             # /sync-push, /sync-pull
│   │
│   ├── models/                        # DTO, có fromJson/toJson
│   │   ├── transaction.dart
│   │   ├── wallet.dart
│   │   ├── category.dart
│   │   ├── budget.dart
│   │   ├── month_summary.dart
│   │   └── sync_change.dart
│   │
│   └── repositories/
│       ├── transaction_repository.dart
│       ├── wallet_repository.dart
│       ├── category_repository.dart
│       ├── budget_repository.dart
│       ├── summary_repository.dart
│       └── sync_repository.dart
│
├── domain/                            # logic nghiệp vụ thuần, không phụ thuộc Flutter
│   ├── entities/                      # model dùng trong UI
│   ├── services/
│   │   ├── daily_limit_calculator.dart # CÔNG THỨC TRUNG TÂM
│   │   ├── budget_status.dart
│   │   ├── quick_input_parser.dart     # "com 35k" → Transaction
│   │   └── sync_service.dart
│   └── usecases/
│       ├── add_transaction.dart
│       ├── delete_transaction.dart
│       ├── compute_month_summary.dart
│       └── check_limits.dart
│
├── presentation/
│   ├── providers/                      # Riverpod providers
│   │   ├── db_provider.dart
│   │   ├── api_provider.dart
│   │   ├── repository_providers.dart
│   │   ├── transaction_providers.dart
│   │   ├── wallet_providers.dart
│   │   ├── budget_providers.dart
│   │   ├── summary_providers.dart
│   │   ├── sync_providers.dart
│   │   └── auth_providers.dart
│   │
│   ├── screens/
│   │   ├── onboarding/
│   │   │   ├── splash_screen.dart
│   │   │   ├── onboarding_income_screen.dart
│   │   │   ├── onboarding_budget_screen.dart
│   │   │   └── onboarding_first_tx_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/
│   │   │       ├── daily_limit_card.dart
│   │   │       ├── summary_row.dart
│   │   │       ├── category_pie.dart
│   │   │       └── recent_transactions.dart
│   │   ├── transactions/
│   │   │   ├── transaction_list_screen.dart
│   │   │   ├── transaction_edit_screen.dart
│   │   │   └── widgets/
│   │   │       ├── transaction_tile.dart
│   │   │       └── filter_sheet.dart
│   │   ├── add_transaction/
│   │   │   ├── add_transaction_sheet.dart
│   │   │   ├── quick_input_sheet.dart
│   │   │   └── widgets/
│   │   │       ├── amount_input.dart
│   │   │       ├── category_grid.dart
│   │   │       └── type_selector.dart
│   │   ├── budget/
│   │   │   ├── budget_screen.dart
│   │   │   ├── budget_edit_screen.dart
│   │   │   └── widgets/budget_bar.dart
│   │   ├── report/
│   │   │   ├── report_screen.dart
│   │   │   └── widgets/
│   │   │       ├── daily_bar_chart.dart
│   │   │       └── category_ranking.dart
│   │   ├── account/
│   │   │   ├── account_screen.dart
│   │   │   ├── wallet_manage_screen.dart
│   │   │   ├── category_manage_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── auth/
│   │       ├── login_screen.dart
│   │       └── register_prompt_sheet.dart
│   │
│   ├── widgets/                        # dùng chung giữa các màn
│   │   ├── money_text.dart
│   │   ├── progress_bar.dart
│   │   ├── category_icon.dart
│   │   ├── empty_state.dart
│   │   ├── sync_badge.dart
│   │   └── loading_shimmer.dart
│   │
│   └── router/
│       └── app_router.dart
│
└── services/                           # tích hợp nền tảng
    ├── connectivity_service.dart
    ├── notification_service.dart
    ├── purchase_service.dart           # Google Play Billing / StoreKit
    └── secure_storage_service.dart
```

---

## 3. Quy tắc phụ thuộc giữa các tầng

```
presentation  →  domain  →  data
      ↓            ↓          ↓
    core        core        core
```

**Cấm:**

| Cấm | Vì sao |
|---|---|
| `domain` import `flutter/material.dart` | Logic phải test được bằng `dart test`, không cần Flutter |
| `presentation` gọi thẳng `data/remote` | Bỏ qua cache và đồng bộ → dữ liệu không nhất quán |
| `data` import `presentation` | Vòng phụ thuộc |
| Widget tự tính `daily_limit` | Phải gọi `DailyLimitCalculator` để một công thức duy nhất |

Có thể kiểm tra tự động bằng `dart_code_metrics` trong CI. Nếu vi phạm, build đỏ.

---

## 4. Công thức trung tâm — `daily_limit_calculator.dart`

Đây là tệp quan trọng nhất của toàn bộ mã nguồn. Chỉ số "hôm nay được tiêu" là lý do người dùng mở app.

```dart
class DailyLimitCalculator {
  /// Trả về số tiền được tiêu hôm nay.
  /// remaining <= 0 → trả về chính remaining (số âm), KHÔNG chia.
  /// Quyết định Q3: chỉ cộng giao dịch type = 'expense', bỏ qua 'transfer'.
  static int calculate({
    required int budget,        // ngân sách tổng kỳ này, 0 nếu chưa đặt
    required int spent,         // đã chi từ đầu kỳ đến hết hôm nay, CHỈ expense
    required int daysLeft,      // số ngày còn lại, TÍNH CẢ HÔM NAY
  }) {
    if (budget <= 0) return 0;

    final remaining = budget - spent;
    if (remaining <= 0) return remaining;   // âm, UI hiện "đã vượt"
    if (daysLeft <= 0) return remaining;    // hết kỳ, không chia

    return remaining ~/ daysLeft;           // chia LẤY NGUYÊN, không làm tròn
  }
}
```

**Ba cạm bẫy phải có test:**

| Cạm bẫy | Sai | Đúng |
|---|---|---|
| Làm tròn | `(1150000 / 18).round()` = 63889, tổng 18 ngày = 1.150.002 → vượt 2 đồng | `1150000 ~/ 18` = 63888, tổng 1.149.984, an toàn |
| `daysLeft` không tính hôm nay | Ngày 30/11 với kỳ hết 30/11 → `daysLeft = 0` → chia cho 0 | `daysLeft = 1` |
| `remaining` âm mà vẫn chia | `-120000 / 5` = -24000 → hiện "được tiêu 24.000" sai dấu | Trả `-120000`, UI hiện "đã vượt 120.000" |

### Bộ test bắt buộc

```dart
test('ngân sách 3tr, đã chi 1.85tr, còn 18 ngày', () {
  expect(DailyLimitCalculator.calculate(
    budget: 3000000, spent: 1850000, daysLeft: 18), 63888);
});

test('đã vượt ngân sách trả về số âm, không chia', () {
  expect(DailyLimitCalculator.calculate(
    budget: 3000000, spent: 3120000, daysLeft: 18), -120000);
});

test('ngày cuối kỳ daysLeft = 1', () {
  expect(DailyLimitCalculator.calculate(
    budget: 3000000, spent: 1850000, daysLeft: 1), 1150000);
});

test('chưa đặt ngân sách trả về 0', () {
  expect(DailyLimitCalculator.calculate(
    budget: 0, spent: 500000, daysLeft: 18), 0);
});

test('chia không hết thì không được vượt ngân sách', () {
  const budget = 100000, spent = 0, days = 3;
  final d = DailyLimitCalculator.calculate(
    budget: budget, spent: spent, daysLeft: days);
  expect(d * days, lessThanOrEqualTo(budget));  // 33333 * 3 = 99.999 ✓
});

test('chuyển ví không được tính vào spent (Q3)', () {
  // 1 expense 100.000 + 1 transfer 200.000
  // spent phải là 100.000, không phải 300.000
  const spent = 100000;
  const budget = 1000000;
  final d = DailyLimitCalculator.calculate(
    budget: budget, spent: spent, daysLeft: 10);
  expect(d, 90000);  // (1.000.000 - 100.000) / 10
});
```

Test cuối là test then chốt: nếu dùng `round()` sẽ ra 33333 (may mắn) nhưng với bộ số khác sẽ vượt. Phải chạy property test với 1.000 bộ số ngẫu nhiên.

---

## 5. Riverpod — mẫu sử dụng

### Provider cho repository

```dart
final dbProvider = Provider<AppDatabase>((ref) => AppDatabase());

final transactionRepoProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    local: ref.watch(dbProvider),
    api: ref.watch(apiClientProvider),
  );
});
```

### Provider cho dữ liệu reactive

Dùng `StreamProvider` vì drift trả về stream — khi ghi vào DB, UI tự cập nhật:

```dart
final recentTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  return ref.watch(transactionRepoProvider).watchRecent(limit: 10);
});
```

### Chỉ số hôm nay — phụ thuộc nhiều nguồn

```dart
final dailyLimitProvider = Provider.autoDispose<AsyncValue<DailyLimit>>((ref) {
  final budget = ref.watch(currentBudgetProvider);
  final spent  = ref.watch(monthSpentProvider);

  return budget.when(
    data: (b) => spent.when(
      data: (s) => AsyncData(DailyLimit(
        amount: DailyLimitCalculator.calculate(
          budget: b?.amount ?? 0,
          spent: s,
          daysLeft: DateHelper.daysLeftInMonth(),
        ),
        budget: b?.amount ?? 0,
        spent: s,
      )),
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    ),
    loading: () => const AsyncLoading(),
    error: AsyncError.new,
  );
});
```

Dài dòng, nhưng **đúng**: khi ghi giao dịch → `monthSpentProvider` phát giá trị mới → `dailyLimitProvider` tự tính lại → UI tự vẽ lại. Không cần gọi `setState` ở đâu.

### Quy ước đặt tên

| Hậu tố | Loại | Ví dụ |
|---|---|---|
| `*Provider` | Provider thường | `dbProvider` |
| `*StreamProvider` | Stream | `recentTransactionsProvider` |
| `*NotifierProvider` | Có state thay đổi | `addTransactionNotifierProvider` |
| `*Repository` | Truy cập dữ liệu | `TransactionRepository` |
| `*Service` | Logic nghiệp vụ | `SyncService` |
| `*Calculator`, `*Parser` | Hàm thuần | `DailyLimitCalculator` |

---

## 6. Repository — mẫu local-first

Mọi repository theo cùng một khuôn: **ghi local trước, đẩy sync sau**.

```dart
class TransactionRepository {
  final TransactionDao local;
  final SyncQueueDao queue;

  Stream<List<Transaction>> watchRecent({int limit = 10}) =>
      local.watchRecent(limit);

  Future<Transaction> add(TransactionDraft draft) async {
    final tx = Transaction(
      id: const Uuid().v4(),          // sinh trên máy
      ...draft.toEntity(),
      rev: 1,
      syncStatus: SyncStatus.pending,
      occurredAt: DateTime.now().toUtc(),
      occurredOn: DateHelper.todayVn(),
    );

    await local.insert(tx);           // 1. ghi local
    await queue.enqueue(               // 2. đưa vào hàng đợi
      table: 'transactions',
      recordId: tx.id,
      op: SyncOp.insert,
      payload: tx.toJson(),
      rev: 1,
    );
    // 3. không chờ mạng — SyncService tự đẩy khi có kết nối
    return tx;
  }
}
```

**UI không bao giờ `await` mạng khi lưu giao dịch.** Nếu chờ, app sẽ treo khi mất mạng.

---

## 7. Xử lý lỗi

### Lỗi có kiểu, không dùng `String` làm lỗi

```dart
sealed class AppException implements Exception {
  final String code;
  const AppException(this.code);
}

class ValidationException extends AppException {
  final String field;
  ValidationException(this.field) : super('VALIDATION_FAILED');
}

class NetworkException extends AppException {
  NetworkException() : super('NETWORK');
}

class PlanLimitException extends AppException {
  final int limit;
  PlanLimitException(this.limit) : super('PLAN_LIMIT');
}

class QuotaException extends AppException {
  final DateTime resetAt;
  QuotaException(this.resetAt) : super('QUOTA_EXCEEDED');
}
```

### Ánh xạ sang câu tiếng Việt

Tập trung một chỗ, không rải rác trong widget:

```dart
String errorMessage(AppException e) => switch (e) {
  ValidationException(:final field) => 'Vui lòng kiểm tra lại $field',
  NetworkException()                => 'Không có kết nối mạng. Dữ liệu đã được lưu trên máy.',
  PlanLimitException(:final limit)  => 'Gói miễn phí chỉ cho phép $limit. Nâng cấp để thêm.',
  QuotaException(:final resetAt)    => 'Đã hết lượt trong tháng. Lượt mới vào ${formatDate(resetAt)}.',
  _                                 => 'Có lỗi xảy ra. Vui lòng thử lại.',
};
```

Câu của `NetworkException` rất quan trọng: phải nói **"dữ liệu đã được lưu trên máy"** để người dùng không tưởng mất dữ liệu rồi nhập lại.

---

## 8. Kiểm thử

| Loại | Phạm vi | Số lượng mục tiêu | Công cụ |
|---|---|---|---|
| Đơn vị | `DailyLimitCalculator`, `QuickInputParser`, `DateHelper` | ≥ 40 test | `flutter_test` |
| Đơn vị | Repository với DAO giả | ≥ 25 | `mocktail` |
| Widget | Màn thêm giao dịch, thẻ chỉ số hôm nay | ≥ 15 | `flutter_test` |
| Tích hợp | Thêm giao dịch → chỉ số cập nhật → đồng bộ | ≥ 5 | `integration_test` |
| Đối chiếu | Công thức Dart vs SQL, 20 bộ số | 1 bộ | script |

**Test đối chiếu công thức** là bắt buộc: chạy cùng 20 bộ `(budget, spent, daysLeft)` qua Dart và qua SQL, kết quả phải giống nhau. Nếu lệch, chỉ số trên app khác chỉ số trong push notification.

### Cấu trúc test

```
test/
├── domain/
│   ├── daily_limit_calculator_test.dart
│   ├── quick_input_parser_test.dart
│   └── budget_status_test.dart
├── data/
│   └── transaction_repository_test.dart
└── widget/
    ├── add_transaction_sheet_test.dart
    └── daily_limit_card_test.dart
```

---

## 9. CI

GitHub Actions, chạy mỗi pull request:

```yaml
name: ci
on: [pull_request, push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.x', channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: dart format --set-exit-if-changed lib test
      - run: flutter analyze --fatal-infos
      - run: flutter test --coverage
      - run: dart run dart_code_metrics:metrics analyze lib
```

**`--fatal-infos`:** coi cả thông tin là lỗi. Khó chịu lúc đầu nhưng giữ mã sạch về sau.

---

## 10. Quy ước viết mã

| Quy ước | Nội dung |
|---|---|
| Ngôn ngữ đặt tên | Tiếng Anh cho mã, tiếng Việt cho chuỗi hiển thị |
| Chuỗi hiển thị | Tập trung trong `strings_vi.dart`, không hardcode trong widget |
| Số tiền | Luôn `int` (đồng). Không dùng `double` ở bất kỳ đâu |
| Thời gian | `DateTime` UTC trong data, đổi sang giờ VN ở presentation |
| Tệp | Một lớp công khai một tệp, tên `snake_case` |
| Độ dài hàm | Dưới 50 dòng; widget dưới 150 dòng (tách widget con) |
| Comment | Chỉ comment cho phần **vì sao**, không cho phần **làm gì** |

**Về số tiền:** dùng `double` cho tiền là lỗi nghiêm trọng. `0.1 + 0.2 != 0.3` trong số thực nhị phân, và với tiền thì sai một đồng cũng là sai.

---

## 11. Thứ tự triển khai

| Tuần | Việc | Đầu ra kiểm chứng được |
|---|---|---|
| 1 | `core`, `data/local` (drift), seed danh mục | Mở app, thấy danh mục mặc định |
| 2 | Onboarding 3 bước + màn thêm giao dịch | Ghi được giao dịch, thấy trong danh sách |
| 3 | `DailyLimitCalculator` + Trang chủ + test | Chỉ số hôm nay đúng, 40 test xanh |
| 4 | Ngân sách, danh sách giao dịch, sửa/xóa | Dùng được hoàn toàn offline |
| 5 | Biểu đồ, báo cáo | Có biểu đồ tròn và cột |
| 6 | Auth + `sync-push`/`sync-pull` | Đăng nhập, đăng xuất, dữ liệu còn |
| 7 | Thông báo đẩy, ví, cài đặt | Nhắc cuối ngày hoạt động |
| 8 | Kiểm thử, sửa lỗi, closed testing | Bản nộp |

**MVP xong ở tuần 6** (chưa có thông báo). Đây là mốc cần cho bản dự thi.

---

## 12. Điểm cần bạn quyết

| # | Vấn đề | Đề xuất | Phương án khác |
|---|---|---|---|
| 1 | Riverpod hay BLoC | Riverpod | BLoC nếu đội đã quen |
| 2 | drift hay sqflite | drift | sqflite nếu muốn ít thư viện |
| 3 | Có dùng `freezed` không | Chỉ cho model có union | Dùng toàn bộ, an toàn hơn nhưng build chậm |
| 4 | Tách `domain/entities` khỏi `data/models` | Có | Gộp một, ít mã hơn nhưng dễ lẫn DTO vào UI |
| 5 | Có `usecases` riêng hay gọi repository trực tiếp | Chỉ 4 usecase quan trọng | Bỏ hẳn, gọi repository từ provider |

Điểm 5: chỉ giữ usecase cho luồng có nhiều bước (`add_transaction` phải kiểm tra hạn mức gói, sinh ID, ghi local, đẩy queue, kiểm tra đề nghị đăng ký). Các thao tác đơn giản gọi repository trực tiếp cho gọn.

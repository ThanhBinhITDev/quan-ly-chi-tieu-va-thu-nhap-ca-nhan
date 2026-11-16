# 05 — Cấu trúc mã nguồn iOS (SwiftUI)

**Phiên bản:** 2.0 · **Ngày:** 2026-11-16 · **Trạng thái:** bản nháp đầu

iOS làm **native SwiftUI** (Q4). Android dùng Flutter ([06](06-flutter-structure.md)); Web dùng Next.js ([apps/web](../../apps/web/README.md)). Ba nền không share mã.

---

## 1. Vì sao tách riêng (tóm tắt Q4)

| Vấn đề | Flutter | Native SwiftUI |
|---|---|---|
| Liquid Glass (iOS 26) | Chỉ làm `BackdropFilter` giả, không có khúc xạ thật | Dùng hệ vật liệu của hệ điều hành |
| SF Symbols, App Intents, WidgetKit | Hỗ trợ hạn chế, phải viết plugin | Có sẵn, cập nhật theo hệ điều hành |
| Độ trễ cảm ứng, chất lượng cuộn | Tốt nhưng không bằng native | Tối đa |
| Chi phí | 1 codebase | Sửa 2 lần, test 2 lần, phát hành 2 lần |

Đánh đổi này chấp nhận vì: Liquid Glass là điểm khác biệt giao diện chính trong bản demo, và demo chạy trên iPhone (chờ quyết D4).

---

## 2. Chọn công nghệ

| Thành phần | Chọn | Lý do | Phương án bị loại |
|---|---|---|---|
| UI | **SwiftUI + Liquid Glass (iOS 26)** | Native, chất lượng cuộn, hệ vật liệu thật | UIKit: nhiều mã, khó khớp thiết kế nhanh |
| CSDL local | **SwiftData** | Native, sinh mã ít, tích hợp SwiftUI, hỗ trợ migration | GRDB: linh hoạt hơn nhưng thêm thư viện; Core Data: lỗi thời |
| Trạng thái | **@Observable** (Observation framework, iOS 17+) | Nhẹ, test được, không cần thư viện bên ngoài | TCA: mạnh nhưng học chậm, không cần cho MVP |
| Gọi HTTP | **URLSession async/await** | Có sẵn trong hệ thống | Alamofire: thêm thư viện, lợi ích nhỏ ở MVP |
| Biểu đồ | **Swift Charts** | Native, khớp thiết kế, đủ loại tròn/cột/dòng | Thư viện bên thứ ba: không cần |
| Định dạng tiền | **Foundation `FormatStyle`** | `0.5` → `500.000 đ` theo vùng VN, chuẩn hệ thống | Tự viết: dễ sai dấu phân cách |
| Widget | **WidgetKit + App Intents** | Widget "hôm nay được tiêu" một chạm | — |
| Thông báo cục bộ | **UNUserNotificationCenter** | Nhắc cuối ngày không cần server | — |
| Kiểm thử | **XCTest + XCUITest** | Có sẵn; snapshot test chọn thêm nếu cần | — |

**Nguyên tắc:** mọi logic tính toán (hạn mức hôm nay, tổng chi, tiến độ ngân sách) nằm trong **đại diện model** thuần Swift, không nằm trong view hay view-model — để bộ test không cần chạy UI.

---

## 3. Cây thư mục

```
iOS/
├── App/
│   ├── ExpenseApp.swift               # @main, WindowGroup
│   ├── AppRouter.swift                # điều hướng, deep link
│   └── RootView.swift
├── Features/
│   ├── Home/                          # trang chủ + chỉ số hôm nay
│   │   ├── HomeView.swift
│   │   ├── TodayLimitCard.swift
│   │   └── HomeViewModel.swift        # @Observable, mỏng
│   ├── Transactions/                  # danh sách, thêm, sửa, xóa
│   ├── Wallets/
│   ├── Budgets/
│   ├── Reports/                       # biểu đồ tròn, xu hướng
│   ├── Onboarding/
│   ├── Auth/
│   ├── Settings/
│   └── QuickEntry/                    # nhập nhanh "com 35k"
├── Core/
│   ├── Money/
│   │   ├── MoneyFormatter.swift       # 100000 → "100.000 đ"
│   │   └── MoneyParser.swift          # "com 35k" → (35000, "Ăn uống")
│   ├── Limit/
│   │   ├── DailyLimitCalculator.swift # công thức trung tâm, thuần Swift
│   │   └── BudgetProgress.swift       # 0–100%, ngưỡng 70/90/100
│   ├── Theme/
│   │   ├── LiquidGlassTheme.swift     # hệ vật liệu iOS 26
│   │   ├── AppColors.swift
│   │   └── SFIcons.swift             # bản đồ tên icon → SF Symbol
│   └── Components/
│       ├── AmountField.swift
│       ├── CategoryPicker.swift
│       ├── ProgressBar.swift
│       └── CategoryChartCard.swift
├── Data/
│   ├── Local/
│   │   ├── Models/                    # @Model SwiftData
│   │   │   ├── User.swift
│   │   │   ├── Wallet.swift
│   │   │   ├── Category.swift
│   │   │   ├── Transaction.swift
│   │   │   └── Budget.swift
│   │   ├── Seed/
│   │   │   └── DefaultCategories.swift
│   │   └── Sync/
│   │       ├── SyncQueue.swift        # hàng đợi đẩy/kéo cục bộ
│   │       └── ConflictResolver.swift # LWW theo rev, như [03](03-sync-strategy.md)
│   ├── Remote/
│   │   ├── APIClient.swift            # URLSession, token, retry
│   │   ├── AuthAPI.swift
│   │   └── Models/                   # DTO, không dùng @Model
│   └── Repositories/
│       ├── WalletRepository.swift     # protocol
│       ├── LocalWalletRepository.swift
│       └── ...
├── Domain/
│   ├── Entities/                      # struct thuần, dùng trong test
│   └── UseCases/                      # AddTransaction, ComputeDailyLimit
└── Tests/
    ├── Unit/
    │   ├── DailyLimitCalculatorTests.swift
    │   ├── MoneyParserTests.swift
    │   └── ConflictResolverTests.swift
    ├── Integration/
    └── UI/
```

---

## 4. Quy tắc phụ thuộc giữa các tầng

| Tầng | Được dùng | Không được dùng |
|---|---|---|
| `Features/` | `Core/`, `Data/Repositories` (protocol), `Domain/` | `Data/Local`, `Data/Remote`, SwiftData, URLSession |
| `Core/` | Foundation, số học thuần | Mọi thứ khác — không biết app, không biết DB |
| `Data/Local` | SwiftData, `Domain/Entities` | `Features/` |
| `Data/Remote` | URLSession, DTO | `Features/`, SwiftData |
| `Domain/` | Foundation thôi | Mọi thứ khác |

**Hệ quả:** `DailyLimitCalculator` nằm trong `Core/Limit`, chỉ nhận struct đầu vào và trả struct đầu ra. Chạy được trong test không cần Xcode Simulator, không cần SwiftData.

---

## 5. Công thức trung tâm — `DailyLimitCalculator`

Giống hệt [06](06-flutter-structure.md) và công thức Web, khác ở cú pháp Swift:

```swift
struct LimitInput: Equatable {
    let budgetMonth: Int64        // đồng
    let spentMonth: Int64
    let daysInPeriod: Int
    let daysLeft: Int            // tính cả hôm nay
}

struct LimitResult: Equatable {
    let todayMax: Int64          // >= 0
    let budgetExhausted: Bool
}

enum DailyLimitCalculator {
    static func calculate(_ in: LimitInput) -> LimitResult { ... }
}
```

**Bộ test bắt buộc** (như [06](06-flutter-structure.md)): đủ số, thiếu 1 ngày, ngân sách 0, đã chi vượt ngân sách, ngày 31, tháng 30/31 ngày, biên `daysLeft = 0`.

**Riêng iOS:** bộ test này **dùng chung bộ số liệu** với bản Flutter và bản Web — ba file test viết độc lập nhưng đọc cùng một file số liệu, để phát hiện lệch giữa ba nền tảng. Ghi chú này quan trọng vì bug "iOS tính 96.000, Android tính 95.800" chỉ lộ khi so hai nền với nhau.

---

## 6. SwiftData — mẫu

```swift
@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var wallet: Wallet?
    var category: Category?
    var toWallet: Wallet?
    var type: TransactionType     // .expense, .income, .transfer
    var amount: Int64             // đồng, luôn > 0
    var note: String?
    var occurredAt: Date
    var rev: Int
    var deletedAt: Date?
    var synced: Bool
    // ...
}
```

| Vấn đề | Cách xử lý |
|---|---|
| `@Model` không serialize được sang JSON | Repository đổi qua `Domain/Entities` (struct) khi đẩy/kéo; DTO riêng cho API |
| Query theo tháng | `#Predicate` với ngày đầu/tháng cuối; index SwiftData hạn chế — đo lại khi dữ liệu lớn |
| Migration | `VersionedSchema` + `MigrationPlan`, giữ mỗi schema từng version |
| Dữ liệu mẫu onboarding | Seed một lần, kiểm tra `hasSeeded` trước khi chạy |

**Điểm cần kiểm chứng trong tuần 1:** SwiftData có chịu được query thống kê "tổng chi tháng theo danh mục" với 3.000 dòng trong 50 ms không. Nếu không, chuyển sang GRDB (SQLite trực tiếp) — thay đổi nằm gọn trong `Data/Local`, các tầng khác không động.

---

## 7. App Intents và Widget

| Thành phần | Việc làm |
|---|---|
| Widget "Hôm nay được tiêu" | Đọc từ App Group (dùng chung `UserDefaults` + SwiftData store), không gọi API |
| App Intent `AddExpense` | "Thêm khoản chi 35.000đ ăn trưa" — chạy nhanh, không mở app |
| App Intent `MonthlySummary` | Trả lời Siri "tháng này chi bao nhiêu" — đọc số liệu đã tính, không tính lại |

Nguyên tắc: App Intent chỉ **đọc kết quả đã tính sẵn** hoặc **ghi một giao dịch** — không bao giờ chạy tính toán phức tạp trong intent.

---

## 8. Kiểm thử

| Tầng | Công cụ | Tiêu chuẩn |
|---|---|---|
| Đơn vị | XCTest | 100% nhánh trong `Core/` |
| Repository | SwiftData in-memory (`ModelContainer` nhớ) | CRUD + sync queue |
| API | `URLProtocol` giả | Token hết hạn, lỗi mạng, xung đột |
| UI chính | XCUITest | 1 luồng: onboarding → ghi khoản → thấy chỉ số |
| Snapshot | swift-snapshot-testing (chọn) | Chỉ cho 5 màn hình chính |

**CI:** GitHub Actions với `xcodebuild test` trên simulator, chạy mọi push. Snapshot test chạy hằng đêm.

---

## 9. Quy ước viết mã

| Quy ước | Nội dung |
|---|---|
| Tiền | `Int64`, đơn vị đồng, mọi hàm ghi rõ `// đơn vị: đồng` |
| Ngày | `Date` UTC khi lưu; hiển thị qua `FormatStyle` vùng VN |
| Sai | `enum APIError: Error` có mã, không dùng `String` |
| View | Mỗi view một file, dưới 150 dòng; tách component khi vượt |
| `@Observable` | View-model chỉ giữ dữ liệu hiển thị, không gọi repository trực tiếp trong `body` |
| Async | `async/await` cho API; không dùng `DispatchQueue` |

---

## 10. Thứ tự triển khai

| Tuần | Việc | Đầu ra kiểm chứng được |
|---|---|---|
| 1 | `Core/`, SwiftData + seed, kiểm chứng hiệu năng query | Query thống kê 3.000 dòng < 50 ms |
| 2 | Onboarding + QuickEntry + Trang chủ | Ghi được giao dịch, thấy chỉ số hôm nay |
| 3 | `DailyLimitCalculator` + 40 test + Widget | Widget hiện số đúng |
| 4 | Ngân sách, danh sách giao dịch, ví | Dùng offline hoàn toàn |
| 5 | Biểu đồ (Swift Charts), báo cáo | Biểu đồ tròn + cột chạy thật |
| 6 | Auth + đồng bộ + App Intents | Đăng nhập, 2 thiết bị không mất dữ liệu |

Chạy **song song với Android và Web**: tuần 1–2 cả ba nền cùng dựng khung; từ tuần 3 tách hẳn (iOS làm widget + Liquid Glass; Android làm nhập nhanh + ngân sách; Web làm báo cáo đọc).

---

## 11. Điểm cần bạn quyết

| # | Vấn đề | Đề xuất | Phương án khác |
|---|---|---|---|
| 1 | SwiftData hay GRDB từ đầu | SwiftData; chuyển GRDB nếu query chậm | GRDB từ đầu, chắc chắn hơn |
| 2 | Tối thiểu iOS nào | iOS 18 (để có đủ API Liquid Glass + App Intents ổn định) | iOS 26 nếu demo bắt buộc iPhone mới |
| 3 | Có viết App Intents cho MVP không | Có, chỉ `AddExpense` | Bỏ, ưu tiên widget |
| 4 | Snapshot test có cần không | Có, 5 màn hình chính | Bỏ, tiết kiệm thời gian |

**Nghi ngờ cần xác minh trước khi cam kết:** tên API Liquid Glass cụ thể trong SDK iOS 26 — cần kiểm chứng trên Xcode mới trước khi viết `LiquidGlassTheme.swift`.

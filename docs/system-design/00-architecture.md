# 00 — Kiến trúc hệ thống

Tài liệu gốc của bộ thiết kế. Mọi tài liệu khác (`01`–`07`) triển khai chi tiết nội dung ở đây.

Phiên bản 2.0 — 2026-11-16. Thay thế bản 1.1 (một nền tảng Flutter cho cả iOS và Android).

---

## 1. Mục tiêu và ràng buộc
### Mục tiêu kiến trúc

| # | Mục tiêu | Cách đo |
|---|---|---|
| M1 | Ghi một khoản chi khi không có mạng | Tắt wifi + 4G, ghi 5 khoản, mở lại app vẫn còn đủ |
| M2 | Không mất dữ liệu khi đồng bộ | Đồng bộ 1.000 lượt liên tiếp, đối chiếu checksum hai đầu khớp |
| M3 | Không tạo bản ghi trùng | Chạy lại cùng một gói tin 10 lần, số bản ghi không đổi |
| M4 | Ba nền tảng dùng chung một nguồn sự thật | Web, iOS, Android đọc cùng dữ liệu, số liệu khớp từng đồng |
| M5 | Đổi nhà cung cấp AI không sửa client | Chỉ sửa cấu hình server, không phát hành bản mới |
| M6 | Chi phí hạ tầng giai đoạn đầu dưới 500.000đ/tháng | Hoá đơn thực tế ba tháng đầu |

### Ràng buộc

| Loại | Ràng buộc | Hệ quả lên kiến trúc |
|---|---|---|
| Nhân lực | 1 người làm kỹ thuật, part-time | Không viết native cho nhiều nền tảng; không tự dựng backend từ đầu |
| Thời gian | 10 tuần tới ngày nộp | MVP chạy được ở tuần 6 ([lộ trình](../05-lo-trinh.md)) |
| Tiền | 0đ hạ tầng giai đoạn đầu | Chỉ dùng gói miễn phí; không thuê VPS riêng |
| Pháp lý | Không có giấy phép trung gian thanh toán | App **không giữ tiền**, không nạp, không rút, không liên kết ngân hàng |
| Thị trường | Người dùng chủ yếu Android tầm trung | Thiết kế trên 360dp trước, không thiết kế trên iPhone rồi thu nhỏ |

### Ngoài phạm vi (không thiết kế ở bản này)

MVP chỉ nhập tay. Các mục sau để giai đoạn sau, chưa thiết kế: đọc sao kê ngân hàng, share sheet từ app khác, OCR hoá đơn (ML Kit). Mục tiêu tiết kiệm có trong MVP, nhập tay, không gắn số dư ví (Q8). Đọc tiền qua API ngân hàng: Việt Nam chưa có chuẩn Open Banking mở. Đọc thông báo hệ điều hành: không đáng tin trên ROM Trung Quốc.

---

## 2. Quyết định nền tảng đã chốt
| # | Quyết định | Ngày | Hệ quả |
|---|---|---|---|
| Q1 | Không lưu `balance` trong `wallets`; số dư luôn tính từ giao dịch | 2026-11-13 | `transactions` là nguồn sự thật duy nhất |
| Q3 | Chuyển ví không tính vào tổng chi | 2026-11-13 | Mọi truy vấn tổng chi phải có `AND type = 'expense'` |
| Q4 | **Ba nền tảng, ba công nghệ riêng:** iOS SwiftUI native; Android Flutter; Web Next.js (React, TypeScript) | 2026-11-16 | Ba codebase, ba ngôn ngữ, một hợp đồng API (OpenAPI) |
| Q5 | **Backend tách khỏi Supabase: NestJS tự viết, Supabase chỉ làm Postgres + Auth + Storage** | 2026-11-16 | Logic nghiệp vụ nằm ở nơi kiểm thử được |
| Q6 | **Cron chạy trong worker NestJS + BullMQ, không dùng pg_cron hay Edge Functions** | 2026-11-16 | Có retry, có dead-letter, có log |
| Q7 | Loại bỏ tính năng mục tiêu tiết kiệm | 2026-11-16 | Đã bị đảo bởi Q8 |
| Q8 | **Mục tiêu tiết kiệm trở lại, nhập tay, không gắn ví** | 2026-11-17 | Bảng `goals` có `saved_amount` nhập tay; không khoá ngoại tới `wallets`; giai đoạn sau mới xét ví `savings` |
| Q9 | **Chia tiền nhóm (Split Bill) vào MVP** | 2026-11-17 | Thêm 4 bảng; RLS theo thành viên nhóm; người trả chỉ ghi phần của mình vào sổ cá nhân |

> Q2 cũ ("mục tiêu tiết kiệm tách khỏi ví") không còn hiệu lực: Q7 loại tính năng, rồi Q8 đưa trở lại nhưng **không gắn ví**. Trạng thái hiện tại do Q8 quyết.

### Vì sao mỗi nền chọn một công nghệ

| Nền tảng | Chọn | Lý do | Không chọn |
|---|---|---|---|
| iOS | SwiftUI native | Liquid Glass (iOS 26) chỉ có ở native: Flutter tự vẽ canvas nên chỉ làm được `BackdropFilter`, không khúc xạ. Nhóm có Mac + Xcode, iOS là máy trình bày | Flutter cho iOS: mất Liquid Glass thật |
| Android | Flutter | Chiếm đa số người dùng; một codebase Dart, phù hợp đội 1 người làm kỹ thuật | Native Kotlin: tốn thời gian gấp đôi |
| Web | Next.js (React, TypeScript) | SEO, tải trang nhanh (~150 KB so với 2–3 MB của Flutter Web), hệ sinh thái React, dùng chung TypeScript với backend | Flutter Web: nặng, SEO kém, canvas không được lập chỉ mục |

**Đánh đổi phải nói rõ:** ba codebase = ba lần sửa lỗi, ba lần viết test, ba lần phát hành. Bù lại bằng hợp đồng API duy nhất ([08](08-api-principles.md)) và bộ số liệu test dùng chung cho công thức "hôm nay được tiêu". Nếu thời gian eo hẹp, cắt phạm vi Web xuống landing + đăng nhập, không cắt iOS.

---

## 3. Sơ đồ C4 — mức 1 (bối cảnh)
Ai dùng hệ thống và hệ thống nói chuyện với những đâu.

```mermaid
graph TB
    SV["Sinh viên<br/>người dùng cuối"]
    ADM["Nhóm phát triển<br/>vận hành, xem số liệu"]

    subgraph SYS["Hệ thống Quản lý Chi tiêu"]
        CORE["Ứng dụng<br/>ghi chi tiêu, tính hạn mức"]
    end

    IDP["Supabase Auth<br/>đăng nhập, phát JWT"]
    DB["Supabase Postgres<br/>dữ liệu người dùng"]
    ST["Supabase Storage<br/>ảnh hoá đơn"]
    FCM["Firebase Cloud Messaging<br/>thông báo đẩy"]
    GEM["Gemini API<br/>đọc hoá đơn, hỏi đáp"]
    GP["Google Play Billing<br/>App Store"]
    MON["Giám sát<br/>log, lỗi, chi phí"]

    SV -->|"dùng trên iOS, Android, Web"| CORE
    CORE -->|"đăng nhập, lấy token"| IDP
    CORE -->|"đọc ghi dữ liệu"| DB
    CORE -->|"lưu ảnh hoá đơn"| ST
    CORE -->|"gửi thông báo"| FCM
    CORE -->|"gọi mô hình AI"| GEM
    CORE -->|"kiểm tra quyền mua"| GP
    CORE -->|"đẩy log, chỉ số"| MON
    ADM -->|"xem bảng điều khiển"| MON

    classDef ext fill:#F5F5F5,stroke:#9E9E9E
    classDef sys fill:#E8F3EA,stroke:#2D7C3D
    class IDP,DB,ST,FCM,GEM,GP,MON ext
    class CORE sys
```

### Thành phần ngoài hệ thống

| Thành phần | Vai trò | Nếu hỏng thì sao |
|---|---|---|
| Supabase Auth | Cấp và làm mới token | Không đăng nhập được mới; phiên cũ vẫn dùng tới khi token hết hạn |
| Supabase Postgres | Lưu dữ liệu gốc | App vẫn ghi được (local-first), đồng bộ dừng |
| Supabase Storage | Ảnh hoá đơn | Không tải ảnh lên được, giao dịch vẫn lưu |
| Firebase Cloud Messaging | Gửi thông báo | Không có thông báo; app vẫn chạy bình thường |
| Gemini API | Đọc hoá đơn, trả lời câu hỏi | Tính năng AI tắt, các phần khác không ảnh hưởng |
| Google Play / App Store | Thanh toán gói Pro | Không mua được gói; người dùng cũ giữ quyền |

**Nguyên tắc:** mọi thành phần ngoài đều là **tuỳ chọn đối với chức năng cốt lõi**. Ghi chi tiêu là chức năng không phụ thuộc mạng, không phụ thuộc dịch vụ ngoài.

---

## 4. Sơ đồ C4 — mức 2 (container)
```mermaid
graph TB
    subgraph CLIENT["Lớp ứng dụng"]
        IOS["Ứng dụng iOS<br/>SwiftUI, Swift 6<br/>iOS 26+"]
        AND["Ứng dụng Android<br/>Flutter 3.24+<br/>Android 8+"]
        WEB["Ứng dụng Web<br/>Next.js, React, TypeScript<br/>Chrome, Safari, Edge"]
    end

    subgraph SVC["Lớp dịch vụ — NestJS"]
        API["API Server<br/>REST, JWT guard<br/>nghiệp vụ, tổng hợp"]
        WRK["Worker<br/>BullMQ, 12 job định kỳ<br/>hàng đợi AI, thông báo"]
        RED["Redis<br/>hàng đợi, cache, khoá idempotent"]
    end

    subgraph DATA["Lớp dữ liệu"]
        PG["PostgreSQL 15<br/>12 bảng, RLS bật"]
        OBJ["Object Storage<br/>ảnh hoá đơn, signed URL"]
    end

    subgraph EXT["Dịch vụ ngoài"]
        AUTH["Auth<br/>JWT, refresh token"]
        GC["Google Calendar? — không dùng"]
        PUSH["FCM / APNs"]
        LLM["Gemini Flash"]
        BILL["Play Billing / StoreKit"]
    end

    IOS -->|HTTPS| API
    AND -->|HTTPS| API
    WEB -->|HTTPS| API
    IOS -.->|đăng nhập| AUTH
    AND -.->|đăng nhập| AUTH
    WEB -.->|đăng nhập| AUTH
    API --> PG
    API --> OBJ
    API --> RED
    WRK --> PG
    WRK --> RED
    WRK --> PUSH
    WRK --> LLM
    API --> BILL
```

### Trách nhiệm từng container

| Container | Làm gì | Không làm gì |
|---|---|---|
| **iOS (SwiftUI)** | Giao diện native, Liquid Glass thật, đọc ghi SQLite/SwiftData, hàng đợi đồng bộ | Không tính tổng hợp báo cáo phức tạp; không giữ khoá AI |
| **Android (Flutter)** | Giao diện Material 3, đọc ghi SQLite (drift), hàng đợi đồng bộ | Như trên |
| **Web (Next.js)** | Landing, đăng ký, xem báo cáo tháng | Không phải bản đầy đủ ở MVP; không có ghi giao dịch; không có thông báo đẩy |
| **API Server** | Xác thực, phân quyền, nghiệp vụ, tổng hợp, đồng bộ, quản lý hạn mức AI | Không chạy tác vụ dài; không gửi thông báo trực tiếp |
| **Worker** | 12 job định kỳ, hàng đợi AI, gửi thông báo, dọn dẹp | Không phục vụ request đồng bộ của người dùng |
| **PostgreSQL** | Nguồn sự thật, ràng buộc toàn vẹn, RLS | Không chứa logic nghiệp vụ phức tạp (trigger chỉ để bảo vệ toàn vẹn) |
| **Redis** | Hàng đợi, cache tổng hợp, khoá chống trùng | Không phải nguồn sự thật; mất Redis không mất dữ liệu |

### Vì sao tách API khỏi Worker

| Lý do | Chi tiết |
|---|---|
| Tác vụ dài không chặn request | Job AI mất 2–10 giây, không thể nằm trong luồng HTTP |
| Chạy lại độc lập | Worker chết không ảnh hưởng app; bật lại là chạy tiếp |
| Mở rộng riêng | Khi tải tăng, chỉ cần thêm instance Worker |
| Log tách biệt | Lỗi job không lẫn vào log request |

### Vì sao không dùng Supabase Realtime, Edge Functions, pg_cron

| Thành phần | Không dùng vì |
|---|---|
| Realtime | MVP dùng local-first; đồng bộ theo lượt kéo/đẩy là đủ. Realtime tốn kết nối thường trực, khó kiểm thử |
| Edge Functions | Chạy Deno, khó debug cục bộ, cold start, không có hệ sinh thái thư viện Node |
| pg_cron | Chỉ viết được SQL; không retry, không dead-letter, không log, không gọi được API ngoài |
| Supabase REST (PostgREST) tự động | Đẩy logic phân quyền xuống client, khó kiểm soát tổng hợp, khó chặn lạm dụng |

---

## 5. Cấu trúc repository — ba nền tảng
```
quan-ly-chi-tieu-va-thu-nhap-ca-nhan/
├── apps/
│   ├── ios/                         # SwiftUI native
│   ├── android/                     # Flutter, Riverpod, drift
│   └── web/                         # Next.js, React, TypeScript
├── packages/
│   └── shared-types/                # openapi.yaml — hợp đồng API duy nhất
├── services/
│   ├── api/                         # NestJS — HTTP, 11 module
│   └── worker/                      # NestJS — 12 job cron + hàng đợi
├── infra/
│   └── migrations/                  # SQL tạo 12 bảng
└── docs/                            # tài liệu, system-design/ là bộ kỹ thuật
```

### Vì sao ba nền không share mã

| Cặp | Share được? | Lý do |
|---|---|---|
| iOS ↔ Android | Không | Swift và Dart khác ngôn ngữ |
| Android ↔ Web | Không | Web cần SEO, tải trang nhanh; Flutter Web nặng 2–3 MB, không phù hợp |
| iOS ↔ Web | Không | Swift và TypeScript khác ngôn ngữ |

Chia sẻ qua **hợp đồng API JSON** (`packages/shared-types/openapi.yaml`) và nguyên tắc ở [08-api-principles](08-api-principles.md).

### Quy tắc phụ thuộc — áp dụng cho cả ba client

```
Features / presentation  →  Domain  ←  Data
        ↓                    ↑          ↓
      Core  ←───────────────┴──────────┘
```

| Tầng | Được import | Không được import |
|---|---|---|
| Domain | Không import gì của framework | SwiftUI, Flutter, drift, SwiftData, HTTP |
| Data | Domain, Core | Features, presentation |
| Features / presentation | Domain, Core, Data | — |
| Core | Chỉ thư viện chuẩn | Domain, Data, Features |

**Lý do:** công thức tính "hôm nay được tiêu" nằm ở Domain, viết một lần, kiểm thử không cần máy ảo. Nếu công thức nằm trong widget thì không test được và dễ lệch giữa ba nền tảng.

---

## 6. Luồng dữ liệu
### 6.1 Ghi giao dịch khi có mạng

```mermaid
sequenceDiagram
    participant U as Người dùng
    participant C as App
    participant L as SQLite / SwiftData
    participant Q as Hàng đợi đồng bộ
    participant A as API
    participant P as Postgres

    U->>C: Bấm Lưu (35.000đ, Ăn uống)
    C->>C: Sinh UUID trên máy
    C->>L: Ghi ngay (trạng thái pending)
    L-->>C: Xong, giao diện cập nhật
    C-->>U: Hiện trong danh sách (chưa có dấu tick)
    C->>Q: Đưa vào hàng đợi
    Q->>A: POST /v1/transactions (kèm id)
    A->>P: INSERT ... ON CONFLICT (id) DO NOTHING
    P-->>A: Đã ghi
    A-->>Q: 201 Created
    Q->>L: Đánh dấu synced
    L-->>C: Bỏ dấu "chờ đồng bộ"
```

**Điểm quan trọng:** người dùng thấy phản hồi trước khi mạng trả lời. Nếu mạng hỏng ở bước cuối, bản ghi vẫn còn trên máy và tự gửi lại.

### 6.2 Ghi giao dịch khi không có mạng

```mermaid
sequenceDiagram
    participant U as Người dùng
    participant C as App
    participant L as SQLite / SwiftData
    participant Q as Hàng đợi

    U->>C: Bấm Lưu
    C->>L: Ghi (pending)
    C->>Q: Đưa vào hàng đợi
    Q->>Q: Không có mạng, giữ lại
    C-->>U: Đã lưu. Sẽ đồng bộ khi có mạng.
    Note over Q: Thử lại 1s, 5s, 25s, 2 phút, 10 phút<br/>Sau đó chuyển dead-letter, báo người dùng
```

### 6.3 Đồng bộ hai chiều và xử lý xung đột

```mermaid
sequenceDiagram
    participant C as App
    participant A as API
    participant P as Postgres

    C->>A: GET /v1/sync/pull?since=2026-11-01T00:00:00Z
    A->>P: Lấy bản ghi updated_at > since
    P-->>A: Danh sách
    A-->>C: Bản ghi + con trỏ mới
    C->>C: So từng bản ghi với bản local

    alt Không có bản local
        C->>C: Lưu mới
    else Bản local đã synced
        C->>C: Ghi đè
    else Bản local còn pending
        C->>C: Đánh dấu XUNG ĐỘT
        C-->>C: Hỏi người dùng giữ bản nào
        Note over C: Không tự chọn. Không ghi đè im lặng.
    end
```

### 6.4 Đọc báo cáo

```mermaid
sequenceDiagram
    participant C as App
    participant A as API
    participant R as Redis
    participant P as Postgres

    C->>A: GET /v1/reports/monthly?month=2026-11
    A->>R: Lấy cache theo (user, month)
    alt Có cache và còn hạn
        R-->>A: Trả cache
    else Không có
        A->>P: Tổng hợp theo danh mục, ngày
        P-->>A: Số liệu
        A->>R: Ghi cache 5 phút
    end
    A-->>C: Tổng chi, cơ cấu, so sánh kỳ trước
    Note over A: Mọi tổng chi đều lọc type = 'expense'
```

### 6.5 Gọi AI (giai đoạn 2)

```mermaid
sequenceDiagram
    participant C as App
    participant A as API
    participant W as Worker
    participant R as Redis
    participant G as Gemini

    C->>A: POST /v1/ai/ocr (ảnh đã upload)
    A->>R: Kiểm hạn mức còn không
    alt Hết hạn mức
        A-->>C: 429 AI_QUOTA_EXCEEDED
    else Còn
        A->>R: Kiểm cache theo hash ảnh
        alt Có cache
            R-->>A: Kết quả cũ
            A-->>C: Trả ngay, không tính lượt
        else Không
            A->>W: Đưa job vào hàng đợi
            A-->>C: 202 Accepted, kèm jobId
            W->>G: Gọi mô hình
            G-->>W: JSON (số tiền, ngày, tên quán)
            W->>W: Kiểm hợp lệ, không tin số mô hình trả
            W->>C: Đẩy kết quả qua kênh đồng bộ
            C-->>C: Hiện form đã điền, người dùng sửa nếu cần
        end
    end
```

**Nguyên tắc bất di bất dịch:** mô hình AI không sinh ra con số tài chính. AI chỉ trích xuất từ ảnh; mọi tổng hợp do Postgres tính bằng công thức xác định.

---

## 7. Sơ đồ quan hệ dữ liệu
```mermaid
erDiagram
    users ||--o{ wallets : "sở hữu"
    users ||--o{ categories : "tuỳ biến"
    users ||--o{ transactions : "ghi"
    users ||--o{ budgets : "đặt"
    users ||--o{ recurring_rules : "tạo"
    users ||--o{ devices : "đăng ký"
    users ||--o{ goals : "đặt mục tiêu"
    users ||--o{ group_members : "tham gia"
    users ||--o{ shared_expenses : "trả tiền"

    wallets ||--o{ transactions : "chứa"
    wallets ||--o{ transactions : "nhận chuyển"
    categories ||--o{ transactions : "phân loại"
    categories ||--o{ budgets : "giới hạn"
    wallets ||--o{ recurring_rules : "sinh vào"

    users {
        uuid id PK
        text email
        text display_name
        text locale
        text timezone
        text plan
        int  ai_quota_used
        timestamptz created_at
    }
    wallets {
        uuid id PK
        uuid user_id FK
        text name
        text type
        bigint initial_balance
        text color
        text icon
        timestamptz deleted_at
    }
    categories {
        uuid id PK
        uuid user_id FK
        text name
        text type
        text icon
        text color
        boolean is_default
    }
    transactions {
        uuid id PK
        uuid user_id FK
        uuid wallet_id FK
        uuid to_wallet_id FK
        uuid category_id FK
        text type
        bigint amount
        uuid recurring_rule_id FK
        date occurrence_date
        text note
        text receipt_url
        timestamptz occurred_at
        date occurred_on
        timestamptz deleted_at
    }
    budgets {
        uuid id PK
        uuid user_id FK
        uuid category_id FK
        bigint amount
        text period
        date start_date
        date end_date
    }
    recurring_rules {
        uuid id PK
        uuid user_id FK
        jsonb template
        text frequency
        date next_run_on
        date last_run_on
    }
    goals {
        uuid id PK
        uuid user_id FK
        text name
        bigint target_amount
        bigint saved_amount
        date deadline
        bool is_completed
    }
    groups {
        uuid id PK
        text name
        uuid owner_id FK
        text invite_code
    }
    group_members {
        uuid group_id FK
        uuid user_id FK
        text role
        timestamptz left_at
    }
    shared_expenses {
        uuid id PK
        uuid group_id FK
        uuid payer_id FK
        bigint amount
        date occurred_on
    }
    shared_shares {
        uuid expense_id FK
        uuid user_id FK
        bigint share_amount
        timestamptz settled_at
    }
    devices {
        uuid id PK
        uuid user_id FK
        text platform
        text fcm_token
        timestamptz last_seen_at
    }
```

Chi tiết cột, kiểu, index, ràng buộc: xem [01-database-schema.md](01-database-schema.md).

**Ghi chú ERD:** bảng `goals` có lại từ Q8 (2026-11-17), nhập tay, không khoá ngoại tới `wallets`. Bốn bảng chia tiền (`groups`, `group_members`, `shared_expenses`, `shared_shares`) từ Q9. Bảng `transactions` có hai khoá ngoại tới `wallets` — `wallet_id` (ví nguồn) và `to_wallet_id` (chỉ dùng khi `type = 'transfer'`).

---

## 8. Quy trình tự động
Toàn bộ chạy trên Worker NestJS + BullMQ, múi giờ `Asia/Ho_Chi_Minh`.
Mỗi job phải **chạy lại được** mà không tạo dữ liệu trùng.

### 8.1 Mười hai job định kỳ

| # | Job | Lịch | Việc làm | Khoá chống trùng | Khi lỗi |
|---|---|---|---|---|---|
| 1 | `recurring-generate` | `05 0 * * *` | Sinh giao dịch từ `recurring_rules` tới hạn, cập nhật `next_run_on` | `(rule_id, occurrence_date)` unique | Thử lại 3 lần, cách 5 phút |
| 2 | `budget-close` | `10 0 1 * *` | Chốt tổng tháng trước, tạo khung ngân sách tháng mới cho user đã đặt | `(user_id, month)` unique | Thử lại 3 lần |
| 3 | `aggregate-refresh` | `30 0 * * *` | Tính lại bảng tổng hợp tháng, ghi cache | Ghi đè theo `(user, month)` | Thử lại 3 lần |
| 4 | `budget-alert` | `*/15 * * * *` | Quét ngưỡng 70/90/100%, gửi thông báo | `(user, category, month, level)` unique | Bỏ qua lần này, lần sau quét lại |
| 5 | `daily-reminder` | `0 20 * * *` | Nhắc ghi chép, kèm số thật của ngày | 1 tin/người/ngày | Bỏ qua |
| 6 | `winback` | `0 9 * * *` | Quét người vắng 7 ngày và 14 ngày | Tối đa 2 lần/người, ghi vào `notifications` | Bỏ qua |
| 7 | `ai-monthly-review` | `0 6 1 * *` | Sinh nhận xét thói quen tháng trước | Chỉ user có ≥ 10 giao dịch | Thử lại 2 lần |
| 8 | `ai-quota-reset` | `0 0 1 * *` | Xoá key tháng cũ trong `ai_quota_used`, giữ key tháng hiện tại | Idempotent theo tháng | Thử lại 3 lần |
| 9 | `ai-cost-breaker` | `0 * * * *` | Tổng chi phí AI giờ qua; vượt ngưỡng thì khoá tính năng tới đầu giờ sau | Khoá Redis có TTL | Gửi cảnh báo nếu chạy lỗi 2 lần |
| 10 | `fcm-token-cleanup` | `0 3 * * 0` | Xoá token FCM không hợp lệ | Idempotent | Thử lại 1 lần |
| 11 | `soft-delete-purge` | `30 3 * * *` | Xoá cứng bản ghi có `deleted_at` quá 30 ngày | Idempotent | Thử lại 3 lần |
| 12 | `integrity-check` | `0 4 * * 0` | Tìm dòng mồ côi, `amount <= 0`, tổng lệch giữa các bảng | Chỉ đọc | Gửi báo cáo cho nhóm |

### 8.2 Ba cơ chế không phải cron nhưng phải định nghĩa cùng lúc

| Cơ chế | Nội dung | Khi nào chạy |
|---|---|---|
| **Hàng đợi đồng bộ** | Thử lại cách 1s, 5s, 25s, 2 phút, 10 phút; sau đó dead-letter và báo người dùng | Mỗi lần client đẩy giao dịch |
| **Trigger toàn vẹn trong Postgres** | Cập nhật `updated_at`; chặn `amount <= 0`; chặn `type = 'transfer'` mà thiếu `to_wallet_id` | Mỗi lệnh ghi |
| **Cảnh báo vận hành** | Job nào lỗi 2 lần liên tiếp thì gửi thông báo cho nhóm qua email và Telegram | Sau mỗi lần job lỗi |

### 8.3 Vì sao không dùng pg_cron

| Cần | pg_cron | Worker + BullMQ |
|---|---|---|
| Thử lại có backoff | Không | Có |
| Dead-letter queue | Không | Có |
| Gọi API ngoài (Gemini, FCM) | Không (chỉ SQL) | Có |
| Chạy cục bộ để test | Không | Có |
| Log có cấu trúc | Không | Có |
| Tách theo múi giờ người dùng | Khó | Có |

### 8.4 Trình tự chạy trong một đêm

```mermaid
gantt
    title Các job ban đêm theo giờ Việt Nam
    dateFormat HH:mm
    axisFormat %H:%M
    section Dữ liệu
    recurring-generate   :00:05, 10m
    budget-close         :00:10, 20m
    aggregate-refresh    :00:30, 30m
    section Dọn dẹp
    soft-delete-purge    :03:30, 20m
    fcm-token-cleanup    :03:00, 15m
    section Định kỳ tuần
    integrity-check      :04:00, 30m
```

---

## 9. Bảo mật
### Luồng xác thực

```mermaid
sequenceDiagram
    participant C as App
    participant A as API
    participant AUTH as Supabase Auth
    participant P as Postgres

    C->>AUTH: Đăng nhập email mật khẩu hoặc Google
    AUTH-->>C: access token (1 giờ) + refresh token (30 ngày)
    C->>A: API request (nạp access token)
    A->>AUTH: Xác thực token
    AUTH-->>A: hợp lệ, kèm user_id
    A->>P: Truy vấn với RLS theo user_id
    P-->>A: Chỉ dữ liệu của user đó
    A-->>C: Response
```

| Thành phần | Cách bảo vệ |
|---|---|
| Token | Access 1 giờ, refresh 30 ngày, refresh một lần; hết hạn thì xoá cả cặp |
| Dữ liệu | RLS bật trên mọi bảng; chính sách chỉ đọc/ghi khi `user_id` khớp token |
| Ảnh hoá đơn | Signed URL 15 phút cho tải lên, 24 giờ cho tải về; không lưu công khai |
| Dữ liệu nhạy cảm | Không lưu mật khẩu thanh toán, không lưu số tài khoản ngân hàng |
| Mật mã | TLS cho mọi request; hash mật khẩu bằng Argon2id trong Supabase Auth |
| Xoá tài khoản | Xoá dữ liệu trong vòng 30 ngày; không xoá ngay vì còn nghĩa vụ hoá đơn |
| Giới hạn tải | 500 request/phút per user; 429 khi vượt |

### Phân quyền

| Vai trò | Quyền |
|---|---|
| Khách (chưa đăng nhập) | Chỉ đọc trang giới thiệu; mọi endpoint dữ liệu bị chặn |
| User miễn phí | Toàn bộ dữ liệu của mình; 10 lượt AI; có quảng cáo |
| User Pro | Toàn bộ dữ liệu của mình; 300 lượt AI; không quảng cáo |
| Nhà phát triển | Chỉ đọc log và chỉ số; không đọc dữ liệu cá nhân |

---

## 10. Suy giảm và chịu lỗi
| Khi X xảy ra | Hệ thống phản ứng | Người dùng thấy gì |
|---|---|---|
| Mất mạng | Ghi local; hàng đợi tự thử lại | Dấu "chờ đồng bộ" trên giao dịch |
| API sập | Không ảnh hưởng tính năng offline | Không tải được báo cáo mới |
| Redis sập | Job chờ, API trả lời chậm hơn | Không thấy gì, dữ liệu không mất |
| Gemini hết hạn mức | Tính năng AI đóng tạm, các phần khác chạy | Thông báo "danh sách chờ" |
| FCM sập | Không gửi được thông báo | Không có thông báo nhắc; app vẫn chạy |
| Chạy hết bộ nhớ DB | Nâng cấp, không tự động | Không thấy gì nếu chưa sập |
| Job chạy lỗi 2 lần liên tiếp | Gửi cảnh báo cho nhóm | Không thấy gì |
| Xung đột đồng bộ | Không tự ghi đè, hỏi người dùng | Màn hình chọn giữ bản nào |

---

## 11. Nhật ký quyết định kiến trúc
| # | Quyết định | Bối cảnh | Đã chọn | Đã từ chối | Lý do chọn |
|---|---|---|---|---|---|
| A1 | Backend NestJS riêng | Muốn kiểm thử logic nghiệp vụ | NestJS + BullMQ | Edge Functions Supabase | Deno khó debug, thiếu hệ sinh thái |
| A2 | iOS native | Cần Liquid Glass thật | SwiftUI | Flutter cho iOS | Flutter không gọi được API kính |
| A3 | Web tách khỏi Flutter | Web dùng Next.js; SEO, tải trang nhanh, React ecosystem | Next.js | Flutter Web (nặng, SEO kém) | Thêm một ngôn ngữ (TypeScript), nhưng backend cũng TypeScript |
| A4 | Redis cho hàng đợi | Cần retry và dead-letter | BullMQ + Redis | pg_cron | pg_cron không retry, không gọi API |
| A5 | UUID sinh trên máy | Chống trùng khi đồng bộ | UUID trên client | Tăng tự động trong DB | Tăng tự động không chạy được khi offline |
| A6 | RLS bật trên mọi bảng | Không để logic phân quyền rơi vào client | RLS ở DB | Chỉ kiểm tra trong API | RLS là lớp an toàn khi API bị khai thác sai |
| A7 | Không dùng Realtime | Local-first là đủ | Đồng bộ kéo/đẩy theo lượt | Supabase Realtime | Kết nối thường trực tốn pin, khó test |
| A8 | Money là BIGINT | Tránh sai số thập phân | Int theo đơn vị đồng | DECIMAL | Tổng và nhân nhanh hơn, so khớp đúng |
| A9 | Lưu UTC + ngày giờ Việt | Không lỗi khi người dùng đổi máy | 2 cột trong 1 bản ghi | Chỉ lưu UTC rồi quy đổi | Cần hiển thị đúng ngày theo múi người dùng |

---

## 12. Điểm cần bạn quyết
| # | Điểm | Đề xuất hiện tại | Cần bạn chọn |
|---|---|---|---|
| D1 | ~~Web cắt hẳn ở MVP hay giữ như tính năng phụ~~ | **Đã chốt 2026-11-16:** Web tách khỏi Flutter, dùng Next.js; MVP chỉ landing + đăng ký + báo cáo đọc | — |
| D2 | Dùng Redis có trả phí không khi vượt free tier | Chưa mua; xem theo chi phí [09 mục 3](09-chi-tiet-ky-thuat.md#3-chi-phí-hạ-tầng-theo-quy-mô) | Xác nhận |
| D3 | Gói AI miễn phí 10 lượt có đủ demo không | Đủ nếu chỉ demo 1 người | Chốt con số |
| D4 | Máy demo chạy bản nào (iOS hay Android) | Android (đúng phân khúc chính) | Chốt máy |

---

## 13. Lộ trình theo ba nền tảng
Chi tiết tuần cho từng codebase: xem [docs/05-lo-trinh.md](../05-lo-trinh.md).

```
Tuần 0     Chốt thiết kế, tạo repo, CI chạy được
Tuần 1–2   Postgres + Auth + Auth guard + module đầu tiên
Tuần 3–4   iOS: khung app + local DB + 2 màn hình
Tuần 5–6   Flutter: khung app + 2 màn hình tương ứng
Tuần 7     Web (tương đương màn Flutter, chỉ đọc)
Tuần 8     Đồng bộ 2 chiều + xử lý xung đột
Tuần 9     12 job cron + giám sát + cảnh báo
Tuần 10    Chạy thử, đo, sửa trước khi nộp
```

---

## 14. Trạng thái
Phiên bản 2.0, 2026-11-16. Bản gốc 1.x (một codebase Flutter cho cả hai nền) bị thay thế bởi Q4 và A3.
Tài liệu dẫn về file này: `01`–`10`. Mọi thay đổi quyết định phải cập nhật mục 11 và 14 trước.

## 15. Chi tiết kỹ thuật

Các phần văn bản dài không phải sơ đồ được tách sang [09-chi-tiet-ky-thuat.md](09-chi-tiet-ky-thuat.md): phân tầng backend, yêu cầu phi chức năng, chi phí hạ tầng, rủi ro kỹ thuật.

---

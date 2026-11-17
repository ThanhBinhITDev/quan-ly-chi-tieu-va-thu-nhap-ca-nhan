# 04 — Cấu trúc màn hình

**Phiên bản:** 1.1 · **Ngày:** 2026-11-13 · **Trạng thái:** đã chốt Q1–Q3, các điểm khác chờ duyệt

Mô tả bằng khối và trạng thái. Không dùng công cụ thiết kế — đủ để lập trình viên dựng trực tiếp.

---

## 1. Nguyên tắc giao diện

| Nguyên tắc | Cụ thể |
|---|---|
| Một màn hình, một câu hỏi | Mỗi màn trả lời đúng một câu hỏi của người dùng |
| Số quan trọng nhất ở trên cùng, cỡ lớn | Không cần cuộn để thấy chỉ số hôm nay |
| Màu chỉ dùng để báo trạng thái | Xanh = an toàn, vàng = chú ý, đỏ = vượt |
| Không quá 3 màu nhấn | Tránh rối mắt |
| Mọi thao tác chính trong 1 tay | Nút thêm giao dịch nằm vùng ngón cái |

### Bảng màu

Màu nhận diện thương hiệu: **`#2D7C3D`** (xanh lá — tài chính, an toàn). Chốt ngày 2026-11-17.

```
Nhận diện      #2D7C3D     Nền tối: #5FBF77
Nền chính      #FFFFFF     Nền tối: #121212
Chữ chính      #212121     Nền tối: #E0E0E0
Chữ phụ        #757575     Nền tối: #9E9E9E
An toàn        #2D7C3D  (dùng chung màu nhận diện)
Chú ý          #F57C00  (cam — chỉ nền, icon, thanh; chữ dùng #8A4B00)
Cảnh báo       #C62828  (đỏ)
Đường viền     #E0E0E0
```

**Vì sao "An toàn" dùng chung màu nhận diện:** `#2E7D32` cũ gần như trùng `#2D7C3D`, để hai mã riêng thì mắt không phân biệt được. Xanh lá vốn đã mang nghĩa "an toàn, tài chính", nên gộp làm một. Trạng thái vẫn phân biệt được vì còn cam và đỏ ở hai ngưỡng cao hơn.

**Ràng buộc tương phản (đo bằng công thức WCAG):**

| Cặp màu | Tỷ lệ | Kết luận |
|---|---|---|
| Chữ trắng trên `#2D7C3D` | 5,17:1 | Đạt AA cho chữ thường. Dùng cho nút chính và thẻ tổng quan |
| `#2D7C3D` trên nền tối `#121212` | 3,62:1 | **Không đạt** cho chữ nhỏ. Nền tối phải dùng tint `#5FBF77` (8,21:1) |
| Chữ `#212121` trên tint `#5FBF77` | 7,06:1 | Đạt AAA |
| Cam `#F57C00` trên nền trắng | 2,70:1 | **Không đạt** cho chữ. Chỉ dùng cho icon, viền, thanh tiến độ. Chữ cam dùng `#8A4B00` |
| Đỏ `#C62828` trên nền trắng | 5,62:1 | Đạt AA |

Chỉ dùng 3 màu trạng thái cho thanh tiến độ và số dư. Không dùng cho trang trí.

---

## 2. Luồng khởi động (3 bước, không đăng ký)

```
┌─────────────────────────────────────┐
│                                     │
│      TIỀN ĐI ĐÂU — BẠN BIẾT ĐÓ     │
│                                     │
│      [Minh họa: ví và biểu đồ]      │
│                                     │
│   Bạn có biết tháng trước mình      │
│   đã tiêu bao nhiêu không?          │
│                                     │
│         [ Bắt đầu ]                 │
│                                     │
│      Đã có tài khoản? Đăng nhập     │
└─────────────────────────────────────┘
```

### Bước 1 — Thu nhập

```
┌─────────────────────────────────────┐
│  ← 1/3                              │
│                                     │
│  Mỗi tháng bạn có khoảng            │
│  bao nhiêu tiền?                    │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  3.000.000 đ                  │  │
│  └───────────────────────────────┘  │
│                                     │
│  Gồm tiền gia đình gửi, học bổng,  │
│  tiền làm thêm...                   │
│                                     │
│  [ Tiếp tục ]                       │
└─────────────────────────────────────┘
```

### Bước 2 — Ngân sách

```
┌─────────────────────────────────────┐
│  ← 2/3                              │
│                                     │
│  Tiền ăn mỗi tháng khoảng?          │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  1.500.000 đ                  │  │
│  └───────────────────────────────┘  │
│                                     │
│  Bạn có thể sửa lại bất cứ lúc nào │
│                                     │
│  [ Tiếp tục ]                       │
└─────────────────────────────────────┘
```

### Bước 3 — Ghi thử

```
┌─────────────────────────────────────┐
│  ← 3/3                              │
│                                     │
│  Thử ghi khoản chi gần nhất         │
│                                     │
│  ┌───────────────┬───────────────┐  │
│  │   Ăn uống  ▾  │   35.000 đ    │  │
│  └───────────────┴───────────────┘  │
│                                     │
│  Gợi ý: Cơm  •  Trà sữa  •  Xăng   │
│                                     │
│  [ Xong ]                           │
│                                     │
│  Bỏ qua                             │
└─────────────────────────────────────┘
```

**Sau khi bấm Xong:** chèn thêm 6 khoản chi mẫu vào tháng hiện tại, chuyển thẳng vào Trang chủ. Người dùng thấy biểu đồ có dữ liệu ngay.

**Không có bước đăng ký.** Đăng ký được đề nghị ở giao dịch thứ 5.

---

## 3. Màn hình 1 — Trang chủ

Bố cục theo bản nhóm chốt ngày 2026-11-17: card tổng quan nền xanh đậm ở trên cùng, các thẻ bo góc xếp dọc.

```
┌─────────────────────────────────────┐
│  Student Finance        🔔    ⚙️    │
├─────────────────────────────────────┤
│ ╭─────────────────────────────────╮ │
│ │ SỐ DƯ HIỆN TẠI        (nền xanh)│ │
│ │                                 │ │
│ │        1.200.000 đ              │ │  ← 36sp, chữ trắng
│ │                                 │ │
│ │  ↑ Thu nhập tháng  ↓ Chi tháng  │ │
│ │     3.000.000        1.800.000  │ │
│ ╰─────────────────────────────────╯ │
├─────────────────────────────────────┤
│   Hôm nay được tiêu      63.888 đ › │  ← giữ chỉ số khác biệt
│   Còn dùng được 18 ngày             │
├─────────────────────────────────────┤
│   NGÂN SÁCH THÁNG 11          ✏️    │
│                                     │
│   1.850.000 / 3.000.000   61,7%     │
│   ┌───────────────────────────────┐ │
│   │████████████████░░░░░░░░       │ │
│   └───────────────────────────────┘ │
│   Còn 1.150.000                     │
│                                     │
│   🍜     🚌     📚     🎮     🛍     │  ← icon danh mục nhanh
│   Ăn     Đi     Học    Giải   Mua   │
│   uống   lại    tập    trí   sắm    │
├─────────────────────────────────────┤
│   MỤC TIÊU TIẾT KIỆM          🏅    │
│                                     │
│   Mua laptop                        │
│   200.000 / 500.000        40%      │
│   ┌───────────────────────────────┐ │
│   │████████░░░░░░░░░░░░░░░░       │ │
│   └───────────────────────────────┘ │
│   [ Ghi thêm tiết kiệm ]            │
├─────────────────────────────────────┤
│   Giao dịch gần đây       Xem tất cả│
│                                     │
│  🍜  Cơm trưa             -35.000   │
│      Hôm nay · Ăn uống              │
│                                     │
│  🚌  Xe buýt              -7.000    │
│      Hôm nay · Đi lại               │
│                                     │
└─────────────────────────────────────┘
                        ╭─────────╮
                        │    +    │   ← nút nổi, 56dp
                        ╰─────────╯
```

**Vì sao vẫn có dòng "Hôm nay được tiêu":** card số dư trả lời "tôi có bao nhiêu", nhưng không trả lời "hôm nay tiêu được bao nhiêu". Chỉ số này là điểm khác biệt so với Money Lover. Nó nằm ngay dưới card số dư, không chiếm vị trí số lớn nhất.

**Số dư là số tính ra, không phải số lưu sẵn** (Q1): `initial_balance` + tổng giao dịch. Người dùng không sửa trực tiếp được; muốn đổi thì sửa ví.

**Thẻ mục tiêu chỉ hiện khi có ít nhất một mục tiêu chưa xong.** Chưa có thì ẩn hẳn, không hiện khung trống.

### Trạng thái màu của số "Hôm nay được tiêu"

| Điều kiện | Màu | Số hiển thị |
|---|---|---|
| `daily_limit > 0` và ngân sách dùng < 70% | `#2D7C3D` | `63.888 đ` |
| Ngân sách dùng 70–89% | `#F57C00` | `42.300 đ` |
| Ngân sách dùng 90–99% | `#F57C00` đậm hơn + biểu tượng ⚠ | `12.500 đ` |
| `daily_limit ≤ 0` | `#C62828` | `Đã vượt 120.000 đ` |

**Quan trọng:** khi đã vượt, không hiển thị số âm. Hiển thị câu "Đã vượt 120.000 đ" — rõ nghĩa hơn `-120.000đ`.

### Trạng thái trống (người dùng mới)

```
┌─────────────────────────────────────┐
│                                     │
│         Chưa có ngân sách           │
│                                     │
│   Đặt ngân sách để biết mỗi ngày    │
│   được tiêu bao nhiêu               │
│                                     │
│      [ Đặt ngân sách ]              │
│                                     │
└─────────────────────────────────────┘
```

Không hiển thị `0 đ` — gây cảm giác sản phẩm hỏng.

---

## 4. Màn hình 2 — Giao dịch

```
┌─────────────────────────────────────┐
│  Giao dịch              🔍   ▾      │
├─────────────────────────────────────┤
│  [Tất cả] [Chi] [Thu] [Chuyển ví]  │  ← tab lọc
├─────────────────────────────────────┤
│  Tháng 11 · Chi 1.850.000           │
├─────────────────────────────────────┤
│  HÔM NAY                            │
│                                     │
│  🍜  Cơm trưa             -35.000   │
│      Ăn uống · Tiền mặt             │
│                                     │
│  🚌  Xe buýt              -7.000    │
│      Đi lại · Tiền mặt              │
│                                     │
│  HÔM QUA                            │
│                                     │
│  💰  Mẹ gửi             +2.000.000  │
│      Tiền gia đình · VCB            │
│                                     │
│  🛍  Shopee               -189.000  │
│      Mua sắm · MoMo                 │
└─────────────────────────────────────┘
```

### Thao tác trên một dòng

| Thao tác | Kết quả |
|---|---|
| Chạm | Mở màn sửa giao dịch |
| Vuốt sang trái | Hiện nút Xóa (đỏ) |
| Vuốt sang phải | Hiện nút Sửa (xanh) |
| Giữ lâu | Menu: Nhân bản, Xóa |

**Giữ lâu để nhân bản** — sinh viên hay có giao dịch giống nhau (cơm trưa mỗi ngày). Nhân bản tiết kiệm thời gian.

### Bộ lọc nâng cao (bấm ▾)

```
┌─────────────────────────────────────┐
│  Lọc giao dịch                      │
├─────────────────────────────────────┤
│  Thời gian    [Tháng này ▾]         │
│  Danh mục     [Tất cả ▾]            │
│  Ví           [Tất cả ▾]            │
│  Khoảng tiền  [      ] – [      ]   │
├─────────────────────────────────────┤
│  [ Xóa lọc ]        [ Áp dụng ]     │
└─────────────────────────────────────┘
```

---

## 5. Màn hình 3 — Ngân sách

```
┌─────────────────────────────────────┐
│  Ngân sách                     ✏️   │
├─────────────────────────────────────┤
│  TỔNG THÁNG 11                      │
│                                     │
│  1.850.000 / 3.000.000              │
│  ┌───────────────────────────────┐  │
│  │████████████████░░░░░░░░  61,7% │  │
│  └───────────────────────────────┘  │
│  Còn 1.150.000 · 18 ngày            │
│                                     │
│      ╭──────────────────╮           │
│     ╱    ████ 61,7%      ╲          │  ← donut: phần đã dùng
│    │    ░░░░░░░░░░░░      │         │     phần còn lại màu xám
│     ╲                     ╱         │
│      ╰───────────────────╯          │
│                                     │
├─────────────────────────────────────┤
│  THEO DANH MỤC                      │
│                                     │
│  🍜 Ăn uống            980.000      │
│     ┌─────────────────────────┐     │
│     │████████████████░░░  65% │     │  ← xanh
│     └─────────────────────────┘     │
│     1.500.000 · còn 520.000         │
│                                     │
│  🛍 Mua sắm            295.000      │
│     ┌─────────────────────────┐     │
│     │████████████████████░  98%│     │  ← cam
│     └─────────────────────────┘     │
│     300.000 · còn 5.000 ⚠           │
│                                     │
│  🚌 Đi lại             320.000      │
│     ┌─────────────────────────┐     │
│     │████████████████████████ │     │  ← đỏ
│     └─────────────────────────┘     │
│     300.000 · vượt 20.000           │
│                                     │
└─────────────────────────────────────┘
```

### Màn hình đặt ngân sách

```
┌─────────────────────────────────────┐
│  ← Đặt ngân sách                    │
├─────────────────────────────────────┤
│  Áp dụng cho                        │
│  [ Tổng tất cả ▾ ]                  │
│                                     │
│  Số tiền mỗi tháng                  │
│  ┌───────────────────────────────┐  │
│  │  3.000.000 đ                  │  │
│  └───────────────────────────────┘  │
│                                     │
│  Gợi ý theo thu nhập:               │
│  [50%]  1.500.000   [70%]  2.100.000│
│                                     │
│  Cảnh báo khi đạt:                  │
│  ● 70%   ○ 80%   ○ 90%              │
│                                     │
│  [ Lưu ]                            │
└─────────────────────────────────────┘
```

**Gợi ý % theo thu nhập** quan trọng: sinh viên không biết nên đặt bao nhiêu. Đưa sẵn 3 mức để chọn thay vì bắt tự nghĩ.

---

### Thẻ mẹo (gắn ngưỡng, không phải AI khen)

```
┌─────────────────────────────────────┐
│  💡 Đã dùng 61,7% ngân sách,        │
│     còn 18 ngày. Mức hiện tại là    │
│     ổn.                             │
└─────────────────────────────────────┘
```

Câu sinh theo ngưỡng cố định, **không gọi AI**, để cùng số liệu thì luôn ra cùng câu:

| Đã dùng | Câu |
|---|---|
| < 50% | "Đã dùng X%, còn N ngày. Còn nhiều dư địa." |
| 50–80% | "Đã dùng X%, còn N ngày. Mức hiện tại là ổn." |
| 80–100% | "Đã dùng X%, còn N ngày. Chậm lại một chút." |
| > 100% | "Đã vượt X% ngân sách. Cắt khoản không cần thiết." |

Lý do không dùng AI: câu khen "Bạn đang chi tiêu khá hợp lý!" phụ thuộc mô hình, cùng dữ liệu có thể ra câu khác nhau, và không kiểm chứng được. Ngưỡng thì test được.

### Chế độ tiết kiệm

Công tắc bật/tắt nằm ở cuối màn Ngân sách. **Định nghĩa cụ thể** (theo bản nhóm chốt, chi tiết hoá để code được):

- Bật → **hạn mức ngày** giảm đi một khoản dự trữ, để người dùng giữ lại tiền cho mục tiêu.
- Khoản dự trữ = `mục tiêu đang ưu tiên` ÷ số ngày còn lại trong tháng. Mục tiêu ưu tiên là mục tiêu chưa xong có `deadline` gần nhất (nếu không có deadline, lấy mục tiêu tạo trước).
- Tắt → hạn mức ngày như bình thường.
- Chỉ ảnh hưởng số "hôm nay được tiêu" trên Trang chủ. **Không** thay đổi ngân sách danh mục hay số liệu thống kê.

Ví dụ: mục tiêu laptop 500.000đ, còn 200.000đ, còn 40 ngày → dự trữ 7.500đ/ngày. Hạn mức ngày 63.888đ thành 56.388đ.

```
┌─────────────────────────────────────┐
│  CHẾ ĐỘ TIẾT KIỆM            [ ◯ ]  │
│  Đang tắt                           │
│                                     │
│  Bật: giữ lại 7.500đ/ngày cho      │
│  "Mua laptop" (còn 40 ngày)         │
└─────────────────────────────────────┘
```

**Khi không có mục tiêu chưa xong:** công tắc bị khoá, hiện "Đặt mục tiêu để dùng chế độ này".

---

## 6. Màn hình 4 — Thống kê

```
┌─────────────────────────────────────┐
│  Thống kê        [Tháng này ▾]      │
├─────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐ │
│  │ ↑ Tổng thu   │  │ ↓ Tổng chi   │ │
│  │  3.000.000   │  │  1.850.000   │ │
│  └──────────────┘  └──────────────┘ │
├─────────────────────────────────────┤
│  CHI TIÊU THEO NGÀY                 │
│                                     │
│  100k ┤                             │
│       │        ▂                    │
│   75k ┤    ▃  ▅ █ ▃                 │
│       │  ▂ █  █ █ █ ▂  ▃            │
│   50k ┤  █ █  █ █ █ █  █  ▂         │
│       │  █ █  █ █ █ █  █  █         │
│    0  └──1──5──10──15──20──25──30   │
│                                     │
├─────────────────────────────────────┤
│  SO VỚI THÁNG TRƯỚC                 │
│                                     │
│  Chi tháng này   1.850.000          │
│  Chi tháng trước 1.568.000          │
│  Tăng 18%  ▲                        │
│                                     │
│  Tăng mạnh nhất:                    │
│  🍜 Ăn uống   +240.000 (+32%)       │
│  🛍 Mua sắm   +85.000  (+40%)       │
│                                     │
├─────────────────────────────────────┤
│  CƠ CẤU CHI TIÊU                    │
│                                     │
│      ╭──────────────────╮           │
│     ╱  ████ Ăn uống 53%  ╲          │
│    │  ▓▓▓▓ Đi lại 17%    │          │
│    │  ▒▒▒▒ Mua sắm 16%   │          │
│     ╲ ░░░░ Khác 14%     ╱           │
│      ╰──────────────────╯           │
│                                     │
├─────────────────────────────────────┤
│  KHOẢN CHI LỚN NHẤT                 │
│  🍜 Ăn uống                         │
│  720.000 đ · 38,9% tổng chi         │
├─────────────────────────────────────┤
│  XẾP HẠNG DANH MỤC                  │
│                                     │
│  1. Ăn uống      980.000    53,0%   │
│  2. Đi lại       320.000    17,3%   │
│  3. Mua sắm      295.000    15,9%   │
│  4. Học tập      180.000     9,7%   │
│  5. Khác          75.000     4,1%   │
│                                     │
├─────────────────────────────────────┤
│  🔒 Báo cáo chuyên sâu              │
│     Xu hướng 6 tháng, dự báo        │
│     chi tiêu cuối tháng             │
│     [ Nâng cấp Pro ]                │
└─────────────────────────────────────┘
```

**Thứ tự khối quan trọng:** tổng thu/chi trước (trả lời "tháng này thế nào"), rồi xu hướng ngày, rồi so sánh tháng trước, rồi cơ cấu tròn, rồi khoản chi lớn nhất, rồi xếp hạng. Người dùng đọc từ trên xuống và dừng ở đâu cũng đã có thông tin dùng được.

**Khối bị khóa** hiển thị mờ + nút nâng cấp. Không ẩn hoàn toàn — để người dùng biết có gì đang chờ.

---

## 7. Màn hình 5 — Tài khoản (mở từ ⚙ ở Trang chủ)

```
┌─────────────────────────────────────┐
│  Tài khoản                          │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │  NHD                          │  │
│  │  Nguyễn Huyền Diệu            │  │
│  │  Gói miễn phí                 │  │
│  │  [ Nâng cấp Pro ]             │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  VÍ                                 │
│  💵 Tiền mặt            520.000     │
│  📱 MoMo                 80.000     │
│  🏦 Vietcombank       2.000.000     │
│  + Thêm ví                          │
├─────────────────────────────────────┤
│  CÀI ĐẶT                            │
│  Danh mục                        ›  │
│  Thông báo                       ›  │
│  Giao dịch định kỳ               ›  │
│  Sao lưu & đồng bộ               ›  │
│  Bảo mật                         ›  │
├─────────────────────────────────────┤
│  KHÁC                               │
│  Trợ giúp & phản hồi             ›  │
│  Giới thiệu ứng dụng             ›  │
│  Điều khoản & quyền riêng tư     ›  │
│  Đăng xuất                          │
└─────────────────────────────────────┘
```

---

## 8. Màn hình thêm giao dịch (modal)

Đây là màn hình quan trọng nhất — mục tiêu dưới 5 giây.

```
┌─────────────────────────────────────┐
│  ✕                     Thêm giao dịch│
├─────────────────────────────────────┤
│                                     │
│          35.000 đ                   │  ← 36sp, tự focus
│                                     │
├─────────────────────────────────────┤
│  [Chi]  [Thu]  [Chuyển ví]          │
├─────────────────────────────────────┤
│  🍜  🚌  🛍  📚  🎮  🏥  🏠  ⋯      │  ← danh mục, chọn 1
│  Ăn  Đi  Mua Học Giải Khỏe Nhà      │
├─────────────────────────────────────┤
│  Ví: [ Tiền mặt ▾ ]                 │
│  Ghi chú: [                    ]     │
│  Ngày: [ Hôm nay ▾ ]                │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │          LƯU                  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Chi tiết quan trọng

1. **Bàn phím số hiện ngay** khi mở, không cần chạm vào ô nhập.
2. **Danh mục gợi ý sẵn** dựa trên lịch sử (danh mục dùng nhiều nhất lên đầu).
3. **Lưu được ngay** sau khi nhập số tiền + chọn danh mục. Ví mặc định, ngày hôm nay, ghi chú trống.
4. **Nút Lưu luôn hiện**, không bị bàn phím che.

### Nhập nhanh bằng cú pháp

Bấm biểu tượng `⌨` ở góc trên → hiện ô nhập văn bản:

```
┌─────────────────────────────────────┐
│  Nhập nhanh                          │
│  ┌───────────────────────────────┐   │
│  │  com 35k                      │   │
│  └───────────────────────────────┘   │
│                                      │
│  Đã hiểu:                            │
│    Số tiền:  35.000 đ                │
│    Danh mục: Ăn uống                 │
│    Ví:       Tiền mặt                │
│                                      │
│  [ Lưu ]                             │
└─────────────────────────────────────┘
```

Cú pháp hỗ trợ: `com 35k`, `xang 50k`, `trasua 25k`, `35k an`, `com 35000`.

Quy tắc phân tích:
- Số có hậu tố `k` = nghìn, `tr`/`m` = triệu
- Từ khóa đầu hoặc cuối là gợi ý danh mục
- Nếu không nhận ra từ khóa → dùng danh mục dùng nhiều nhất, người dùng sửa được

### Chụp hóa đơn (giai đoạn sau MVP)

Nút 📷 ở góc trên. Chụp → gọi `/ai/ocr` → hiện màn xác nhận giống nhập nhanh, người dùng sửa rồi Lưu.

---

## 9. Thông báo đẩy — mẫu câu

| Loại | Tiêu đề | Nội dung | Nút |
|---|---|---|---|
| Nhắc cuối ngày | Còn 18 ngày | 1.150.000đ → 63.888đ/ngày. Hôm nay bạn tiêu bao nhiêu? | Ghi nhanh |
| Cảnh báo 70% | Ăn uống đã dùng 70% | 1.050.000 / 1.500.000đ hạn mức tháng | Xem |
| Cảnh báo 90% | Sắp hết hạn mức Ăn uống | Còn 150.000đ cho 18 ngày = 8.333đ/ngày | Xem |
| Vượt hạn mức | Đã vượt hạn mức Mua sắm | 320.000 / 300.000đ. Vượt 20.000đ | Xem |
| Báo cáo tuần | Tuần này: 480.000đ | Nhiều hơn tuần trước 12%. Ăn uống tăng mạnh nhất | Xem |
| Đầu tháng | Tháng mới | Ngân sách tháng trước dùng 92%. Đặt lại ngân sách? | Đặt ngân sách |
| Win-back 7 ngày | Tháng này bạn chi 2.100.000đ | Còn 8 ngày với 400.000đ — đủ không? | Xem |
| Win-back 14 ngày | 47 giao dịch chưa xem báo cáo | Xem trong 30 giây? | Xem |

**Không có mẫu nào là "Bạn chưa ghi chi tiêu".** Mọi thông báo đều chứa con số hoặc thông tin.

---

## 10. Thành phần dùng chung

| Thành phần | Mô tả |
|---|---|
| `MoneyText` | Hiển thị số tiền: định dạng `1.234.567 đ`, chữ số tabular để không nhảy khi thay đổi |
| `ProgressBar` | Thanh tiến độ, tự đổi màu theo ngưỡng (xanh/cam/đỏ) |
| `CategoryIcon` | Icon danh mục, nền tròn màu nhạt |
| `EmptyState` | Trạng thái trống: icon + tiêu đề + 1 dòng giải thích + 1 nút hành động |
| `SyncBadge` | Chấm nhỏ trạng thái đồng bộ (chỉ hiện khi cần) |
| `AmountInput` | Ô nhập tiền có định dạng tự động, không cho nhập chữ |

### Số tiền hiển thị

| Giá trị | Hiển thị |
|---|---|
| 35000 | `35.000` |
| 1500000 | `1.500.000` |
| 15000000 | `15.000.000` |
| Trong biểu đồ trục | `1,5tr` / `15tr` |

Dùng dấu chấm phân cách nghìn, không dùng dấu phẩy. Đơn vị `đ` sau số, khoảng trắng 1 ký tự.

---

## 11. Điều hướng

```
Khởi động (3 bước)
   ↓
Trang chủ ────┬──── Giao dịch ──── Sửa giao dịch
              ├──── Ngân sách ──── Đặt ngân sách ──── Mục tiêu
              ├──── Thống kê
              ├──── Chia tiền nhóm ──── Chi tiết nhóm ──── Thêm chi phí
              └──── (⚙ ở header) ──── Tài khoản ──── Cài đặt con
                     ↑
       Nút + (từ mọi tab) → Modal thêm giao dịch → lưu → về tab cũ
```

Thanh tab dưới: **4 mục** — Trang chủ, Giao dịch, Ngân sách, Thống kê. Nút `+` nổi chỉ ở tab Trang chủ và Giao dịch.

**Chia tiền nhóm** mở từ mục "Chia tiền" trong tab Giao dịch hoặc nút `+` → "Chia chi phí". Không có tab riêng, để thanh dưới giữ 4 mục.

**Vì sao 4 tab, không phải 5:** bản nhóm chốt 2026-11-17. Tab Tài khoản bỏ khỏi thanh dưới, chuyển thành icon ⚙ ở header Trang chủ. Lý do vẫn phải có đường vào Tài khoản: nó chứa chính sách riêng tư — Google Play bắt buộc phải truy cập được từ trong app.

> **Khác biệt nền tảng (Q4):** nút `+` nổi là mẫu Material (Android). Trên **iOS dùng nút thêm ở thanh điều hướng trên** hoặc thanh dưới dạng `Toolbar` — không dùng FAB, vì iOS không có mẫu FAB và HIG không khuyến nghị. Các khối còn lại dùng chung.

**Khi người dùng bấm thông báo:** mở thẳng màn hình liên quan, không qua trang chủ. VD bấm "Sắp hết hạn mức Ăn uống" → mở tab Ngân sách, cuộn đến danh mục Ăn uống.

---

## 12. Màn hình — Chia tiền nhóm (Split Bill)

Mở từ tab Thêm (+) hoặc từ mục "Chia tiền" trong Giao dịch. Không có tab riêng, tránh thanh dưới thành 5 mục.

**Danh sách nhóm:**

```
┌─────────────────────────────────────┐
│  ←  Chia tiền                  ＋   │
├─────────────────────────────────────┤
│  Nhóm trọ 4 người             4 người│
│  Bạn đang nhận 300.000              │
│                                     │
│  Nhóm đi chơi                3 người│
│  Bạn đang nợ 50.000                 │
│                                     │
│  [ Vào nhóm bằng mã ]               │
└─────────────────────────────────────┘
```

**Chi tiết nhóm:** một danh sách khoản chi, mỗi dòng có người trả và phần của mình. Nút "Thêm chi phí" ở cuối. Khối "Ai nợ ai" hiện ở đầu, bấm vào để đánh dấu đã trả.

```
┌─────────────────────────────────────┐
│  ←  Nhóm trọ 4 người           ⋯   │
├─────────────────────────────────────┤
│  AI NỢ AI                           │
│  Trần Văn A → Diệu     100.000  [Đã trả] │
│  Lê Thị B   → Diệu     100.000  [Đã trả] │
├─────────────────────────────────────┤
│  Tiền điện tháng 11      400.000    │
│  Diệu trả · chia đều 4 người        │
│  Phần của bạn: 100.000              │
│                                     │
│  Tiền nước tháng 11      120.000    │
│  Bạn trả · chia đều 4 người         │
│  Phần của bạn: 30.000               │
├─────────────────────────────────────┤
│  [ + Thêm chi phí ]                 │
└─────────────────────────────────────┘
```

**Quy tắc hiển thị, phải làm đúng:**
- Dòng luôn ghi rõ **"Phần của bạn"**, không ghi tổng. Người xem phải biết mình chịu bao nhiêu.
- Nếu bạn là người trả: hiện thêm "Bạn cần thu" = tổng − phần của bạn.
- Số trong "Ai nợ ai" là gợi ý tối thiểu từ server, không tự tính ở app.

**Thêm chi phí:** nhập số tiền, ghi chú, chọn người trả, chọn cách chia. Cách chia mặc định là **chia đều**; cho phép **chia theo số tiền cụ thể** cho từng người (phải cộng đúng bằng tổng, không đúng thì không cho lưu).

**Khi không có mạng:** khoản chi nhóm **không** lưu offline như giao dịch cá nhân, vì người khác cần thấy ngay và số liệu phải khớp giữa các máy. Hiện thông báo "Cần mạng để chia tiền nhóm", không cho lưu nháp. Giao dịch cá nhân vẫn hoạt động offline bình thường.

**Trạng thái trống:**

```
┌─────────────────────────────────────┐
│     Chưa có nhóm nào                │
│                                     │
│   Tạo nhóm để chia tiền trọ,        │
│   đi chơi, hoá đơn chung            │
│                                     │
│   [ Tạo nhóm ]  [ Vào bằng mã ]     │
└─────────────────────────────────────┘
```

---

## 13. Điểm cần bạn quyết

| # | Vấn đề | Đề xuất | Phương án khác |
|---|---|---|---|
| 2 | Số tiền tabular (chữ số đều nhau) | Có | Không, đẹp hơn nhưng số nhảy khi cập nhật |
| 3 | Chế độ tối | Có, theo hệ thống | Chỉ sáng, đơn giản hơn |
| 4 | Onboarding 3 bước hay 2 | 3 (có bước ghi thử) | 2 bước, nhanh hơn nhưng không tạo được "aha moment" |
| 5 | Vuốt để sửa/xóa hay chỉ giữ lâu | Cả hai | Chỉ một, đỡ nhầm |

Điểm 4 quan trọng: bước 3 (ghi thử) là thứ tạo ra khoảnh khắc người dùng hiểu sản phẩm. Bỏ đi thì tỷ lệ giữ chân ngày đầu giảm rõ rệt.

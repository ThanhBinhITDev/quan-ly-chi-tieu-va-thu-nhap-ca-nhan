# 10 — Bản mô tả UI do nhóm đề xuất

**Ngày nhận:** 2026-11-17 · **Trạng thái:** bản đề xuất, **chưa phải đặc tả chính thức**

Nguồn: văn bản nhóm gửi để đưa cho AI dựng giao diện. Lưu nguyên văn ở [phụ lục](#phụ-lục-nguyên-văn) để không mất. Đọc xong phần dưới rồi mới quyết chỗ nào nhận, chỗ nào sửa.

---

## 1. Phần nhận ngay

| Nội dung | Ghi chú |
|---|---|
| Màu chủ đạo **`#2D7C3D`** | Đã áp vào [04 mục 1](04-wireframes.md#bảng-màu) |
| Thẻ bo góc, nền sáng, tối giản | Khớp nguyên tắc "một màn một câu hỏi" đã có |
| Cam/đỏ cho cảnh báo | Đã có sẵn trong bảng màu trạng thái |
| Card tổng quan nền xanh đậm ở đầu Trang chủ | Phù hợp "số quan trọng nhất ở trên cùng" |

---

## 2. Chỗ xung đột với quyết định đã chốt

Bốn điểm dưới đây **không nhận nguyên văn**. Cần sếp chọn.

### 2.1 Tên ứng dụng

Bản đề xuất: **"Student Finance"**.
Tên chính thức đã chốt: **"Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân"**, slogan "TIỀN ĐI ĐÂU – BẠN BIẾT ĐÓ!" ([01-tong-quan](../01-tong-quan.md)).

Đề xuất: giữ tên chính thức ở tiêu đề, "Student Finance" chỉ là tên gọi tắt nội bộ. Hoặc sếp đổi tên chính thức — nhưng phải sửa cả 5 file tài liệu.

### 2.2 Thử thách tiết kiệm / mục tiêu (gamification)

Bản đề xuất có "Thẻ Thử thách tiết kiệm — Mua laptop 500.000đ kèm thanh tiến trình" và "chế độ tiết kiệm hiển thị mục tiêu hiện tại".

**Tính năng mục tiêu tiết kiệm đã bị loại bỏ** ngày 2026-11-16 (Q7): con số người dùng tự gõ, không kiểm chứng được, không gắn với tiền thật. Bảng `goals` không tồn tại trong schema.

Nếu muốn có lại, phải làm khác đi: mục tiêu gắn với số dư thật của một ví, không phải con số tự nhập. Đây là việc thiết kế lại, không phải thêm một thẻ vào giao diện.

### 2.3 "Số dư hiện tại" trên card tổng quan

Bản đề xuất hiển thị "Số dư hiện tại 1.200.000 đ" to nhất.

Quyết định Q1: **không lưu `balance` trong `wallets`**; số dư luôn tính từ giao dịch. Hiển thị được, nhưng phải ghi rõ là số tính ra, không phải số lưu sẵn.

Quan trọng hơn: chỉ số mà app này muốn người dùng thấy là **"hôm nay được tiêu bao nhiêu"**, không phải số dư. Số dư không trả lời câu hỏi "hôm nay tiêu được bao nhiêu". Nếu để số dư to nhất, app mất điểm khác biệt so với Money Lover.

Đề xuất: giữ card xanh, nhưng số to nhất là chỉ số hạn mức hôm nay; số dư và thu/chi tháng xuống hàng dưới.

### 2.4 Thanh điều hướng: 4 tab hay 5 tab

Bản đề xuất: **4 tab** — Trang chủ, Giao dịch, Ngân sách, Thống kê. Không có tab Tài khoản.
Đặc tả hiện tại: **5 tab** — thêm tab Tài khoản ([04 mục 11](04-wireframes.md#11-điều-hướng)).

Tab Tài khoản chứa đăng xuất, cài đặt thông báo, hạn mức AI, chính sách riêng tư. Bốn thứ này bắt buộc phải có (Google Play yêu cầu chính sách riêng tư truy cập được). Nếu bỏ tab, phải có đường vào khác — thường là icon bánh răng ở góc phải header Trang chủ.

Đề xuất: **4 tab + icon cài đặt ở header**, gọn hơn 5 tab trên màn 360dp.

---

## 3. Tính năng mới chưa có trong thiết kế

Ba thứ này **chưa có** trong schema, API, hay lộ trình. Không dựng được ngay.

| Tính năng | Thiếu gì | Ước lượng |
|---|---|---|
| **Split Bill** (chia tiền nhóm trọ) | 3 bảng mới: nhóm, thành viên, khoản chia. API mới. Đồng bộ nhiều người dùng — khác hẳn mô hình local-first hiện tại | Lớn: 2–3 tuần, không thuộc MVP |
| **Trợ lý "có nên mua món này"** | Chỉ là biến thể của AI hỏi đáp (AI-3), đã có trong lộ trình tuần 9. Không cần thiết kế mới | Nhỏ, dùng lại AI-3 |
| **"Dự báo dùng được 20 ngày nữa"** | Công thức đã có: `daily_limit`. Chỉ là cách diễn đạt khác: `số_dư / daily_limit`. Chia cho 0 thì phải xử lý | Nhỏ, chỉ là hiển thị |

**Khuyến nghị:** Split Bill không làm ở MVP. Nó phá mô hình dữ liệu một người dùng và tốn 2–3 tuần.

---

## 4. Chỗ dùng chữ mơ hồ

| Câu trong bản đề xuất | Vấn đề |
|---|---|
| "Bạn có thể sử dụng tiền trong khoảng 20 ngày nữa" | Sai ngữ pháp, và "khoảng" nghĩa là ước lượng — nhưng con số này tính chính xác được. Nên viết "Còn dùng được 20 ngày" |
| "Bạn đang chi tiêu khá hợp lý!" | Đây là AI sinh câu khen. Nguyên tắc đã chốt: **AI không sinh số**, nhưng câu khen không kiểm chứng được cũng là vấn đề. Nên dựa vào ngưỡng: "Đã dùng 60% ngân sách, còn 18 ngày" |
| "Bạn có thể mua — Nhưng hãy cân nhắc nếu còn nhiều khoản chi khác" | Nửa cho phép nửa cảnh báo, người dùng không biết nghe bên nào. Phải chọn một kết luận |

---

## Phụ lục: nguyên văn

Giữ nguyên văn bản nhóm gửi, kể cả lỗi chính tả, để đối chiếu sau này.

> Tên ứng dụng: Student Finance (Ứng dụng quản lý tài chính cá nhân dành cho sinh viên). Phong cách thiết kế (UI Style): Modern, Clean, Minimalist. Sử dụng các thẻ bo góc (rounded cards), màu chủ đạo là Xanh lá (Emerald/Green) biểu trưng cho tài chính/an toàn, kết hợp màu xám sáng cho nền và các điểm nhấn màu cam/đỏ khi cảnh báo.
>
> Cấu trúc điều hướng (Navigation): Thanh điều hướng dưới cùng (Bottom Navigation Bar) gồm 4 tab chính: Trang chủ (Home), Giao dịch (Transactions), Ngân sách (Budget), Thống kê (Statistics).
>
> **1. Màn hình Trang chủ (Home Screen)**
> Header: Hiển thị logo "Student Finance", tiêu đề ứng dụng và icon chuông thông báo ở góc phải.
> Card Tổng quan tài chính (Top Card): Nền màu xanh lá đậm. Hiển thị "Số dư hiện tại" (ví dụ: 1.200.000 đ) với font chữ to, nổi bật. Hàng dưới chia đôi: "Thu nhập tháng" (mũi tên xanh) và "Chi tiêu tháng" (mũi tên đỏ).
> Thẻ Dự báo thông minh: Dòng chữ "Bạn có thể sử dụng tiền trong khoảng 20 ngày nữa" kèm icon lịch và mũi tên chuyển hướng, giúp sinh viên nhận biết tình trạng sức khỏe tài chính hiện tại.
> Thẻ Ngân sách tháng: Hiển thị tổng ngân sách, số tiền còn lại và thanh tiến trình (Progress bar) thể hiện % đã sử dụng (ví dụ: 60%). Bên dưới hiển thị các icon danh mục nhanh (Ăn uống, Đi lại, Học tập, Giải trí, Mua sắm).
> Thẻ Thử thách tiết kiệm / Gamification: Khung hiển thị mục tiêu (ví dụ: Mua laptop 500.000đ) kèm thanh tiến trình và icon huy chương.
>
> **2. Màn hình Ghi chép giao dịch nhanh (Add Transaction Screen)**
> Header: Nút quay lại (<), tiêu đề "Ghi chép giao dịch", và 2 nút phân loại lớn ở đầu: "Thu nhập" (mũi tên xanh) và "Chi tiêu" (mũi tên đỏ).
> Khu vực nhập tiền: Hiển thị số tiền lớn (ví dụ: đ 50.000) kèm nút xóa (X).
> Lưới danh mục (Categories Grid): Các icon danh mục được sắp xếp dạng lưới (Ăn uống, Đi lại, Học tập, Giải trí, Mua sắm, Khác...). Khi chọn danh mục nào, icon sẽ được đổi màu làm nổi bật.
> Ghi chú & Nút lưu: Ô nhập ghi chú tùy chọn (ví dụ: "Ăn trưa") và nút lớn màu xanh lá "Lưu giao dịch" ở dưới cùng.
>
> **3. Màn hình Ngân sách & Hũ chi tiêu (Budget Screen)**
> Tổng quan: Hiển thị tổng ngân sách tháng (ví dụ: 3.000.000 đ) kèm nút chỉnh sửa (icon cây bút).
> Biểu đồ phân bổ: Biểu đồ tròn (Donut Chart) ở giữa thể hiện tỷ lệ % đã dùng (60% đã sử dụng).
> Danh sách chi tiết các Hũ: Liệt kê các hũ kèm màu sắc tương ứng (Ăn uống 40%, Đi lại 13%, Học tập 10%, Giải trí 10%, Khác 27%).
> Thẻ Mẹo nhỏ (Smart Tips): Khung màu vàng nhạt đưa ra lời khuyên AI (ví dụ: "Bạn đang chi tiêu khá hợp lý! Hãy cố gắng giữ vững nhé").
> Chế độ tiết kiệm: Nút gạt (Toggle switch) bật/tắt chế độ tiết kiệm và hiển thị mục tiêu hiện tại.
>
> **4. Màn hình Thống kê (Statistics Screen)**
> Bộ lọc thời gian: Nút chuyển đổi giữa "Tháng này" và "Tháng trước".
> Tổng kết nhanh: Hai thẻ hiển thị "Tổng thu" và "Tổng chi" kèm biểu đồ mũi tên.
> Biểu đồ chi tiêu: Biểu đồ tròn trực quan kèm chú thích tỷ lệ phần trăm các danh mục.
> Khoản chi lớn nhất: Thẻ làm nổi bật danh mục ngốn nhiều tiền nhất (ví dụ: Ăn uống - 720.000 đ).
> So sánh tháng trước: Dòng thông báo biến động (ví dụ: "Chi tiêu tăng 12% so với tháng trước" với mũi tên màu xanh/đỏ).
>
> **5. Màn hình Tính năng nâng cao (AI Assistant, Split Bill, AI Advisor)**
> Trợ lý tài chính AI (AI Chatbot): Giao diện khung chat với avatar dễ thương, dòng chào mừng "Bạn cần mình giúp gì hôm nay?" và các câu hỏi gợi ý mẫu dạng bong bóng chat (ví dụ: "Tháng này tôi tiêu nhiều nhất ở đâu?", "Tôi còn bao nhiêu tiền đến cuối tháng?").
> Chia sẻ chi phí nhóm (Split Bill): Hiển thị nhóm đang tham gia ("Nhóm trọ 4 người - 4 thành viên"). Thẻ chi phí chung (Ví dụ: Tiền điện tháng 11 - 400.000 đ, mỗi người 100.000 đ). Nút "Thêm chi phí" và danh sách lịch sử chi.
> Trợ lý phân tích mua sắm ("Tôi có nên mua món này?"): Hiển thị món hàng dự định mua (Ví dụ: Tai nghe không dây - 350.000 đ). Phần Phân tích nhanh: Check list 3 điều kiện (Số dư hiện tại, Sau khi mua còn bao nhiêu, Vẫn đủ dùng đến cuối tháng). Kết luận rõ ràng: "Bạn có thể mua - Nhưng hãy cân nhắc nếu còn nhiều khoản chi khác" kèm các nút hành động.

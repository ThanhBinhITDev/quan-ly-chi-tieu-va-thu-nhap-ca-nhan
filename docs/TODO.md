# Danh sách việc còn thiếu

Tổng hợp các khoảng trống của dự án tính đến 2026-11-16. Sắp theo mức độ ảnh hưởng đến điểm thi và tính khả thi.

## P0 — Phải làm trước khi nộp bài

| # | Việc | Vì sao | Ước lượng công |
|---|---|---|---|
| 1 | Khảo sát 150–200 sinh viên về thói quen chi tiêu | Bài hiện không có một dữ liệu thực tế nào chứng minh nhu cầu | 1 tuần |
| 2 | Bảng tài chính 3 năm có con số cụ thể | Hội đồng chắc chắn hỏi; hiện chỉ có tỷ trọng % | 3 ngày |
| 3 | Trừ hoa hồng Google/Apple (15–30%) khỏi mọi bảng doanh thu | Gói 29.000đ thực nhận chỉ 20.300–24.650đ. Số hiện tại đang sai | 0,5 ngày |
| 4 | Điền tên người hướng dẫn | Mục này đang trống trong file gốc, nhiều cuộc thi trừ điểm nặng | — |
| 5 | Xác định vai trò của Hà Văn Thương | Đang để trống phần "kinh nghiệm/sở trường" | — |
| 6 | Phân tích đối thủ cụ thể (Money Lover, Misa, Spendee, app ngân hàng) | Bài chỉ nói chung chung, không chứng minh được lợi thế | 3 ngày |
| 7 | Rà lỗi chính tả file thuyết minh gốc | "qạn học sinh", "ngồn tiền", "thù quản lý", "Bán giải pháp ." | 1 giờ |

> Việc phân công người phụ trách do nhóm trưởng quyết định — tài liệu này chỉ liệt kê đầu việc và khối lượng ước tính.

## P1 — Cần cho tính khả thi

| # | Việc | Vì sao |
|---|---|---|
| 8 | Thiết kế hệ thống: kiến trúc, schema DB, API contract, luồng sync, màn hình, cấu trúc iOS, cấu trúc Flutter, 12 job định kỳ | Xong bản nháp 2.0 — xem [`system-design/`](system-design/README.md), chờ duyệt |
| 9 | Wireframe chi tiết 5 màn hình chính | Hiện chỉ có mô tả bằng chữ |
| 10 | Bộ nhận diện thương hiệu: logo, màu sắc, font | Bài thi có logo nhưng repo chưa có file gốc |
| 11 | Viết chính sách quyền riêng tư + điều khoản sử dụng | Google Play và App Store từ chối app nếu thiếu |
| 12 | Xác định tuổi tối thiểu người dùng | Nhắm học sinh THPT đồng nghĩa xử lý dữ liệu người <16 tuổi, cần đồng ý phụ huynh theo NĐ 13/2023 |
| 13 | Đăng ký tài khoản Google Play developer (25 USD) | Cần thời gian, xem mục 14 |
| 14 | Lên kế hoạch closed testing 12–20 tester trong 14 ngày | Google Play bắt buộc với tài khoản cá nhân mới — mốc thời gian cứng, phải bắt đầu trước ngày thi ít nhất 1 tháng |
| 14b | Kiểm chứng 3 điểm trước khi đưa đọc sao kê vào lộ trình giai đoạn sau | (a) VCB/TPBank/MB có xuất CSV/Excel hay chỉ PDF, (b) MoMo share ra text hay ảnh, (c) có app Việt nào đang làm và còn sống trên Play Store |
| 14c | Quyết 4 điểm D1–D4 trong [`system-design/00`](system-design/00-architecture.md) mục 10 | Chặn việc chốt lộ trình và môi trường chạy thật |

## P2 — Nên có

| # | Việc | Ghi chú |
|---|---|---|
| 15 | Kịch bản demo 5 phút cho hội đồng | Chuẩn bị sẵn, không nghĩ tại chỗ |
| 16 | Bộ câu hỏi hội đồng có thể hỏi + câu trả lời | Đã có 7 câu trong trao đổi, chưa đưa vào file |
| 17 | Kế hoạch marketing 3 tháng đầu | Bài có kênh nhưng chưa có lịch và ngân sách |
| 18 | Ước tính CAC và vòng hoàn vốn | Chi phí có 1 khách trả tiền: 60.000–260.000đ, gần hòa vốn năm đầu |

## Điểm mâu thuẫn trong tài liệu gốc (đã sửa trong file đặc tả, cần sửa cả file thuyết minh)

| Vấn đề | Hiện trạng | Đề xuất |
|---|---|---|
| Chi phí "API AI (30–35%)" | Gộp chung với hạ tầng, tính như chi phí cố định | Tách: hạ tầng 8–10%, AI 3–5% (biến đổi theo user) |
| Gói Pro "không giới hạn lượt quét AI" | Không giới hạn = chi phí vô hạn | 300 lượt/tháng |
| AI không có chức năng nào được mô tả | Chỉ xuất hiện ở 2 dòng chi phí/doanh thu | Đã bổ sung 4 chức năng AI-1 đến AI-4 |
| Affiliate chiếm 35–40% doanh thu | Giai đoạn đầu gần bằng 0 | 6 tháng đầu: Pro ~90%, quảng cáo ~10%, affiliate ~0 |
| Tên app có "thu nhập" nhưng nội dung chỉ nói chi tiêu | 90% nội dung về chi | Đã bổ sung phần thu nhập không đều (làm thêm theo ca) |

## Rủi ro chưa có đối sách trong tài liệu

| Rủi ro | Mức độ | Ghi chú |
|---|---|---|
| Chỉ 1 người làm kỹ thuật (4/5 thành viên học Kế toán) | Cao | Nếu người này bận, dự án dừng |
| Người dùng bỏ app sau 2 tuần | Cao | Đã có tài liệu riêng về chiến lược giữ chân |
| App ngân hàng đã làm miễn phí | Cao | Đối thủ thật, không phải Money Lover |
| Không có ngân sách marketing | Cao | CAC gần bằng doanh thu năm đầu → không được chạy quảng cáo trả tiền |
| 10 tuần cho 4 nhóm chức năng là không thực tế với 1 dev part-time | Cao | Đề xuất thu hẹp MVP còn 3 tính năng |

# apps/ — Ba nền tảng, ba công nghệ riêng

| Thư mục | Nền tảng | Công nghệ | Ngôn ngữ |
|---|---|---|---|
| [ios/](ios/) | iPhone | SwiftUI native, SwiftData, Swift Charts | Swift |
| [android/](android/) | Android | Flutter, Riverpod, drift | Dart |
| [web/](web/) | Trình duyệt | Next.js (React), TypeScript | TypeScript |

Ba nền, ba ngôn ngữ, **không share mã nguồn**. Chia sẻ qua **hợp đồng API JSON** — chi tiết ở [docs/system-design/08-api-principles.md](../docs/system-design/08-api-principles.md).

## Vì sao không share mã

| Cặp | Có share được không | Lý do |
|---|---|---|
| iOS ↔ Android | Không | Swift và Dart khác ngôn ngữ hoàn toàn |
| Android ↔ Web | Không chọn share | Web cần SEO, tải trang nhanh, thư viện web mạnh (React ecosystem). Flutter Web tải 2–3 MB trước khi hiện chữ, không phù hợp landing page và SEO |
| iOS ↔ Web | Không | Swift và TypeScript khác ngôn ngữ |

**Bù lại bằng ba thứ:**

1. **Một hợp đồng API** — `packages/shared-types/openapi.yaml` là nguồn sự thật duy nhất. Sinh client cho Dart (OpenAPI Generator) và Swift (OpenAPI Generator Swift), còn TypeScript dùng trực tiếp.
2. **Cùng bộ số liệu test** cho công thức "hôm nay được tiêu" — viết ba lần nhưng dùng chung file số liệu, CI chạy cả ba, để phát hiện lệch giữa ba nền.
3. **Cùng tài liệu màn hình** — [04-wireframes.md](../docs/system-design/04-wireframes.md), ghi rõ chỗ nào khác theo nền tảng.

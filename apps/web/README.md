# apps/web — Web (Next.js)

> Nhánh: `dev/web`. Phát triển vùng này thì đứng ở nhánh đó — xem [../../docs/BRANCHING.md](../../docs/BRANCHING.md).

Chưa tạo project. Sẽ có ở tuần 1.

| Việc | Giá trị |
|---|---|
| Framework | Next.js (App Router), React 19, TypeScript |
| Style | Tailwind CSS |
| Dữ liệu | TanStack Query (cache + refetch), gọi `services/api` |
| Form | React Hook Form + Zod (validate khớp với DTO) |
| Offline | Service Worker + IndexedDB (Dexie) cho ghi nháp |
| Deploy | Vercel free tier, hoặc Cloudflare Pages |
| CI | GitHub Actions: `next lint`, `tsc --noEmit`, `vitest` |

## Vì sao Next.js chứ không Flutter Web

| Tiêu chí | Next.js | Flutter Web |
|---|---|---|
| Tải trang đầu | ~100–200 KB, hiện chữ ngay | ~2–3 MB, màn hình trắng vài giây |
| SEO | Có, SSR/SSG | Kém, nội dung do canvas vẽ |
| Hệ sinh thái | Lớn nhất (React) | Nhỏ, nhiều gói không hỗ trợ web |
| Chia sẻ type với backend | Có, cùng TypeScript | Không, phải sinh client |
| Landing page, đăng ký | Mạnh | Yếu |

Đổi lại: thêm một ngôn ngữ nữa trong dự án (TypeScript, nhưng backend cũng TypeScript nên chỉ thêm một runtime).

## Phạm vi ở MVP

Web **không phải bản đầy đủ**. Ở MVP chỉ làm:

1. Landing page giới thiệu
2. Đăng ký / đăng nhập
3. Xem báo cáo tháng (đọc, không ghi)

Ghi giao dịch và quản lý ví để giai đoạn 2. Lý do: người dùng chính dùng điện thoại; web chủ yếu để tìm hiểu và đăng ký.

> **D1 đã chốt:** Web tách khỏi Flutter, dùng Next.js. Vẫn ưu tiên thấp ở MVP — nếu thiếu thời gian thì cắt phần ghi giao dịch trên web, không cắt landing + đăng ký.

# Quy trình nhánh

Mỗi vùng phát triển có nhánh riêng. Làm gì thì đứng ở nhánh đó, không nhảy
sang nhánh của vùng khác.

## Danh sách nhánh

| Nhánh | Phụ trách | Thư mục được sửa |
| --- | --- | --- |
| `main` | Bản ổn định, đã kiểm chứng | Không sửa trực tiếp |
| `dev/ios` | App iPhone | `apps/ios/` |
| `dev/android` | App Android | `apps/android/` |
| `dev/web` | Web Next.js | `apps/web/` |
| `dev/api` | Backend NestJS | `services/api/` |
| `dev/worker` | Job định kỳ, BullMQ | `services/worker/` |
| `dev/shared-types` | DTO, OpenAPI, client sinh tự động | `packages/shared-types/` |
| `dev/infra` | Migration, Postgres local, hạ tầng | `infra/` |

Tài liệu (`docs/`) sửa ở nhánh của vùng liên quan. Nếu sửa tài liệu chung
cho nhiều vùng thì làm ở `main` qua một commit riêng, hoặc ở nhánh vùng
chính đang mô tả.

## Vì sao tách thay vì chỉ dùng main

Ba nền tảng chạy song song với ba bộ công cụ khác nhau. Nếu tất cả cùng
đẩy vào `main` thì lịch sử trộn lẫn, một lần `flutter analyze` lỗi cũng
không biết là do ai, và không thể chỉ deploy backend khi app còn dở.

Nhánh theo vùng giữ cho mỗi lần review chỉ phải đọc một thứ.

## Quy trình làm việc

### Bắt đầu một việc

```bash
cd /Users/thanhbinh/Projects/quan-ly-chi-tieu-sinh-vien
git checkout dev/android          # hoặc nhánh của vùng sếp làm
git pull origin dev/android       # lấy mới nhất
```

Làm việc, commit, đẩy lên:

```bash
git add apps/android/
git commit -m "..."
git push origin dev/android
```

### Đưa vào main

Khi một việc đã xong và đã kiểm chứng:

```bash
git checkout dev/android
git pull origin dev/android
git checkout main
git pull origin main
git merge --no-ff dev/android -m "Gộp dev/android: <mô tả>"
```

`--no-ff` giữ lại một merge commit để sau này nhìn lịch sử vẫn biết nhóm
nào gộp lúc nào. Không dùng `--squash` vì sẽ mất dấu vết từng bước.

Kiểm chứng trước khi gộp, tùy vùng:

| Vùng | Lệnh bắt buộc |
| --- | --- |
| `dev/android` | `cd apps/android && flutter analyze && flutter test` |
| `dev/api` | `cd services/api && npx tsc --noEmit && npx vitest run && npm run lint` |
| `dev/infra` | Áp migration lên Postgres local phải sạch |
| `dev/ios` | `xcodebuild test` khi đã có mã |

Gộp xong thì đẩy:

```bash
git push origin main
```

### Đồng bộ ngược từ main về nhánh vùng

Khi `main` có thay đổi mà nhánh vùng cần (ví dụ migration mới, DTO mới):

```bash
git checkout dev/android
git merge main -m "Đồng bộ main vào dev/android"
```

Làm sớm và làm thường xuyên. Để lâu thì xung đột chồng chất.

## Ranh giới giữa các vùng

Đây là phần dễ hỏng nhất. Một số thứ **không** được sửa ở nhánh vùng:

| Thứ | Chỉ sửa ở | Vì sao |
| --- | --- | --- |
| `infra/migrations/*.sql` | `dev/infra` | Là nguồn sự thật của schema, cả ba nền cùng phụ thuộc |
| `packages/shared-types/` | `dev/shared-types` | Client Dart và Swift sinh từ đây |
| `docs/system-design/01-database-schema.md` | `dev/infra` | Phải khớp migration |
| `docs/system-design/02-api-contract.md` | `dev/api` | Phải khớp code backend |
| `assets/brand/` | `main` | Dùng chung, không thuộc vùng nào |

Nếu một việc cần sửa cả hai vùng (ví dụ thêm cột DB rồi dùng ở API): làm
ở `dev/infra` trước, gộp vào `main`, rồi đồng bộ `main` xuống `dev/api`.
Không sửa migration trong nhánh `dev/api`.

## Đặt tên commit

Một dòng đầu nêu việc làm, không nêu tên file. Thân commit giải thích
**vì sao**, không kể lại **cái gì** (diff đã kể rồi).

```
Thêm form nhập giao dịch cho Android

Bottom sheet nhập tay, mở từ FAB ở tab Giao dịch.

parseAmount nhận cả ba kiểu người Việt hay gõ - 35000, 35.000,
35,000 - và từ chối chuỗi rỗng, 0, số âm và ký tự không phải số.
```

Viết tiếng Việt, không dấu ở mã lệnh nhưng có dấu ở câu văn.

## Nhánh tạm cho việc lớn

Việc dài hơn vài ngày và cần tách khỏi nhánh vùng đang chạy:

```bash
git checkout dev/api
git checkout -b feature/api-sync-push
# làm xong, gộp lại vào dev/api rồi xoá
git checkout dev/api && git merge feature/api-sync-push
git branch -d feature/api-sync-push
```

Dùng cho việc có rủi ro làm hỏng nhánh vùng, hoặc cần người khác review
riêng. Việc nhỏ thì commit thẳng vào nhánh vùng, đừng tạo nhánh rác.

## Những điều không làm

- Không commit trực tiếp vào `main` khi đang phát triển tính năng.
- Không `git push --force` lên `main` hay bất kỳ nhánh `dev/*` đã đẩy.
- Không sửa file migration đã áp dụng. Thêm migration mới.
- Không commit `.env`, credential, hay `node_modules`, `dist/`, `.dart_tool/`.
- Không gộp nhánh vùng vào `main` khi test còn đỏ.

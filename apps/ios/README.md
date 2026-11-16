# apps/ios — iOS (SwiftUI native)

Chưa tạo project Xcode. Sẽ có ở tuần 1.

| Việc | Giá trị |
|---|---|
| Ngôn ngữ / UI | Swift 6, SwiftUI, @Observable |
| Target | iOS 18 (chờ quyết ở mục 11 [05](../../docs/system-design/05-ios-structure.md)) |
| CSDL local | SwiftData — kiểm chứng query 3.000 dòng < 50 ms ở tuần 1, chậm thì chuyển GRDB |
| Biểu đồ | Swift Charts |
| Widget / Siri | WidgetKit + App Intents |
| Gọi API | URLSession async/await + `Codable` |
| CI | GitHub Actions, `xcodebuild test` trên simulator |

Cây thư mục **bắt buộc** khi tạo: `Features/ Core/ Data/ Domain/ Tests/` — chi tiết ở [docs/system-design/05-ios-structure.md](../../docs/system-design/05-ios-structure.md).

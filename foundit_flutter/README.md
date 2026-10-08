# FOUND !T｜Flutter 前端

台灣失物共享 App。此專案為目前主前端，使用 Flutter 3.47 / Dart 3.13、Riverpod、go_router、Dio、flutter_map 與 Noto Sans TC。後端評估、部署設定與正式上線限制見 [根目錄 README](../README.md)。

## 本機體驗

```powershell
flutter pub get
flutter run -d chrome --dart-define=USE_MOCK=true
```

`USE_MOCK` 預設 false；必須明確開啟才使用示範資料。正式 API 以 `API_BASE_URL` 與 `SOCKET_HOST` dart-define 設定。不要把體驗模式當成正式 SMS、聊天或認領服務。

Windows 工作環境的 Flutter 位於 `D:\dev\flutter`。若依賴已解析而桌面 symlink 受開發人員模式限制，可使用 `--no-pub` 建置已驗證的 Web 版：

```powershell
flutter build web --no-pub --no-wasm-dry-run --dart-define=USE_MOCK=true
node tool/serve-preview.mjs
```

本機預覽位於 http://127.0.0.1:4173 。

## 品牌與排版

- 炭黑 `#282B30`、暖白 `#FCFAF7`、陶橘品牌 `#C64B30`；小字操作色 `#BA4329`。
- `assets/brand` 保存原創 FOUND !T SVG 字標、括角驚嘆號符號及深淺版 App icon。
- `lib/presentation/widgets/brand_mark.dart` 使用 SVG，縮小時可改用獨立符號。
- 文字依系統縮放；按鈕採最小尺寸及內容高度，長內容換行／捲動。
- 主要動畫尊重減少動態設定；中文字型授權見 `assets/fonts/OFL.txt`。

## 驗證

```powershell
flutter test --no-pub
flutter analyze --no-pub --no-fatal-infos
```

測試包含搜尋、篩選、刊登、登入、QR、收藏、訊息、個人資料、失敗重試，並以實際 Noto Sans TC 覆蓋手機／橫向／平板／桌面及 100%／130%／200% 字級。測試用相機、相片選擇、上傳與地圖圖磚採可控制替身；真機硬體、相機／定位權限、SMS、正式 API 仍需另行驗收。

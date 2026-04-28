# 如何啟動這個 Flutter 專案

## 1. 安裝 Flutter SDK（只需一次）

1. 下載 [Flutter SDK for Windows](https://docs.flutter.dev/get-started/install/windows)
2. 解壓到 `C:\src\flutter`（或任何不需要管理員權限的路徑）
3. 把 `C:\src\flutter\bin` 加入系統環境變數 `PATH`
4. 開新的 PowerShell，執行：
   ```powershell
   flutter doctor
   ```
   確認 Flutter、Android Studio、Android SDK 都顯示 `[✓]`

## 2. 初始化平台資料夾

此專案目前只包含 `lib/`（所有程式碼）、`pubspec.yaml` 與資源。Android/iOS 平台資料夾需要一次性補齊：

```powershell
cd "e:\Programming Project\Foundit2\foundit_flutter"
flutter create . --org com.foundit --project-name foundit --platforms=android,ios
```

`flutter create .` 會自動：
- 產生 `android/`、`ios/` 平台資料夾
- **不會覆蓋** 已存在的 `lib/`、`pubspec.yaml`、`README.md`

## 3. 取得套件

```powershell
flutter pub get
```

## 4. 執行

在 Android Studio 打開裝置管理器啟動一個模擬器，然後：

```powershell
flutter run
```

第一次編譯會比較慢（幾分鐘），之後的熱重載（按 `r`）只要幾百毫秒。

---

## 目前的預設行為

- `lib/core/constants/app_constants.dart` 裡 `useMock = true`，首頁直接顯示 6 筆假資料，不需要後端。
- `baseUrl` 預設 `http://10.0.2.2:3000/api/v1`（Android 模擬器指向主機 localhost）。
  - 想真的連後端時，把 `useMock` 改成 `false`，並確認後端在執行中。
  - 如果用實機，把 baseUrl 改成電腦的 IP（如 `http://192.168.1.100:3000/api/v1`）。

---

## 常見問題

### Google Fonts 下載不了？
部分網路環境需要用 VPN；或直接把 `google_fonts` 套件換成本地字體（放到 `assets/fonts/`，在 `pubspec.yaml` 宣告即可）。

### flutter_map 地圖空白？
本專案使用 OpenStreetMap 圖磚，需要連線到 `tile.openstreetmap.org`。若要換成 Google Maps，改用 `google_maps_flutter` 套件即可。

### 想看完整視覺設計？
先跑起來，Splash → Login（隨便填手機 → 隨便填驗證碼）→ Home，就能看到所有畫面。

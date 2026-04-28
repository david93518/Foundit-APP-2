# 上線部署檢查清單（Foundit）

> 本檔案是「準備將 App 上架到 Google Play / App Store」前的最後檢查表。
> 後端使用 NestJS（`Foundit/backend`），前端使用 Flutter（`foundit_flutter`）。

---

## 1. 後端（NestJS）

### 1.1 環境變數

請在部署環境（Render / Railway / 自己的 VPS）建立以下變數：


| 變數                                                            | 必填  | 說明                                              |
| ------------------------------------------------------------- | --- | ----------------------------------------------- |
| `DATABASE_URL`                                                | ✅   | Postgres 連線字串（建議用受控資料庫服務）                       |
| `JWT_SECRET`                                                  | ✅   | 至少 32 個隨機字元，**不可 commit 進 repo**                |
| `JWT_EXPIRES_IN`                                              | ⭕   | 預設 `7d`                                         |
| `OTP_DRIVER`                                                  | ✅   | `console`（開發）/ `every8d` / `twilio`             |
| `OTP_EXPIRES_MINUTES`                                         | ⭕   | 預設 5 分鐘                                         |
| `EVERY8D_API_KEY` / `TWILIO_`*                                | ⭕   | 對應簡訊商                                           |
| `GOOGLE_CLIENT_ID_WEB`                                        | ✅   | Google Cloud Console 產生的「網頁應用程式」OAuth Client ID |
| `LINE_CHANNEL_ID` / `LINE_CHANNEL_SECRET`                     | ⚠️  | 目前 LINE 登入標示為「即將推出」，可暫時不填                       |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` / `S3_BUCKET` / `S3_REGION` | ✅   | 圖片上傳儲存                                          |
| `OPENAI_API_KEY` 或 `GEMINI_API_KEY`                           | ✅   | AI 物品配對                                         |
| `CORS_ORIGINS`                                                | ✅   | 允許的前端網域，逗號分隔                                    |


### 1.2 部署前指令

```bash
cd Foundit/backend
npm ci
npm run build
npm run typeorm:migration:run   # 確認所有 migration 已執行
npm run start:prod
```

### 1.3 性能 / 索引

本次已加入以下索引（生效需重啟並執行 migration / 同步）：

- `notifications` 表：`(user_id, created_at)`、`(user_id, is_read)`
- `items` 表：`(status, created_at)`、`(user_id)`、`(type, status)`、`(category)`

如使用 `synchronize: true`（不建議生產環境）會自動建立；
建議改用 migration 並手動產生 SQL。

### 1.4 序列化（避免外洩敏感資料）

所有對行動端的回傳都已通過 mobile serializer：

- `users.controller` / `auth.controller`：`toMobileUser`
- `items.controller`：`toMobileItem`（含 `user_verified`）
- `qr.controller`：`toMobileQrItem` + `toMobileUser`
- `ai.controller`：`toMobileItem`
- `notifications.controller`：`toMobileNotification`

請確保**未來新增 endpoint 時也走 serializer**，避免不小心輸出 `fcmToken`、`googleSub`、`lineSub` 等欄位。

---

## 2. 前端（Flutter）

### 2.1 build 時必填的 `--dart-define`

```bash
flutter build apk \
  --dart-define=API_BASE_URL=https://api.foundit.com.tw/api/v1 \
  --dart-define=SOCKET_HOST=https://api.foundit.com.tw \
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com \
  --dart-define=PROD=true
```

iOS 用 `flutter build ipa` 也用一樣的旗標。
**不要在 `app_constants.dart` 寫死 production URL。**

### 2.2 各平台配置檢查

- **Android**：
  - `android/app/build.gradle` 的 `applicationId` 改為正式值（非 `com.example.`*）
  - `android/app/src/main/AndroidManifest.xml` 已聲明 INTERNET、CAMERA、ACCESS_FINE_LOCATION
  - keystore 已建立（`upload-keystore.jks`）並 `key.properties` 配好
  - 將 `signingConfigs.release` 指向正式 keystore
- **iOS**：
  - `ios/Runner/Info.plist` 加上：
    - `NSCameraUsageDescription`（QR 掃描）
    - `NSPhotoLibraryUsageDescription`（選照片）
    - `NSLocationWhenInUseUsageDescription`（定位）
  - 升 Bundle ID 並到 App Store Connect 開好對應 App
  - Push notification capability 開（如果用 FCM iOS）

### 2.3 已確認移除 / 改寫的 mock

- ✅ AI 配對：改接 `/ai/match`
- ✅ QR 標籤 / 掃描：改接 `/qr/`*
- ✅ Add Item：定位改用真實 GPS
- ✅ Item Detail 收藏：改用 SharedPreferences 持久化
- ✅ 聊天列表 / 聊天室：走 REST + WebSocket
- ✅ 個人頁統計：`UserStats` 由後端回，收藏數從 prefs 計算
- ✅ Login LINE：標示「即將推出」並 disable

### 2.4 上線前一定要關

```dart
// foundit_flutter/lib/core/constants/app_constants.dart
static const bool useMock = false;   // ← 確認是 false
```

### 2.5 401 自動登出

`ApiClient` 已加 401 攔截器，會清掉 token + 廣播事件，
`FounditApp` 收到事件後 `go('/login')`。
**測試**：手動把 prefs 的 token 改錯後操作任一 API 應自動跳回登入頁。

---

## 3. 上架前最後測試清單

請在實機（Android / iOS）跑完以下流程：

1. [ ] 全新安裝 → 開啟 → 看到登入頁
2. [ ] 手機 OTP 註冊 / 登入
3. [ ] Google 登入
4. [ ] 主畫面顯示自己頭像（無頭像時顯示預設 icon，不要外連 i.pravatar）
5. [ ] 新增遺失 / 拾獲物品（含拍照、定位）
6. [ ] 在地圖頁看到剛新增的物品
7. [ ] AI 配對：上傳照片 + 關鍵字皆能拿到結果
8. [ ] 用另一隻手機 / 帳號開聊天，雙方訊息即時送達
9. [ ] QR 標籤：建立、列表、刪除
10. [ ] 用另一隻手機掃 QR → 顯示物主資訊
11. [ ] 設定頁編輯個人資料（名稱、頭像、bio）
12. [ ] 推播：收到聊天 / AI 配對通知
13. [ ] 登出 → 重新登入 → 收藏 / 個人資料仍正確
14. [ ] 把後端 token 弄壞 → app 自動跳回登入頁
15. [ ] 切到飛航模式 → 主要畫面有 retry / 友善錯誤訊息

---

## 4. 監控 / 日誌

部署後建議：

- 後端串 Sentry / Datadog 收 unhandled exception
- 前端串 Crashlytics
- 設置 uptime monitor（健康檢查 endpoint：`GET /api/v1/health`）

---

最後祝上架順利 🚀
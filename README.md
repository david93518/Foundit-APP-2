# 找得到 Foundit｜失物共享平台

> 版本：1.0.0 ｜ 最後更新：2026/04

台灣在地化的失物共享平台，參考韓國 FindingAll 模式，整合遺失物登記、撿到物登記、AI 圖片配對、地圖搜尋、即時聊天、賞金系統、QR 防丟貼紙等功能。

---

## 目錄

1. [專案結構](#專案結構)
2. [系統架構圖](#系統架構圖)
3. [技術棧總覽](#技術棧總覽)
4. [後端 Backend (NestJS)](#後端-backend-nestjs)
   - [環境需求](#後端環境需求)
   - [啟動步驟](#後端啟動步驟)
   - [環境變數說明](#環境變數說明)
   - [資料庫操作](#資料庫操作)
   - [API 文件](#api-文件)
5. [前端 Frontend (Flutter)](#前端-frontend-flutter)
   - [環境需求](#前端環境需求)
   - [啟動步驟](#前端啟動步驟)
   - [連接後端設定](#連接後端設定)
6. [功能模組](#功能模組)
7. [開發進度](#開發進度)
8. [部署上線](#部署上線)
9. [版本紀錄](#版本紀錄)

---

## 專案結構

```
Foundit2/                          # 根目錄（本 Repo）
├── Foundit/                       # 後端（NestJS）
│   ├── backend/
│   │   ├── src/
│   │   │   ├── main.ts            # 程式進入點
│   │   │   ├── app.module.ts      # 根模組
│   │   │   ├── auth/              # 認證模組（OTP、JWT、Google OAuth）
│   │   │   ├── users/             # 用戶模組
│   │   │   ├── items/             # 物品模組（遺失 / 撿到）
│   │   │   ├── chat/              # 聊天模組（REST + WebSocket）
│   │   │   ├── notifications/     # 推播通知模組（FCM）
│   │   │   ├── ai/                # AI 圖片配對模組
│   │   │   ├── qr/                # QR Code 模組
│   │   │   └── upload/            # 圖片上傳模組
│   │   ├── migrations/            # TypeORM 資料庫遷移
│   │   ├── .env.example           # 環境變數範例
│   │   ├── docker-compose.yml     # Docker 一鍵啟動
│   │   ├── Dockerfile
│   │   └── package.json
│   └── README.md                  # 後端詳細說明
├── foundit_flutter/               # 前端（Flutter）
│   ├── lib/
│   │   ├── main.dart              # 進入點
│   │   ├── app.dart               # MaterialApp + 主題
│   │   ├── core/
│   │   │   ├── theme/             # 設計系統（顏色、字體、陰影）
│   │   │   ├── router/            # 路由（go_router）
│   │   │   ├── constants/         # 全域常數（API URL）
│   │   │   └── utils/             # 工具函式
│   │   ├── data/
│   │   │   ├── models/            # 資料模型（對應後端 DTO）
│   │   │   ├── api/               # Dio client + endpoints
│   │   │   ├── repositories/      # Repository 層
│   │   │   └── mock/              # Mock 資料（開發用）
│   │   └── presentation/
│   │       ├── screens/           # 各畫面
│   │       └── widgets/           # 共用 UI 元件
│   ├── android/                   # Android 平台設定
│   ├── ios/                       # iOS 平台設定
│   └── README.md                  # Flutter 詳細說明
├── DEPLOYMENT.md                  # 上線部署檢查清單
└── README.md                      # 本檔案
```

---

## 系統架構圖

```
┌──────────────────────────────────────────────────────────┐
│                  Flutter App（Client）                    │
│          Android / iOS — Riverpod + go_router            │
└───────────────────────┬──────────────────────────────────┘
                        │ HTTPS / WSS
         ┌──────────────▼──────────────┐
         │      後端伺服器 (NestJS)     │
         │   REST API + WebSocket       │
         └──┬──────────────┬───────────┘
            │              │
   ┌─────────▼──┐     ┌────▼──────┐
   │ PostgreSQL  │     │   Redis   │
   │ (主要資料庫)│     │ (Session/ │
   │            │     │  快取/佇列)│
   └────────────┘     └───────────┘
            │
   ┌─────────▼──────────┐
   │    外部服務          │
   │ • Firebase FCM（推播）│
   │ • Google OAuth       │
   │ • AI 圖片配對服務    │
   │ • AWS S3（圖片儲存） │
   │ • Every8d / Twilio（OTP 簡訊）│
   └────────────────────┘
```

---

## 技術棧總覽

### 後端

| 層級 | 技術 | 版本 |
|------|------|------|
| 語言 | TypeScript | 5.x |
| 框架 | NestJS | 10.x |
| ORM | TypeORM | 0.3.x |
| 資料庫 | PostgreSQL | 16.x |
| 快取／佇列 | Redis | 7.x |
| 即時通訊 | Socket.IO (WebSocket) | 4.x |
| 認證 | JWT + Passport.js | - |
| 圖片上傳 | Multer + AWS S3 | - |
| 推播 | Firebase Admin SDK | 12.x |
| API 文件 | Swagger (OpenAPI 3.0) | - |
| 容器化 | Docker + Docker Compose | - |

### 前端

| 層級 | 技術 | 版本 |
|------|------|------|
| 語言 | Dart | 3.3+ |
| 框架 | Flutter | 3.22+ |
| 狀態管理 | Riverpod | - |
| 路由 | go_router | - |
| 網路 | Dio | - |
| 地圖 | flutter_map（OpenStreetMap）| - |
| QR 掃描 | mobile_scanner + qr_flutter | - |
| 圖片 | cached_network_image | - |

---

## 後端 Backend (NestJS)

### 後端環境需求

| 軟體 | 最低版本 | 說明 |
|------|----------|------|
| Node.js | 20.x LTS | 執行環境 |
| npm | 10.x | 套件管理 |
| PostgreSQL | 16.x | 主要資料庫 |
| Redis | 7.x | 快取與 Session |
| Docker（選用）| 24.x | 一鍵部署 |

---

### 後端啟動步驟

#### 方法一：Docker 一鍵啟動（推薦）

> 需先安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/)

**步驟 1：進入後端目錄**

```bash
cd Foundit/backend
```

**步驟 2：複製並設定環境變數**

```bash
cp .env.example .env
# 用文字編輯器開啟 .env，填入必要設定（見下方「環境變數說明」）
```

**步驟 3：啟動所有服務（後端 + PostgreSQL + Redis）**

```bash
docker-compose up -d
```

**步驟 4：執行資料庫遷移**

```bash
docker-compose exec api npm run typeorm:migration:run
```

**步驟 5：確認服務正常運行**

```bash
# 查看容器狀態
docker-compose ps

# 查看後端日誌
docker-compose logs -f api
```

**步驟 6：開啟 API 文件**

瀏覽器前往 `http://localhost:3000/api/docs` 查看完整 Swagger 互動文件。

---

#### 方法二：手動本機啟動

**步驟 1：安裝 PostgreSQL**

- 前往 [postgresql.org](https://www.postgresql.org/download/) 下載安裝包
- 安裝後建立資料庫：

```sql
CREATE DATABASE foundit;
CREATE USER foundit_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE foundit TO foundit_user;
```

**步驟 2：安裝 Redis**

- Windows 建議使用 [Memurai](https://www.memurai.com/) 或透過 WSL2：

```bash
# WSL2 方式
sudo apt update && sudo apt install redis-server
sudo service redis-server start
```

**步驟 3：安裝 Node.js 依賴**

```bash
cd Foundit/backend
npm install
```

**步驟 4：設定環境變數**

```bash
cp .env.example .env
# 編輯 .env 填入資料庫、Redis、JWT 等設定
```

**步驟 5：執行資料庫遷移**

```bash
npm run typeorm:migration:run
```

**步驟 6：啟動開發伺服器**

```bash
# 開發模式（支援熱重載）
npm run start:dev

# 正式模式
npm run build
npm run start:prod
```

**步驟 7：確認啟動成功**

終端機出現以下訊息代表成功：

```
[NestJS] Application is running on: http://localhost:3000
```

---

### 環境變數說明

後端根目錄的 `.env` 檔案需填入以下設定：

```env
# ===== 應用設定 =====
NODE_ENV=development
PORT=3000

# ===== 資料庫 (PostgreSQL) =====
DATABASE_URL=postgresql://foundit_user:your_password@localhost:5432/foundit

# ===== Redis =====
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=                      # 若有設定密碼則填入

# ===== JWT 認證 =====
JWT_SECRET=your_super_secret_key     # 建議使用 32+ 字元隨機字串，絕不可 commit 進 repo
JWT_EXPIRES_IN=7d

# ===== OTP 簡訊 =====
OTP_DRIVER=console                   # 開發用 console；正式用 every8d 或 twilio
OTP_EXPIRES_MINUTES=5
EVERY8D_API_KEY=your_api_key         # 使用 Every8d 時填入
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxx # 使用 Twilio 時填入
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# ===== Google OAuth =====
GOOGLE_CLIENT_ID_WEB=your_google_client_id.apps.googleusercontent.com

# ===== Firebase Admin (推播通知) =====
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com

# ===== 圖片上傳 (AWS S3) =====
S3_ACCESS_KEY=your_access_key
S3_SECRET_KEY=your_secret_key
S3_BUCKET=your-bucket-name
S3_REGION=ap-northeast-1

# ===== AI 配對服務 =====
OPENAI_API_KEY=your_openai_key       # 或使用 GEMINI_API_KEY

# ===== CORS =====
CORS_ORIGINS=http://localhost:3001   # 允許的前端來源，多個用逗號分隔
```

> **安全提醒：** `.env` 檔案已加入 `.gitignore`，請勿 commit 至版本控制。

---

### 資料庫操作

後端採用 TypeORM Migration 管理資料庫版本：

```bash
# 執行所有未執行的 migration
npm run typeorm:migration:run

# 產生新的 migration（偵測 entity 變更）
npm run typeorm:migration:generate -- src/migrations/YourMigrationName

# 回滾最後一次 migration
npm run typeorm:migration:revert
```

主要資料表：

| 資料表 | 說明 |
|--------|------|
| `users` | 用戶資料（手機、名稱、積分、頭像） |
| `items` | 物品（遺失 / 撿到）、類別、地點、照片 |
| `chats` | 聊天室（兩用戶間） |
| `messages` | 聊天訊息 |
| `notifications` | 推播通知紀錄 |
| `qr_codes` | QR 防丟貼紙對應關係 |
| `point_logs` | 積分變動紀錄 |

---

### API 文件

啟動後端後，瀏覽器開啟 `http://localhost:3000/api/docs` 查看完整 Swagger UI 文件。

主要 API 端點：

```
# 認證
POST   /api/v1/auth/otp/send          # 發送 OTP 簡訊
POST   /api/v1/auth/otp/verify        # 驗證 OTP，回傳 JWT
GET    /api/v1/auth/google            # Google OAuth 登入

# 用戶
GET    /api/v1/users/me               # 取得目前用戶資料
PUT    /api/v1/users/me               # 更新用戶資料

# 物品
GET    /api/v1/items                  # 取得物品列表（支援分頁 / 篩選）
POST   /api/v1/items                  # 新增物品
GET    /api/v1/items/:id              # 取得物品詳情
PUT    /api/v1/items/:id              # 更新物品
DELETE /api/v1/items/:id              # 刪除物品
PATCH  /api/v1/items/:id/found        # 標記為已找到

# 聊天
GET    /api/v1/chats                  # 聊天列表
GET    /api/v1/chats/:id/messages     # 取得訊息記錄

# 其他
POST   /api/v1/upload                 # 上傳圖片（回傳 URL）
POST   /api/v1/ai/match               # AI 圖片配對
POST   /api/v1/qr/generate            # 產生 QR Code
GET    /api/v1/qr/:code               # QR 掃描查詢
GET    /api/v1/health                 # 健康檢查

# WebSocket（Socket.IO）
ws://localhost:3000
  chat:join      # 加入聊天室
  chat:send      # 發送訊息
  chat:message   # 接收訊息（伺服器 → 客戶端）
```

---

## 前端 Frontend (Flutter)

### 前端環境需求

| 軟體 | 版本 | 說明 |
|------|------|------|
| Flutter | 3.22+ | 官方 SDK |
| Dart | 3.3+ | 語言環境（Flutter 內建） |
| Android Studio | Ladybug (2024.2.x) 以上 | 官方 IDE |
| Android SDK | API 35 (Android 15) | 目標版本 |
| 最低支援 Android | API 26 (Android 8.0) | minSdk |
| Xcode（macOS 限定）| 15+ | iOS 編譯需要 |

---

### 前端啟動步驟

**步驟 1：安裝 Flutter SDK**

前往 [flutter.dev](https://docs.flutter.dev/get-started/install) 下載並安裝，安裝完成後將 `flutter\bin` 加入系統 `PATH`。

驗證安裝：

```bash
flutter doctor
```

確認所有必要項目均為綠色勾號。

**步驟 2：進入前端目錄**

```bash
cd foundit_flutter
```

**步驟 3：取得所有依賴套件**

```bash
flutter pub get
```

**步驟 4：設定後端 API 位址**

開啟 `lib/core/constants/app_constants.dart`，依環境修改：

```dart
class AppConstants {
  // 本地開發（Android 模擬器連接本機後端）
  static const String baseUrl = 'http://10.0.2.2:3000/api/v1';
  static const String socketHost = 'http://10.0.2.2:3000';

  // iOS 模擬器
  // static const String baseUrl = 'http://localhost:3000/api/v1';

  // 實機測試（改成你的電腦區網 IP）
  // static const String baseUrl = 'http://192.168.1.xxx:3000/api/v1';

  // 正式環境（--dart-define 注入，不要寫死）
  // static const String baseUrl = String.fromEnvironment('API_BASE_URL');
}
```

> **注意：** Android 模擬器中 `10.0.2.2` 對應到本機的 `localhost`；實機測試需改為電腦的區網 IP。

**步驟 5：確認 Mock 模式已關閉（正式串接時）**

```dart
// lib/core/constants/app_constants.dart
static const bool useMock = false;  // ← 確認為 false
```

**步驟 6：執行 App**

```bash
# 執行（自動偵測可用裝置）
flutter run

# 指定裝置（先用 flutter devices 查看裝置清單）
flutter devices
flutter run -d <device-id>
```

- **模擬器**：在 Android Studio → Device Manager 建立 AVD（建議 Pixel 8 / API 35），再執行 `flutter run`
- **實體手機**：啟用「開發人員選項」→「USB 偵錯」，USB 連接後執行 `flutter run`

**步驟 7：建置 Release 版本**

```bash
# Android APK
flutter build apk \
  --dart-define=API_BASE_URL=https://api.foundit.com.tw/api/v1 \
  --dart-define=SOCKET_HOST=https://api.foundit.com.tw \
  --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com \
  --dart-define=PROD=true

# Android AAB（上架 Google Play 用）
flutter build appbundle --dart-define=...（同上）

# iOS IPA（需 macOS + Xcode）
flutter build ipa --dart-define=...（同上）
```

---

### 連接後端設定

| 情境 | API Base URL |
|------|-------------|
| Android 模擬器 | `http://10.0.2.2:3000/api/v1` |
| iOS 模擬器 | `http://localhost:3000/api/v1` |
| 實體手機（區網）| `http://192.168.x.x:3000/api/v1` |
| 正式環境 | `https://api.foundit.com.tw/api/v1` |

---

## 功能模組

| 模組 | 功能說明 | 前端狀態 | 後端狀態 |
|------|----------|----------|----------|
| 帳號 / 認證 | 手機 OTP 登入、Google OAuth | ✅ UI 完成 | ⚙️ 待串接 |
| 遺失物 CRUD | 新增、編輯、刪除、標記已找到 | ✅ UI 完成 | ⚙️ 待串接 |
| 撿到物 CRUD | 新增、編輯、刪除 | ✅ UI 完成 | ⚙️ 待串接 |
| 搜尋 / 篩選 | 分類、地區、關鍵字、賞金篩選 | ✅ UI 完成 | ⚙️ 待串接 |
| 地圖模式 | OpenStreetMap 標記顯示 | ✅ UI 完成 | ⚙️ 待串接 |
| AI 配對 | 圖片相似度配對 | ✅ UI 完成 | ⚙️ 待實作 |
| 即時聊天 | WebSocket 即時訊息 | ✅ UI 完成 | ⚙️ 待串接 |
| QR 系統 | 產生 QR、掃描、快速聯絡物主 | ✅ UI 完成 | ⚙️ 待串接 |
| 積分系統 | 點數記錄、排行榜 | ✅ UI 完成 | ⚙️ 待串接 |
| 推播通知 | FCM 推播整合 | ⚙️ 需設定 google-services.json | ⚙️ 待串接 |

---

## 開發進度

### Flutter App

- [x] 環境建置、專案架構
- [x] 設計系統（品牌色、字體、陰影）
- [x] 路由架構（go_router）
- [x] 資料模型定義
- [x] API Service 介面（Dio）
- [x] Repository 層
- [x] Riverpod 狀態管理
- [x] 登入 / OTP 畫面
- [x] 首頁（物品列表）
- [x] 搜尋 / 篩選
- [x] 地圖模式
- [x] 新增遺失物 / 撿到物
- [x] 物品詳情
- [x] 聊天列表 / 聊天室
- [x] QR Code 產生 / 掃描
- [x] AI 配對結果頁
- [x] 個人資料 / 積分
- [x] 通知頁
- [ ] 正式串接後端 API（進行中）
- [ ] FCM 推播設定
- [ ] 401 自動登出測試

### 後端 (NestJS)

- [ ] 專案初始化（NestJS + TypeORM）
- [ ] Docker Compose 設定（PostgreSQL + Redis）
- [ ] 資料庫 Schema 設計與 Migration
- [ ] 認證模組（OTP 簡訊 + JWT + Google OAuth）
- [ ] 用戶模組
- [ ] 物品模組（CRUD + 篩選 + 分頁）
- [ ] 聊天模組（REST + WebSocket Gateway）
- [ ] 通知模組（FCM 推播）
- [ ] AI 配對整合
- [ ] QR Code 模組
- [ ] 圖片上傳（AWS S3）
- [ ] Swagger API 文件
- [ ] 單元測試 / E2E 測試

---

## 部署上線

詳細的部署步驟與上架前檢查清單請參考 [DEPLOYMENT.md](./DEPLOYMENT.md)。

### 快速部署概覽

**後端（NestJS）**

```bash
cd Foundit/backend
npm ci
npm run build
npm run typeorm:migration:run
npm run start:prod
```

**前端（Flutter）**

```bash
cd foundit_flutter
flutter build appbundle \
  --dart-define=API_BASE_URL=https://api.foundit.com.tw/api/v1 \
  --dart-define=SOCKET_HOST=https://api.foundit.com.tw \
  --dart-define=GOOGLE_WEB_CLIENT_ID=你的GoogleClientId \
  --dart-define=PROD=true
```

### 建議監控設定

- 後端串接 **Sentry / Datadog** 收集 unhandled exception
- 前端串接 **Firebase Crashlytics**
- 設置 uptime monitor 監控健康檢查：`GET /api/v1/health`

---

## 版本紀錄

| 版本 | 日期 | 說明 |
|------|------|------|
| 1.0.0 | 2026/04 | 初版：Flutter 完整 UI 架構，API stub；後端架構規劃中 |

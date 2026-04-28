# 找得到 (Foundit) — 失物共享平台

> 版本：1.0.0 | 最後更新：2026/03

## 專案概述

「找得到」是台灣版失物共享平台，參考韓國 FindingAll 模式，整合遺失物登記、撿到物登記、AI 配對、地圖搜尋、聊天聯絡、賞金系統、QR 防丟貼紙等功能。

本專案分為兩個部分：
- **後端 (Backend)**：NestJS + PostgreSQL + Redis，提供 REST API 與 WebSocket 即時通訊
- **前端 (Android App)**：Kotlin + Jetpack Compose，MVVM 架構

---

## 目錄

1. [系統架構圖](#系統架構圖)
2. [後端 Backend](#後端-backend)
   - [技術棧](#後端技術棧)
   - [專案結構](#後端專案結構)
   - [環境需求](#後端環境需求)
   - [架設步驟](#後端架設步驟)
   - [環境變數說明](#環境變數說明)
   - [資料庫初始化](#資料庫初始化)
   - [API 文件](#api-文件)
3. [前端 Android App](#前端-android-app)
   - [技術棧](#前端技術棧)
   - [專案結構](#前端專案結構)
   - [環境需求](#前端環境需求)
   - [架設步驟](#前端架設步驟)
4. [功能模組](#功能模組)
5. [開發進度](#開發進度)
6. [版本紀錄](#版本紀錄)

---

## 系統架構圖

```
┌─────────────────────────────────────────────────────────┐
│                   Android App (Client)                   │
│         Kotlin + Jetpack Compose + Retrofit              │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS / WSS
          ┌──────────────▼──────────────┐
          │      後端伺服器 (NestJS)      │
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
    │   外部服務          │
    │ • Firebase FCM (推播)│
    │ • Google Maps API   │
    │ • AI 圖片配對服務   │
    │ • LINE / Google OAuth│
    └────────────────────┘
```

---

## 後端 Backend

### 後端技術棧

| 層級 | 技術 | 版本 |
|------|------|------|
| 語言 | TypeScript | 5.x |
| 框架 | NestJS | 10.x |
| ORM | TypeORM | 0.3.x |
| 資料庫 | PostgreSQL | 16.x |
| 快取/佇列 | Redis | 7.x |
| 即時通訊 | Socket.IO (WebSocket) | 4.x |
| 認證 | JWT + Passport.js | - |
| 檔案上傳 | Multer + AWS S3 / 本地儲存 | - |
| 推播 | Firebase Admin SDK | 12.x |
| API 文件 | Swagger (OpenAPI 3.0) | - |
| 容器化 | Docker + Docker Compose | - |

---

### 後端專案結構

```
foundit-backend/
├── src/
│   ├── main.ts                    # 程式進入點
│   ├── app.module.ts              # 根模組
│   ├── config/
│   │   ├── database.config.ts     # 資料庫設定
│   │   ├── redis.config.ts        # Redis 設定
│   │   └── jwt.config.ts          # JWT 設定
│   ├── auth/                      # 認證模組
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts     # POST /auth/otp/send, /auth/otp/verify
│   │   ├── auth.service.ts
│   │   ├── strategies/
│   │   │   ├── jwt.strategy.ts
│   │   │   └── google.strategy.ts
│   │   └── guards/
│   │       └── jwt-auth.guard.ts
│   ├── users/                     # 用戶模組
│   │   ├── users.module.ts
│   │   ├── users.controller.ts    # GET/PUT /users/me
│   │   ├── users.service.ts
│   │   └── entities/
│   │       └── user.entity.ts
│   ├── items/                     # 物品模組（遺失/撿到）
│   │   ├── items.module.ts
│   │   ├── items.controller.ts    # CRUD /items
│   │   ├── items.service.ts
│   │   └── entities/
│   │       └── item.entity.ts
│   ├── chat/                      # 聊天模組
│   │   ├── chat.module.ts
│   │   ├── chat.gateway.ts        # WebSocket Gateway
│   │   ├── chat.controller.ts     # GET /chats, /chats/:id/messages
│   │   ├── chat.service.ts
│   │   └── entities/
│   │       ├── chat.entity.ts
│   │       └── message.entity.ts
│   ├── notifications/             # 通知模組
│   │   ├── notifications.module.ts
│   │   ├── notifications.controller.ts
│   │   ├── notifications.service.ts
│   │   └── fcm.service.ts         # Firebase 推播
│   ├── ai/                        # AI 配對模組
│   │   ├── ai.module.ts
│   │   ├── ai.controller.ts       # POST /ai/match
│   │   └── ai.service.ts          # 呼叫外部 AI API
│   ├── qr/                        # QR Code 模組
│   │   ├── qr.module.ts
│   │   ├── qr.controller.ts       # POST /qr/generate, GET /qr/:code
│   │   └── qr.service.ts
│   └── upload/                    # 檔案上傳模組
│       ├── upload.module.ts
│       ├── upload.controller.ts   # POST /upload
│       └── upload.service.ts
├── migrations/                    # TypeORM 資料庫遷移
├── test/                          # E2E 測試
├── .env.example                   # 環境變數範例
├── docker-compose.yml             # Docker 一鍵啟動
├── Dockerfile
├── package.json
└── tsconfig.json
```

---

### 後端環境需求

| 軟體 | 最低版本 | 說明 |
|------|----------|------|
| Node.js | 20.x LTS | 執行環境 |
| npm | 10.x | 套件管理 |
| PostgreSQL | 16.x | 主要資料庫 |
| Redis | 7.x | 快取與 Session |
| Docker (選用) | 24.x | 一鍵部署 |

---

### 後端架設步驟

#### 方法一：Docker 一鍵啟動（推薦）

> 需先安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/)

**1. 取得後端程式碼**
```bash
git clone https://github.com/your-org/foundit-backend.git
cd foundit-backend
```

**2. 複製並設定環境變數**
```bash
cp .env.example .env
# 用文字編輯器開啟 .env，填入必要設定（見下方「環境變數說明」）
```

**3. 啟動所有服務（後端 + PostgreSQL + Redis）**
```bash
docker-compose up -d
```

**4. 執行資料庫遷移**
```bash
docker-compose exec api npm run migration:run
```

**5. 確認服務正常運行**
```bash
# 查看容器狀態
docker-compose ps

# 查看後端日誌
docker-compose logs -f api
```

**6. 開啟 API 文件**

瀏覽器前往 `http://localhost:3000/api/docs` 查看 Swagger 文件。

---

#### 方法二：手動本機啟動

**1. 安裝 PostgreSQL**
- Windows：至 [postgresql.org](https://www.postgresql.org/download/) 下載安裝包
- 安裝後建立資料庫：
  ```sql
  CREATE DATABASE foundit;
  CREATE USER foundit_user WITH PASSWORD 'your_password';
  GRANT ALL PRIVILEGES ON DATABASE foundit TO foundit_user;
  ```

**2. 安裝 Redis**
- Windows：使用 [Memurai](https://www.memurai.com/)（Redis for Windows 替代品）或 WSL2 安裝 Redis
  ```bash
  # WSL2 方式
  sudo apt update && sudo apt install redis-server
  sudo service redis-server start
  ```

**3. 安裝 Node.js 依賴**
```bash
git clone https://github.com/your-org/foundit-backend.git
cd foundit-backend
npm install
```

**4. 設定環境變數**
```bash
cp .env.example .env
# 編輯 .env 填入資料庫、Redis、JWT 等設定
```

**5. 執行資料庫遷移**
```bash
npm run migration:run
```

**6. 啟動開發伺服器**
```bash
# 開發模式（熱重載）
npm run start:dev

# 正式模式
npm run build
npm run start:prod
```

**7. 確認啟動成功**

終端機出現以下訊息代表成功：
```
[NestJS] Application is running on: http://localhost:3000
[NestJS] WebSocket server is running on port: 3001
```

---

### 環境變數說明

後端根目錄的 `.env` 檔案需填入以下設定：

```env
# ===== 應用設定 =====
NODE_ENV=development
PORT=3000
WS_PORT=3001

# ===== 資料庫 (PostgreSQL) =====
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=foundit_user
DB_PASSWORD=your_password
DB_NAME=foundit

# ===== Redis =====
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=                    # 若有設定密碼則填入

# ===== JWT 認證 =====
JWT_SECRET=your_super_secret_key   # 建議使用 256-bit 亂數字串
JWT_EXPIRES_IN=7d

# ===== OTP 簡訊 (以 Twilio 為例) =====
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# ===== Firebase Admin (推播) =====
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com

# ===== Google OAuth =====
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_CALLBACK_URL=http://localhost:3000/auth/google/callback

# ===== 檔案上傳 (選擇本地或 S3) =====
UPLOAD_MODE=local                  # local 或 s3
UPLOAD_LOCAL_PATH=./uploads
AWS_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=ap-northeast-1

# ===== AI 配對服務 =====
AI_SERVICE_URL=http://localhost:8000/api/match
AI_SERVICE_API_KEY=your_ai_api_key
```

---

### 資料庫初始化

後端採用 TypeORM Migration 管理資料庫版本：

```bash
# 產生新的 migration
npm run migration:generate -- src/migrations/InitSchema

# 執行所有未執行的 migration
npm run migration:run

# 回滾最後一次 migration
npm run migration:revert

# 匯入初始測試資料（Seed）
npm run seed
```

主要資料表結構：

| 資料表 | 說明 |
|--------|------|
| `users` | 用戶資料（手機、名稱、點數、頭像） |
| `items` | 物品（遺失/撿到）、類別、地點、照片 |
| `chats` | 聊天室（兩用戶間） |
| `messages` | 聊天訊息 |
| `notifications` | 推播通知紀錄 |
| `qr_codes` | QR 防丟貼紙對應 |
| `point_logs` | 積分變動紀錄 |

---

### API 文件

啟動後端後，瀏覽器開啟 `http://localhost:3000/api/docs` 查看完整 Swagger UI 互動文件。

主要 API 端點：

```
POST   /api/v1/auth/otp/send          # 發送 OTP 簡訊
POST   /api/v1/auth/otp/verify        # 驗證 OTP，回傳 JWT
GET    /api/v1/auth/google            # Google OAuth 登入

GET    /api/v1/users/me               # 取得目前用戶資料
PUT    /api/v1/users/me               # 更新用戶資料

GET    /api/v1/items                  # 取得物品列表（支援分頁/篩選）
POST   /api/v1/items                  # 新增物品
GET    /api/v1/items/:id              # 取得物品詳情
PUT    /api/v1/items/:id              # 更新物品
DELETE /api/v1/items/:id              # 刪除物品
PATCH  /api/v1/items/:id/found        # 標記為已找到

GET    /api/v1/chats                  # 聊天列表
GET    /api/v1/chats/:id/messages     # 取得訊息記錄
POST   /api/v1/upload                 # 上傳圖片（回傳 URL）

POST   /api/v1/ai/match               # AI 圖片配對
POST   /api/v1/qr/generate            # 產生 QR Code
GET    /api/v1/qr/:code               # QR 掃描查詢

# WebSocket（Socket.IO）
ws://localhost:3001
  chat:join    # 加入聊天室
  chat:send    # 發送訊息
  chat:message # 接收訊息（伺服器 → 客戶端）
```

---

## 前端 Android App

### 前端技術棧

| 層級 | 技術 | 版本 |
|------|------|------|
| 語言 | Kotlin | 2.2.10 |
| UI | Jetpack Compose + Material3 | BOM 2024.09.00 |
| 架構 | MVVM + Repository Pattern | - |
| 導航 | Navigation Compose | 2.8.5 |
| 網路 | Retrofit + OkHttp | 2.9.0 / 4.12.0 |
| 圖片 | Coil | 2.7.0 |
| 地圖 | Google Maps Compose | 4.4.1 |
| 本地儲存 | DataStore Preferences | 1.1.1 |
| QR 掃描 | ML Kit Barcode + CameraX | 17.3.0 / 1.4.0 |
| 推播 | FCM (Firebase Cloud Messaging) | - |
| 構建工具 | AGP | 9.1.0 |

---

### 前端專案結構

```
app/src/main/java/com/example/foundit/
├── FounditApplication.kt          # Application 類別
├── MainActivity.kt                 # 主 Activity
├── data/
│   ├── model/                     # 資料模型
│   │   ├── User.kt
│   │   ├── Item.kt
│   │   ├── Chat.kt
│   │   ├── Message.kt
│   │   ├── Notification.kt
│   │   └── QrItem.kt
│   ├── remote/                    # 網路層
│   │   ├── ApiService.kt          # Retrofit API 介面定義
│   │   ├── RetrofitClient.kt      # Retrofit / OkHttp 設定
│   │   ├── WebSocketClient.kt     # Socket.IO 連線管理
│   │   └── dto/                   # 請求/回應 DTO
│   ├── local/
│   │   └── AppPreferences.kt      # DataStore（JWT Token 儲存）
│   └── repository/                # Repository 層（封裝 API 呼叫）
│       ├── AuthRepository.kt
│       ├── ItemRepository.kt
│       └── ChatRepository.kt
├── ui/
│   ├── theme/                     # 主題設定
│   │   ├── Color.kt
│   │   ├── Theme.kt
│   │   └── Type.kt
│   ├── navigation/                # 導航
│   │   ├── Screen.kt              # 路由定義
│   │   └── AppNavigation.kt       # NavHost 設定
│   ├── component/                 # 可重用元件
│   │   ├── BottomNavBar.kt
│   │   ├── ItemCard.kt
│   │   └── CommonComponents.kt
│   └── screen/                    # 各頁面
│       ├── splash/SplashScreen.kt
│       ├── auth/                  # 登入/OTP 驗證
│       ├── home/                  # 首頁（物品列表）
│       ├── search/                # 搜尋/篩選
│       ├── map/                   # 地圖模式
│       ├── item/                  # 物品 CRUD
│       ├── chat/                  # 聊天列表/聊天室
│       ├── qr/                    # QR Code 產生/掃描
│       ├── ai/                    # AI 配對結果
│       ├── profile/               # 個人資料/積分
│       └── notification/          # 通知列表
└── util/
    ├── Constants.kt               # API Base URL 等常數
    └── Extensions.kt              # Kotlin 擴充函數
```

---

### 前端環境需求

| 軟體 | 版本 | 說明 |
|------|------|------|
| Android Studio | Ladybug (2024.2.x) 以上 | 官方 IDE |
| JDK | 17 (Temurin 推薦) | Android Studio 內建 |
| Android SDK | API 35 (Android 15) | 目標版本 |
| 最低支援 | API 26 (Android 8.0) | minSdk |
| Google Maps API Key | - | 地圖功能 |
| Firebase 專案 | - | 推播通知 |

---

### 前端架設步驟

**1. 安裝 Android Studio**

前往 [developer.android.com/studio](https://developer.android.com/studio) 下載並安裝最新版 Android Studio。

首次啟動時依照精靈指示安裝 Android SDK（建議安裝 API 35）。

---

**2. 取得前端程式碼**

```bash
git clone https://github.com/your-org/foundit-android.git
cd foundit-android
```

用 Android Studio 開啟此資料夾（File → Open）。

---

**3. 設定後端 API 位址**

開啟 `app/src/main/java/com/example/foundit/util/Constants.kt`，修改：

```kotlin
object Constants {
    // 本地開發（模擬器連接本機後端）
    const val BASE_URL = "http://10.0.2.2:3000/api/v1/"
    const val WS_URL   = "http://10.0.2.2:3001"

    // 正式環境
    // const val BASE_URL = "https://api.foundit.tw/api/v1/"
    // const val WS_URL   = "wss://api.foundit.tw"
}
```

> 注意：模擬器中 `10.0.2.2` 對應到本機的 `localhost`，實機測試需改為電腦的區網 IP（如 `192.168.1.xxx`）。

---

**4. 設定 Google Maps API Key**

1. 前往 [Google Cloud Console](https://console.cloud.google.com/) → 啟用 **Maps SDK for Android**
2. 建立 API 金鑰（建議限制 Android App 使用）
3. 開啟 `app/src/main/AndroidManifest.xml`，填入：

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY" />
```

---

**5. 設定 Firebase 推播（FCM）**

1. 前往 [Firebase Console](https://console.firebase.google.com/) → 建立新專案
2. 新增 Android App，Package name 填入 `com.example.foundit`
3. 下載 `google-services.json`
4. 將檔案放入 `app/` 目錄下（與 `build.gradle.kts` 同層）
5. 確認 `app/build.gradle.kts` 已有：

```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

---

**6. 同步 Gradle 並建置專案**

在 Android Studio 中：
- 點選右上角 **Sync Project with Gradle Files**（大象圖示）
- 等待 Gradle 下載所有依賴套件

---

**7. 執行 App**

- **模擬器**：在 Android Studio 選單 Device Manager 建立 AVD（建議 Pixel 8 / API 35），按下 ▶ Run
- **實體手機**：
  1. 手機啟用「開發人員選項」→「USB 偵錯」
  2. 用 USB 連接電腦
  3. Android Studio 選擇你的手機，按下 ▶ Run

---

**8. 簽名設定（正式發布用）**

在 `app/build.gradle.kts` 中設定 Release 簽名：

```kotlin
android {
    signingConfigs {
        create("release") {
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
            storeFile = file(System.getenv("KEYSTORE_PATH"))
            storePassword = System.getenv("STORE_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

建置 Release APK：

```bash
./gradlew assembleRelease
```

或建置 AAB（上架 Google Play）：

```bash
./gradlew bundleRelease
```

---

## 功能模組

| 模組 | 功能 | 前端狀態 | 後端狀態 |
|------|------|----------|----------|
| 帳號/認證 | 手機 OTP 登入、Google OAuth | ✅ UI 完成 | ⚙️ 待串接 |
| 遺失物 CRUD | 新增/編輯/刪除/標記已找到 | ✅ UI 完成 | ⚙️ 待串接 |
| 撿到物 CRUD | 新增/編輯/刪除 | ✅ UI 完成 | ⚙️ 待串接 |
| 搜尋/篩選 | 分類、地區、關鍵字、賞金篩選 | ✅ UI 完成 | ⚙️ 待串接 |
| 地圖模式 | Google Maps 標記顯示 | ✅ UI 完成 | ⚙️ 待串接 |
| AI 配對 | 圖片相似度配對 | ✅ UI 完成，API stub | ⚙️ 待實作 |
| 聊天 | 即時訊息（WebSocket）| ✅ UI 完成，API stub | ⚙️ 待串接 |
| QR 系統 | 產生 QR、掃描、快速聯絡 | ✅ UI 完成 | ⚙️ 待串接 |
| 積分系統 | 點數記錄、排行榜 | ✅ UI 完成 | ⚙️ 待串接 |
| 推播通知 | FCM 推播整合 | ⚙️ 需設定 google-services.json | ⚙️ 待串接 |

---

## 開發進度

### Android App
- [x] 環境建置、專案架構
- [x] 主題設計（Material3 品牌色）
- [x] 導航架構（Navigation Compose）
- [x] 資料模型定義
- [x] API Service 介面（Retrofit）
- [x] Repository 層
- [x] ViewModel 層
- [x] 登入/OTP 畫面
- [x] 首頁（物品列表）
- [x] 搜尋/篩選
- [x] 地圖模式
- [x] 新增遺失物/撿到物
- [x] 物品詳情
- [x] 聊天列表/聊天室
- [x] QR Code 產生/掃描
- [x] AI 配對結果頁
- [x] 個人資料/積分
- [x] 通知頁

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
- [ ] 檔案上傳（圖片儲存）
- [ ] Swagger API 文件
- [ ] 單元測試 / E2E 測試

---

## 版本紀錄

| 版本 | 日期 | 說明 |
|------|------|------|
| 1.0.0 | 2026/03 | 初版：Android 完整 UI 架構，API stub；後端架構規劃 |

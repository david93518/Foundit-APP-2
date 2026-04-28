# 找得到 Foundit｜Flutter 版

> 台灣取向的失物共享平台 — 全新 Flutter 設計版本

這是從 Kotlin/Jetpack Compose 版本重新設計的 Flutter 專案，主打 **現代感、溫暖、具呼吸感** 的視覺語言，擺脫傳統 Material 樣板風格。

---

## 設計語言

| 元素 | 值 |
|------|-----|
| 主色（Indigo） | `#4F46E5` |
| 遺失物（Coral） | `#F97316` |
| 撿到物（Emerald） | `#10B981` |
| 賞金（Amber） | `#F59E0B` |
| 背景（奶白） | `#FAFAF9` |
| 字體 | Noto Sans TC + Inter |
| 圓角 | 16 / 20 / 28 px（大圓角） |
| 陰影 | 柔和多層（非 Material 預設） |

---

## 技術堆疊

- **Flutter 3.22+** / **Dart 3.3+**
- **狀態管理：** Riverpod
- **路由：** go_router
- **網路：** Dio
- **地圖：** flutter_map（OpenStreetMap）
- **QR：** mobile_scanner + qr_flutter

---

## 專案結構

```
lib/
├── main.dart                   # 進入點
├── app.dart                    # MaterialApp + 主題
├── core/
│   ├── theme/                  # 設計系統（顏色、字體、間距、陰影）
│   ├── router/                 # 路由
│   ├── constants/              # 全域常數
│   └── utils/                  # 工具函式
├── data/
│   ├── models/                 # 資料模型（對應後端 DTO）
│   ├── api/                    # Dio client + endpoints
│   ├── repositories/           # Repository 層
│   └── mock/                   # Mock 資料
└── presentation/
    ├── screens/                # 各畫面
    └── widgets/                # 共用 UI 元件
```

---

## 啟動步驟

### 1. 安裝 Flutter
從 [flutter.dev](https://docs.flutter.dev/get-started/install) 下載並安裝，把 `flutter\bin` 加入 `PATH`。

### 2. 取得相依套件
```bash
cd foundit_flutter
flutter pub get
```

### 3. 執行
```bash
flutter run
```

---

## 後端串接

預設連線到您原有的 NestJS 後端：
- Android 模擬器：`http://10.0.2.2:3000/api/v1`
- iOS 模擬器：`http://localhost:3000/api/v1`
- 實機：改成電腦 IP（例如 `http://192.168.1.100:3000/api/v1`）

請於 `lib/core/constants/app_constants.dart` 修改 `baseUrl`。

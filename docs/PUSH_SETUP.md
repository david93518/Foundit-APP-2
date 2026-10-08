# 推播通知（FCM）啟用步驟

程式已完成：新訊息、有人掃到防丟牌時，後端會推播給對方；點通知直接打開該聊天室。
以下設定沒做之前推播會自動停用，聊天仍可在 App 內正常使用。

Firebase 專案：`foundit-873c1`（Android 的 `google-services.json` 已在 repo 內）。

## 1. 後端：服務帳戶金鑰（Android、iOS 都需要）

1. Firebase 主控台 → 專案設定 → 服務帳戶 → **產生新的私密金鑰**，下載 JSON。這是機密，不要 commit。
2. 在後端主機（192.168.66.216）產生單行 base64，寫進 `/home/david/foundit/backend/deploy/.env`：

   ```bash
   echo "FCM_SERVICE_ACCOUNT_JSON=$(base64 -w0 foundit-873c1-firebase-adminsdk-xxxx.json)" >> deploy/.env
   ```

3. 重新部署後端。啟動 log 若出現「FCM 推播未設定」代表變數沒讀到。

## 2. iOS（TestFlight 需要）

1. **Apple Developer** → Keys → 新增 Key，勾選 *Apple Push Notifications service (APNs)*，下載 `.p8`，記下 Key ID 與 Team ID（`3X8U3KP7SH`）。
2. **Firebase 主控台** → 專案設定 → 新增 iOS App，Bundle ID 填 `com.david93518.foundit`。
   下載的 `GoogleService-Info.plist` **不用放進專案**，只要從裡面抄兩個值：`API_KEY`、`GOOGLE_APP_ID`。
3. Firebase → 專案設定 → Cloud Messaging → Apple 應用程式設定 → 上傳步驟 1 的 `.p8`（填 Key ID、Team ID）。
4. 在 Mac build 時多帶兩個參數（沒帶就是不含推播的版本，也不會要求推播權限）：

   ```bash
   python3 tool/build_real_ios.py ... --build-number 3 \
     --firebase-ios-api-key <API_KEY> \
     --firebase-ios-app-id <GOOGLE_APP_ID>
   ```

   帶了參數才會簽入 `Runner/Runner.entitlements`（aps-environment），Xcode 自動簽署會替 App ID 開啟 Push 功能。

## 3. 驗收

- 兩支手機各登入一個帳號：A 建防丟牌，B 掃描 → A 收到「有人掃到你的防丟牌」；點通知 → 進聊天室。
- A 把 App 退到背景，B 傳訊息 → A 收到「B · 物品名稱」通知，App 圖示角標顯示未讀數。
- A 停在該聊天室時，B 再傳 → 不跳通知，訊息直接出現。
- A 登出 → B 再傳 → A 的手機不再收到。

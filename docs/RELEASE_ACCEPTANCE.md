# FOUND !T 上架驗收表

## 使用者確認的交付目標（2026-10-06）

交付可供真實使用者使用的正式 App。Google 帳號登入、遺失／拾獲通報與刊登、照片上傳、搜尋與地圖、由物品聯絡對方、雙方即時對話及歷史訊息保存，必須串接實際 API 和持久資料庫。正式環境不得啟用 mock 資料或示範對话。TestFlight 僅作為目前安裝與驗收管道，不能把示範版視為交付完成。

放行前必須以兩個獨立使用者完成：A 刊登 → B 搜尋並開啟物品 → B 聯絡 A → 雙方收發訊息 → 關閉重開仍保留物品及訊息。另須驗證第三方不能讀取對話、定位拒絕時可操作，以及外網 HTTPS 可用。單元測試或單機模擬通過不足以代表正式可用。

建立日期：2026-10-04。搭配 [上架前修復清單](LAUNCH_READINESS.md) 使用。**下列方框代表尚待完整驗收，沒有因為建立本表就算通過。** 各候選版本已執行的 API、部署、自動測試與 TestFlight 查核記於下節；不得把局部驗證當成原生真機或正式上架整體驗收。

## 每次候選版本先填

### 2026-10-08 聯絡安全與訊息同步版 1.0.0 (8)

- 聊天室右上角新增「交還前核對、檢舉對方、封鎖聯絡／解除封鎖、同步最新訊息」。檢舉是真實 POST `/reports`，失敗保留原因與補充內容；不會把取消或網路失敗當成功。體驗模式不會呼叫真實封鎖／檢舉 API。
- 設定新增「安全與封鎖」，可查看自己封鎖的使用者名稱並解除。API 只回公開名稱／頭像與封鎖時間，不回電話、email 或憑證。封鎖阻止雙方建房與傳訊，既有對話保留，公開刊登不隱藏；畫面已明確說明這個範圍。
- 聊天歷史以 `before` cursor 向前載入，每次 50 則；重連或 App 回到前景時重新取得最新一頁，再向前補齊，避免把不相鄰的兩頁拼成看似完整的歷史。保留尚在傳送的訊息，以伺服器 ID／client message ID 去重，忽略過期的分頁回應。同步失敗保留原訊息並提供重試。
- 看舊訊息時收到新訊息不強制捲到底部，提供「有新訊息」入口；背景及非目前頁面不自動標已讀。對方已讀事件以伺服器指定的訊息為截止，不把全部未讀訊息一次標已讀。
- 後端新增需 JWT 且驗證成員資格的 GET `/chats/:id`；封鎖寫入可重複執行，解除封鎖限定本人資料，檢舉使用者前檢查 UUID／對象存在且不是自己。
- Flutter **119 項通過**，含較早歷史、漏超過 50 則後重連、前景恢復、同步失敗重試、閱讀舊訊息不誤標已讀、已讀截止位置、封鎖取消／失敗／成功／解除、檢舉失敗重試，以及 320×568／844×390 的 200% 字級。使用實際 NotoSansTC 與 AppTheme 產生畫面檢視，修正 AppBar 標題顏色及按鈕中文字型。Analyze 無 error／warning，維持原有 7 項 info。
- 後端 **18 suites／80 項通過**，Nest build 通過。Linux 已部署映像 `sha256:466d9d29ef1f1d3faff3b838ebc2e140e186a6525ae15e360517e20928ab2675`；資料庫與原 service 備份 `/home/david/foundit-private/safety8/`，回滾映像 `foundit-api:before-safety8`。本版沒有 schema 變更。
- 正式 HTTPS 驗證 health、未登入封鎖名單 401、登入後本人名單 200、非法解除／自我封鎖／非法檢舉 400、不存在的檢舉對象 404、非成員聊天室詳情 403。未封鎖或檢舉真實使用者；審查帳號沒有既有聊天室，因此本人詳情成功回傳及雙人封鎖收發仍以自動測試驗證，**未代替兩台 iPhone 真機實測**。證據 `tmp/safety8-live-evidence.json`。
- Mac `/Users/megumi/Projects/foundit-ios-build8/` 已完成 archive／簽署匯出；IPA SHA-256 `9a01050eaaaeea844fdb70fc1d00e08c9513d77aeccc0cb613c9e918dd9e0321`。正式 HTTPS、`USE_MOCK=false`。2026-10-08 22:01:03（台灣）altool 回報 `UPLOAD SUCCEEDED with no errors`，Delivery UUID／Build ID `1f4c6781-85ed-478a-a0e1-a85488ebb73a`。Apple 後續確認 `VALID`，已加入既有內部／外部群組、更新測試與審查說明、開啟自動通知；送審後重新 GET 確認 `betaReviewState=APPROVED`，內部與外部均 `IN_BETA_TESTING`。兩個群組均包含本版，測試者可更新 `1.0.0 (8)`；公開連結維持 `https://testflight.apple.com/join/ymFd6M3A`。證據 `tmp/asc-build8-final-evidence.json`；這是外部 Beta 放行，尚非正式 App Store 上架。

### 下一輪重要缺口（2026-10-08 核對，以下尚未完成）

1. **背景推播是最高優先。** 聊天已有 App 內同步，但 build 8 沒有 Firebase iOS 設定／APNs entitlement，後端 FCM 也未配置。需要建立對應 iOS Firebase App、串接 APNs 金鑰與伺服器發送身份，重新簽署建置，再以兩支 iPhone 驗證前景／背景／關閉 App、點通知進正確對話、拒絕權限、換帳號及登出不串號。不能把「已有 push 程式碼」當成可用推播。
2. **刊登草稿自動保存與恢復。** 聊天文字已有本機草稿，刊登表單目前只有離開確認，尚未持久保存完整表單與未上傳照片。應按帳號隔離、提供恢復／捨棄，處理照片暫存被清除、App 被系統關閉、失敗重送及避免重複刊登。這比增加更多首頁卡片更能避免使用者挫折。
3. **真實配對與追蹤提醒。** `/ai/match` 目前是文字關鍵字候選比對，沒有真正解析傳入照片，分數也不是驗證過的視覺相似機率。需先讓介面／商店文案如實呈現，再決定導入圖片特徵比對；「關注某地區／分類／特徵，有新刊登就通知」尚未形成可驗收的完整流程，並依賴推播、偏好設定與去重。
4. **檢舉處理完成後的結果通知與營運流程。** 本版只有提交、後台處置及聯絡封鎖，沒有使用者可追蹤的檢舉案件狀態／結果通知／申訴入口；需安排實際管理員、處理時限與聯絡管道。封鎖是否還應隱藏對方公開內容，需另定規格後一致套用搜尋／地圖／詳情，不能只改一個畫面。
5. **資料備份還原、故障告警與上架驗收。** 有部署前備份不等於還原演練成功；需要隔離環境驗證 DB＋照片完整還原、設定容量／憑證／錯誤告警，完成兩個真實帳號主流程與 iPhone 測試。另需完成正式隱私／資料保留／刪帳流程與適用登入要求；TestFlight 通過不代表正式 App Store 上架要求全部滿足。

### 2026-10-08 刊登管理版 1.0.0 (7)

- 補齊「我的 → 我的刊登 → 開啟物品」的編輯與刪除入口，只有發布者可操作。原有已找回／已交還流程保留。尚未結束的刊登可編輯名稱、照片（保留／移除／新增）、分類、顏色、描述、地圖位置、日期與保管資訊；不允許透過編輯改變擁有人、刊登類型或狀態。
- 共用三步表單載入既有內容，PATCH 原本 ID；保留建立時間、既有懸賞資訊及未變更的日期時間，不建立重複刊登。失敗保留輸入可重試，取消編輯需確認且不修改原資料。照片載入既有網址，不會重新上傳全部舊照片。
- 刪除有確認視窗，失敗不跳頁或顯示成功。伺服器標記 CLOSED／hidden_at，從公開列表、地圖、個人刊登清單與本人／公開詳情讀取移除；保留資料列以維持已有對話關聯。這是刊登下架，不等同帳號／儲存圖片的完整個資清除流程。API 拒絕修改已結束或移除的刊登，更新／結案使用 ACTIVE＋未隱藏條件避免並發刪除後復活。
- Flutter 全套 **113 項通過**：新增既有內容預填、移除照片保存、失敗後重試、不重複刊登、取消修改、刪除成功／失敗、他人管理入口拒絕，以及 320×568／844×390 的 200% 字級操作。發現並修正已有照片時「新增照片」格子固定高度溢位。Analyze 原有 7 項 info；新增 2 項括號風格提示已自動修正，無 error／warning。尚未取得本版 iPhone 真機驗收回報。
- 後端 **16 suites／73 項通過**，Nest build 通過；包含擁有人／狀態白名單、他人刪除拒絕、刪除後不可讀寫／結案，以及並發刪除後編輯失敗。Linux 映像 `sha256:b4120051b117ee637040d39b95b04a47e08684ce3690a3aa58b8b37c10812621` 已部署且 healthy；資料庫及舊 service 備份於 `/home/david/foundit-private/edit7/`，舊映像 `foundit-api:before-edit7`。無 schema 變更。
- 正式 HTTPS 以專用受邀帳號建立標示為系統驗證的刊登，實測 PATCH、重新 GET 保存、ID／擁有人／建立時間不變、我的刊登可見；DELETE 後本人／匿名詳情均 404、再修改 400、公開及本人清單均排除。測試刊登已下架，原本 4 筆使用者刊登保持原狀；未操作他人的實際刊登。
- Mac `/Users/megumi/Projects/foundit-ios-build7/` 完成 `1.0.0 (7)` archive 及 Apple 簽署匯出；正式 HTTPS API，`USE_MOCK=false`。IPA SHA-256 `d01a80c3f7e29f6a49d9b4618263ffd1fb7348264e4d14cbf37886a4cdecb7de`。背景推播仍未啟用。
- 2026-10-08 21:29:10（台灣）altool 回報 `UPLOAD SUCCEEDED with no errors`，Delivery UUID／Build ID `5a8a0d1a-18fd-4f30-a83a-c12b82bb3a8c`。Apple 處理為 `VALID`，已加入既有內部／外部群組、開啟自動通知、補齊繁中測試說明及英文審查操作步驟。送審後重新讀取確認 `betaReviewState=APPROVED`，內部與外部均為 `IN_BETA_TESTING`；外部測試者已可更新第 7 版。公開連結仍為 `https://testflight.apple.com/join/ymFd6M3A`。這是外部 Beta 放行，並非正式 App Store 上架。

### 2026-10-08 地圖位置修正版 1.0.0 (6)

- 問題實證：正式 API 當時有 4 筆 ACTIVE 刊登，其中「小波／成大」、「烤肉串／成大」、「灰貓宅急便／小東路」的 latitude 與 longitude 均為 null；只有「社會學書本」有座標。地圖只顯示 1 筆的原因是刊登允許只有地點文字，沒有取得可用座標；既有資料未遺失。
- 新刊登必須明確選擇並確認地圖位置，不能把預設台北鏡頭當作已確認位置；修改地點文字會清除舊座標。可主動搜尋地點後選擇結果、點選地圖，或使用自己的定位；搜尋不會自動選第一筆結果。
- 地圖顯示已標示／待補位置數量，待補清單可開啟刊登。發布者可在自己的物品詳情按「補上地圖位置／調整地圖位置」，成功儲存後刷新地圖、列表及自己的刊登；也新增手動刷新地圖入口。未猜測或批次改寫其他使用者的地點，原本 3 筆仍須發布者確認位置。
- 新增需 JWT 的 `GET /api/v1/locations/search`。依公開 Nominatim 使用政策，只有主動送出的搜尋、每帳號 15 次／分鐘、單一 API 實例全域佇列至少間隔 1.1 秒、同查詢合併及 24 小時快取，最多 8 個待處理查詢及 500 筆快取；識別 User-Agent、8 秒上游 timeout，失敗可改用手動地圖選點。UI 提供 OpenStreetMap attribution。可用 `GEOCODER_BASE_URL` 切換 HTTPS 相容供應商；**增加 API 副本前必須改用共用全域限流或合適容量的供應商**，目前限制器只在單實例有效。
- 後端 16 suites／68 項通過，Nest build 通過。正式 Linux 映像 `sha256:43445242c507869f6e0260a6ccb3061084b2de3dd2f95dcd5349ec13ec52bb04` 已部署且 healthy；舊映像保留為 `foundit-api:before-map6`。無資料庫 schema 變更，既有 4 筆刊登保持原狀。
- 外網 HTTPS 實測：health 200、匿名地點搜尋 401、真實受邀帳號登入 201、成功大學搜尋 200 且結果位於台南、重複查詢 200。未替其他使用者修改位置；發布者補位置的 UI／持久化行為以 repository 及 widget 測試驗證，仍待新版 iPhone 真機操作確認。
- Flutter 全套 **108 項通過**；包含只有文字不能刊登、必須明確選點、舊刊登補位置保存、1 有座標＋3 無座標清單、搜尋選擇、320×568／844×390／768×1024 的 200% 字級與鍵盤情境。Analyze 只有 7 項既有 info 等級風格提示，沒有 error 或 warning；預設 analyze 因 info 回 exit 1。
- Mac 工作目錄 `/Users/megumi/Projects/foundit-ios-build6/`；archive／Apple 簽署匯出成功。IPA SHA-256 `606d06c08f5912f119c80fcf0b4be566aea2875f732db21c93ca8a5370e42b9f`，版本 `1.0.0 (6)`、bundle `com.david93518.foundit`，使用正式 HTTPS API、`USE_MOCK=false`。背景推播仍未啟用。
- 2026-10-08 21:04:59（台灣）altool 回報 `UPLOAD SUCCEEDED with no errors`，Delivery UUID／Build ID `54c2e1e3-b63d-4f6e-8f2c-4b620cf74cfc`。Apple 隨後處理為 `VALID`；加入既有內部與外部群組，補齊繁中測試說明、開啟自動通知、保留真實審查帳號並更新第 6 版操作說明。送審初始 `WAITING_FOR_REVIEW`，重新讀取後確認 `betaReviewState=APPROVED`、內部／外部均為 `IN_BETA_TESTING`，兩個群組均包含 build 6。外部測試者已可取得本版；每位使用者是否已更新仍須裝置確認。公開連結維持 `https://testflight.apple.com/join/ymFd6M3A`。

### 2026-10-08 審查帳號候選版 1.0.0 (5)

- 使用者授權建立隨機密碼及送出外部 TestFlight 審查。新增可見的「受邀帳號登入」，使用真實 API、一般使用者權限及正常 JWT；不包含 mock 登入、共用管理權限或內嵌密碼。Google 登入保留。
- 伺服器只允許明確核發的帳號 ID、角色 user、active 狀態與 invited 識別；密碼使用 scrypt 雜湊、限速與到期日。未設定或到期時拒絕登入，不自動建立／復原帳號。受邀帳號可在設定中用密碼確認刪除；沿用刊登移除、訊息匿名化與 token 撤銷流程。
- 新隨機密碼只保存在本機受限私人資料夾及 Apple 審查欄位；有效至 2027-01-15 UTC，不寫入 Git。伺服器環境只保存雜湊。審查帳號刪除後必須人工補發；停用邀請若也要撤銷已登入 session，需停權並遞增 token_version。
- Linux 新映像 `sha256:98c4aa30c9423665bb6452afa07800ea8439c202055b4f9a5350f134f9e52e5a` 已部署、healthy。部署前保留資料庫與環境備份於 `/home/david/foundit-private/review-20261008/`，舊映像標記 `foundit-api:before-review5`；未清除既有資料。
- 外網實測：health 200、匿名 me 401、錯誤密碼 401、正確登入 201／me 200、管理 API 403、錯誤刪帳密碼 401 且帳號仍可用、登出後舊 token 401、重新登入成功。未在正式資料庫刪除審查帳號；刪除、跨帳號拒絕、停權及過期邊界使用自動測試驗證。
- 後端 Jest 15 suites／65 項通過，Nest build 通過。Flutter 全套 102 項通過，補充登入流程測試後該組 4 項通過（新增 1 項，測試總數 103）；包含錯誤密碼重試、dialog 關閉後登入狀態，以及小螢幕／200% 文字／鍵盤情境。這些不是 iPhone 真機驗收。
- Mac 建置目錄 `/Users/megumi/Projects/foundit-ios-build5/`；封存及簽署匯出成功。IPA SHA-256 `325fab2216cfdac9b51692bb8225d793b5d39c9680a09c5eaa823c8dd2b4dd8e`。實際 IPA 核對 bundle `com.david93518.foundit`、版本 `1.0.0 (5)`、Google iOS ID 與加密聲明；建置 `USE_MOCK=false`、`PROD=true`、API `https://api.foundit.tw/api/v1`。
- 2026-10-08 17:39:53（台灣）altool 回報 `UPLOAD SUCCEEDED with no errors`，Delivery UUID `db0e905c-e7ff-4bbf-abd0-e2f97937a2df`。
- Apple 已處理為 `VALID`；build 5 加入既有內部／外部群組，設定自動通知並補上新版測試說明。正式提交 beta review 得到 HTTP 201、初始 `WAITING_FOR_REVIEW`；隨後重新讀取 Apple API，已變為 `betaReviewState=APPROVED`，內部與外部均為 `IN_BETA_TESTING`。Build／審查 ID 同為 `db0e905c-e7ff-4bbf-abd0-e2f97937a2df`。外部測試第 5 版已放行；實際每位測試者是否已下載仍須由裝置確認。公開測試連結維持 `https://testflight.apple.com/join/ymFd6M3A`。
- 最終 Flutter analyze exit 0（`--no-fatal-infos`），僅 7 項既有 info 等級風格提示；本次新增程式未增加提示。
- 已更新 Apple 審查帳號、聯絡資訊與英文登入／刪帳步驟；Beta 說明不再宣稱使用模擬資料，明確說明背景推播尚未啟用。
- 仍待完成：兩個獨立真實 Google 帳號的 iPhone 主流程、背景推播、公開隱私政策網址及正式上架完整安全／商店驗收；不將此次 Beta 送審視為正式上架放行。

### 2026-10-08 更新候選版 1.0.0 (4)

- 接手使用者已在 Mac 完成的 build 4 封存，來源壓縮檔 `app-f737996d.tar.gz`；原始碼對應本機 `f737996d`。未覆蓋 Mac 上的新版本。
- Mac 工作目錄：`/Users/megumi/Projects/foundit-ios-build4/`。封存成功，已以 Apple API 金鑰簽署匯出 IPA；13:05:59 altool 回報 `UPLOAD SUCCEEDED with no errors`。Delivery UUID／Build ID：`11ef9020-bb75-473b-8c5e-ebe8b6b2970f`。Apple 已處理為 `VALID`，補齊加密申報並加入既有內部／外部群組；內部狀態 `IN_BETA_TESTING` 可安裝，外部狀態 `READY_FOR_BETA_SUBMISSION` 尚未送審。已加入繁體中文測試說明，明確註明推播未啟用。
- IPA SHA-256：`ad957e7a6fe6268fd3bfa519c33397d8330cec84909b9edc5a81c342b62ef1dd`。
- Mac Flutter 測試 100 項通過；analyze exit 0（`--no-fatal-infos`），有 7 項 info 等級風格提示。Windows 後端 Jest 14 suites / 49 項通過。
- 建置使用 `USE_MOCK=false`、`PROD=true`、API `https://api.foundit.tw/api/v1`、Socket `https://api.foundit.tw`。
- 本版沒有 Firebase iOS 建置參數，因此推播停用；216 後端日誌亦回報 FCM 未設定。此版可驗收 App 內聊天，不能宣稱背景推播已可用。
- Linux API 容器於 2026-10-08 12:54 建立，映像 `sha256:bd0c0cde7938f4cf62593074581123ee6ebdcf23a77d846f64e850175ac0b8ca2`。已包含 QR 聊天及 push 模組；migration 紀錄包含 `QrTagChats1760000000000`，無待執行 migration。已部署此次更新，本輪未重複重建／重啟後端。
- 公網 health HTTP 200；未登入呼叫 `/api/v1/admin/me` 回 HTTP 401。這不取代完整管理員及兩帳號真機驗收。
- 外部審查登入資料仍為舊 mock 帳號；未將它當作新版有效審查憑證送出。

### 2026-10-08 真實 API 候選版 1.0.0 (2)

- `https://api.foundit.tw/api/v1/health` 外網 HTTPS 實測 HTTP 200；Cloudflare Tunnel 路由已建立。
- 已取得並套用 iOS Google Client ID、Web Client ID 與原生回呼 scheme，封存產物 Info.plist 已核對。這不代表真機 OAuth 已驗證。
- Mac 建置使用 `USE_MOCK=false`、`PROD=true`、API `https://api.foundit.tw/api/v1`、Socket `https://api.foundit.tw`。
- Flutter analyze 無問題，85 項 Flutter 測試通過；Xcode archive 與 App Store Connect 簽署匯出成功。
- IPA SHA-256：`767af9d13d52fb7e3711ff5d5a6642fe77d7ff8978f6e033de1c8711c54384cc`。
- Mac 產物及日誌：`/Users/megumi/Projects/foundit-ios-20261008/`。2026-10-08 altool 回報 `UPLOAD SUCCEEDED with no errors`，exit 0；Delivery UUID：`7f0e4473-3f5b-48b1-a3af-74c098bf0a7e`。已上傳，不代表 Apple 已處理完成或外部測試已放行。
- 仍未完成：iPhone 真機 Google 登入、兩個真實帳號刊登／聯絡／對話／重開保存流程、正式上架完整安全及管理驗收。本版為 TestFlight 驗收候選版，不代表正式上架放行。
- Apple 後續查核：build 2 `processingState=VALID`；已補 `usesNonExemptEncryption=false` 並加入既有內部／外部測試群組。`internalBuildState=IN_BETA_TESTING`，內部測試可用；`externalBuildState=READY_FOR_BETA_SUBMISSION`，尚未送外部審查。審查資料仍沿用舊版模擬登入，不能用它宣稱新版登入可供審查；需提供有效審查登入方式再送出。

下方 2026-10-06 內容為歷史紀錄；Client ID、HTTPS 與建置狀態以本節為準。

### 2026-10-06 真實測試版進度（尚未放行）

本輪重新連線核對：Linux `192.168.66.216` 的 `foundit-beta-api-1` 和 PostgreSQL 均顯示 healthy，容器內 `/api/v1/health` 回傳 HTTP 200。映像內有 `google-id-token.js`，但遠端 Google 驗證及 auth service 原始碼的 SHA-256 與本機不同（排除本機 CRLF 後仍不同），因此不能當成本機最新版已部署的證據。外網 HTTPS 尚未驗證。

iOS 已加入 Google 原生 Client ID／Server Client ID 和回呼 URL scheme 的建置變數。新增 `foundit_flutter/tool/build_real_ios.py`，由同一組輸入產生原生 xcconfig 與 Dart 設定，固定 `USE_MOCK=false`，拒絕 HTTP、IP 位址與缺少／格式錯誤的 Client ID。設定驗證與 Info.plist XML 語法檢查通過；尚未取得實際 iOS Client ID，因此原生建置及 Google 回呼仍未驗證。

在 Mac 的 `foundit_flutter` 目錄執行（填入實際設定；build number 每次上傳須遞增）：

```sh
python3 tool/build_real_ios.py --ios-client-id IOS_CLIENT_ID --web-client-id WEB_CLIENT_ID --origin https://YOUR_API_HOST --build-number 2
```

此指令建置 IPA，不會自行上傳或繞過簽署。執行前須先驗證實際 HTTPS、Google OAuth 設定與兩帳號資料保存流程；產生設定檔不代表這些驗收完成。

- Flutter 自動測試 83 項通過；後端 Jest 10 suites / 28 項通過。這些結果不代表 Google 實際登入、資料庫整合或 iPhone 真機驗收完成。
- 已加入 Google 登入、Google 重新驗證刪除帳號、自動定位、OpenFreeMap 清爽／街道樣式及 demo session 清除。Android 不套用 iOS OAuth client ID。
- 已收到 Web OAuth Client ID，iOS OAuth Client ID 尚待提供，Bundle ID 應為 `com.david93518.foundit`。尚未設定原生回呼 URL scheme。
- Linux beta PostgreSQL 與 API 容器初次建置完成；該映像仍是 Google 登入修改前版本。更新傳輸 SSH 逾時，既有連線隨後 reset，不能宣稱新版已部署。資料庫隔離整合腳本 `Foundit/backend/test/database-smoke.cjs` 尚未執行。
- 外部 HTTPS／DNS／路由器轉發尚未驗證；未上傳新 TestFlight build。既有 1.0.0 (1) 為 mock build。


| 欄位 | 本次執行紀錄 |
| --- | --- |
| 日期、測試人員 | 待填 |
| 前端 commit / build number / 檔案雜湊 | 待填 |
| 後端 commit / image digest | 待填 |
| migration 版本、DB 版本 | 待填 |
| 測試環境、API / Socket / 圖片 / QR origin | 待填，勿放秘密 |
| 首版功能清單、停用功能與方式 | 待填 |
| 裝置、OS、App 版本、文字／顯示縮放 | 待填 |
| 驗收結果與未解問題 | 待填 |

每次修復或更換候選 build 後，重跑受影響案例。結果只填「通過／失敗／未測／不適用」，不適用必須寫清楚功能已如何停用；不要用「應該可以」代替實測。證據可存 CI artifact、去識別畫面、測試報告或受控營運紀錄，勿提交真實 token、手機號碼或私訊。

## 環境與資料準備

- [ ] 建立隔離的測試環境，使用真實 NestJS / PostgreSQL 與 `USE_MOCK=false`；不對未知的正式系統做破壞性測試。
- [ ] 建立測試帳號 A（物品擁有人）、B（另一使用者）、C（無關第三人）、訪客、管理員；使用受控測試門號與供應商測試額度。
- [ ] 建立可識別的測試物品、超過 50 筆搜尋資料、至少 120 則對話，並包含空資料、長文字、特殊字元與失效圖片。
- [ ] 測試資料獨立標記，測後依既定清理流程處理；不要把 `db:wipe-content` 當一般環境清理指令。
- [ ] 保存測試前版本／schema 與必要備份；權限、限流及費用限制已啟用。

## 1. 安全放行

這些測試應有可重跑的 API / WS 整合測試；只測畫面隱藏按鈕不算完成。

| 完成 | 案例／對應修復 | 操作 | 必須看到的結果 |
| --- | --- | --- | --- |
| [ ] | SEC-01 · S01 | 合法、過期、錯簽章、錯 audience、未知 provider 的測試登入 | 只有合法且允許的身分取得 session；非法請求不建立／綁定帳號 |
| [ ] | SEC-02 · S02 | 在隔離環境移除 JWT 秘密，或使用已知範例設定 | 正式模式拒絕啟動；不是默默退回預設值 |
| [ ] | SEC-03 · S02 / F04 | A 登出、管理員停權、刪帳、token 到期與輪替 | 舊 REST／Socket 都失效；已連線者也不能繼續收／發私人內容 |
| [ ] | SEC-04 · S03 | C 用已知聊天室 ID 嘗試 join、讀、發訊息、標已讀 | 無法訂閱或操作；A / B 正常事件不洩漏給 C |
| [ ] | SEC-05 · S03 / S07 | 連線驗證未完成即送事件，送錯型別、超長內容、客戶端 SYSTEM | 穩定拒絕且不落庫／不廣播；服務不崩潰 |
| [ ] | SEC-06 · S04 | B 修改 A 物品；A PATCH 自己物品並附 id、userId、status 等欄位 | 越權與非法欄位被拒，DB 主鍵／擁有人／狀態不被偷偷改寫 |
| [ ] | SEC-07 · S05 | 匿名／C／本人讀排行榜、QR、聊天室名片、物品詳情 | 回應鍵符合用途；私人聯絡資料與認證／推播識別不公開 |
| [ ] | SEC-08 · S06 | 上傳假 MIME、HTML / SVG、非圖片、超大像素／容量；再傳合法圖片 | 無效檔被拒，合法圖重新編碼且無 GPS EXIF，檔名／URL／存取政策正確 |
| [ ] | SEC-09 · S06 / S07 | B 嘗試引用／刪除 A 檔案，匿名或超額使用各端點 | 檔案擁有權有效；帳號／IP／跨節點限流符合規格，正常請求可用 |
| [ ] | SEC-10 · S08 | 重跑正式依賴、原生 SDK、秘密與歷史掃描 | 每個剩餘風險有紀錄與處置；外洩秘密已撤銷，而非只刪檔 |

## 2. 兩個使用者完成一次真正的找回流程

| 完成 | 案例／對應修復 | 操作 | 必須看到的結果 |
| --- | --- | --- | --- |
| [ ] | FLOW-01 · F01 | A 真實手機收碼；重送、錯碼、過期、重複提交、供應商拒絕 | 正確登入；一次性驗證；未送達不謊報成功；錯誤可理解且受限流 |
| [ ] | FLOW-02 · F05 / S06 | A 建立遺失／拾獲各一筆，選照片、確認地點、中斷一次上傳後重試 | 正確照片、狀態、日期與座標落庫；不重複刊登；未提交資料可恢復 |
| [ ] | FLOW-03 · F05 / F06 | B 搜尋僅存在地點欄位的字，再切縣市／分類／分頁與地圖 | 找到 A 新刊登，真實地圖標記正確；臺／台、空結果、超過 50 筆符合規格 |
| [ ] | FLOW-04 · F02 | B 從物品詳情聯絡 A，以 REST 與 WS 路徑各送一次文字 | 後端成功保存，另一裝置收到，重開可讀；沒有 enum 格式錯誤 |
| [ ] | FLOW-05 · F03 | 開啟 120 則房間，向上讀歷史，送連續相同文字，斷網／重試／重連 | 先看到最新訊息、歷史無漏；沒有重複／假成功；未載入內容不被標已讀 |
| [ ] | FLOW-06 · F04 / F09 | A 登出→B 登入→訪客→A；查看收藏、草稿、聊天室、通知 | 身分、Socket、資料互不混用；本機／同步收藏行為與規格一致 |
| [ ] | FLOW-07 · F10 / P02 | 並發聯絡、重複提交、交還、結案，再查列表和舊聊天 | 不重複建房或加點；狀態正確；結案／刪除不讓外鍵或舊對話出錯 |
| [ ] | FLOW-08 · F07 | 通知權限允許／拒絕，前景／背景／關閉 App，點擊通知 | 通知內容與收件人正確、導向正確；不洩漏舊帳號資料；拒絕者仍可查 App 內通知 |
| [ ] | FLOW-09 · F08 | 用兩平台原生相機掃實體 QR，測安裝／未安裝、登入／訪客、失效 code | 能按規格聯絡，未安裝者有可用網頁；已撤銷 code 不揭露物主；沒有 localhost 連結 |
| [ ] | FLOW-10 · F08 | 用舊 code 測試受控域名遷移方案 | 舊貼紙按相容策略繼續有效或清楚引導，不因字串拼接直接查不到 |

F07 / F08 若首版延期，填「不適用」並附伺服器停用、入口撤下與文案移除證據；核心認證、權限、刪帳和 UGC 治理不能用延期規避。

## 3. 管理、檢舉與刪帳

- [ ] **ADMIN-01 / A01：** 一般帳號直接呼叫每個管理 API 都被拒；管理員完成 MFA 並按角色獲權，撤權立即生效。
- [ ] **ADMIN-02 / A02：** B 檢舉 A 的貼文／訊息，管理員在佇列處理、寫理由、留稽核，B 能得知結果，A 有適當申訴流程。
- [ ] **ADMIN-05 / A02：** 首次建立／上傳內容前可讀條款與禁止內容規則，完成同意才可刊登，後端可核對同意版本；未同意者不能只靠直接呼叫 API 繞過。
- [ ] **ADMIN-03 / A02：** B 封鎖 A 後，建房、訊息、通知與其他入口均遵守規則；被隱藏內容無法從搜尋、地圖、詳情直連或快取繞過。
- [ ] **ADMIN-04 / A01：** 敏感個資查閱／匯出只限必要角色，操作可追溯；稽核資料不含密碼、OTP 或完整 token。
- [ ] **DELETE-01 / A03：** A 在 App 內重新驗證並申請刪帳，後端按政策完成；App 顯示真實狀態，不只清除本機登入。
- [ ] **DELETE-02 / A03：** 核對使用者、貼文、聊天、圖片、QR、push、session 與第三方服務；依法保留項目有理由、期限與權限限制。
- [ ] **DELETE-03 / A03：** 未安裝 App 的使用者可從公開網頁提出刪帳請求；B 看到合規的匿名化對話，舊連結不能暴露 A 私人資料。
- [ ] **OPS-01 / P02：** 客服、檢舉、申訴、資料請求與事故有實際負責人；演練一筆從收件到結案的處理。

## 4. 裝置、文字大小與 UI / UX

前輪自動版面測試已涵蓋下列尺寸；這裡要求對**修復後候選版本**重新檢查，並補齊真機。畫面上的原創識別與配色已建立，但是否讓失主感到安心，仍需目標使用者回饋，不能用獎項級等自我評語代替。

| 尺寸／平台 | 100% 文字 | 130% 文字 | 200% 文字 | 鍵盤／橫向／安全區 | 證據／問題 |
| --- | --- | --- | --- | --- | --- |
| 320×568 緊湊視窗 | 未測 | 未測 | 未測 | 未測 | 待填 |
| 390×844 手機視窗 | 未測 | 未測 | 未測 | 未測 | 待填 |
| 844×390 橫向視窗 | 未測 | 未測 | 未測 | 未測 | 待填 |
| 768×1024 平板視窗 | 未測 | 未測 | 未測 | 未測 | 待填 |
| 1440×900 Web 視窗（若提供） | 未測 | 未測 | 未測 | 未測 | 待填 |
| Android 真機：型號／OS 待填 | 未測 | 未測 | 未測 | 未測 | 待填 |
| iPhone 真機：型號／OS 待填 | 未測 | 未測 | 未測 | 未測 | 待填 |
| iPad／Android 平板（若提供）：型號待填 | 未測 | 未測 | 未測 | 未測 | 待填 |

原生 OS 字級不一定能剛好設定為這些百分比；記錄實際系統選項，並至少測預設及最大支援設定。另測「顯示大小／Display Zoom」，不能只放大文字。裝置需覆蓋宣稱支援的最低及較新 OS。

- [ ] 探索、搜尋／篩選、詳情、收藏、登入／OTP、三步刊登、照片選擇、聊天室、個人資料、QR、設定、刪帳與檢舉所有可見控制項均實際點擊；沒有無效或假成功操作。
- [ ] 標題／正文／輔助文字層級清楚，長中文、長姓名、換行、日期與金額不裁切；按鈕隨內容增高或捲動可達，彈窗與底部面板不被鍵盤遮住。
- [ ] 保持合理點擊面積和間距；每個圖示有可理解名稱；焦點順序、TalkBack／VoiceOver、錯誤提示、載入狀態可被理解，資訊不只靠顏色傳達。
- [ ] 尊重減少動態；動畫不阻擋操作，連點不重複提交；返回、中斷來電、切背景、重啟後能按規格恢復草稿與正確頁面。
- [ ] 測照片權限拒絕／限選、相機不存在／被占用、GPS 拒絕／服務關閉／舊定位；有可用替代路徑，不陷無限 loading。
- [ ] 測離線、弱網、API 4xx / 5xx、圖片失效、登入失效；錯誤指出可採取的下一步，重試不弄丟輸入。
- [ ] 以真實候選版測啟動、長列表、圖片記憶體及聊天室長歷史；先寫明測試裝置與可接受目標，再保存實測值。
- [ ] 邀請目標使用者實做「我掉了東西」和「我撿到了東西」兩項任務，記下卡住點；收集陶橘點綴、文案是否造成不必要緊張的回饋，再調整，不能把配色心理假設當研究結論。

## 5. 資料庫、部署與恢復

- [ ] **DEPLOY-01 / D01：** 空 DB 可用 migration 建立；去識別的舊資料副本可升級；驗證索引／唯一性／外鍵／時間格式與筆數；記錄回復策略。
- [ ] **DEPLOY-02 / D02：** 候選版 `USE_MOCK=false`；API、WSS、圖片、QR 都是受控 HTTPS 網域；沒有區網／localhost／範例金鑰或 console OTP。
- [ ] **DEPLOY-03 / D02：** CI 能重建同一候選產物；測試／正式秘密隔離，DB／Redis 不開公網，API 與管理端權限正確；CORS 與 proxy trust 設定經驗證。
- [ ] **DEPLOY-04 / D03：** 重啟、換容器、多副本讀取後圖片仍在；配額、孤兒清理、私密檔與快取失效符合政策。
- [ ] **DEPLOY-05 / D03：** 在新隔離環境以備份還原 DB＋圖片；抽查帳號、刊登、對話與檔案；量測資料遺失窗口和恢復時間，與訂定目標比較。
- [ ] **DEPLOY-06 / D04：** API／DB／儲存／SMS 受控故障會觸發告警，實際負責人收到並依手冊復原；日誌無秘密／完整個資。
- [ ] **DEPLOY-07 / D02 / D04：** 演練候選版本部署失敗與回滾，確認資料庫相容；WebSocket 斷線後用戶端可恢復；保留可回滾產物。
- [ ] **DEPLOY-08 / D04 / P02：** 在受控流量下量測延遲／錯誤率與 SMS／儲存／流量費用；設定超額告警和停用濫用功能的手段。

## 6. 商店提交前

- [ ] **STORE-01 / R01：** 確認更新舊 App 或建立新 App；正式 Android identity、upload key／Play signing、version code、AAB 與實際 manifest 正確。
- [ ] **STORE-02 / R01：** 實際 AAB／APK 的 native libraries 通過 16 KB 對齊及執行測試；最低與新版本 Android 可安裝、升級、登入和開相機。
- [ ] **STORE-03 / R02：** iOS 正式 bundle、team／profile、最低目標版本與提交 SDK 合規；release archive 進 TestFlight，實機主流程通過。
- [ ] **STORE-09 / R02：** 若提供第三方主帳號登入，確認 Apple 4.8 適用性並驗收所需選項；自家登入或例外情境記明依據。
- [ ] **STORE-04 / A03 / R04：** 隱私政策、刪帳網站、客服連結可公開使用；App Privacy／Data Safety 與實際網路流量、SDK、資料保留一致。
- [ ] **STORE-05 / R04：** 名稱、logo、照片、字型來源／授權已核對；截圖出自實際候選版；沒有 mock 資料假裝真實營運、未提供功能的宣稱。
- [ ] **STORE-06 / R04：** 年齡分級與 UGC 問卷如實填寫；審查帳號可用，登入、QR、檢舉、刪帳等特殊流程有審查說明。
- [ ] **STORE-07 / R04：** Console 中確認開發者資格、必要封測與其他待辦；適用的新個人 Play 帳號完成相關封測條件。
- [ ] **STORE-08 / 全部：** 送審當天重新核對修復清單附的官方政策連結，記錄查核日；分階段釋出、監控、停止釋出／回滾與客服值班有安排。

## 問題與證據紀錄模板

| 案例 ID | 結果 | 修復 commit／build | 環境／裝置 | 證據位置 | 未解問題／負責人 |
| --- | --- | --- | --- | --- | --- |
| 待填 | 未測 | 待填 | 待填 | 待填 | 待填 |

放行前必須清除全部 P0，完成首版適用 P1 的修復與驗收；任何未測項目都不能勾選通過。P2 可另排版本，但目前公開的資料和端點仍受同一安全要求約束。

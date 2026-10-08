# FOUND !T 上架前修復與交接清單

查核日期：2026-10-04（Asia/Taipei）  
範圍：本機 `foundit_flutter`、`Foundit/backend` 與版本庫設定；舊 Kotlin 專案僅供參考。  
基準：分支 `codex/foundit-experience`，HEAD `37156e640a14450956a5f26d788d4e93f6a70f66`，**包含尚未提交的工作目錄變更**。行號只對應此次快照，修復後請以檔案與函式名稱定位。

## 目前結論

**目前尚未達到可公開營運、可送審的狀態。** 新版已有可操作的 Flutter UI、FOUND !T 識別與部分自動測試；NestJS / PostgreSQL 後端有可以沿用的基礎，但存在登入與權限缺口、真實 API 串接錯誤，以及尚未完成的營運和部署工作。

這份文件是修復交接，不是修復完成證明。本輪只補文件與查核證據，沒有代為修正以下功能。新版前端缺少刊登座標、聊天 API 格式不一致等問題也列在內，不把缺口全歸因於舊後端。

| 你問的項目 | 真實狀態 | 相關工作 |
| --- | --- | --- |
| 後端處理了嗎？ | 保留原後端，前輪修過縣市篩選 SQL；尚未完成正式整合與安全修復 | S01–S08、F01–F10、D01 |
| 管理者後台有嗎？ | 查到的專案沒有管理介面、角色權限、審核工作流與操作稽核 | A01、A02 |
| 資安完成了嗎？ | 做過部分原始碼與隔離驗證，已發現阻擋上線問題；沒有完成全面安全驗收 | S01–S08、F04、F09 |
| 部署好了嗎？ | 本輪只有本機示範預覽；repo 的 Compose 只有 PostgreSQL / Redis，不能代表正式服務已部署 | D01–D04 |
| UI / UX 完成了嗎？ | 排版、字級、尺寸和部分流程有測；正式資料、真機權限、送達狀態與完整任務仍待驗收 | F01–F10、R03 |
| 可以上架嗎？ | 缺安全修復、核心整合、管理與刪帳、部署、簽署和送審資料 | 全部 P0 / 首版適用 P1 |

優先讀 [修復順序](#修復順序)，逐項修復後使用 [上架驗收表](RELEASE_ACCEPTANCE.md) 留下證據。

## 如何判讀狀態與優先級

- **已確認／原始碼**：程式中可以直接定位；不等同已對正式服務重現。
- **已隔離驗證**：使用本機驗證器或記憶體替身重現；未涉及真實帳號、雲端或正式資料庫。
- **待整合驗證／靜態風險**：程式路徑存在風險，但尚未用真實資料庫、裝置或網路驗證結果。
- **待決策／待外部確認**：需要產品、營運、開發者帳號或雲端設定才能定案；不能當成已完成，也不能斷言外部資源不存在。
- **P0**：公開 API 或接收真實使用者資料前必須排除的阻擋項。
- **P1**：首版功能範圍內，送審與營運前必做；下列驗收方框目前均未完成。
- **P2**：可以延期的延伸能力；延期時必須同步撤除入口、宣稱及不安全的伺服器能力。

### 已有證據與限制

| 檢查 | 已有結果 | 能證明／不能證明 |
| --- | --- | --- |
| Flutter 自動測試 | 前輪 77 / 77 通過；後續 QR 配色調整另有 2 項針對性測試通過 | 主要為 widget、版面與 mock 流程；不能證明真實 SMS、API、GPS、相機與推播可用 |
| Dart analyze / Web release | 前輪無 error / warning，11 項 info；Web build 成功 | 不能代替 Android / iOS 正式簽署與裝置測試 |
| NestJS 測試 / TypeScript | 前輪 7 項通過、型別檢查通過 | 6 項縣市 SQL 建構測試加 1 項基本回應；沒有完整認證、授權、資料庫 E2E |
| 聊天訊息格式 | 本輪實際 `ValidationPipe` 拒絕 `text`，接受 `TEXT` | 已證明 DTO 契約不一致；未啟動真實 HTTP / PostgreSQL |
| 正式依賴掃描 | 本輪重新執行：19 個受影響套件項目，13 high / 5 moderate / 1 low / 0 critical | 不是 19 個獨立、已可利用的漏洞；也不涵蓋 Flutter、原生 SDK 或業務邏輯 |
| OAuth、PATCH、Socket | 前輪以隔離替身驗證過驗證失敗後取 sub、非允許欄位進入 save、任意聊天室 join | 未進行正式環境攻擊，未證實資料庫層每一種後果 |

本輪保存的原始結果與重跑方法見 [查核證據](evidence/2026-10-04/README.md)。既有 Flutter 執行紀錄位於本機 `foundit_flutter/build/final-tests.txt`、`final-analyze.txt`、`final-build.txt`；build 目錄可能被忽略或清除，不把它當成永久 CI 證據。

未做：正式雲端／商店後台檢查、完整 Git 歷史秘密掃描、完整 SAST / DAST、第三方滲透測試、備份還原演練、負載與原生真機驗收。不能保證這份清單已窮盡全部缺陷。

## 修復順序

| 順序 | 交付目標 | 必須先完成 |
| --- | --- | --- |
| 1 | 登入失敗就拒絕、聊天室權限、回應資料與上傳安全 | S01–S08；尚未修妥前不公開目前 API |
| 2 | 可重建資料庫、正式設定、真實 SMS 與前後端契約 | D01、D02、F01、F02、F04、F09 |
| 3 | 兩個真實測試帳號完成刊登、找物、聯絡、交還、結案 | F03、F05、F06、F10；首版保留的 F07、F08 |
| 4 | 管理員可處理檢舉、封鎖、申訴與刪帳 | A01–A03，並驗證所有讀取路徑遵守處置 |
| 5 | 測試環境可持久保存、監控、備份、還原及回滾 | D02–D04 |
| 6 | 簽署版本與商店資料通過完整驗收 | R01–R04、P01、P02、上架驗收表 |

修復可沿用 NestJS / PostgreSQL；目前沒有證據顯示必須全面重寫後端。比較務實的是補權限邊界、資料遷移、回應 DTO 和整合測試，再決定是否替換個別服務。

## S｜資安與 API 邊界

<a id="s01"></a>

### S01 · P0 · OAuth 驗證失敗仍能繼續登入

**已確認／原始碼＋前輪隔離驗證。** [auth.service.ts](../Foundit/backend/src/auth/auth.service.ts#L117) 的 `resolveGoogleIdTokenSubject` 在 Google 驗證失敗後仍解碼 JWT 的 `sub`，後續用它查使用者並簽發平台 token。非 Google 分支 `resolveOAuthExternalKeyNonGoogle` 也未做供應商驗證，使用解碼結果或 token 雜湊辨識帳號。這可能讓未經供應商認證的身分被接受。

**修法：** 刪除驗證失敗的 fallback；明確列出允許的 provider，驗簽、issuer、audience、期限及供應商要求。未完成的登入方式在伺服器端停用。前端拿掉 Google / LINE 按鈕並不能封住 API。帳號綁定需另做重新驗證，不能僅憑相同 email 自動合併。

- [ ] 錯誤簽章、偽造 sub、錯 audience、過期 token、未知 provider 均拒絕且不建立帳號；合法測試帳號成功；有可重跑的 API 測試。

<a id="s02"></a>

### S02 · P0 · JWT 設定可退回固定字串，缺少完整 session 撤銷策略

**已確認／設定路徑；正式環境值未知。** [auth.module.ts](../Foundit/backend/src/auth/auth.module.ts#L20)、[jwt.strategy.ts](../Foundit/backend/src/auth/jwt.strategy.ts#L18)、[chats.module.ts](../Foundit/backend/src/chats/chats.module.ts#L19) 缺設定時使用 `fallback-secret`。沒有證據表示外部正式服務正用此值；問題是錯誤配置仍可啟動。範例 JWT 期限為 30 天，登出、停權與刪帳的伺服器撤銷機制仍須完成。

**修法：** 啟動時驗證必要環境變數與秘密強度，REST / Socket 使用一致設定；秘密存放 secret manager，準備輪替流程。設計 session / refresh token 或其他可撤銷機制，讓登出、停權、刪帳可終止既有授權。若曾以不安全設定公開運行，需評估撤銷既有 token 和事件追查。

- [ ] 正式模式缺少或使用範例秘密時啟動失敗；輪替、過期、撤銷後 REST 與既有／重連 Socket 均無法繼續操作。

<a id="s03"></a>

### S03 · P0 · WebSocket 訂閱聊天室未檢查成員資格

**已確認／原始碼＋前輪隔離驗證。** [chats.gateway.ts](../Foundit/backend/src/chats/chats.gateway.ts#L56) 的 `handleJoin` 直接加入 `chat:<id>`。同一 room 會收到新訊息廣播；REST 的讀取、發送、已讀已有 `assertParticipant`，但不能保護這條訂閱路徑。

**修法：** 每次 join、send、read 都驗證已登入、帳號狀態與聊天室成員；防止連線驗證尚未完成就先送事件。離開聊天室、停權與撤銷 session 時清除訂閱。採用實際 WS DTO、事件大小及速率限制。

- [ ] 帳號 B 知道 A 的聊天室 ID 仍無法加入或收到事件；斷線重連、token 過期、停權、登入競速情境也無法繞過。

<a id="s04"></a>

### S04 · P1 · 物品 PATCH 接受不該由使用者修改的欄位

**已確認／原始碼＋前輪隔離驗證。** [items.controller.ts](../Foundit/backend/src/items/items.controller.ts#L55) 使用 `Partial<CreateItemDto>`，執行期不是可驗證的 DTO class；[items.service.ts](../Foundit/backend/src/items/items.service.ts#L57) 隨後 `Object.assign`。隔離驗證顯示 `id`、`userId`、`status` 可流入 save。變更主鍵後是否覆寫別筆資料仍須 PostgreSQL 驗證，不能寫成已完成攻擊。

**修法：** 建立真正的 `UpdateItemDto`，白名單與明確欄位賦值；拒絕 id、userId、關聯、建立時間等欄位。結案／關閉使用獨立授權的狀態轉換，不任意接受狀態字串。

- [ ] A 不能改 B 的物品；A 修改自己的物品也不能改主鍵、擁有人或繞過狀態流程；未知欄位被拒絕且資料庫無副作用。

<a id="s05"></a>

### S05 · P1 · 公開與聯絡 API 暴露過多使用者資料

**已確認／回傳程式路徑，未擷取真實使用者資料。** [points.service.ts](../Foundit/backend/src/points/points.service.ts#L55) 排行榜載入並直接回傳 user entity；[user.entity.ts](../Foundit/backend/src/common/entities/user.entity.ts#L21) 包含電話、email、googleSub、fcmToken。[qr.controller.ts](../Foundit/backend/src/qr/qr.controller.ts#L55) 公開掃描使用的 [使用者 serializer](../Foundit/backend/src/users/user-mobile.serializer.ts#L13) 包含電話與 email；[聊天室 serializer](../Foundit/backend/src/chats/chat-mobile.serializer.ts#L49) 含參與者電話。googleSub 洩漏可加重 S01 風險。

**修法：** 依公開名片、自己的資料、聊天室、管理需求分開 response DTO；禁止直接輸出 entity。聯絡先透過站內訊息，電話／email 需明確同意與必要性。位置、照片與 QR 也要按用途最小揭露；隱藏／刪除資料不能只從首頁移除。

- [ ] 以匿名、非本人、本人三種身分檢查所有回應鍵；公開排行榜／QR／聊天室名片不含認證識別、push token 或未同意的私人聯絡資料；隱藏物品詳情也被保護。

<a id="s06"></a>

### S06 · P1 · 上傳只信任 MIME，原始檔以公開靜態資源提供

**已確認／原始碼；尚未進行 HTTP 惡意檔重現。** [upload.controller.ts](../Foundit/backend/src/upload/upload.controller.ts#L25) 已要求登入並限制 10 MB，但僅檢查客戶端 `image/*`，保留原副檔名；[main.ts](../Foundit/backend/src/main.ts#L25) 公開供應檔案。這留下偽裝 HTML / SVG、圖片資源耗盡與 EXIF 洩漏等風險。套件中有 sharp 不代表上傳已使用它。

**修法：** 限定格式、實際解碼與重新編碼、限制像素／張數／容量、移除 EXIF；SVG 不支援時明確拒絕。建立檔案擁有權、用量配額、孤兒清理與刪帳清理；回傳 URL 使用受信任的正式 origin，不能依未驗證 Host / forwarded header 任意生成。儲存與快取策略須支持隱私刪除。

- [ ] 假 MIME、錯副檔名、非圖片、超大像素和超量上傳被拒絕；合法圖片能讀取；輸出無 GPS EXIF；不能把別人的上傳認作自己的；刪除與清理可驗證。

<a id="s07"></a>

### S07 · P1 · API 限額、內容驗證與防濫用仍不完整

**已確認／DTO 與事件處理；外部 WAF 設定未知。** [create-item.dto.ts](../Foundit/backend/src/items/dto/create-item.dto.ts) 座標缺範圍、陣列缺張數上限，多個字串缺長度／非空驗證；聊天分頁與 WS payload 邊界仍需補齊。`SYSTEM` 是訊息 enum 成員，應由伺服器控制而非讓客戶端偽造。物品列表已有最多 50 筆限制，不能誤列為完全無分頁上限。

**修法：** 統一 schema／錯誤格式；限制正整數分頁、內容長度、座標、日期、金額與圖片數。限制登入、OTP、發文、聊天、QR 掃描、查詢與上傳的帳號／IP 配額，分散部署使用共用計數。圖片與頭像驗證允許來源和擁有權；任意外站 URL 目前是隱私／追蹤風險，未證實為 SSRF。

- [ ] 繞過 App 直接呼叫 API 的空字串、越界值、超大內容、客戶端 SYSTEM 訊息皆被拒絕；濫用觸發穩定 429 或對應 WS 錯誤，正常流量不被錯擋。

<a id="s08"></a>

### S08 · P1 · 正式依賴有已知安全公告，其他供應鏈尚未完整查核

**已確認／本輪 npm 掃描。** [原始報告](evidence/2026-10-04/npm-audit-production.json) 記錄 19 個受影響套件項目（13 high、5 moderate、1 low）；包括 NestJS 周邊、multer、sharp、Socket.IO 周邊等直接或傳遞依賴。公告數、受影響套件數和可利用漏洞數不是同一件事。

**修法：** 依 lockfile 逐批更新、讀相容性差異、跑登入／上傳／聊天回歸並重新掃描；例如 sharp 的修復可能跨版本，不能盲跑 `npm audit fix --force`。補 Flutter / Android / iOS 依賴、授權及 repo / Git 歷史秘密掃描。若找到實際外洩金鑰，須撤銷輪替，刪檔不等於處理完畢。

- [ ] 保存修復後掃描與套件版本；每個保留公告都有適用性、可達性、處置與負責人紀錄，無未處理的可利用高風險項；原生 SDK 及秘密掃描另有結果。

## F｜真實前後端串接與資料可靠性

<a id="f01"></a>

### F01 · P1 · 簡訊尚未真正接通，OTP 儲存與防刷不足

**已確認／原始碼。** [otp.service.ts](../Foundit/backend/src/auth/otp.service.ts#L17) 用記憶體 Map、`Math.random`、console 預設模式；`sendViaSms` 仍為 TODO，沒有真正送出簡訊也可能回覆成功。已有 5 次驗證限制，但重送會重建紀錄，不能代替完整防刷；Compose 有 Redis 不代表 OTP 已使用 Redis。

**修法：** 接通供應商與錯誤／送達處理，使用密碼學安全亂數與共享、具期限的儲存；原子驗證、單次消耗、重送冷卻及電話／IP／裝置的合理限額，設簡訊費用上限告警。統一台灣號碼與 `+886` 正規化；正式環境拒絕 console driver，日誌不可記驗證碼。

換號、遺失 SIM 卡或長期收不到驗證碼的恢復方式也需定義；客服不能僅憑公開貼文或電話資訊就解除帳號保護。

- [ ] 指定測試門號真實收到且僅能驗證一次；過期、錯碼、重送、雙節點同時驗證、供應商失敗及限流皆符合規格；不得未寄送卻顯示已寄送。

<a id="f02"></a>

### F02 · P1 · 聊天訊息 type 大小寫契約不一致

**已確認／本輪隔離驗證。** Flutter [MessageType](../foundit_flutter/lib/data/models/chat.dart#L77) 為小寫；[REST 發送](../foundit_flutter/lib/data/repositories/chat_repository.dart#L218) 用 `type.name`，Socket [sendMessage](../foundit_flutter/lib/core/services/chat_socket_service.dart#L106) 預設 `text`。後端 [SendMessageDto](../Foundit/backend/src/chats/dto/send-message.dto.ts) 要求 `TEXT` 等大寫，實際 ValidationPipe 回傳 400。Socket 路徑繞過同一 DTO，可能將錯誤值送入 PostgreSQL enum；此 DB 後果尚未重現。

**修法：** 定義唯一 wire schema，前端明確序列化或後端受控正規化，REST / WS 共用驗證；不要只改 mock 或以任意 cast 掩蓋錯誤。同步處理不可由客戶端建立的 SYSTEM 類型。

- [ ] 真實 API 與 Socket 雙向文字訊息成功落庫、另一帳號收到、重開 App 還在；錯誤 enum 有明確回應。[本輪 probe](evidence/2026-10-04/probe-chat-contract.cjs) 可供比較 DTO 行為。

<a id="f03"></a>

### F03 · P1 · 聊天缺送達確認、補訊息與正確的歷史／已讀邊界

**已確認／原始碼；可靠性尚未網路故障實測。** [chat_socket_service.dart](../foundit_flutter/lib/core/services/chat_socket_service.dart#L106) emit 沒有 ACK／timeout；[chat_room_screen.dart](../foundit_flutter/lib/presentation/screens/chat/chat_room_screen.dart#L225) 的 pending 去重依內容／發送人，缺 client message ID。[chats.service.ts](../Foundit/backend/src/chats/chats.service.ts#L117) 歷史採時間升冪分頁，畫面只呼叫預設第一頁 50 筆；`markRead` 卻標記整個聊天室其他人的未讀訊息。長對話可能看不到最新內容，還把未載入的內容標為已讀。

**修法：** ACK 以伺服器持久保存為準，分清發送中／已送出／失敗／已讀；加入 timeout、保留草稿、重試及冪等 client ID。先載入最新一頁，往上讀舊訊息，以穩定 cursor 排序；重連補漏、去重、更新列表與未讀數。已讀只到實際顯示的最後訊息 ID。

- [ ] 超過 120 則的房間先見最新訊息，往上能補齊；斷線／重送／連續相同文字不遺失不重複；未載入訊息保持未讀，跨裝置狀態一致。

<a id="f04"></a>

### F04 · P1 · 切換帳號時 Socket 與資料生命週期未完整重置

**待整合驗證／靜態風險。** [auth_provider.dart](../foundit_flutter/lib/presentation/providers/auth_provider.dart#L127) 登出只呼叫 repository 並清 user；[Socket connect](../foundit_flutter/lib/core/services/chat_socket_service.dart#L53) 已連線便提前返回，provider 未依登入身分重建。存在 A 登出、B 登入後沿用 A 舊連線的風險；本輪尚未用兩個真實帳號重現。

**修法：** 身分切換統一中止連線、取消訂閱／在途請求、清除使用者專屬 provider 與記憶體資料；新 token 建新連線。伺服器撤銷機制依 S02；push token 綁定亦須解除／更新。

- [ ] A 登出後既有 Socket 失效；B 登入收到的所有訊息／通知／列表皆屬 B，重新登入 A 也正確；背景恢復、token 過期與 mock / 正式環境切換另測。

<a id="f05"></a>

### F05 · P1 · 新刊登沒有座標，不會出現在地圖

**已確認／原始碼。** [add_item_screen.dart](../foundit_flutter/lib/presentation/screens/item/add_item_screen.dart#L232) 只設定文字地點，未帶 latitude / longitude；[Item](../foundit_flutter/lib/data/models/item.dart#L70) 預設為 0,0 並送出；[map_screen.dart](../foundit_flutter/lib/presentation/screens/map/map_screen.dart#L54) 排除 0,0。示範資料已有座標，因此原型可看地圖不能證明新刊登能進地圖。

**修法：** 刊登步驟加入可確認的地點選擇／地圖標點，處理定位拒絕與手動輸入。沒有座標時用明確的缺值和文案，不能填假座標。決定公開位置精度，避免讓遺失物地點變成住家位置曝光。

- [ ] 真實帳號新刊登後，另一裝置從 API 讀到正確座標並看到標記；拒絕 GPS 仍可手動刊登；定位與公開位置精度符合產品規格。

<a id="f06"></a>

### F06 · P1 · 搜尋與地圖承諾和真實查詢不完全一致

**已確認／原始碼。** 首頁搜尋提示包含地點；[mock 搜尋](../foundit_flutter/lib/data/repositories/item_repository.dart#L193) 含 locationName，但 [真實 keyword 查詢](../Foundit/backend/src/items/items.service.ts#L195) 只比 title / description。縣市篩選已另修。地圖目前讀最近列表，後端上限 50，定位按鈕只移動畫面；尚非依可視範圍完整搜尋。畫面已有「最多 50」提示，不能誤寫成完全未提示。

**修法：** 統一 mock / API 搜尋欄位、分類／縣市代碼、臺／台與地址格式，避免純自由文字造成縣市漏查。首版若只顯示最新物品須清楚說明；若保留「附近全部」承諾，則加 viewport / 距離查詢、分頁與適量聚合。舊定位資料須判斷新鮮度。

- [ ] 僅存在地點欄位的關鍵字可被正式 API 搜出；縣市／分類組合、空結果及跨頁無重複／漏失；地圖測超過 50 筆並符合對使用者的描述。

<a id="f07"></a>

### F07 · P1（保留通知功能時）· 通知清單不等於推播完成

**已確認／目前串接。** [notifications.service.ts](../Foundit/backend/src/notifications/notifications.service.ts#L39) 只寫通知資料表；聊天／QR 沒有完整事件產生通知與推送鏈。Flutter 尚無完整 Firebase Messaging 初始化、token 註冊更新與背景處理。存在 `google-services.json` 或 fcmToken 欄位不能證明已接通。

**修法：** 定義哪些事件要通知，接 FCM / APNs、裝置 token 輪替／解除、發送重試與去重、點擊導向、通知偏好與鎖屏隱私。拒絕推播仍能在 App 內看到通知。若首版不做，移除即時通知相關承諾並提供清楚替代流程。

- [ ] 前景、背景、關閉 App 的真機皆按平台允許行為收到通知並開正確頁；登出後不收到上一帳號內容；失效 token 清理、拒絕權限與重複事件可驗證。

<a id="f08"></a>

### F08 · P1（保留 QR 功能時）· 一般相機掃碼缺公開落地頁與完整連結流程

**已確認／設定與程式。** [qr.service.ts](../Foundit/backend/src/qr/qr.service.ts#L19) 產生 `<APP_BASE_URL>/qr/<code>`；Flutter [router](../foundit_flutter/lib/core/router/app_router.dart) 有 QR 管理／掃描頁，未完成此公開路徑與 App Links / Universal Links。查找還會用「目前 domain＋code」重建完整字串，變更 domain 可能令舊貼紙查不到。

**修法：** 定義永久 code 與獨立的公開前端 origin，DB 依穩定 code 查找；建立未安裝 App 也可使用的安全落地頁，配置雙平台關聯檔與深層連結。設撤銷、失效、重製、域名移轉相容與防掃描濫用；依 S05 保護物主資料。

- [ ] iPhone / Android 原生相機掃實體貼紙，已安裝、未安裝、登入與訪客都走完聯絡；撤銷 code 立即失效；更換受控域名仍能按遷移規格處理舊 code。

<a id="f09"></a>

### F09 · P1 · 收藏／草稿未按帳號隔離，憑證儲存需分平台設計

**已確認／原始碼。** [foundit_ui.dart](../foundit_flutter/lib/presentation/widgets/foundit_ui.dart#L17) 收藏鍵為 `bookmark:<itemId>`，未按帳號分區、沒有伺服器同步；[chat_room_screen.dart](../foundit_flutter/lib/presentation/screens/chat/chat_room_screen.dart#L48) 草稿鍵只有 chatId。登出不清這些資料；[auth_repository.dart](../foundit_flutter/lib/data/repositories/auth_repository.dart) token 存 SharedPreferences。跨帳號完整表現尚待實測。

**修法：** 先決定收藏是帳號同步或明示的本機功能；加入帳號／環境命名空間、訪客合併規則及登出／刪帳清理。原生憑證改用 Keychain / Keystore 等安全儲存；Web 另設安全 session、XSS / CSRF 防護，不假設原生方案直接適用。啟動時與伺服器同步 session 狀態，不能只信本機登入旗標。

- [ ] 同裝置 A / B / 訪客互不看到私人草稿與收藏；刪帳資料清乾淨；清快取、重裝、第二裝置行為符合已選規格；過期登入能恢復流程而不丟未提交表單。

<a id="f10"></a>

### F10 · P1 · 交易邊界、重複請求與刪除關聯需資料庫驗證

**待整合驗證／靜態風險。** [chats.service.ts](../Foundit/backend/src/chats/chats.service.ts) 建房為查詢後新增；[chat.entity.ts](../Foundit/backend/src/common/entities/chat.entity.ts) 未見對該業務組合的唯一約束，並發可能重複建房。訊息保存／聊天室更新、使用者／積分建立是分開操作。物品硬刪除與已有聊天的外鍵關係需確認，尚未證實實際 PostgreSQL 會如何失敗。

**修法：** 定義建房唯一性，在 DB 設約束並正確處理衝突；重要多步寫入使用交易／可靠事件機制。發文、發訊息、結案及積分用冪等鍵／唯一事件避免重複。明確選擇刪除、匿名化、保留證據及外鍵政策。

- [ ] 並發建房只得到一個有效對話；請求重試不多建貼文／訊息／加點；模擬中途失敗不留半成品；有聊天的物品刪除／結案不出 500，歷史顯示符合保留政策。

## A｜管理者與使用者權益

<a id="a01"></a>

### A01 · P1 · 管理者介面與伺服器角色權限尚未建置

**已確認／repo 範圍。** [app.module.ts](../Foundit/backend/src/app.module.ts) 沒有管理模組；User 未見管理角色／停權模型。現有一般使用者個人頁不能當作管理後台。

**需交付：** 受保護的管理入口、管理員 MFA、最小權限角色、檢舉工作佇列、貼文／帳號處置、申訴與稽核紀錄。敏感欄位查閱與匯出需額外權限並記錄；管理員帳號不能由公開註冊或前端自稱角色取得。建立首位管理員與撤銷管理權的安全流程。

- [ ] 一般使用者直接呼叫每個管理 API 都被拒絕；管理員可完成一次審核／停權／申訴；每項操作記下操作者、目標、時間、原因與結果，不能任意改抹稽核紀錄。

<a id="a02"></a>

### A02 · P1 · 檢舉、封鎖與內容治理需前後端一起完成

**已確認／缺少完整工作流。** 使用者可發文和聊天，但尚未具備完整的檢舉、封鎖、內容過濾、處理紀錄及客服入口。Apple 和 Google 的 UGC 政策要求相應的治理措施，不能僅有「使用者自行負責」文案。[Apple UGC 規範](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)、[Google UGC 政策](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en-GB)。

**需交付：** 貼文／帳號／訊息檢舉，理由、必要證據、處理狀態；封鎖立即影響建房、發訊息與通知。建立內容規則、處置時限和申訴流程。被隱藏貼文從搜尋、地圖、詳情直連、QR 與快取都遵守同一政策；目前 public detail 不按治理狀態過濾，未來不可只改列表。

Google UGC 政策也要求使用者在建立／上傳內容前接受使用條款或使用者政策；刊登流程需補上可閱讀的規範與同意紀錄，包含條款版本。[Google UGC 政策](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en-GB)。

- [ ] A 封鎖 B 後 B 不能繼續聯絡或用其他入口繞過；一件檢舉能進後台、被處理、留稽核並讓使用者知道結果；隱藏內容不能靠 ID 直接讀取。

<a id="a03"></a>

### A03 · P1 · 刪除帳號、隱私政策與資料保留尚未完成

**已確認／repo；外部政策網站未知。** [users.controller.ts](../Foundit/backend/src/users/users.controller.ts) 沒有完整刪帳端點；設定頁資料說明不是完整刪帳／隱私流程。舊 Kotlin 裡的 TODO 也不算完成。

**需交付：** App 內可發起刪除、適當重新驗證、進度與完成通知；定義電話、照片、聊天、貼文、QR、push token、積分、備份與申訴證據如何刪除／匿名化／依法保留，避免先刪帳後留下一串可識別資料。政策需有營運主體、目的、資料種類、第三方、保留期限、使用者權利與聯絡方式，實際 SDK／服務必須一致。台灣個資與拾得物相關法律適用仍需按真實營運模式確認；本文件不替你設定法定期限。

Apple 對可建立帳號的 App 要求可在 App 內發起刪除；Google 還要求可從 App 外使用的刪帳請求網頁，不能只讓已卸載使用者重新安裝。[Apple 帳號刪除](https://developer.apple.com/support/offering-account-deletion-in-your-app)、[Google 帳號刪除](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)。

- [ ] 刪除後原 token／Socket／QR 不能繼續用；另一使用者看到合規的匿名化歷史；儲存檔案與第三方資料按政策清理；外部網頁可提出請求，政策可公開瀏覽。

## D｜資料庫、部署與營運可靠性

<a id="d01"></a>

### D01 · P1 · 沒有完整 production migration 與舊資料升級方案

**已確認／repo。** [app.module.ts](../Foundit/backend/src/app.module.ts#L37) production 關閉 synchronize，但未找到可交付的 migration、獨立 DataSource 與執行腳本。這是正式空資料庫建置的缺口。沒有檢查外部既有 DB schema。

**修法：** 盤點實體、enum、索引、約束、時區／時間格式，建立初始及漸進 migration；既有資料需要去重、欄位補值、隱私資料清理與回填，先在去識別副本演練。production seed 預設關閉，不能用開啟 synchronize 解決部署。既有 `db:wipe-content` 是破壞性工具，不應作為共享或正式環境的一般驗收步驟。

- [ ] 全新空 DB 能按版本建立；舊版副本可升級且筆數／約束符合預期；重跑安全，失敗有可演練的回復策略；正式啟動不自動加入示範資料。

<a id="d02"></a>

### D02 · P1 · 正式 API、網域、HTTPS 與部署流程尚未驗收

**已確認／本輪未部署；外部資源未知。** [docker-compose.yml](../Foundit/backend/docker-compose.yml) 只有 PostgreSQL / Redis，含本機對外連接埠與範例設定，沒有完整 API / reverse proxy 交付流程。Flutter [app_constants.dart](../foundit_flutter/lib/core/constants/app_constants.dart) 預設 API 是區網 HTTP 位址；目前可看的 4173 預覽為本機 mock。CORS 設為 `*`。

**需交付：** 測試／正式環境分離、固定 SDK / Node / lockfile、可重複 API 建置與部署、HTTPS / WSS、DNS、秘密管理、非 root 執行與網路存取限制。正式發行明確設定 `USE_MOCK=false` 與 API / Socket / 圖片／QR origin，缺少設定就阻擋；DB / Redis 不直接暴露公網。Web／後台 CORS 限制已知 origin，但不能拿 CORS 代替授權。CI 設定 migration 次序、驗證與回滾版本。

- [ ] 乾淨環境依 runbook 可部署；外網真機使用正式候選版本完成登入、上傳、聊天與重啟後讀取；秘密不進 bundle／repo／log；DNS、憑證更新及回滾演練有紀錄。

<a id="d03"></a>

### D03 · P1 · 上傳儲存持久性、備份和刪除需實際建立

**已確認／實作，正式儲存未知。** 上傳目前寫本機磁碟；範例中的 S3 類設定不代表已接物件儲存。單純容器重建可能丟檔或多副本讀不到同一張圖。

**需交付：** 選擇持久卷或物件儲存、存取政策、生命週期、配額、圖片快取及隱私撤回；DB、圖片、設定的備份與還原需配套，不能只備份其中一項。定義可容忍遺失資料量和恢復時間，並按預算設定。

- [ ] API 重建與多實例切換後檔案仍可讀；用備份在隔離環境恢復資料庫與圖片，對照實際樣本；刪帳／隱藏後原 URL 與 CDN 快取依政策失效。

<a id="d04"></a>

### D04 · P1 · 監控、故障處理與成本控管尚未驗收

**待外部確認；repo 未具備完整交付證據。** DB / Redis healthcheck 不等於 API readiness、業務可用性或告警已完成。

**需交付：** liveness / readiness、錯誤追蹤、request ID、去識別日誌、延遲與失敗率、DB 連線與磁碟／圖片／簡訊成本告警。準備簡訊失效、資料庫滿、推播中斷、圖片失效、異常登入的處理與復原手冊；設定告警收件人和事故負責人。

- [ ] 主動製造一次受控故障，告警真的送達負責人且能按手冊恢復；量測預期首波流量下的 API 延遲／錯誤率；可停止濫用並查出受影響請求，日誌不露 token／OTP／完整私人訊息。

## R｜Android、iOS 與商店交付

<a id="r01"></a>

### R01 · P1 · Android 正式身分、簽署與產物尚未交付

**已確認／設定。** [build.gradle.kts](../foundit_flutter/android/app/build.gradle.kts#L27) 使用 `com.example.foundit`，release 仍用 debug 簽章。**若要更新既有商店 App，先核對既有 package name 與 signing 身分，不要任意改名令更新路徑中斷。** 新 App 才建立正式命名與對應 Google 服務設定。

目前 compileSdk 為 36，targetSdk 跟隨本機 Flutter 3.47.6，其 `FlutterExtension.kt` 為 36；因此未將此版誤列為 target API 過低。官方目前的新 App／更新要求已到 API 36，仍須以實際候選 AAB 和提交當日規則確認。[Google Play target API](https://developer.android.com/google/play/requirements/target-sdk)。

**需交付：** 正式 upload key／Play App Signing、秘密備份與受控 CI 簽署、版本號策略、release AAB、OAuth 指紋更新。Flutter 與外掛含 native library，需檢查 16 KB 對齊及真實執行相容性，不能僅由 targetSdk 推論已符合。[Android 16 KB 檢查指南](https://developer.android.com/guide/practices/page-sizes)。

- [ ] 候選 AAB 由正式簽署流程產生並可內部安裝；確認 applicationId、targetSdk、版本號與實際原生函式庫；安裝、升級、16 KB 環境及 Google 登入（若保留）通過。

<a id="r02"></a>

### R02 · P1 · iOS bundle、部署版本、簽署與 SDK 需補齊

**已確認／設定；10/05 未簽署原生 release 編譯通過，尚未完成簽署與真機驗收。** [project.pbxproj](../foundit_flutter/ios/Runner.xcodeproj/project.pbxproj) 原查核使用 `com.example.founditFlutter`（10/05 新 App 候選 ID 已改為 `com.david93518.foundit`），原查核 deployment target 為 12.0，尚無本輪簽署交付。2026-10-04 原生建置準備已將最低版本改為 15.5，以符合鎖定的 mobile_scanner 6.0.11 原生依賴；補上 Podfile 與 Pods xcconfig include，並清理未使用的麥克風／相簿寫入權限說明。Mac 上已完成 Ruby 與 plist 語法檢查，但尚未執行完整 iOS 編譯、簽署或上傳。Apple 自 2026-09-09 要求上傳的 iOS / iPadOS App 最低目標為 iOS 13；自 2026-04-28 要求 Xcode 26 與 iOS 26 等 SDK。最低可執行版本與建置 SDK 是兩件不同的事。[Apple 提交要求](https://developer.apple.com/news/upcoming-requirements/)。

**需交付：** 核對舊 App 身分或建立正式 bundle，設定 team／憑證／profile、以原生編譯確認外掛相容，準備 macOS release archive / TestFlight。檢查產物中每個 SDK 的 privacy manifest／required-reason API；目前未見自有 manifest 不足以斷言所有套件均缺失。[Info.plist](../foundit_flutter/ios/Runner/Info.plist) 已更新名稱與權限文案，仍需在真機驗收實際權限流程。

**Mac 建置環境進度（更新至 2026-10-05）：** Mac mini 已從 macOS 15.3.1 更新至 15.8.1（24H32），驗證重啟後 SSH 登入成功、開機服務啟用、FileVault 仍開啟。GovAI 保持停止。已安裝 Flutter 3.47.6、CocoaPods 1.17.0；Mac 上 77 項 Flutter 測試通過，analyzer 無 error／warning，另有 11 項 info。Xcode 26.3（17C529）已安裝，Apple 安裝包簽章、App codesign 與 Gatekeeper 驗證通過；iOS 26.2 SDK 與模擬器已安裝。依使用者明確授權啟用 DevToolsSecurity，但此設定本身未解決建置問題；後續以 `xcrun simctl runtime match set iphoneos26.2 23C52` 修正一般帳號的 SDK／runtime 對應後，iPhone 建置目標可用。CocoaPods 安裝完成，未簽署的 `USE_MOCK=true` release 編譯成功（exit 0），產生 56.3 MB、arm64 的 Runner.app，產物最低 iOS 15.5；此版本不能直接安裝到 iPhone。使用者選擇建立新 App，候選 Bundle ID 已改為 `com.david93518.foundit`，尚未在 Apple 註冊；未簽署 archive 亦已產生（exit 0）。後續以使用者授權的 API 金鑰成功匯出 Apple Distribution 簽署 IPA，解包後 codesign 驗證通過；TestFlight 上傳已成功（exit 0），Apple 處理已完成，內部測試版本準備測試、帳號持有人已邀請，尚未驗證真機安裝。Mac 查到 0 個有效 codesigning identity；Team ID `3X8U3KP7SH` 已設入本機與 Mac 專案；自動簽署實測 exit 65，原因為 Xcode 尚無登入帳號且無對應 provisioning profile。後續 API 認證與 IPA 分發簽署已成功，Bundle ID 已註冊；App Store Connect 記錄已建立（App ID 6819309048），1.0.0 (1) 已成功上傳 TestFlight，出口合規由使用者送出後，版本已加入「FOUND !T 內部測試」，狀態為準備測試，帳號持有人顯示已邀請。iPhone 實際安裝與功能驗收仍待使用者完成。建置亦提示鎖定的 QR 掃描／Google ML Kit 套件缺少 arm64 模擬器支援，真機相機驗收不能省略。[10/04 前置紀錄](evidence/2026-10-04/mac-ios-preflight.json)、[10/05 建置紀錄](evidence/2026-10-05/mac-xcode-status.json)、[Apple Xcode 系統需求](https://developer.apple.com/xcode/system-requirements)。

若首版提供 Google / LINE 等第三方主帳號登入，另核對 Apple 4.8 的等同登入選項與例外；只用自家手機帳號時不能一概宣稱必須加 Apple 登入。[Apple 登入規範](https://developer.apple.com/app-store/review/guidelines/#login-services)。

- [ ] 符合當日 SDK 要求的正式 archive 可上傳 TestFlight；支持的最低／新版本裝置可啟動；相機、照片、定位與推播權限、關聯網域及隱私 manifest 隨實際功能驗收。

<a id="r03"></a>

### R03 · P1 · 響應式已有自動測試，仍需真機與真實任務驗收

**部分完成。** 前輪涵蓋 320×568、390×844、844×390、768×1024、1440×900，100% / 130% / 200% 字級，鍵盤、安全區與長文字。這些是本機 Flutter 測試的證據，不能當成各平台的實測報告。

**需補：** Android / iPhone、平板若宣稱支援、低階裝置的真實候選版；系統字體／顯示縮放、動態島／手勢區、橫向、鍵盤、螢幕閱讀器、焦點順序、減少動態、照片選取與權限拒絕、返回／中斷／重開、弱網／離線／token 過期。逐一點擊所有入口，沒有假按鈕或永遠成功的提示；上傳圖方向／HEIC 等支援範圍須明確。量測啟動、長列表捲動、圖片記憶體與服務延遲。

- [ ] [驗收表](RELEASE_ACCEPTANCE.md) 的功能與裝置矩陣有版本、平台和證據；200% 文字下關鍵操作仍可達、無裁切；真實首次使用者能獨立完成找物與拾獲聯絡，失敗能恢復。

<a id="r04"></a>

### R04 · P1 · 商店資料、品牌授權與送審資格仍待整理

**部分完成／待外部確認。** 已有自製 FOUND !T 字標、圖示和多平台輸出，無須從零再做 logo；但尚未完成名稱／商標檢索、所有照片來源授權核對、App Store / Play 截圖與正式商店表單。Noto Sans TC 的 OFL 檔已隨素材保留；不能因此推論全部資產授權已確認。

**需交付：** 實際候選版截圖、名稱／簡介、客服與政策 URL、年齡分級、App Privacy / Data Safety 與 SDK 資料流對照、可用審查帳號與操作說明。不要宣稱圖片 AI 配對、託管賞金或即時推播已完成。刪帳依 A03，UGC 依 A02。

若 Google Play 是 2023-11-13 之後建立的個人帳號，需確認至少 12 位測試者連續加入封閉測試 14 天等 production access 要求；帳號類型和建立日期尚未知，不能直接斷言本案一定適用。[Google 個人帳號測試要求](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)。

- [ ] 商店表單與實際收集／分享資料一致；審查人員可完成核心流程；品牌、照片、字型與其他資產有來源／授權紀錄；帳號資格與必要封測已由 Console 確認。

## P｜首版範圍與營運決策

<a id="p01"></a>

### P01 · P1／P2 · 決定先交付哪些功能，撤下未完成的承諾

**待決策。** 建議首版優先完成：探索、刊登、可用的位置搜尋、安全聯絡、結案、檢舉／封鎖／管理、刪帳和基本通知。QR 是否首版推出需連同 F08 決定。AI、積分／徽章／排行榜、賞金付款可以作 P2，但保留的端點仍須遵守安全規則。

目前 AI 是規則比對，不是已驗證的圖片辨識；賞金欄位不等於收付款／託管服務。積分若保留，需防重放、併發重複加分及刷分，排行榜先修 S05。README 下方舊版完成度敘述不得當成新功能驗收證據。

- [ ] 每項功能標明「首版提供／延後」；未提供的按鈕、說明、商店文案與後端入口同步處理；沒有不存在的 AI／付款／政府整合宣稱。

<a id="p02"></a>

### P02 · P1 · 找回物品的營運規則與服務責任要能落地

**待決策／不是已證實的程式漏洞。** 需定義：如何確認物主、哪些辨識細節不公開、拾獲保管與交警資訊、可否代領、交還與爭議處理、詐騙或騷擾申訴、客服回應時間、誰每天處理檢舉。未接政府／運輸業資料源就不能宣稱已整合，未有真實內容就不能以虛構刊登製造營運量。

地圖目前使用 OpenStreetMap 公共 tiles，已有畫面署名，但 [map_screen.dart](../foundit_flutter/lib/presentation/screens/map/map_screen.dart#L178) 的識別仍是範例 package。需確認署名連結、識別、快取與流量策略；公共 tile 服務沒有 SLA，擴量或離線用途須另選合適方案。[OSM tile 使用政策](https://operations.osmfoundation.org/policies/tiles/)。

- [ ] 寫出認領、交還、爭議、檢舉、個資請求與事故的負責人／處理流程；確認台灣適用規範與公開位置精度；地圖、簡訊、儲存及雲端預算與超量處理有方案。

## 你需要準備或決定的外部資料

| 項目 | 要確認的內容 | 目前狀態 |
| --- | --- | --- |
| 商店身分 | 更新舊 App 或新上架、原 package / bundle、簽署持有人、帳號類型與資格 | 待確認 |
| 網域／部署 | API、公開網站、QR 的永久網址；雲端帳號、區域、環境與預算 | 待確認 |
| SMS／推播 | 供應商、測試門號、發信身分、FCM / APNs 憑證與權限 | 尚未完整接通驗收 |
| 營運主體 | 客服聯絡、政策主體、資料請求負責人、管理員與值班 | 待確認 |
| 首版範圍 | QR、通知、AI、積分、賞金、支援平台與最低版本 | 待決策 |
| 資料政策 | 公開地點精度、聯絡方式、照片／訊息保存、刪帳與備份保留 | 待決策 |
| 上線證據 | 測試環境、原生裝置、真實帳號、封測、還原／回滾結果 | 待補齊 |

金鑰、憑證私密內容、真實驗證碼及使用者資料不要放入本文件或 Git；只記錄受控儲存位置與負責人。

## 完成與放行標準

一項工作只有在「修復 commit＋對應驗收結果＋版本／環境＋必要證據」齊備時才標為完成。截圖能證明畫面，不能證明資料已保存或權限正確；單元測試通過不能取代真實服務驗收。

公開 API 前排除 P0；正式送審前完成首版所有 P1，或有明確且安全的功能縮減。依 [RELEASE_ACCEPTANCE.md](RELEASE_ACCEPTANCE.md) 留下執行紀錄，未測填未測、失敗填失敗。商店規範以文中查核日期為基準，送審當天再核對官方來源。


### 外部 TestFlight 進度（2026-10-05）

1.0.0 (1) 已提交 Apple Beta App Review，頁面確認為「等待審查」。「FOUND !T 外部測試」已有 2 位指定測試人員與 1 個建置版本，啟用核准後自動通知。此為 USE_MOCK=true 測試版，描述已揭露模擬資料及未串接正式後端的限制；並不代表正式 App Store 送審或公開營運完成。審查核准與外部安裝尚未確認。

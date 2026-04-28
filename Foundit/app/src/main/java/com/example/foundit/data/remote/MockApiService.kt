package com.example.foundit.data.remote

import com.example.foundit.data.model.AiMatchResult
import com.example.foundit.data.model.Chat
import com.example.foundit.data.model.ChatParticipant
import com.example.foundit.data.model.CreateChatRequest
import com.example.foundit.data.model.GenerateQrRequest
import com.example.foundit.data.model.Item
import com.example.foundit.data.model.ItemRequest
import com.example.foundit.data.model.ItemStatus
import com.example.foundit.data.model.ItemType
import com.example.foundit.data.model.Message
import com.example.foundit.data.model.MessageType
import com.example.foundit.data.model.Notification
import com.example.foundit.data.model.NotificationType
import com.example.foundit.data.model.QrItem
import com.example.foundit.data.model.SendMessageRequest
import com.example.foundit.data.model.User
import android.util.Base64
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.ResponseBody.Companion.toResponseBody
import okio.Buffer
import retrofit2.Response
import java.util.UUID

/**
 * 後端尚未部署時使用的假資料服務。
 * 當 Constants.USE_MOCK = true 時由 FounditApplication 注入。
 * 正式後端上線後，將 USE_MOCK 改為 false 即可切換至真實 API。
 */
class MockApiService : ApiService {

    // ── 假使用者 ──────────────────────────────────────────────

    private val mockUser = User(
        id = "user-001",
        phone = "0912345678",
        name = "測試使用者",
        avatarUrl = "https://i.pravatar.cc/150?u=user001",
        points = 350,
        isVerified = true,
        createdAt = System.currentTimeMillis() - 86400000L * 30
    )

    private val mockUsers = listOf(
        mockUser,
        User(id = "user-002", phone = "0922111222", name = "熱心市民小明",
            avatarUrl = "https://i.pravatar.cc/150?u=user002", points = 200, isVerified = true,
            createdAt = System.currentTimeMillis() - 86400000L * 60),
        User(id = "user-003", phone = "0933222333", name = "阿花",
            avatarUrl = "https://i.pravatar.cc/150?u=user003", points = 80, isVerified = true,
            createdAt = System.currentTimeMillis() - 86400000L * 20),
        User(id = "user-004", phone = "0955444555", name = "大安好市民",
            avatarUrl = "https://i.pravatar.cc/150?u=user004", points = 520, isVerified = true,
            createdAt = System.currentTimeMillis() - 86400000L * 90),
        User(id = "user-005", phone = "0966555666", name = "信義路王先生",
            avatarUrl = "https://i.pravatar.cc/150?u=user005", points = 130, isVerified = false,
            createdAt = System.currentTimeMillis() - 86400000L * 10)
    )

    // ── 假物品清單 ────────────────────────────────────────────

    private val now = System.currentTimeMillis()

    private val mockItems = mutableListOf(
        // ===== 遺失物 =====
        Item(
            id = "item-001",
            type = ItemType.LOST,
            userId = "user-001",
            userName = "測試使用者",
            title = "黑色真皮長夾（內有身分證）",
            category = "錢包/皮夾",
            description = "在捷運忠孝敦化站 4 號出口附近遺失，黑色牛皮長夾，內有身分證、健保卡、悠遊卡及現金約 1,200 元。皮夾背面有英文名字刻印「David」，若有找到懇請聯繫，提供賞金 500 元！",
            color = "黑色",
            images = listOf("https://images.unsplash.com/photo-1627123424-af7-4a07-a9df-fa71b9a898a8?w=400&q=80&auto=format",
                "https://picsum.photos/seed/wallet_black/400/300"),
            latitude = 25.0415,
            longitude = 121.5514,
            locationName = "台北市大安區忠孝東路四段",
            lostAt = now - 86400000L * 2,
            reward = 500,
            hasReward = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L * 2
        ),
        Item(
            id = "item-003",
            type = ItemType.LOST,
            userId = "user-001",
            userName = "測試使用者",
            title = "iPhone 15 Pro（深空黑）手機",
            category = "手機/平板",
            description = "忘在台北車站 K 區星巴克二樓座位，鈦金屬框深空黑色，裝有透明手機殼，螢幕右上角有一小道細痕，鎖屏桌布是柴犬圖案。請盡快聯繫，內有重要資料！賞金 1,000 元。",
            color = "黑色",
            images = listOf("https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400&q=80&auto=format",
                "https://picsum.photos/seed/iphone15_black/400/300"),
            latitude = 25.0478,
            longitude = 121.5170,
            locationName = "台北市中正區台北車站 K 區星巴克",
            lostAt = now - 3600000L * 5,
            reward = 1000,
            hasReward = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 3600000L * 5
        ),
        Item(
            id = "item-005",
            type = ItemType.LOST,
            userId = "user-003",
            userName = "阿花",
            title = "Nike 黑色後背包（含 MacBook Air M3）",
            category = "包包/背包",
            description = "信義誠品六樓附近弄丟，Nike 黑色雙肩後背包，左側口袋有一個小破洞，包內有 MacBook Air M3（銀色）、充電磚、個人文件、筆記本等，非常重要！提供賞金 3,000 元，請務必聯繫。",
            color = "黑色",
            images = listOf("https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&q=80&auto=format",
                "https://picsum.photos/seed/nike_backpack/400/300"),
            latitude = 25.0395,
            longitude = 121.5677,
            locationName = "台北市信義區信義路五段（信義誠品附近）",
            lostAt = now - 3600000L * 8,
            reward = 3000,
            hasReward = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 3600000L * 8
        ),
        Item(
            id = "item-007",
            type = ItemType.LOST,
            userId = "user-004",
            userName = "大安好市民",
            title = "AirPods Pro 2 充電盒（含耳機）",
            category = "電子產品",
            description = "忘在大安區 Cama Café，白色 AirPods Pro 2 充電盒，充電盒後蓋有一小貼紙（彩色格子圖案），兩隻耳機都在盒子裡。如果有人找到麻煩聯繫，謝謝！",
            color = "白色",
            images = listOf("https://images.unsplash.com/photo-1603351154351-5e2d0600bb77?w=400&q=80&auto=format",
                "https://picsum.photos/seed/airpods_pro/400/300"),
            latitude = 25.0368,
            longitude = 121.5439,
            locationName = "台北市大安區復興南路一段",
            lostAt = now - 3600000L * 3,
            reward = 300,
            hasReward = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 3600000L * 3
        ),
        Item(
            id = "item-009",
            type = ItemType.LOST,
            userId = "user-002",
            userName = "熱心市民小明",
            title = "橘色虎斑貓（走失）",
            category = "寵物",
            description = "我家的橘色虎斑貓「橘子」在大安森林公園附近走失，已結紮、有晶片，脖子戴藍色鈴鐺項圈，非常親人。找到的話請立刻聯繫，提供賞金 2,000 元，橘子快回家！",
            color = "橘色",
            images = listOf("https://images.unsplash.com/photo-1529778873920-4da4926a72c2?w=400&q=80&auto=format",
                "https://picsum.photos/seed/orange_cat/400/300"),
            latitude = 25.0330,
            longitude = 121.5342,
            locationName = "台北市大安區大安森林公園周邊",
            lostAt = now - 86400000L,
            reward = 2000,
            hasReward = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L
        ),
        Item(
            id = "item-011",
            type = ItemType.LOST,
            userId = "user-005",
            userName = "信義路王先生",
            title = "台灣護照（附機票）",
            category = "文件/證件",
            description = "緊急！在松山機場第一航廈報到櫃台附近遺失台灣護照，護照封面有輕微磨損，內夾有曼谷來回機票。明天早上有班機，非常緊急，找到的話拜託盡快聯繫！",
            color = "藍色",
            images = listOf("https://images.unsplash.com/photo-1580600301354-3348f8c3c1fe?w=400&q=80&auto=format",
                "https://picsum.photos/seed/passport_tw/400/300"),
            latitude = 25.0631,
            longitude = 121.5512,
            locationName = "台北市松山區松山機場第一航廈",
            lostAt = now - 3600000L * 2,
            reward = 1500,
            hasReward = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 3600000L * 2
        ),
        Item(
            id = "item-013",
            type = ItemType.LOST,
            userId = "user-003",
            userName = "阿花",
            title = "Apple Watch Series 9（午夜色）",
            category = "電子產品",
            description = "在健身房淋浴後遺忘，午夜色 Apple Watch Series 9，45mm，搭配黑色運動型錶帶，錶背有刻字「Hua 2024」。可能放在更衣室置物櫃旁的架子上。",
            color = "黑色",
            images = listOf("https://images.unsplash.com/photo-1551816230-ef5deaed4a26?w=400&q=80&auto=format",
                "https://picsum.photos/seed/apple_watch/400/300"),
            latitude = 25.0480,
            longitude = 121.5441,
            locationName = "台北市大安區復興南路健身房",
            lostAt = now - 3600000L * 6,
            reward = 500,
            hasReward = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 3600000L * 6
        ),
        Item(
            id = "item-015",
            type = ItemType.LOST,
            userId = "user-001",
            userName = "測試使用者",
            title = "藍色折疊雨傘（傘柄有小缺口）",
            category = "其他",
            description = "在捷運大安站候車時忘在座椅上，深藍色三折傘，傘柄末端有一小缺口，傘面印有小白點圖案。如有撿到麻煩告知，謝謝！",
            color = "藍色",
            images = listOf("https://images.unsplash.com/photo-1548401840-91c9df9c4f02?w=400&q=80&auto=format",
                "https://picsum.photos/seed/blue_umbrella/400/300"),
            latitude = 25.0261,
            longitude = 121.5318,
            locationName = "台北市大安區捷運大安站",
            lostAt = now - 3600000L * 12,
            reward = 0,
            hasReward = false,
            status = ItemStatus.ACTIVE,
            createdAt = now - 3600000L * 12
        ),
        // ===== 撿到物 =====
        Item(
            id = "item-002",
            type = ItemType.FOUND,
            userId = "user-002",
            userName = "熱心市民小明",
            title = "撿到一串鑰匙（附小熊吊飾）",
            category = "鑰匙",
            description = "在大安森林公園南側入口長椅旁撿到，共三支鑰匙（一支像汽車鑰匙），附有棕色小熊玩偶吊飾，鑰匙圈上有一張小名片（已模糊）。目前由我保管，請聯繫認領。",
            color = "銀色",
            images = listOf("https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&q=80&auto=format",
                "https://picsum.photos/seed/keys_bear/400/300"),
            latitude = 25.0330,
            longitude = 121.5342,
            locationName = "台北市大安區大安森林公園南側入口",
            lostAt = now - 86400000L,
            handedToPolice = false,
            storageLocation = "我自己保管，請私訊聯絡",
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L
        ),
        Item(
            id = "item-004",
            type = ItemType.FOUND,
            userId = "user-004",
            userName = "大安好市民",
            title = "發現金屬框眼鏡（近視約 400 度）",
            category = "眼鏡",
            description = "在西門町蜂大咖啡門口附近發現，金色細金屬框眼鏡，外觀幾乎全新，試戴估計近視約 400 度左右。已交由旁邊 OK 便利商店保管，請帶身分證認領。",
            color = "金色",
            images = listOf("https://images.unsplash.com/photo-1591076482161-42ce6da69f67?w=400&q=80&auto=format",
                "https://picsum.photos/seed/glasses_gold/400/300"),
            latitude = 25.0424,
            longitude = 121.5080,
            locationName = "台北市萬華區西門町蜂大咖啡附近",
            lostAt = now - 86400000L * 3,
            handedToPolice = false,
            storageLocation = "西門町 OK 便利商店（峨眉街）",
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L * 3
        ),
        Item(
            id = "item-006",
            type = ItemType.FOUND,
            userId = "user-005",
            userName = "信義路王先生",
            title = "撿到咖啡色女用皮包（含悠遊卡）",
            category = "包包/背包",
            description = "在中山北路二段捷運出口撿到，咖啡色小型女用皮包，內有悠遊卡、一張信用卡（已收好）、少許零錢及口紅一支。已交由中山分局警察局保管，請攜帶證件認領。",
            color = "棕色",
            images = listOf("https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&q=80&auto=format",
                "https://picsum.photos/seed/brown_purse/400/300"),
            latitude = 25.0524,
            longitude = 121.5224,
            locationName = "台北市中山區中山北路二段捷運出口",
            lostAt = now - 86400000L * 4,
            handedToPolice = true,
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L * 4
        ),
        Item(
            id = "item-008",
            type = ItemType.FOUND,
            userId = "user-003",
            userName = "阿花",
            title = "捷運座位撿到白色藍牙耳機",
            category = "電子產品",
            description = "在捷運板南線往南港方向、忠孝復興站上車後在座位下面發現，白色頸掛式藍牙耳機，品牌看起來像 Sony，有小的刮痕。目前由我保管，請確認後聯繫！",
            color = "白色",
            images = listOf("https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&q=80&auto=format",
                "https://picsum.photos/seed/sony_headphones/400/300"),
            latitude = 25.0416,
            longitude = 121.5443,
            locationName = "台北捷運板南線 忠孝復興站附近",
            lostAt = now - 3600000L * 4,
            handedToPolice = false,
            storageLocation = "由本人暫時保管",
            status = ItemStatus.ACTIVE,
            createdAt = now - 3600000L * 4
        ),
        Item(
            id = "item-010",
            type = ItemType.FOUND,
            userId = "user-002",
            userName = "熱心市民小明",
            title = "師大夜市地上撿到學生證",
            category = "文件/證件",
            description = "在師大夜市美食街段地面撿到，是台大外文系學生證，照片是一位女生，有效期限到 2025 年底。已拍照存證，目前由我保管，請本人盡快聯繫認領。",
            color = "其他",
            images = listOf("https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=400&q=80&auto=format",
                "https://picsum.photos/seed/student_id/400/300"),
            latitude = 25.0258,
            longitude = 121.5295,
            locationName = "台北市大安區師大路師大夜市",
            lostAt = now - 86400000L * 2,
            handedToPolice = false,
            storageLocation = "由本人暫時保管",
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L * 2
        ),
        Item(
            id = "item-012",
            type = ItemType.FOUND,
            userId = "user-004",
            userName = "大安好市民",
            title = "象山步道發現白色遮陽帽",
            category = "服飾",
            description = "在象山步道第三涼亭旁的長椅上發現，白色寬沿遮陽帽，帽內縫有粉紅色緞帶，帽緣有些微泥土痕跡。目前放在象山入口管理處，請盡快認領。",
            color = "白色",
            images = listOf("https://images.unsplash.com/photo-1521369909029-2afed882baee?w=400&q=80&auto=format",
                "https://picsum.photos/seed/white_hat/400/300"),
            latitude = 25.0271,
            longitude = 121.5776,
            locationName = "台北市信義區象山步道第三涼亭",
            lostAt = now - 86400000L * 5,
            handedToPolice = false,
            storageLocation = "象山登山口管理服務處",
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L * 5
        ),
        Item(
            id = "item-014",
            type = ItemType.FOUND,
            userId = "user-005",
            userName = "信義路王先生",
            title = "陽明山停車場撿到登山背包",
            category = "包包/背包",
            description = "在陽明山遊客服務中心旁停車場發現，深綠色 60L 登山大背包，外掛有登山安全帽和睡袋（黃色），包內有衣物及地圖，感覺是外縣市來爬山的遊客落下的。已交管理處。",
            color = "綠色",
            images = listOf("https://images.unsplash.com/photo-1588117260148-b47818741c74?w=400&q=80&auto=format",
                "https://picsum.photos/seed/hiking_pack/400/300"),
            latitude = 25.1645,
            longitude = 121.5559,
            locationName = "台北市士林區陽明山遊客服務中心停車場",
            lostAt = now - 86400000L * 6,
            handedToPolice = false,
            storageLocation = "陽明山遊客服務中心",
            status = ItemStatus.ACTIVE,
            createdAt = now - 86400000L * 6
        )
    )

    // ── 假聊天資料 ────────────────────────────────────────────

    private val mockChats = mutableListOf(
        Chat(
            id = "chat-001",
            itemId = "item-002",
            itemTitle = "撿到一串鑰匙（附小熊吊飾）",
            itemImage = "https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=200&q=80&auto=format",
            participants = listOf(
                ChatParticipant(id = "user-001", name = "測試使用者"),
                ChatParticipant(id = "user-002", name = "熱心市民小明")
            ),
            otherUserName = "熱心市民小明",
            otherUserAvatar = "https://i.pravatar.cc/150?u=user002",
            lastMessage = "好的，我明天下午兩點在大安森林公園正門口等您！",
            lastMessageAt = now - 1800000L,
            unreadCount = 1
        ),
        Chat(
            id = "chat-002",
            itemId = "item-008",
            itemTitle = "捷運座位撿到白色藍牙耳機",
            itemImage = "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=200&q=80&auto=format",
            participants = listOf(
                ChatParticipant(id = "user-001", name = "測試使用者"),
                ChatParticipant(id = "user-003", name = "阿花")
            ),
            otherUserName = "阿花",
            otherUserAvatar = "https://i.pravatar.cc/150?u=user003",
            lastMessage = "可以請您描述一下耳機上有什麼特徵嗎？",
            lastMessageAt = now - 86400000L,
            unreadCount = 0
        ),
        Chat(
            id = "chat-003",
            itemId = "item-009",
            itemTitle = "橘色虎斑貓（走失）",
            itemImage = "https://images.unsplash.com/photo-1529778873920-4da4926a72c2?w=200&q=80&auto=format",
            participants = listOf(
                ChatParticipant(id = "user-001", name = "測試使用者"),
                ChatParticipant(id = "user-002", name = "熱心市民小明")
            ),
            otherUserName = "熱心市民小明",
            otherUserAvatar = "https://i.pravatar.cc/150?u=user002",
            lastMessage = "我剛剛在和平東路看到一隻很像的橘貓！",
            lastMessageAt = now - 3600000L * 2,
            unreadCount = 2
        ),
        Chat(
            id = "chat-004",
            itemId = "item-011",
            itemTitle = "台灣護照（附機票）",
            itemImage = "https://images.unsplash.com/photo-1580600301354-3348f8c3c1fe?w=200&q=80&auto=format",
            participants = listOf(
                ChatParticipant(id = "user-001", name = "測試使用者"),
                ChatParticipant(id = "user-004", name = "大安好市民")
            ),
            otherUserName = "大安好市民",
            otherUserAvatar = "https://i.pravatar.cc/150?u=user004",
            lastMessage = "護照已送到航警局，您可以直接去那邊領取！",
            lastMessageAt = now - 3600000L * 5,
            unreadCount = 0
        )
    )

    private val mockMessages = mutableListOf(
        // chat-001: 關於鑰匙
        Message(id = "msg-001", chatId = "chat-001", senderId = "user-001", senderName = "測試使用者",
            content = "您好！我是前幾天在大安森林公園遺失鑰匙的那位，請問您撿到的鑰匙有小熊吊飾嗎？",
            type = MessageType.TEXT, createdAt = now - 3600000L * 5),
        Message(id = "msg-002", chatId = "chat-001", senderId = "user-002", senderName = "熱心市民小明",
            content = "您好，是的！我撿到的那串鑰匙有一個棕色的小熊玩偶吊飾，應該就是您的！",
            type = MessageType.TEXT, createdAt = now - 3600000L * 4),
        Message(id = "msg-003", chatId = "chat-001", senderId = "user-001", senderName = "測試使用者",
            content = "太好了！請問方便描述一下共有幾支鑰匙嗎？其中一支是不是比較大的那種？",
            type = MessageType.TEXT, createdAt = now - 3600000L * 3),
        Message(id = "msg-004", chatId = "chat-001", senderId = "user-002", senderName = "熱心市民小明",
            content = "共三支，一支大的看起來像汽車鑰匙，兩支比較小。是這樣嗎？",
            type = MessageType.TEXT, createdAt = now - 3600000L * 2),
        Message(id = "msg-005", chatId = "chat-001", senderId = "user-001", senderName = "測試使用者",
            content = "完全正確！真的太感謝您了！請問方便約時間見面歸還嗎？",
            type = MessageType.TEXT, createdAt = now - 3600000L),
        Message(id = "msg-006", chatId = "chat-001", senderId = "user-002", senderName = "熱心市民小明",
            content = "好的，我明天下午兩點在大安森林公園正門口等您！",
            type = MessageType.TEXT, createdAt = now - 1800000L),
        // chat-002: 關於耳機
        Message(id = "msg-007", chatId = "chat-002", senderId = "user-001", senderName = "測試使用者",
            content = "您好，請問您在捷運撿到的白色耳機，是頸掛式的嗎？",
            type = MessageType.TEXT, createdAt = now - 86400000L * 2),
        Message(id = "msg-008", chatId = "chat-002", senderId = "user-003", senderName = "阿花",
            content = "是的，白色頸掛式藍牙耳機，看起來像 Sony 的款式。",
            type = MessageType.TEXT, createdAt = now - 86400000L + 3600000L),
        Message(id = "msg-009", chatId = "chat-002", senderId = "user-003", senderName = "阿花",
            content = "可以請您描述一下耳機上有什麼特徵嗎？",
            type = MessageType.TEXT, createdAt = now - 86400000L),
        // chat-003: 關於橘貓
        Message(id = "msg-010", chatId = "chat-003", senderId = "user-001", senderName = "測試使用者",
            content = "您好，請問您有沒有在大安森林公園附近看到一隻橘色虎斑貓？脖子有藍色鈴鐺項圈。",
            type = MessageType.TEXT, createdAt = now - 3600000L * 6),
        Message(id = "msg-011", chatId = "chat-003", senderId = "user-002", senderName = "熱心市民小明",
            content = "我剛剛在和平東路看到一隻很像的橘貓！牠正在一家便利商店門口徘徊。",
            type = MessageType.TEXT, createdAt = now - 3600000L * 2),
        Message(id = "msg-012", chatId = "chat-003", senderId = "user-002", senderName = "熱心市民小明",
            content = "我拍了照片，等我傳給您確認一下，您稍等！",
            type = MessageType.TEXT, createdAt = now - 3600000L * 2 + 60000L),
        // chat-004: 關於護照
        Message(id = "msg-013", chatId = "chat-004", senderId = "user-001", senderName = "測試使用者",
            content = "您好！我在松山機場遺失護照，請問您有看到嗎？",
            type = MessageType.TEXT, createdAt = now - 3600000L * 8),
        Message(id = "msg-014", chatId = "chat-004", senderId = "user-004", senderName = "大安好市民",
            content = "有的，我在報到櫃台附近撿到一本護照，已經交給航空警察局了！",
            type = MessageType.TEXT, createdAt = now - 3600000L * 6),
        Message(id = "msg-015", chatId = "chat-004", senderId = "user-004", senderName = "大安好市民",
            content = "護照已送到航警局，您可以直接去那邊領取！記得帶其他身分證明文件。",
            type = MessageType.TEXT, createdAt = now - 3600000L * 5)
    )

    // ── 假通知資料 ────────────────────────────────────────────

    private val mockNotifications = mutableListOf(
        Notification(
            id = "notif-001",
            userId = "user-001",
            type = NotificationType.AI_MATCH,
            title = "AI 配對成功！",
            content = "您遺失的「黑色真皮長夾」與新登記的撿到物有 91% 相似度，快去確認吧！",
            itemId = "item-002",
            isRead = false,
            createdAt = now - 3600000L * 3
        ),
        Notification(
            id = "notif-002",
            userId = "user-001",
            type = NotificationType.NEW_MESSAGE,
            title = "熱心市民小明 傳來新訊息",
            content = "好的，我明天下午兩點在大安森林公園正門口等您！",
            chatId = "chat-001",
            isRead = false,
            createdAt = now - 1800000L
        ),
        Notification(
            id = "notif-003",
            userId = "user-001",
            type = NotificationType.NEW_MESSAGE,
            title = "熱心市民小明 傳來新訊息",
            content = "我剛剛在和平東路看到一隻很像的橘貓！",
            chatId = "chat-003",
            isRead = false,
            createdAt = now - 3600000L * 2
        ),
        Notification(
            id = "notif-004",
            userId = "user-001",
            type = NotificationType.NEARBY_ITEM,
            title = "附近有新撿到物！",
            content = "距您 1.5 公里內有人登記撿到「白色藍牙耳機」，快去確認是否是您的！",
            itemId = "item-008",
            isRead = false,
            createdAt = now - 3600000L * 4
        ),
        Notification(
            id = "notif-005",
            userId = "user-001",
            type = NotificationType.AI_MATCH,
            title = "AI 找到可能的配對！",
            content = "您遺失的「AirPods Pro 充電盒」與近期登記的撿到物有 78% 相似度。",
            itemId = "item-008",
            isRead = true,
            createdAt = now - 86400000L
        ),
        Notification(
            id = "notif-006",
            userId = "user-001",
            type = NotificationType.SYSTEM,
            title = "歡迎使用找得到！",
            content = "感謝您加入找得到平台。登記一個撿到物品，立即獲得 50 積分！",
            isRead = true,
            createdAt = now - 86400000L * 7
        )
    )

    // ── 假 QR 物品 ────────────────────────────────────────────

    private val mockQrItems = mutableListOf(
        QrItem(
            id = "qr-001",
            userId = "user-001",
            name = "我的後背包",
            description = "黑色 Nike 後背包，失物請聯繫謝謝",
            qrCode = "foundit://qr/abc123xyz",
            qrImageUrl = "",
            createdAt = now - 86400000L * 5
        )
    )

    // ─────────────────────────────────────────────────────────
    // ApiService 介面實作
    // ─────────────────────────────────────────────────────────

    override suspend fun sendOtp(request: SendOtpRequest): Response<BaseResponse> =
        Response.success(BaseResponse(success = true, message = "驗證碼已發送（Mock 模式：請輸入 123456）"))

    override suspend fun verifyOtp(request: VerifyOtpRequest): Response<AuthResponse> {
        return if (request.otp == "123456") {
            Response.success(
                AuthResponse(
                    success = true,
                    token = "mock-jwt-token-dev",
                    user = mockUser.copy(phone = request.phone),
                    message = "登入成功"
                )
            )
        } else {
            Response.success(AuthResponse(success = false, message = "驗證碼錯誤（Mock 模式：請輸入 123456）"))
        }
    }

    override suspend fun oauthLogin(provider: String, request: OAuthRequest): Response<AuthResponse> =
        Response.success(
            AuthResponse(
                success = true,
                token = "mock-jwt-token-dev",
                user = mockUser,
                message = "${provider} 登入成功"
            )
        )

    override suspend fun getMe(): Response<DataResponse<User>> =
        Response.success(DataResponse(success = true, data = mockUser))

    override suspend fun updateProfile(request: UpdateProfileRequest): Response<DataResponse<User>> =
        Response.success(
            DataResponse(
                success = true,
                data = mockUser.copy(name = request.name, avatarUrl = request.avatarUrl)
            )
        )

    override suspend fun getPoints(): Response<PointsResponse> =
        Response.success(
            PointsResponse(
                points = mockUser.points,
                history = listOf(
                    PointEvent("found_item", 50, "登記撿到鑰匙", now - 86400000L),
                    PointEvent("daily_login", 5, "每日登入獎勵", now - 86400000L * 2),
                    PointEvent("match_success", 100, "成功協助配對", now - 86400000L * 5)
                )
            )
        )

    override suspend fun getItems(filters: Map<String, String>): Response<PagedResponse<Item>> {
        var result = mockItems.toList()
        filters["type"]?.let { type ->
            result = result.filter { it.type.name.lowercase() == type.lowercase() }
        }
        filters["category"]?.let { cat ->
            result = result.filter { it.category == cat }
        }
        filters["keyword"]?.let { kw ->
            if (kw.isNotBlank()) result = result.filter {
                it.title.contains(kw, ignoreCase = true) || it.description.contains(kw, ignoreCase = true)
            }
        }
        filters["has_reward"]?.let { hr ->
            if (hr == "true") result = result.filter { it.hasReward }
        }
        return Response.success(
            PagedResponse(success = true, data = result, total = result.size, hasMore = false)
        )
    }

    override suspend fun createItem(item: ItemRequest): Response<DataResponse<Item>> {
        val newItem = Item(
            id = "item-${UUID.randomUUID()}",
            type = when (item.type.uppercase()) {
                "LOST" -> ItemType.LOST
                else -> ItemType.FOUND
            },
            userId = mockUser.id,
            userName = mockUser.name,
            title = item.title,
            category = item.category,
            description = item.description,
            color = item.color,
            images = item.images,
            latitude = item.latitude,
            longitude = item.longitude,
            locationName = item.locationName,
            lostAt = item.lostAt,
            reward = item.reward,
            hasReward = item.hasReward,
            storageLocation = item.storageLocation,
            handedToPolice = item.handedToPolice,
            status = ItemStatus.ACTIVE,
            createdAt = System.currentTimeMillis()
        )
        mockItems.add(0, newItem)
        return Response.success(DataResponse(success = true, data = newItem))
    }

    override suspend fun getItem(id: String): Response<DataResponse<Item>> {
        val item = mockItems.find { it.id == id }
        return if (item != null) {
            Response.success(DataResponse(success = true, data = item))
        } else {
            Response.error(404, "Not Found".toResponseBody("text/plain".toMediaType()))
        }
    }

    override suspend fun updateItem(id: String, item: ItemRequest): Response<DataResponse<Item>> {
        val index = mockItems.indexOfFirst { it.id == id }
        return if (index >= 0) {
            val updated = mockItems[index].copy(
                type = when (item.type.uppercase()) {
                    "LOST" -> ItemType.LOST
                    else -> ItemType.FOUND
                },
                title = item.title,
                category = item.category,
                description = item.description,
                color = item.color,
                images = item.images,
                latitude = item.latitude,
                longitude = item.longitude,
                locationName = item.locationName,
                lostAt = item.lostAt,
                reward = item.reward,
                hasReward = item.hasReward,
                storageLocation = item.storageLocation,
                handedToPolice = item.handedToPolice,
                updatedAt = System.currentTimeMillis()
            )
            mockItems[index] = updated
            Response.success(DataResponse(success = true, data = updated))
        } else {
            Response.error(404, "Not Found".toResponseBody("text/plain".toMediaType()))
        }
    }

    override suspend fun deleteItem(id: String): Response<BaseResponse> {
        mockItems.removeAll { it.id == id }
        return Response.success(BaseResponse(success = true, message = "已刪除"))
    }

    override suspend fun resolveItem(id: String): Response<BaseResponse> {
        val index = mockItems.indexOfFirst { it.id == id }
        if (index >= 0) mockItems[index] = mockItems[index].copy(status = ItemStatus.RESOLVED)
        return Response.success(BaseResponse(success = true, message = "已標記為找到"))
    }

    override suspend fun uploadImage(file: MultipartBody.Part): Response<UploadImageResponse> {
        val sink = Buffer()
        file.body.writeTo(sink)
        val bytes = sink.readByteArray()
        val mime = file.body.contentType()?.toString() ?: "image/jpeg"
        val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
        val url = "data:$mime;base64,$b64"
        return Response.success(UploadImageResponse(success = true, url = url))
    }

    override suspend fun aiMatch(request: AiMatchRequest): Response<DataResponse<List<AiMatchResult>>> {
        val results = mockItems
            .filter { it.id != request.itemId }
            .take(3)
            .mapIndexed { i, item -> AiMatchResult(item, score = 0.87f - i * 0.12f) }
        return Response.success(DataResponse(success = true, data = results))
    }

    override suspend fun createChat(request: CreateChatRequest): Response<DataResponse<Chat>> {
        val existing = mockChats.find { it.itemId == request.itemId }
        if (existing != null) return Response.success(DataResponse(success = true, data = existing))
        val item = mockItems.find { it.id == request.itemId }
        val newChat = Chat(
            id = "chat-${UUID.randomUUID()}",
            itemId = request.itemId,
            itemTitle = item?.title ?: "",
            itemImage = item?.images?.firstOrNull() ?: "",
            participants = listOf(
                ChatParticipant(id = mockUser.id, name = mockUser.name),
                ChatParticipant(id = item?.userId ?: "", name = item?.userName ?: "")
            ),
            otherUserName = item?.userName ?: "對方使用者",
            lastMessage = "",
            lastMessageAt = System.currentTimeMillis(),
            unreadCount = 0
        )
        mockChats.add(newChat)
        return Response.success(DataResponse(success = true, data = newChat))
    }

    override suspend fun getChats(): Response<DataResponse<List<Chat>>> =
        Response.success(DataResponse(success = true, data = mockChats.toList()))

    override suspend fun getMessages(chatId: String, page: Int, pageSize: Int): Response<PagedResponse<Message>> {
        val msgs = mockMessages.filter { it.chatId == chatId }
        return Response.success(PagedResponse(success = true, data = msgs, total = msgs.size))
    }

    override suspend fun sendMessage(chatId: String, message: SendMessageRequest): Response<DataResponse<Message>> {
        val newMsg = Message(
            id = "msg-${UUID.randomUUID()}",
            chatId = chatId,
            senderId = mockUser.id,
            senderName = mockUser.name,
            content = message.content,
            type = MessageType.TEXT,
            createdAt = System.currentTimeMillis()
        )
        mockMessages.add(newMsg)
        return Response.success(DataResponse(success = true, data = newMsg))
    }

    override suspend fun generateQr(request: GenerateQrRequest): Response<DataResponse<QrItem>> {
        val newQr = QrItem(
            id = "qr-${UUID.randomUUID()}",
            userId = mockUser.id,
            name = request.name,
            description = request.description,
            qrCode = "foundit://qr/${UUID.randomUUID()}",
            qrImageUrl = "",
            createdAt = System.currentTimeMillis()
        )
        mockQrItems.add(newQr)
        return Response.success(DataResponse(success = true, data = newQr))
    }

    override suspend fun getQrItems(): Response<DataResponse<List<QrItem>>> =
        Response.success(DataResponse(success = true, data = mockQrItems.toList()))

    override suspend fun deleteQrItem(id: String): Response<BaseResponse> {
        mockQrItems.removeAll { it.id == id }
        return Response.success(BaseResponse(success = true, message = "已刪除"))
    }

    override suspend fun scanQr(code: String): Response<QrScanResponse> {
        val qrItem = mockQrItems.firstOrNull()
        return Response.success(
            QrScanResponse(success = qrItem != null, qrItem = qrItem, owner = mockUser)
        )
    }

    override suspend fun getNotifications(): Response<DataResponse<List<Notification>>> =
        Response.success(DataResponse(success = true, data = mockNotifications.toList()))

    override suspend fun markNotificationRead(id: String): Response<BaseResponse> {
        val index = mockNotifications.indexOfFirst { it.id == id }
        if (index >= 0) mockNotifications[index] = mockNotifications[index].copy(isRead = true)
        return Response.success(BaseResponse(success = true))
    }

    override suspend fun markAllNotificationsRead(): Response<BaseResponse> {
        mockNotifications.replaceAll { it.copy(isRead = true) }
        return Response.success(BaseResponse(success = true))
    }
}

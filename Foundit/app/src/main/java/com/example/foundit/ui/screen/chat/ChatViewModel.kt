package com.example.foundit.ui.screen.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.foundit.FounditApplication
import com.example.foundit.data.model.Chat
import com.example.foundit.data.model.Message
import com.example.foundit.data.remote.MessageDeserializer
import com.example.foundit.data.repository.Result
import android.util.Log
import com.example.foundit.util.Constants
import com.google.gson.GsonBuilder
import io.socket.client.IO
import io.socket.client.Socket
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

data class ChatListUiState(
    val isLoading: Boolean = false,
    val chats: List<Chat> = emptyList(),
    val errorMessage: String? = null
)

data class ChatRoomUiState(
    val isLoading: Boolean = false,
    val messages: List<Message> = emptyList(),
    val errorMessage: String? = null,
    val isSending: Boolean = false,
    /** 後端真正的聊天室 id（從列表進入時等於路由參數；從物品詳情進入時為 createOrGet 後的 id） */
    val resolvedChatId: String? = null,
    /** 目前登入者 id（去掉連字號、小寫），用於判斷氣泡靠左／靠右 */
    val selfUserIdNormalized: String = "",
)

class ChatViewModel : ViewModel() {

    private companion object {
        private const val TAG = "FounditChat"
    }

    private val repository = FounditApplication.instance.chatRepository
    private val preferences = FounditApplication.instance.preferences
    private var chatSocket: Socket? = null

    private val messageGson = GsonBuilder()
        .setLenient()
        .registerTypeAdapter(Message::class.java, MessageDeserializer)
        .create()

    private val _chatListState = MutableStateFlow(ChatListUiState())
    val chatListState: StateFlow<ChatListUiState> = _chatListState.asStateFlow()

    private val _chatRoomState = MutableStateFlow(ChatRoomUiState())
    val chatRoomState: StateFlow<ChatRoomUiState> = _chatRoomState.asStateFlow()

    /** 取得聊天列表 */
    fun loadChats() {
        viewModelScope.launch {
            _chatListState.value = _chatListState.value.copy(isLoading = true)
            when (val result = repository.getChats()) {
                is Result.Success -> _chatListState.value = ChatListUiState(chats = result.data)
                is Result.Error -> _chatListState.value = ChatListUiState(errorMessage = result.message)
            }
        }
    }

    /**
     * 進入聊天室：若 [openAsItem] 為 true，[routeId] 為物品 id，會先建立或取得聊天室再載入訊息；
     * 否則 [routeId] 即為聊天室 id（例如從聊天列表進入）。
     */
    fun enterRoom(routeId: String, openAsItem: Boolean) {
        viewModelScope.launch {
            val selfNorm = normalizeChatUserId(preferences.userId.first().orEmpty())
            _chatRoomState.value = ChatRoomUiState(
                isLoading = true,
                selfUserIdNormalized = selfNorm
            )
            val realChatId = if (openAsItem) {
                when (val r = repository.createOrGetChat(routeId)) {
                    is Result.Success -> r.data.id
                    is Result.Error -> {
                        _chatRoomState.value = ChatRoomUiState(
                            isLoading = false,
                            errorMessage = r.message,
                            selfUserIdNormalized = selfNorm
                        )
                        return@launch
                    }
                }
            } else routeId
            when (val result = repository.getMessages(realChatId)) {
                is Result.Success -> _chatRoomState.value = ChatRoomUiState(
                    isLoading = false,
                    messages = result.data,
                    resolvedChatId = realChatId,
                    selfUserIdNormalized = selfNorm
                )
                is Result.Error -> _chatRoomState.value = ChatRoomUiState(
                    isLoading = false,
                    errorMessage = result.message,
                    selfUserIdNormalized = selfNorm
                )
            }
        }
    }

    /** 連線 Socket.IO，即時接收新訊息（與後端 namespace `/chat` 一致） */
    fun attachRealtime(chatId: String) {
        viewModelScope.launch {
            val token = preferences.authToken.first().orEmpty()
            if (token.isBlank()) return@launch
            withContext(Dispatchers.IO) {
                disconnectRealtime()
                val opts = IO.Options().apply {
                    auth = hashMapOf("token" to "Bearer $token")
                    reconnection = true
                    reconnectionDelay = 1000
                    reconnectionAttempts = Int.MAX_VALUE
                    transports = arrayOf("websocket", "polling")
                }
                val sock = IO.socket("${Constants.API_ORIGIN}/chat", opts)
                sock.on(Socket.EVENT_CONNECT) {
                    sock.emit("join", JSONObject().put("chatId", chatId))
                }
                sock.on(Socket.EVENT_CONNECT_ERROR) { args ->
                    Log.w(TAG, "chat socket connect_error: ${args.contentToString()}")
                }
                sock.on(Socket.EVENT_DISCONNECT) { args ->
                    Log.w(TAG, "chat socket disconnect: ${args.contentToString()}")
                }
                sock.on("message") { args ->
                    if (args.isEmpty()) return@on
                    val parsed = runCatching {
                        val raw = args[0]
                        val jsonStr = when (raw) {
                            is JSONObject -> raw.toString()
                            else -> raw.toString()
                        }
                        messageGson.fromJson(jsonStr, Message::class.java)
                    }.getOrNull() ?: return@on
                    viewModelScope.launch(Dispatchers.Main.immediate) {
                        val cur = _chatRoomState.value
                        if (cur.messages.any { it.id == parsed.id }) return@launch
                        _chatRoomState.value = cur.copy(messages = cur.messages + parsed)
                    }
                }
                sock.connect()
                chatSocket = sock
            }
        }
    }

    fun disconnectRealtime() {
        chatSocket?.apply {
            off("message")
            off(Socket.EVENT_CONNECT)
            off(Socket.EVENT_CONNECT_ERROR)
            off(Socket.EVENT_DISCONNECT)
            disconnect()
        }
        chatSocket = null
    }

    override fun onCleared() {
        super.onCleared()
        disconnectRealtime()
    }

    /** 發送訊息 */
    fun sendMessage(chatId: String, content: String) {
        if (content.isBlank()) return
        viewModelScope.launch {
            _chatRoomState.value = _chatRoomState.value.copy(isSending = true)
            when (val result = repository.sendMessage(chatId, content)) {
                is Result.Success -> {
                    val cur = _chatRoomState.value
                    val msg = result.data
                    val next =
                        if (msg.id.isNotBlank() && cur.messages.any { it.id == msg.id }) {
                            cur.messages
                        } else {
                            cur.messages + msg
                        }
                    _chatRoomState.value = cur.copy(isSending = false, messages = next)
                }
                is Result.Error -> _chatRoomState.value = _chatRoomState.value.copy(
                    isSending = false,
                    errorMessage = result.message
                )
            }
        }
    }

    /** 對物品建立或取得聊天室 */
    fun openChatForItem(itemId: String, onSuccess: (chatId: String) -> Unit) {
        viewModelScope.launch {
            when (val result = repository.createOrGetChat(itemId)) {
                is Result.Success -> onSuccess(result.data.id)
                is Result.Error -> _chatListState.value = _chatListState.value.copy(
                    errorMessage = result.message
                )
            }
        }
    }

    /** 與後端 UUID 字串比對（忽略大小寫、連字號） */
    private fun normalizeChatUserId(raw: String): String =
        raw.trim().lowercase().replace("-", "")
}

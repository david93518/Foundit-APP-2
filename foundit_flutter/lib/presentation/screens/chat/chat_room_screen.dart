import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/chat.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';

/// 聊天室畫面 — 接 backend `/chats/:id/messages` (REST) + WebSocket `/chat`
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.chatId,
    this.name = '',
    this.avatar = '',
    this.itemTitle = '',
  });

  final String chatId;
  final String name;
  final String avatar;
  final String itemTitle;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  /// 對話訊息（時間升序）
  final List<Message> _msgs = [];

  /// 我的 user id（用來判斷 bubble 對齊方向）
  String _myId = '';
  bool _loading = true;
  String? _error;
  bool _sending = false;

  StreamSubscription<Message>? _msgSub;
  StreamSubscription<ChatReadEvent>? _readSub;
  StreamSubscription<ChatSocketStatus>? _statusSub;
  ChatSocketStatus _socketStatus = ChatSocketStatus.idle;

  @override
  void initState() {
    super.initState();
    _myId = ref.read(sharedPreferencesProvider).getString(
              AppConstants.prefUserId,
            ) ??
        '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(chatRepositoryProvider);
    final socket = ref.read(chatSocketServiceProvider);

    // 1. 拉歷史訊息
    try {
      final list = await repo.messages(widget.chatId);
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      setState(() {
        _msgs
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      _scrollToEnd(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _humanizeError(e);
      });
      return;
    }

    // 2. 開 WebSocket（如果還沒連）
    final ok = await socket.connect();
    if (!mounted) return;
    if (!ok) {
      // 沒登入或連不上，給 user 提示但仍可看歷史
      AppSnackbar.warning(context, '即時連線失敗，將以一般網路傳送訊息');
    } else {
      socket.joinChat(widget.chatId);
    }

    // 3. 訂閱事件 — 不論 ok 都訂，重連後會收到
    _msgSub = socket.messages
        .where((m) => m.chatId == widget.chatId)
        .listen(_onIncomingMessage);

    _readSub = socket.reads
        .where((e) => e.chatId == widget.chatId && e.userId != _myId)
        .listen((_) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _msgs.length; i++) {
          final m = _msgs[i];
          if (m.senderId == _myId && m.readAt == null) {
            _msgs[i] = m.copyWith(readAt: DateTime.now());
          }
        }
      });
    });

    _statusSub = socket.status.listen((s) {
      if (!mounted) return;
      setState(() => _socketStatus = s);
      // 重連後重新 join 對應房間
      if (s == ChatSocketStatus.connected) {
        socket.joinChat(widget.chatId);
      }
    });

    // 4. 進房就把對方訊息標為已讀（REST 一次定生死）
    unawaited(repo.markRead(widget.chatId));
    socket.markRead(widget.chatId);

    // 5. 把列表頁的 unread badge 失效
    ref.invalidate(chatsProvider);
    ref.invalidate(chatUnreadTotalProvider);
  }

  void _onIncomingMessage(Message msg) {
    if (!mounted) return;

    setState(() {
      // 取代正在 sending 的本機暫存（id 以 'pending_' 開頭）
      final pendingIdx = _msgs.indexWhere(
        (m) =>
            m.id.startsWith('pending_') &&
            m.senderId == msg.senderId &&
            m.content == msg.content,
      );
      if (pendingIdx != -1) {
        _msgs[pendingIdx] = msg;
      } else {
        _msgs.add(msg);
      }
    });

    _scrollToEnd();

    // 若是別人傳來的，自動回 read
    if (msg.senderId != _myId) {
      ref.read(chatSocketServiceProvider).markRead(widget.chatId);
      unawaited(ref.read(chatRepositoryProvider).markRead(widget.chatId));
      ref.invalidate(chatsProvider);
      ref.invalidate(chatUnreadTotalProvider);
    }
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animated) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _readSub?.cancel();
    _statusSub?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || _sending) return;
    Haptics.light();

    final pendingId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final pending = Message(
      id: pendingId,
      chatId: widget.chatId,
      senderId: _myId,
      senderName: '',
      content: txt,
      createdAt: DateTime.now(),
    );

    setState(() {
      _msgs.add(pending);
      _ctrl.clear();
      _sending = true;
    });
    _scrollToEnd();

    final socket = ref.read(chatSocketServiceProvider);

    try {
      if (socket.isConnected) {
        // socket.io 路徑：server 會回 broadcast，_onIncomingMessage 會替換 pending
        socket.sendMessage(chatId: widget.chatId, content: txt);
      } else {
        // fallback：REST
        final saved = await ref.read(chatRepositoryProvider).send(
              chatId: widget.chatId,
              content: txt,
            );
        if (!mounted) return;
        setState(() {
          final idx = _msgs.indexWhere((m) => m.id == pendingId);
          if (idx != -1 && saved != null) _msgs[idx] = saved;
        });
      }
      // 列表頁刷新（last_message_at）
      ref.invalidate(chatsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeWhere((m) => m.id == pendingId);
      });
      AppSnackbar.error(context, '送出失敗：${_humanizeError(e)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _humanizeError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('connection')) {
      return '無法連線，請檢查網路';
    }
    if (s.contains('403')) return '你不在這個聊天室裡';
    if (s.contains('404')) return '聊天室不存在或已關閉';
    return '伺服器錯誤，請稍後再試';
  }

  void _onBubbleLongPress(int index) {
    Haptics.medium();
    final msg = _msgs[index];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BubbleActionSheet(
        onCopy: () {
          Clipboard.setData(ClipboardData(text: msg.content));
          Navigator.pop(context);
          AppSnackbar.success(context, '已複製');
        },
        onReply: () {
          Navigator.pop(context);
          _ctrl.text = '回覆「${msg.content}」：';
        },
        onReport: msg.senderId != _myId
            ? () {
                Navigator.pop(context);
                AppSnackbar.warning(context, '已回報訊息');
              }
            : null,
      ),
    );
  }

  /// 把訊息與日期 header 混合成一個列表
  List<Object> _buildFeed() {
    final feed = <Object>[];
    DateTime? lastDay;
    for (final m in _msgs) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day != lastDay) {
        feed.add(_DayHeader(day));
        lastDay = day;
      }
      feed.add(m);
    }
    return feed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _TopBar(
            name: widget.name.isEmpty ? '聊天室' : widget.name,
            avatar: widget.avatar,
            itemTitle: widget.itemTitle,
            socketStatus: _socketStatus,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: _buildBody(),
          ),
          _InputBar(
            controller: _ctrl,
            onSend: _send,
            sending: _sending,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return _ErrorRetry(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _bootstrap();
        },
      );
    }
    if (_msgs.isEmpty) {
      return const _EmptyChat();
    }

    final feed = _buildFeed();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: feed.length,
      itemBuilder: (_, i) {
        final f = feed[i];
        if (f is _DayHeader) return _DayDivider(day: f.day);
        final m = f as Message;
        if (m.type == MessageType.system) {
          return _SystemNote(text: m.content);
        }
        final idx = _msgs.indexOf(m);
        return _Bubble(
          msg: m,
          isMine: m.senderId == _myId,
          isPending: m.id.startsWith('pending_'),
          onLongPress: () => _onBubbleLongPress(idx),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.avatar,
    required this.itemTitle,
    required this.socketStatus,
    required this.onBack,
  });

  final String name;
  final String avatar;
  final String itemTitle;
  final ChatSocketStatus socketStatus;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: onBack,
                ),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: avatar.isEmpty
                          ? null
                          : CachedNetworkImageProvider(avatar),
                      backgroundColor: AppColors.primary200,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: socketStatus == ChatSocketStatus.connected
                              ? AppColors.found
                              : AppColors.textTertiary,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _statusLabel(socketStatus),
                        style: TextStyle(
                          fontSize: 11,
                          color: socketStatus == ChatSocketStatus.connected
                              ? AppColors.textSecondary
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (itemTitle.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: AppRadius.allMd,
                border: Border.all(
                    color: AppColors.primary100.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '物品：$itemTitle',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(ChatSocketStatus s) {
    switch (s) {
      case ChatSocketStatus.connected:
        return '線上即時連線中';
      case ChatSocketStatus.connecting:
        return '連線中…';
      case ChatSocketStatus.disconnected:
        return '已斷線（仍可送訊息）';
      case ChatSocketStatus.error:
        return '連線異常';
      case ChatSocketStatus.idle:
        return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// 訊息泡泡 / Day header / 系統訊息 / 空狀態
// ─────────────────────────────────────────────────────────────────

class _DayHeader {
  final DateTime day;
  const _DayHeader(this.day);
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.day});
  final DateTime day;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return DateFormatter.date(day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: AppRadius.allRound,
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.msg,
    required this.isMine,
    required this.isPending,
    required this.onLongPress,
  });
  final Message msg;
  final bool isMine;
  final bool isPending;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && msg.senderAvatar.isNotEmpty) ...[
            CircleAvatar(
              radius: 14,
              backgroundImage: CachedNetworkImageProvider(msg.senderAvatar),
              backgroundColor: AppColors.surfaceSoft,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: GestureDetector(
                onLongPress: onLongPress,
                child: Opacity(
                  opacity: isPending ? 0.65 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMine ? AppColors.primaryGradient : null,
                      color: isMine ? null : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 18),
                      ),
                      boxShadow: isMine ? AppShadows.primary : AppShadows.xs,
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        color: isMine ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormatter.time(msg.createdAt),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isMine) _StatusTick(pending: isPending, read: msg.isRead),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTick extends StatelessWidget {
  const _StatusTick({required this.pending, required this.read});
  final bool pending;
  final bool read;

  @override
  Widget build(BuildContext context) {
    if (pending) {
      return const Padding(
        padding: EdgeInsets.only(top: 2),
        child: SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }
    final color = read ? AppColors.primary : AppColors.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Icon(
        read ? Icons.done_all_rounded : Icons.done_rounded,
        size: 12,
        color: color,
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '說聲哈囉吧 👋',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '簡單介紹自己、確認物品的特徵與交付方式，會讓對方更願意回覆。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.lost),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 操作選單 / 輸入列
// ─────────────────────────────────────────────────────────────────

class _BubbleActionSheet extends StatelessWidget {
  const _BubbleActionSheet({
    required this.onCopy,
    required this.onReply,
    this.onReport,
  });
  final VoidCallback onCopy;
  final VoidCallback onReply;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionTile(
              icon: Icons.copy_rounded,
              label: '複製',
              onTap: onCopy,
            ),
            _Divider(),
            _ActionTile(
              icon: Icons.reply_rounded,
              label: '回覆',
              onTap: onReply,
            ),
            if (onReport != null) ...[
              _Divider(),
              _ActionTile(
                icon: Icons.flag_outlined,
                label: '回報此訊息',
                onTap: onReport!,
                destructive: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: AppColors.divider,
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: AppRadius.allRound,
              ),
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => widget.onSend(),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '輸入訊息…',
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: _hasText
                ? _SendBtn(
                    key: const ValueKey('send'),
                    onTap: widget.sending ? null : widget.onSend,
                    busy: widget.sending,
                  )
                : const _SendBtn(
                    key: ValueKey('disabled'),
                    onTap: null,
                    busy: false,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SendBtn extends StatelessWidget {
  const _SendBtn({super.key, required this.onTap, required this.busy});
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.primaryGradient : null,
            color: enabled ? null : AppColors.surfaceSoft,
            shape: BoxShape.circle,
            boxShadow: enabled ? AppShadows.primary : null,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.send_rounded,
                  color: enabled ? Colors.white : AppColors.textTertiary,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

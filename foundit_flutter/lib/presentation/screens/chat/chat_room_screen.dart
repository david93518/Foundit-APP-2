import 'dart:async';

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
import '../../../data/api/api_client.dart';
import '../../providers/safety_provider.dart';
import '../profile/safety_screen.dart';
import '../../widgets/report_user_dialog.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/foundit_ui.dart';
import '../../widgets/private_chat_image.dart';
import 'chat_list_screen.dart' show ChatAvatar;

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

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  /// 對話訊息（時間升序）
  final List<Message> _msgs = [];

  /// 我的 user id（用來判斷 bubble 對齊方向）
  String _myId = '';
  String get _draftKey {
    final id = ref
        .read(sharedPreferencesProvider)
        .getString(AppConstants.prefUserId);
    final owner = (id == null || id.isEmpty) ? 'guest' : id;
    return 'chat_draft:$owner:${widget.chatId}';
  }

  bool _loading = true;
  String? _error;
  bool _sending = false;
  bool _refreshing = false;
  bool _olderLoading = false;
  bool _hasOlder = false;
  bool _foreground = true;
  bool _newMessages = false;
  bool _safetyBusy = false;
  String? _syncError;
  String? _lastReadId;
  int _generation = 0;
  Chat? _chat;
  final List<Message> _duringRefresh = [];

  bool get _nearEnd => !_scroll.hasClients || _scroll.position.extentAfter < 80;
  bool get _visible =>
      _foreground && (ModalRoute.of(context)?.isCurrent ?? true);
  String? get _peerId =>
      _chat?.participants.where((p) => p.id != _myId).firstOrNull?.id;
  bool get _blocked =>
      ref
          .read(blockedContactsProvider)
          .valueOrNull
          ?.any((p) => p.id == _peerId) ??
      false;

  StreamSubscription<Message>? _msgSub;
  StreamSubscription<ChatReadEvent>? _readSub;
  StreamSubscription<ChatSocketStatus>? _statusSub;
  ChatSocketStatus _socketStatus = ChatSocketStatus.idle;

  /// 對方是否開著 App；null = 還不知道（未連線或查詢失敗）。
  bool? _peerOnline;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_ackLatest);
    _ctrl.text = ref.read(sharedPreferencesProvider).getString(_draftKey) ?? '';
    _ctrl.addListener(_saveDraft);
    _myId =
        ref
            .read(sharedPreferencesProvider)
            .getString(AppConstants.prefUserId) ??
        '';
    if (ref.read(useMockProvider)) _myId = 'me';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await _msgSub?.cancel();
    await _readSub?.cancel();
    await _statusSub?.cancel();
    if (!mounted) return;
    unawaited(_loadDetail());
    final socket = ref.read(chatSocketServiceProvider);
    if (!ref.read(useMockProvider)) {
      _msgSub = socket.messages
          .where((m) => m.chatId == widget.chatId)
          .listen(_onIncomingMessage);
      _readSub = socket.reads
          .where((e) => e.chatId == widget.chatId && e.userId != _myId)
          .listen((event) {
            if (!mounted) return;
            final pivot = _msgs
                .where((m) => m.id == event.upToMessageId)
                .firstOrNull;
            if (pivot == null) return;
            setState(() {
              for (var i = 0; i < _msgs.length; i++) {
                final m = _msgs[i];
                if (m.senderId == _myId &&
                    m.readAt == null &&
                    !m.id.startsWith('pending_') &&
                    !m.createdAt.isAfter(pivot.createdAt)) {
                  _msgs[i] = m.copyWith(readAt: DateTime.now());
                }
              }
            });
          });
      _statusSub = socket.status.listen((status) {
        if (!mounted) return;
        setState(() {
          _socketStatus = status;
          if (status != ChatSocketStatus.connected) _peerOnline = null;
        });
        if (status == ChatSocketStatus.connected) {
          socket.joinChat(widget.chatId);
          unawaited(_checkPresence());
          if (!_loading) unawaited(_refreshLatest());
        }
      });
      unawaited(
        socket.connect().then((ok) {
          if (!mounted) return;
          setState(() => _socketStatus = socket.currentStatus);
          if (ok) {
            socket.joinChat(widget.chatId);
            unawaited(_checkPresence());
            if (!_loading) unawaited(_refreshLatest());
          }
        }),
      );
      _presenceTimer?.cancel();
      _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_visible) unawaited(_checkPresence());
      });
    }
    await _refreshLatest();
  }

  Future<void> _checkPresence() async {
    final online = await ref
        .read(chatSocketServiceProvider)
        .peerOnline(widget.chatId);
    if (mounted && online != _peerOnline) setState(() => _peerOnline = online);
  }

  Future<void> _loadDetail() async {
    try {
      final chat = await ref.read(chatRepositoryProvider).detail(widget.chatId);
      if (mounted) setState(() => _chat = chat);
    } catch (_) {
      // History remains usable; opening the safety menu retries identification.
    }
  }

  void _merge(Iterable<Message> incoming) {
    for (final msg in incoming) {
      _msgs.removeWhere(
        (m) =>
            m.id == msg.id ||
            (msg.clientMessageId.isNotEmpty &&
                m.senderId == msg.senderId &&
                m.clientMessageId == msg.clientMessageId),
      );
      _msgs.add(msg);
    }
    _msgs.sort((a, b) {
      final time = a.createdAt.compareTo(b.createdAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
  }

  Future<void> _refreshLatest() async {
    if (_refreshing) return;
    final generation = ++_generation;
    _duringRefresh.clear();
    setState(() {
      _refreshing = true;
      _syncError = null;
      _olderLoading = false;
    });
    try {
      final rows = await ref
          .read(chatRepositoryProvider)
          .messages(widget.chatId);
      if (!mounted || generation != _generation) return;
      final pending = _msgs.where((m) => m.id.startsWith('pending_')).toList();
      setState(() {
        _msgs.clear();
        _merge(pending);
        _merge(rows);
        _merge(_duringRefresh);
        _hasOlder = rows.length == 50;
        _loading = false;
        _error = null;
        _newMessages = false;
      });
      _scrollToEnd(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_loading) {
          _error = _humanizeError(e);
        } else {
          _syncError = '訊息尚未同步，請重試';
        }
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_olderLoading || _refreshing || !_hasOlder) return;
    final first = _msgs.where((m) => !m.id.startsWith('pending_')).firstOrNull;
    if (first == null) return;
    final generation = _generation;
    setState(() => _olderLoading = true);
    try {
      final rows = await ref
          .read(chatRepositoryProvider)
          .messages(widget.chatId, before: first.id);
      if (!mounted || generation != _generation) return;
      final beforeExtent = _scroll.hasClients
          ? _scroll.position.maxScrollExtent
          : 0.0;
      final beforeOffset = _scroll.hasClients ? _scroll.offset : 0.0;
      setState(() {
        _merge(rows);
        _hasOlder = rows.length == 50;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients || generation != _generation) {
          return;
        }
        _scroll.jumpTo(
          (beforeOffset + _scroll.position.maxScrollExtent - beforeExtent)
              .clamp(0.0, _scroll.position.maxScrollExtent),
        );
      });
    } catch (e) {
      if (mounted) AppSnackbar.error(context, '較早訊息尚未載入，請重試');
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _olderLoading = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && !_loading) {
      unawaited(_refreshLatest());
      ref.invalidate(blockedContactsProvider);
    }
  }

  void _onIncomingMessage(Message msg) {
    if (!mounted) return;
    final follow = _visible && _nearEnd;
    if (_refreshing) _duringRefresh.add(msg);
    setState(() {
      _merge([msg]);
      if (!follow && msg.senderId != _myId) _newMessages = true;
      // 剛收到對方的訊息，對方此刻一定開著 App。
      if (msg.senderId != _myId && msg.type != MessageType.system) {
        _peerOnline = true;
      }
    });
    if (follow) _scrollToEnd();
    ref.invalidate(chatsProvider);
    ref.invalidate(chatUnreadTotalProvider);
  }

  void _ackLatest() {
    if (!mounted || !_visible || !_nearEnd || _loading || _olderLoading) return;
    final id = _latestServerMessageId();
    if (id == null || id == _lastReadId) return;
    _lastReadId = id;
    if (_newMessages) setState(() => _newMessages = false);
    unawaited(
      ref
          .read(chatRepositoryProvider)
          .markRead(widget.chatId, upToMessageId: id)
          .then((ok) {
            if (!mounted) return;
            if (!ok && _lastReadId == id) _lastReadId = null;
            if (ok) {
              ref.invalidate(chatsProvider);
              ref.invalidate(chatUnreadTotalProvider);
            }
          }),
    );
  }

  Future<void> _safetyMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('交還前核對'),
                onTap: () => Navigator.pop(c, 'check'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('檢舉對方'),
                onTap: () => Navigator.pop(c, 'report'),
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: Text(_blocked ? '解除封鎖聯絡' : '封鎖聯絡'),
                onTap: () => Navigator.pop(c, 'block'),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('同步最新訊息'),
                onTap: () => Navigator.pop(c, 'refresh'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'check') {
      await showHandoverChecklist(context);
      return;
    }
    if (action == 'refresh') {
      await _refreshLatest();
      return;
    }
    if (ref.read(useMockProvider)) {
      AppSnackbar.warning(context, '體驗模式無法檢舉或封鎖真實使用者');
      return;
    }
    if (_peerId == null) await _loadDetail();
    if (!mounted) return;
    final peer = _peerId;
    if (peer == null) {
      AppSnackbar.error(context, '無法確認聯絡對象，請稍後重試');
      return;
    }
    if (action == 'report') {
      final sent = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ReportUserDialog(userId: peer),
      );
      if (sent == true && mounted) {
        AppSnackbar.success(context, '檢舉已送出，交由管理員查看');
      }
      return;
    }
    await _toggleBlock(peer);
  }

  Future<void> _toggleBlock(String peer) async {
    if (_safetyBusy) return;
    setState(() => _safetyBusy = true);
    try {
      final contacts = await ref.refresh(blockedContactsProvider.future);
      final unblock = contacts.any((p) => p.id == peer);
      if (!mounted ||
          !await confirmContactBlock(context, unblock: unblock) ||
          !mounted) {
        return;
      }
      final repo = ref.read(safetyRepositoryProvider);
      if (unblock) {
        await repo.unblock(peer);
      } else {
        await repo.block(peer);
      }
      if (!mounted) return;
      ref.invalidate(blockedContactsProvider);
      AppSnackbar.success(context, unblock ? '已解除封鎖聯絡' : '已封鎖聯絡');
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, apiErrorMessage(e) ?? '設定尚未更新，請稍後重試');
      }
    } finally {
      if (mounted) setState(() => _safetyBusy = false);
    }
  }

  String? _latestServerMessageId() {
    for (var index = _msgs.length - 1; index >= 0; index--) {
      final id = _msgs[index].id;
      if (!id.startsWith('pending_')) return id;
    }
    return null;
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (animated) {
        _scroll
            .animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            )
            .then((_) => _ackLatest());
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
        _ackLatest();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_ackLatest);
    _presenceTimer?.cancel();
    _msgSub?.cancel();
    _readSub?.cancel();
    _statusSub?.cancel();
    _ctrl.removeListener(_saveDraft);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty || _sending || _blocked || _safetyBusy) return;
    Haptics.light();

    final clientId = DateTime.now().microsecondsSinceEpoch.toString();
    final pendingId = 'pending_$clientId';
    final pending = Message(
      id: pendingId,
      chatId: widget.chatId,
      senderId: _myId,
      senderName: '',
      content: txt,
      createdAt: DateTime.now(),
      clientMessageId: clientId,
    );

    setState(() {
      _msgs.add(pending);
      _ctrl.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      // The API confirms persistence; its socket broadcast delivers to the peer.
      final saved = await ref
          .read(chatRepositoryProvider)
          .send(chatId: widget.chatId, content: txt, clientMessageId: clientId);
      if (!mounted) return;
      if (saved == null) throw StateError('Message was not accepted');
      _onIncomingMessage(saved);
      // 列表頁刷新（last_message_at）
      ref.invalidate(chatsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.removeWhere((m) => m.id == pendingId);
        _ctrl.text = _ctrl.text.isEmpty ? txt : '$txt\n${_ctrl.text}';
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
    if (s.contains('403')) return apiErrorMessage(e) ?? '目前無法與對方聯絡';
    if (s.contains('404')) return '聊天室不存在或已關閉';
    return '伺服器錯誤，請稍後再試';
  }

  void _saveDraft() {
    unawaited(
      ref.read(sharedPreferencesProvider).setString(_draftKey, _ctrl.text),
    );
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
      ),
    );
  }

  /// 把訊息與日期 header 混合成一個列表
  List<Object> _buildFeed() {
    final feed = <Object>[];
    DateTime? lastDay;
    for (final m in _msgs) {
      final day = DateTime(
        m.createdAt.year,
        m.createdAt.month,
        m.createdAt.day,
      );
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
    ref.watch(blockedContactsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 420;
          return Column(
            children: [
              _TopBar(
                name:
                    _chat?.otherUserName ??
                    (widget.name.isEmpty ? '聊天室' : widget.name),
                avatar: widget.avatar,
                itemTitle: compact ? '' : widget.itemTitle,
                socketStatus: _socketStatus,
                peerOnline: _peerOnline,
                demo: ref.watch(useMockProvider),
                onBack: () => context.pop(),
                onMore: _safetyBusy ? null : _safetyMenu,
              ),
              if (ref.watch(useMockProvider) && !compact)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: AppColors.surfaceSoft,
                  child: const Text(
                    '示範對話 · 不會傳送給真實使用者',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              if (_refreshing && !_loading)
                const LinearProgressIndicator(minHeight: 2),
              if (_syncError != null)
                TextButton.icon(
                  onPressed: _refreshLatest,
                  icon: const Icon(Icons.sync_problem),
                  label: Text(_syncError!),
                ),
              Expanded(child: _buildBody()),
              if (_newMessages)
                TextButton.icon(
                  onPressed: _scrollToEnd,
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('有新訊息，前往最新'),
                ),
              if (_blocked)
                SafeArea(
                  top: false,
                  child: TextButton(
                    onPressed: _safetyBusy || _peerId == null
                        ? null
                        : () => _toggleBlock(_peerId!),
                    child: const Text('已封鎖聯絡 · 解除封鎖'),
                  ),
                )
              else
                _InputBar(
                  controller: _ctrl,
                  onSend: _send,
                  sending: _sending,
                  compact: compact,
                ),
            ],
          );
        },
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
      itemCount: feed.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Center(
            child: _hasOlder
                ? TextButton(
                    key: const ValueKey('load-older'),
                    onPressed: _olderLoading || _refreshing ? null : _loadOlder,
                    child: Text(_olderLoading ? '載入中…' : '載入較早訊息'),
                  )
                : const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      '已到對話開頭',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
          );
        }
        final f = feed[i - 1];
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
    required this.onMore,
    this.peerOnline,
    this.demo = false,
  });

  final String name;
  final String avatar;
  final String itemTitle;
  final ChatSocketStatus socketStatus;

  /// 對方是否開著 App；null = 不知道（不顯示綠點）。
  final bool? peerOnline;
  final VoidCallback onBack;
  final VoidCallback? onMore;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final online =
        socketStatus == ChatSocketStatus.connected && peerOnline == true;
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: onBack,
                ),
                const SizedBox(width: 2),
                Stack(
                  children: [
                    ChatAvatar(name: name, url: avatar, size: 38),
                    if (peerOnline != null &&
                        socketStatus == ChatSocketStatus.connected)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: online
                                ? const Color(0xFF3A9D5D)
                                : AppColors.neutral300,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
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
                        demo ? '示範對話' : _statusLabel(socketStatus),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '對話選單',
                  icon: const Icon(Icons.more_horiz),
                  onPressed: onMore,
                ),
              ],
            ),
          ),
          if (itemTitle.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.ink50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.ink700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '關於：$itemTitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink,
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

  /// 連線正常時顯示「對方」的狀態；自己的連線出問題時才提示自己的狀態。
  String _statusLabel(ChatSocketStatus s) {
    switch (s) {
      case ChatSocketStatus.connected:
        return switch (peerOnline) {
          true => '在線上',
          false => '目前不在線上，上線後會看到訊息',
          null => '',
        };
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
    // 我的訊息是炭墨，對方的是白紙：和整個 App 的「兩種聲音」一致。
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && msg.senderAvatar.isNotEmpty) ...[
            ChatAvatar(name: msg.senderName, url: msg.senderAvatar, size: 26),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: GestureDetector(
                onLongPress: onLongPress,
                child: AnimatedOpacity(
                  duration: AppMotion.of(context, AppMotion.base),
                  opacity: isPending ? 0.6 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMine ? AppColors.ink : AppColors.surface,
                      border: isMine
                          ? null
                          : Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMine ? 18 : 5),
                        bottomRight: Radius.circular(isMine ? 5 : 18),
                      ),
                    ),
                    child: msg.type == MessageType.image
                        ? PrivateChatImage(
                            key: ValueKey(msg.content),
                            url: msg.content,
                          )
                        : Text(
                            msg.content,
                            style: TextStyle(
                              color: isMine
                                  ? AppColors.onInk
                                  : AppColors.textPrimary,
                              fontSize: 14.5,
                              height: 1.5,
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
  Widget build(BuildContext context) => const SingleChildScrollView(
    child: EmptyPanel(
      icon: Icons.waving_hand_outlined,
      title: '從確認物品特徵開始',
      message: '簡單介紹自己、確認物品的特徵與交付方式，會讓對方更願意回覆。',
    ),
  );
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: EmptyPanel(
      icon: Icons.cloud_off_outlined,
      title: '訊息暫時載入不了',
      message: message,
      action: '重試',
      onAction: onRetry,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// 操作選單 / 輸入列
// ─────────────────────────────────────────────────────────────────

class _BubbleActionSheet extends StatelessWidget {
  const _BubbleActionSheet({required this.onCopy, required this.onReply});
  final VoidCallback onCopy;
  final VoidCallback onReply;

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
            _ActionTile(icon: Icons.copy_rounded, label: '複製', onTap: onCopy),
            _Divider(),
            _ActionTile(icon: Icons.reply_rounded, label: '回覆', onTap: onReply),
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textPrimary;
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
    this.compact = false,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final bool compact;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
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
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                key: const ValueKey('chat-composer'),
                controller: widget.controller,
                minLines: 1,
                maxLines: widget.compact ? 1 : 4,
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
            color: enabled ? AppColors.ink : AppColors.surfaceSoft,
            shape: BoxShape.circle,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onInk,
                  ),
                )
              : Icon(
                  Icons.send_rounded,
                  color: enabled ? AppColors.onInk : AppColors.textTertiary,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

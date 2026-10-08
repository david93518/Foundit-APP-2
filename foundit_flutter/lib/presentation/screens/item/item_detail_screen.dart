import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/items_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/foundit_ui.dart';
import '../profile/collection_screen.dart';

class ItemDetailRoute extends ConsumerWidget {
  const ItemDetailRoute({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(itemDetailProvider(id))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => Scaffold(
          appBar: AppBar(),
          body: _failureBody(
            EmptyPanel(
              title: '物品暫時無法載入',
              message: '請稍後再試一次。',
              action: '重試',
              onAction: () => ref.invalidate(itemDetailProvider(id)),
            ),
          ),
        ),
        data: (item) => item == null
            ? Scaffold(
                appBar: AppBar(),
                body: _failureBody(
                  EmptyPanel(
                    title: '找不到這件物品',
                    message: '可能已下架，回到探索看看其他物品。',
                    action: '回到探索',
                    onAction: () => context.go('/home'),
                  ),
                ),
              )
            : ItemDetailScreen(item: item),
      );

  Widget _failureBody(Widget panel) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: panel,
        ),
      ),
    ),
  );
}

/// 物品詳情：照片先說話，資訊卡從照片下方浮起，行動固定在拇指可及的底部。
class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.item});
  final Item item;
  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  final _pager = PageController();
  bool _busy = false;
  int _photo = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _reportItem(Item item) async {
    if (!ref.read(authProvider).isLoggedIn) {
      await context.push('/login');
      return;
    }
    final reason = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: const Text('檢舉這則刊登'),
        content: TextField(
          controller: reason,
          maxLength: 1000,
          maxLines: 4,
          decoration: const InputDecoration(labelText: '請說明原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('送出'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (send != true || !mounted) return;
    if (text.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請寫下檢舉原因。')));
      return;
    }
    final result = await ref
        .read(authRepositoryProvider)
        .report(targetType: 'item', targetId: item.id, reason: text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '已送出檢舉，我們會處理。'
              : (result.message.isEmpty ? '檢舉沒有送出。' : result.message),
        ),
      ),
    );
  }

  Future<void> _contact() async {
    final mock = ref.read(useMockProvider);
    if (!mock && !ref.read(authProvider).isLoggedIn) {
      await context.push('/login');
      return;
    }
    final ctrl = TextEditingController();
    final key = GlobalKey<FormState>();
    final detail = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      showDragHandle: true,
      builder: (c) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.viewInsetsOf(c).bottom + 28,
          ),
          child: SafeArea(
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.item.type == ItemType.found ? '核對物品特徵' : '分享你知道的線索',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mock
                        ? '體驗模式：這段內容只會出現在示範對話，不會傳送給真實使用者。'
                        : '描述一個只有你知道的特徵，透過私訊與對方核對。',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: ctrl,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: '辨識特徵或線索',
                      hintText: '例如：內袋有一個小小的藍色吊飾',
                      errorMaxLines: 5,
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 4
                        ? '請填寫至少 4 個字，方便對方核對。'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (key.currentState!.validate()) {
                        Navigator.pop(c, ctrl.text.trim());
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(mock ? '建立示範對話' : '開始私訊'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The bottom sheet releases its text field after its closing animation.
    Future<void>.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    if (detail == null || !mounted) return;
    setState(() => _busy = true);
    final actions = ref.read(chatActionsProvider.notifier);
    final chat = await actions.startChatWithItem(widget.item.id);
    if (chat != null) {
      final sent = await actions.send(chatId: chat.id, content: detail);
      if (!mounted) return;
      setState(() => _busy = false);
      if (sent == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('訊息未送出，請稍後再試。')));
        return;
      }
      ref.invalidate(chatsProvider);
      ref.invalidate(chatMessagesProvider(chat.id));
      context.push(
        '/chat/${chat.id}',
        extra: {'name': widget.item.userName, 'itemTitle': widget.item.title},
      );
    } else if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('目前無法建立對話，請稍後再試。')));
    }
  }

  Future<void> _resolve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('確認完成招領'),
        content: const Text('確認後會將物品標記為完成，並從協尋清單中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('繼續尋找'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('確認完成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final ok = await ref.read(itemRepositoryProvider).resolve(widget.item.id);
      if (!ok) throw StateError('resolve failed');
      ref.invalidate(itemsProvider);
      ref.invalidate(collectionProvider(false));
      ref.invalidate(itemDetailProvider(widget.item.id));
      if (mounted) context.go('/my-items');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('更新失敗，請再試一次。')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPhoto(int index) {
    final item = widget.item;
    if (item.images.isEmpty) return;
    context.push(
      '/photo-viewer',
      extra: {
        'images': item.images,
        'initialIndex': index,
        'heroTag': 'item-photo-${item.id}',
      },
    );
  }

  Future<void> _openMap(Item item) async {
    final query = (item.latitude != 0 || item.longitude != 0)
        ? '${item.latitude},${item.longitude}'
        : Uri.encodeComponent(item.locationName);
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final saved = ref.watch(savedItemsProvider).contains(item.id);
    final mock = ref.watch(useMockProvider);
    final mine =
        item.userId.isNotEmpty &&
        item.userId == (mock ? 'me' : ref.watch(authProvider).user?.id);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final gallery = _Gallery(
      item: item,
      controller: _pager,
      index: _photo,
      onChanged: (i) => setState(() => _photo = i),
      onOpen: _openPhoto,
    );
    final floating = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _RoundButton(
              tooltip: '返回',
              icon: Icons.arrow_back_rounded,
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            const Spacer(),
            _RoundButton(
              tooltip: saved ? '取消收藏' : '收藏物品',
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: saved
                  ? AppColors.primary.light
                  : AppColors.textPrimary.light,
              onTap: () =>
                  ref.read(savedItemsProvider.notifier).toggle(item.id),
            ),
          ],
        ),
      ),
    );
    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(36, 84, 36, 40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: AspectRatio(aspectRatio: 1, child: gallery),
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _info(item, mock: mock, mine: mine, wide: true),
                              const SizedBox(height: 28),
                              _cta(item, mine),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            floating,
          ],
        ),
      );
    }
    final photoHeight = (size.height * .5).clamp(280.0, 520.0);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: photoHeight, child: gallery),
                // 資訊卡浮在照片下緣，像一張從照片底下抽出的卡片。
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 8),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                    ),
                    child: _info(item, mock: mock, mine: mine, wide: false),
                  ),
                ),
              ],
            ),
          ),
          floating,
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: _cta(item, mine),
        ),
      ),
    );
  }

  Widget _info(
    Item item, {
    required bool mock,
    required bool mine,
    required bool wide,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (item.images.length > 1) ...[
        _Thumbnails(
          images: item.images,
          selected: _photo,
          onSelect: (i) {
            setState(() => _photo = i);
            if (_pager.hasClients) {
              _pager.animateToPage(
                i,
                duration: AppMotion.of(context, AppMotion.base),
                curve: AppMotion.curve,
              );
            }
          },
        ),
        const SizedBox(height: 18),
      ],
      Row(
        children: [
          StatusTag(item),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${DateFormatter.relative(item.createdAt)}刊登',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Semantics(
        header: true,
        child: Text(
          item.title,
          style: TextStyle(
            fontSize: wide ? 30 : 25,
            height: 1.3,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
      ),
      const SizedBox(height: 20),
      _Fact(
        icon: Icons.place_outlined,
        label: item.type == ItemType.found ? '拾獲地點' : '遺失地點',
        value: item.locationName,
        onTap: item.locationName.isEmpty ? null : () => _openMap(item),
        actionLabel: '在地圖中開啟',
      ),
      _Fact(
        icon: Icons.calendar_today_outlined,
        label: item.type == ItemType.found ? '拾獲日期' : '遺失日期',
        value:
            '${item.lostAt.year}/${item.lostAt.month.toString().padLeft(2, '0')}/${item.lostAt.day.toString().padLeft(2, '0')}',
      ),
      if (item.color.isNotEmpty)
        _Fact(icon: Icons.palette_outlined, label: '物品顏色', value: item.color),
      if (item.storageLocation.isNotEmpty)
        _Fact(
          icon: Icons.inventory_2_outlined,
          label: '保管地點',
          value: item.storageLocation,
        ),
      if (item.hasReward)
        _Fact(
          icon: Icons.payments_outlined,
          label: '酬謝金額',
          value: 'NT\$${item.reward}',
          valueColor: AppColors.reward,
        ),
      const SizedBox(height: 10),
      const Text(
        '物品描述',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        item.description.isEmpty ? '尚未補充描述，可透過私訊核對物品細節。' : item.description,
        style: const TextStyle(
          fontSize: 14,
          height: 1.8,
          color: AppColors.textSecondary,
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Divider(height: 1),
      ),
      Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 42,
              height: 42,
              child: item.userAvatar.isEmpty
                  ? Container(
                      color: AppColors.ink50,
                      alignment: Alignment.center,
                      child: Text(
                        item.userName.isEmpty
                            ? '訪'
                            : item.userName.characters.first,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    )
                  : ItemPhoto(item.userAvatar),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.userName.isEmpty ? '物品刊登者' : item.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.userVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  mock ? '示範刊登者' : '物品刊登者',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 18, color: AppColors.ink),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '先核對細節，再約定領回方式。\n請勿提供驗證碼或支付認領費用。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.ink700,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      ),
      if (mock)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            '體驗模式 · 示範內容，不是真實招領資訊',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      if (!mock && !mine)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _reportItem(item),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('檢舉這則刊登'),
          ),
        ),
      const SizedBox(height: 8),
    ],
  );

  Widget _cta(Item item, bool mine) => FilledButton.icon(
    onPressed: _busy || item.status != ItemStatus.active
        ? null
        : mine
        ? _resolve
        : _contact,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      minimumSize: const Size.fromHeight(54),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onPrimary,
            ),
          )
        : Icon(
            mine ? Icons.check_rounded : Icons.chat_bubble_outline_rounded,
            size: 19,
          ),
    label: Text(
      item.status != ItemStatus.active
          ? '這件物品已完成招領'
          : mine
          ? (item.type == ItemType.found ? '標記為已交還' : '標記為已找回')
          : item.type == ItemType.found
          ? '這可能是我的'
          : '我有線索',
    ),
  );
}

/// 照片輪播：第一張與列表卡共用 Hero，點照片進入全螢幕檢視。
class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.item,
    required this.controller,
    required this.index,
    required this.onChanged,
    required this.onOpen,
  });
  final Item item;
  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final images = item.images;
    final tag = 'item-photo-${item.id}';
    if (images.isEmpty) return Hero(tag: tag, child: ItemPhoto(null));
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: controller,
          itemCount: images.length,
          onPageChanged: onChanged,
          itemBuilder: (_, i) => Semantics(
            image: true,
            button: true,
            label: '第 ${i + 1} 張照片，共 ${images.length} 張',
            child: GestureDetector(
              onTap: () => onOpen(i),
              child: i == 0
                  ? Hero(tag: tag, child: ItemPhoto(images[i]))
                  : ItemPhoto(images[i]),
            ),
          ),
        ),
        if (images.length > 1) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.base),
                    curve: AppMotion.curve,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == index ? 1 : .55,
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 4),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.ink.light.withValues(alpha: .62),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${index + 1} / ${images.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 多張照片時的縮圖列：每格 56px，既是導覽也是可及性入口。
class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.images,
    required this.selected,
    required this.onSelect,
  });
  final List<String> images;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: images.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) => Semantics(
        button: true,
        selected: i == selected,
        label: '查看第 ${i + 1} 張照片',
        child: GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.base),
            curve: AppMotion.curve,
            width: 56,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                width: 2,
                color: i == selected ? AppColors.ink : Colors.transparent,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ItemPhoto(images[i]),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    // 浮在照片上，永遠用亮色模式的炭墨。
    this.color = const Color(0xFF282B30),
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .94),
    shape: const CircleBorder(),
    elevation: 1,
    shadowColor: const Color(0x33282B30),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      icon: Icon(icon, size: 21, color: color),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.actionLabel,
    this.valueColor,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  final String? actionLabel;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.ink50,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: AppColors.ink700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '未提供' : value,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
              if (onTap != null && actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: onTap == null
          ? row
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: row,
            ),
    );
  }
}

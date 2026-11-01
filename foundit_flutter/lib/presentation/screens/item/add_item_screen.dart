import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import 'location_picker_screen.dart';
import '../../../data/api/api_client.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/upload_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/items_provider.dart';
import '../../widgets/foundit_ui.dart';
import '../profile/collection_screen.dart';

class EditItemRoute extends ConsumerWidget {
  const EditItemRoute({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(itemDetailProvider(id))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('編輯刊登')),
          body: Center(
            child: TextButton(
              onPressed: () => ref.invalidate(itemDetailProvider(id)),
              child: const Text('載入失敗，點此重試'),
            ),
          ),
        ),
        data: (item) => item == null
            ? Scaffold(
                appBar: AppBar(title: const Text('編輯刊登')),
                body: const Center(child: Text('找不到這則刊登。')),
              )
            : AddItemScreen(key: ValueKey(item.id), editing: item),
      );
}

/// 三步刊登。照片以 bytes 預覽，直到發布時才上傳。
class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key, this.type = 'lost', this.editing});
  final String type;
  final Item? editing;
  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _itemForm = GlobalKey<FormState>();
  final _placeForm = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _storage = TextEditingController();
  final List<_DraftPhoto> _photos = [];
  late ItemType _type;
  int _step = 0;
  String? _category;
  String? _color;
  String _custody = '自行保管';
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _showCategoryError = false;
  bool _picking = false;
  bool _submitting = false;
  bool _openingLogin = false;
  String? _error;
  String _progress = '正在發布…';
  bool _acceptedTerms = false;
  bool _allowExit = false;
  bool get _editing => widget.editing != null;
  double? _pinLat;
  double? _pinLng;
  bool get _isFound => _type == ItemType.found;
  bool get _isMock => ref.read(useMockProvider);
  bool get _busy => _submitting || _openingLogin;

  @override
  void initState() {
    super.initState();
    _type = widget.type == 'found' ? ItemType.found : ItemType.lost;
    final item = widget.editing;
    if (item != null) {
      _type = item.type;
      _title.text = item.title;
      _description.text = item.description;
      _location.text = item.locationName;
      _category = item.category;
      _color = item.color;
      _date = DateUtils.dateOnly(item.lostAt);
      _storage.text = item.storageLocation;
      _custody = item.handedToPolice
          ? '已交給警察機關'
          : item.storageLocation.isNotEmpty && item.storageLocation != '自行保管'
          ? '已交給店家或站務人員'
          : '自行保管';
      if (item.hasMapPosition) {
        _pinLat = item.latitude;
        _pinLng = item.longitude;
      }
      _photos.addAll(item.images.map(_DraftPhoto.existing));
      _acceptedTerms = true;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _storage.dispose();
    super.dispose();
  }

  void _moveTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_step > 0) {
      _moveTo(_step - 1);
    } else if (_editing) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: const Text('放棄這次修改？'),
          content: const Text('尚未儲存的修改會取消，原本刊登不受影響。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('繼續編輯'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('放棄修改'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
      setState(() => _allowExit = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      context.canPop()
          ? context.pop()
          : context.go('/item/${widget.editing!.id}');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _next() async {
    if (_busy || _picking) return;
    if (_step == 0) {
      final valid = _itemForm.currentState?.validate() ?? false;
      setState(() => _showCategoryError = _category == null);
      if (!valid || _category == null) return;
      _moveTo(1);
    } else if (_step == 1) {
      if (!(_placeForm.currentState?.validate() ?? false)) return;
      if (!Item.validPosition(_pinLat, _pinLng)) {
        setState(() => _error = '請在地圖上確認大概位置，這則刊登才會顯示在地圖中。');
        await _pickOnMap();
        return;
      }
      if (_date.isAfter(DateTime.now())) {
        setState(() => _error = '日期不能晚於今天，請重新選擇。');
        return;
      }
      _moveTo(2);
    } else {
      await _submit();
    }
  }

  Future<void> _pickPhoto() async {
    if (_picking || _photos.length >= 5 || _busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      var source = ImageSource.gallery;
      if (!kIsWeb) {
        final selected = await showModalBottomSheet<ImageSource>(
          context: context,
          backgroundColor: AppColors.surface,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('從相簿選擇'),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('拍攝照片'),
                    onTap: () =>
                        Navigator.pop(sheetContext, ImageSource.camera),
                  ),
                ],
              ),
            ),
          ),
        );
        if (selected == null || !mounted) return;
        source = selected;
      }
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      if (await file.length() > 8 * 1024 * 1024) {
        if (mounted) setState(() => _error = '照片需小於 8 MB，請選擇較小的圖片。');
        return;
      }
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photos.add(_DraftPhoto(file, bytes)));
    } catch (_) {
      if (mounted) setState(() => _error = '無法讀取照片。請確認照片或相機權限，再試一次。');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: _isFound ? '選擇拾獲日期' : '選擇遺失日期',
      cancelText: '取消',
      confirmText: '確認',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickOnMap() async {
    final result = await context.push<LocationPickedResult>(
      '/location-picker',
      extra: {
        'query': _location.text.trim(),
        if (_pinLat != null) 'lat': _pinLat,
        if (_pinLng != null) 'lng': _pinLng,
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _pinLat = result.latitude;
      _pinLng = result.longitude;
      _error = null;
      if (result.address.trim().isNotEmpty) {
        _location.text = result.address.trim();
      }
    });
  }

  Future<void> _openLogin() async {
    if (_openingLogin) return;
    setState(() => _openingLogin = true);
    try {
      await context.push('/login');
    } finally {
      if (mounted) setState(() => _openingLogin = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!Item.validPosition(_pinLat, _pinLng)) {
      _moveTo(1);
      setState(() => _error = '請先確認地圖位置。');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = '請先閱讀並同意刊登規範。');
      return;
    }
    if (!_isMock && !ref.read(authProvider).isLoggedIn) {
      setState(() => _error = '登入後即可發布，讓對方能安全地與你聯絡。');
      await _openLogin();
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final upload = ref.read(uploadRepositoryProvider);
      for (var index = 0; index < _photos.length; index++) {
        final photo = _photos[index];
        if (photo.url != null) continue;
        setState(() => _progress = '正在處理照片 ${index + 1} / ${_photos.length}…');
        try {
          photo.url = await upload.uploadImageBytes(
            photo.bytes!,
            filename: photo.file!.name,
            mimeType: photo.file!.mimeType,
          );
        } on UploadRejected catch (rejected) {
          if (!mounted) return;
          setState(() => _error = '第 ${index + 1} 張照片：${rejected.message}');
          return;
        }
        if (!mounted) return;
        if (photo.url == null || photo.url!.isEmpty) {
          photo.url = null;
          setState(() => _error = '第 ${index + 1} 張照片上傳失敗。資料已保留，請檢查連線後重試。');
          return;
        }
      }
      setState(
        () => _progress = _editing
            ? '正在儲存修改…'
            : _isMock
            ? '正在建立體驗刊登…'
            : '正在發布…',
      );
      final now = DateTime.now();
      final user = ref.read(authProvider).user;
      final draft = Item(
        id: widget.editing?.id ?? '',
        type: _type,
        userId: user?.id ?? '',
        title: _title.text.trim(),
        category: _category!,
        color: _color ?? '',
        description: _description.text.trim(),
        images: _photos.map((photo) => photo.url!).toList(),
        latitude: _pinLat ?? 0,
        longitude: _pinLng ?? 0,
        locationName: _location.text.trim(),
        lostAt: _editing && DateUtils.isSameDay(widget.editing!.lostAt, _date)
            ? widget.editing!.lostAt
            : _date,
        storageLocation: _isFound
            ? (_custody == '自行保管' ? _custody : _storage.text.trim())
            : '',
        handedToPolice: _isFound && _custody == '已交給警察機關',
        reward: widget.editing?.reward ?? 0,
        hasReward: widget.editing?.hasReward ?? false,
        createdAt: now,
        updatedAt: now,
      );
      final created = _editing
          ? await ref.read(itemRepositoryProvider).update(draft)
          : await ref.read(createItemProvider.notifier).submit(draft);
      if (!mounted) return;
      if (created == null) {
        setState(
          () => _error = _editing
              ? '尚未儲存修改，請重試。'
              : _publishError(ref.read(createItemProvider).error),
        );
        return;
      }
      if (_isMock) {
        final prefs = ref.read(sharedPreferencesProvider);
        final ids = prefs.getStringList('foundit_my_item_ids') ?? [];
        if (!ids.contains(created.id)) {
          await prefs.setStringList('foundit_my_item_ids', [
            ...ids,
            created.id,
          ]);
        }
        if (!mounted) return;
      }
      ref.invalidate(collectionProvider(false));
      ref.invalidate(collectionProvider(true));
      if (!_editing) ref.invalidate(itemDetailProvider(created.id));
      ref.invalidate(itemsProvider);
      ref.invalidate(mapItemsProvider);
      ref.invalidate(itemStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? '刊登已更新。'
                : _isMock
                ? '體驗刊登已建立，僅在此裝置顯示。'
                : '刊登已發布，可以隨時回來更新資訊。',
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_editing && context.canPop()) {
        setState(() => _allowExit = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) context.pop(created);
      } else {
        context.go('/item/${created.id}', extra: created);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _editing
              ? (error is DioException && error.response?.statusCode == 401
                    ? '登入已逾時，請重新登入後再儲存。'
                    : _editError(error))
              : _publishError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _editError(Object? error) {
    final status = error is DioException ? error.response?.statusCode ?? 0 : 0;
    final message = apiErrorMessage(error);
    if (status >= 400 && status < 500 && message != null) {
      return '$message。輸入已保留，修改後再儲存。';
    }
    return '修改尚未儲存。輸入已保留，請檢查連線後重試。';
  }

  String _publishError(Object? error) {
    if (error is DioException) {
      if (error.response?.statusCode == 401) return '登入已逾時，請重新登入後再發布。';
      if (error.response?.statusCode == 413) return '照片太大，請返回第一步更換較小的照片。';
      final status = error.response?.statusCode ?? 0;
      final message = apiErrorMessage(error);
      if (status >= 400 && status < 500 && message != null) {
        return '$message。資料已保留，修改後再發布。';
      }
    }
    return '暫時無法發布。資料已保留，請確認網路連線後重試。';
  }

  @override
  Widget build(BuildContext context) {
    final isMock = ref.watch(useMockProvider);
    final loggedIn = isMock || ref.watch(authProvider).isLoggedIn;
    if (_editing &&
        (widget.editing!.status != ItemStatus.active ||
            widget.editing!.userId !=
                (isMock ? 'me' : ref.watch(authProvider).user?.id))) {
      return Scaffold(
        appBar: AppBar(title: const Text('編輯刊登')),
        body: const Center(child: Text('只有發布者可以編輯尚未結束的刊登。')),
      );
    }
    final label = _busy
        ? (_openingLogin ? '前往登入…' : _progress)
        : _step < 2
        ? (_step == 0 ? '下一步：地點與時間' : '下一步：確認內容')
        : !loggedIn
        ? '登入後發布'
        : _editing
        ? '儲存修改'
        : isMock
        ? '建立體驗刊登'
        : '確認發布';
    return PopScope<Object?>(
      canPop: _allowExit || (!_editing && _step == 0 && !_busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              // The entire form can scroll when a keyboard or large text leaves
              // too little height for pinned chrome. Buttons keep their tap area.
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    sliver: SliverToBoxAdapter(
                      child: AbsorbPointer(
                        absorbing: _busy,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isMock) ...[
                              const _Notice(
                                icon: Icons.visibility_outlined,
                                text: '體驗模式 · 刊登僅儲存在此裝置，不會同步或發布給其他使用者。',
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (_step == 0) _itemStep(),
                            if (_step == 1) _placeStep(),
                            if (_step == 2) _reviewStep(loggedIn),
                            if (_error != null) ...[
                              const SizedBox(height: 20),
                              Semantics(
                                liveRegion: true,
                                child: _Notice(
                                  icon: Icons.info_outline_rounded,
                                  text: _error!,
                                  isError: true,
                                ),
                              ),
                              if (_error!.contains('重新登入'))
                                TextButton(
                                  onPressed: _busy ? null : _openLogin,
                                  child: const Text('重新登入'),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _footer(label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(String label) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Builder(
      builder: (context) {
        final stack =
            MediaQuery.sizeOf(context).width < 428 &&
            MediaQuery.textScalerOf(context).scale(14) > 19;
        final next = FilledButton(
          onPressed: _busy || _picking ? null : _next,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_busy) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (!_busy) ...[
                const SizedBox(width: 8),
                Icon(
                  _step == 2
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                ),
              ],
            ],
          ),
        );
        final back = OutlinedButton(
          onPressed: _busy ? null : _back,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(80, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('上一步'),
        );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              next,
              if (_step > 0) ...[const SizedBox(height: 10), back],
            ],
          );
        }
        return Row(
          children: [
            if (_step > 0) ...[back, const SizedBox(width: 12)],
            Expanded(child: next),
          ],
        );
      },
    ),
  );

  Widget _header() {
    final steps = ['物品資訊', '地點時間', _editing ? '確認修改' : '確認發布'];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _step == 0 ? (_editing ? '返回原刊登' : '返回探索') : '回到上一步',
                onPressed: _busy ? null : _back,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  _editing ? '編輯刊登' : '建立刊登',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_step + 1} / 3',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 三段進度條：完成的段落填滿陶土色，一眼看出還剩幾步。
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index < 2 ? 6 : 0),
                      child: AnimatedContainer(
                        duration: AppMotion.of(context, AppMotion.base),
                        curve: AppMotion.curve,
                        height: 4,
                        decoration: BoxDecoration(
                          color: index <= _step
                              ? AppColors.primary
                              : AppColors.ink100,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Text(
                      steps[index],
                      textAlign: index == 0
                          ? TextAlign.left
                          : index == 1
                          ? TextAlign.center
                          : TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        color: index == _step
                            ? AppColors.ink
                            : AppColors.textTertiary,
                        fontWeight: index == _step
                            ? FontWeight.w700
                            : FontWeight.w500,
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

  Widget _itemStep() => Form(
    key: _itemForm,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 撿到的物品若掛著 FOUND !T 防丟牌，掃描就能直接聯絡物主，不必刊登。
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.base),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: _isFound && !_editing
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _scanTagHint(),
                )
              : const SizedBox(width: double.infinity),
        ),
        const _StepHeading('物品資訊', '新增照片，讓物品更容易被認出。'),
        const _FieldLabel('物品照片', optional: true),
        _photoPicker(),
        const SizedBox(height: 10),
        const Text(
          '最多 5 張。請遮住證件號碼、電話等個人資料。',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Divider(height: 1, color: AppColors.divider),
        ),
        const _FieldLabel('刊登類型'),
        if (_editing)
          Text('${_type.label}（刊登後無法變更類型）')
        else
          Row(
            children: [
              Expanded(
                child: _typeOption(
                  ItemType.lost,
                  Icons.search_rounded,
                  '我遺失了物品',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _typeOption(
                  ItemType.found,
                  Icons.volunteer_activism_outlined,
                  '我撿到了物品',
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        const _FieldLabel('物品名稱'),
        TextFormField(
          key: const ValueKey('publish-title'),
          controller: _title,
          maxLength: _editing ? 100 : 80,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: _decoration('例如：深棕色皮夾、銀色鑰匙圈'),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? '請填寫物品名稱。' : null,
        ),
        const SizedBox(height: 12),
        const _FieldLabel('物品分類'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.itemCategories
              .map(
                (category) => _Choice(
                  label: category.name,
                  selected: _category == category.name,
                  onTap: () => setState(() {
                    _category = category.name;
                    _showCategoryError = false;
                  }),
                ),
              )
              .toList(),
        ),
        if (_showCategoryError)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '請選擇一個物品分類。',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 28),
        const _FieldLabel('主要顏色', optional: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.itemColors
              .map(
                (color) => _Choice(
                  label: color,
                  selected: _color == color,
                  onTap: () =>
                      setState(() => _color = _color == color ? null : color),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        const _FieldLabel('補充描述', optional: true),
        TextFormField(
          controller: _description,
          minLines: 3,
          maxLines: 5,
          maxLength: _editing ? 2000 : 500,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            height: 1.6,
          ),
          decoration: _decoration('品牌、外觀或明顯特徵。保留一個只有失主知道的細節，供私下核對。'),
        ),
      ],
    ),
  );

  /// 撿到模式的小提示：整張卡片可點，直接開啟防丟牌掃描。保持低調，不搶表單焦點。
  Widget _scanTagHint() => Pressable(
    key: const ValueKey('found-scan-hint'),
    onTap: () => context.push('/qr/scan'),
    semanticLabel: '掃描防丟牌',
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '物品上有 FOUND !T 防丟牌？',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '直接掃描，就能傳訊息給物主，不必刊登。',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ],
      ),
    ),
  );

  Widget _typeOption(ItemType type, IconData icon, String label) {
    final selected = _type == type;
    // 遺失＝炭墨、撿到＝陶土，與首頁入口及狀態標籤同一套顏色。
    final accent = type == ItemType.lost ? AppColors.ink : AppColors.primary;
    final onAccent = type == ItemType.lost
        ? AppColors.onInk
        : AppColors.onPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? accent : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => setState(() => _type = type),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? accent : AppColors.divider),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected ? onAccent : AppColors.textSecondary,
                  size: 21,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? onAccent : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    final addLabel = _picking ? '讀取中…' : '新增照片';
    final counter = '${_photos.length} / 5';
    const spinner = SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.primary,
      ),
    );
    if (_photos.isEmpty) {
      // 第一張照片是最重要的欄位：用整寬的角括號框，邀請使用者放進來。
      return Pressable(
        onTap: _picking ? null : _pickPhoto,
        semanticLabel: addLabel,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 168),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BracketMark(
                size: 64,
                color: AppColors.primary300,
                strokeWidth: 2.6,
                child: _picking
                    ? spinner
                    : const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                addLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!_picking) ...[
                const SizedBox(height: 4),
                Text(
                  '第一張會成為封面 · $counter',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (index, photo) in _photos.indexed)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: photo.bytes == null
                    ? SizedBox(
                        width: 100,
                        height: 100,
                        child: ItemPhoto(photo.url),
                      )
                    : Image.memory(
                        photo.bytes!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 100,
                          height: 100,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
              ),
              if (index == 0)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '封面',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF282B30), // 疊在照片上，固定亮色模式的炭墨
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  tooltip: '移除照片',
                  onPressed: () => setState(() => _photos.remove(photo)),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.ink.withValues(alpha: 0.78),
                    foregroundColor: AppColors.onInk,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ],
          ),
        if (_photos.length < 5)
          Material(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _picking ? null : _pickPhoto,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 100,
                constraints: const BoxConstraints(minHeight: 100),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary200),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_picking)
                      spinner
                    else
                      const Icon(
                        Icons.add_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      addLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!_picking)
                      Text(
                        counter,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeStep() => Form(
    key: _placeForm,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeading('地點與時間', _isFound ? '填寫拾獲地點、日期與保管方式。' : '填寫最後看見物品的地點與日期。'),
        _FieldLabel(_isFound ? '拾獲地點' : '遺失地點'),
        TextFormField(
          key: const ValueKey('publish-location'),
          controller: _location,
          onChanged: (_) => setState(() {
            _pinLat = null;
            _pinLng = null;
          }),
          maxLength: 200,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: _decoration('例如：台北市中山區・雙連站 1 號出口').copyWith(
            prefixIcon: const Icon(
              Icons.place_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? '請填寫地點，讓附近的人更容易找到。' : null,
        ),
        const Text(
          '填寫地名後，請在地圖上確認大概位置。可選附近路口或地標，避免公開私人住址。',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pickOnMap,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(_pinLat == null ? '確認地圖位置（必填）' : '已標示地圖位置，可重新選擇'),
          ),
        ),
        const SizedBox(height: 28),
        _FieldLabel(_isFound ? '拾獲日期' : '遺失日期'),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dateLabel,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '不確定時，選擇最接近的日期即可。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        if (_isFound) ...[
          const SizedBox(height: 32),
          const _FieldLabel('目前由誰保管？'),
          for (final option in ['自行保管', '已交給店家或站務人員', '已交給警察機關']) ...[
            const SizedBox(height: 8),
            _custodyOption(option),
          ],
          if (_custody != '自行保管') ...[
            const SizedBox(height: 20),
            const _FieldLabel('保管單位名稱'),
            TextFormField(
              key: const ValueKey('publish-storage'),
              controller: _storage,
              maxLength: _editing ? 200 : 100,
              decoration: _decoration(
                _custody == '已交給警察機關' ? '例如：中山一派出所' : '例如：雙連站服務台',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? '請填寫保管單位，方便失主詢問。' : null,
            ),
          ],
        ],
        const SizedBox(height: 28),
        const _Notice(
          icon: Icons.lock_outline_rounded,
          text: '保留一個未公開的物品特徵，聯絡時再核對，讓物品安心回到主人身邊。',
        ),
      ],
    ),
  );

  Widget _custodyOption(String option) {
    final selected = _custody == option;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary50 : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _custody = option),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 21,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _dateLabel => '${_date.year} 年 ${_date.month} 月 ${_date.day} 日';

  Widget _reviewStep(bool loggedIn) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepHeading(
        _editing ? '確認修改內容' : '確認刊登內容',
        _editing ? '儲存後會更新原本刊登，已有對話保持不變。' : '確認物品資訊後，即可完成刊登。',
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    _isFound ? '待認領' : '協尋中',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _moveTo(0),
                  child: const Text(
                    '修改物品',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _title.text.trim(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              [_category!, if (_color != null) _color!].join('  ·  '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _photos[index].bytes == null
                        ? SizedBox(
                            width: 110,
                            height: 110,
                            child: ItemPhoto(_photos[index].url),
                          )
                        : Image.memory(
                            _photos[index].bytes!,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 110,
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
              ),
            ],
            if (_description.text.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _description.text.trim(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            _reviewRow(Icons.place_outlined, _location.text.trim()),
            const SizedBox(height: 14),
            _reviewRow(Icons.calendar_today_outlined, _dateLabel),
            if (_isFound) ...[
              const SizedBox(height: 14),
              _reviewRow(
                Icons.inventory_2_outlined,
                _custody == '自行保管'
                    ? _custody
                    : '$_custody・${_storage.text.trim()}',
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _moveTo(1),
                child: const Text(
                  '修改地點與時間',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _acceptedTerms,
        onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('我已閱讀並同意刊登規範'),
        subtitle: const Text('刊登前需同意：不得公開證件號碼、私人住址或他人聯絡方式。'),
      ),
      _Notice(
        icon: loggedIn ? Icons.public_outlined : Icons.person_outline_rounded,
        text: _isMock
            ? '這是體驗刊登，不會發布給其他使用者，也不會發送通知。'
            : loggedIn
            ? '以上內容會公開顯示。請確認照片與描述未包含電話、證件號碼或私人住址。'
            : '登入後即可發布，讓對方能安全地與你聯絡。以上內容將公開顯示。',
      ),
    ],
  );

  Widget _reviewRow(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    ],
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 14,
      height: 1.6,
    ),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorMaxLines: 6,
  );
}

class _DraftPhoto {
  _DraftPhoto(this.file, this.bytes);
  _DraftPhoto.existing(this.url) : file = null, bytes = null;
  final XFile? file;
  final Uint8List? bytes;
  String? url;
}

class _StepHeading extends StatelessWidget {
  const _StepHeading(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 23,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.7,
          ),
        ),
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.optional = false});
  final String text;
  final bool optional;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (optional)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text(
              '選填',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.primary50 : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.isError = false});
  final IconData icon;
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isError ? AppColors.error50 : AppColors.primary50,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: isError ? AppColors.error : AppColors.textSecondary,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isError ? AppColors.error : AppColors.textSecondary,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ),
      ],
    ),
  );
}

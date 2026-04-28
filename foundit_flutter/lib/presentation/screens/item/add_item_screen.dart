import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/item.dart';
import '../../providers/core_providers.dart';
import '../../providers/items_provider.dart';
import '../../widgets/gradient_button.dart';
import 'location_picker_screen.dart';

/// 新增遺失物／撿到物 — 步驟式表單（1/3 類型，2/3 詳情，3/3 地點）
class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key, this.type = 'lost'});
  final String type;

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  int _step = 0;
  late ItemType _type;
  String? _category;
  String? _color;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _hasReward = false;
  double _reward = 500;
  DateTime _lostAt = DateTime.now();

  /// 使用者授權後取得的座標；未取得時為 null。
  /// 提交時若為 null，會送 0/0，後端不會把它放進地圖範圍查詢結果。
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;

  /// 已選但尚未上傳的本地照片（最多 5 張）
  final List<XFile> _picked = [];

  /// 上傳完成後得到的後端 URL（與 _picked 一一對應）
  final List<String?> _uploadedUrls = [];

  /// 正在上傳中的 index 集合，UI 顯示 loading
  final Set<int> _uploading = {};

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.type == 'found' ? ItemType.found : ItemType.lost;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_picked.length >= 5) {
      AppSnackbar.error(context, '最多 5 張照片');
      return;
    }
    Haptics.light();
    final picker = ImagePicker();
    // 提供使用者選相機 / 相簿
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImageSourceSheet(),
    );
    if (source == null) return;

    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    final index = _picked.length;
    setState(() {
      _picked.add(file);
      _uploadedUrls.add(null);
      _uploading.add(index);
    });

    final url = await ref.read(uploadRepositoryProvider).uploadImage(
          File(file.path),
        );
    if (!mounted) return;
    setState(() {
      _uploading.remove(index);
      _uploadedUrls[index] = url;
    });
    if (url == null) {
      AppSnackbar.error(context, '第 ${index + 1} 張照片上傳失敗');
    }
  }

  void _removeImage(int i) {
    Haptics.select();
    setState(() {
      _picked.removeAt(i);
      _uploadedUrls.removeAt(i);
      // _uploading 中比 i 大的索引要往前位移
      final newSet = <int>{};
      for (final idx in _uploading) {
        if (idx == i) continue;
        newSet.add(idx > i ? idx - 1 : idx);
      }
      _uploading
        ..clear()
        ..addAll(newSet);
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    final result =
        await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() => _gettingLocation = false);

    if (!result.isOk || result.position == null) {
      AppSnackbar.error(context, result.message);
      return;
    }
    setState(() {
      _latitude = result.position!.latitude;
      _longitude = result.position!.longitude;
    });
    AppSnackbar.success(context, '已取得目前位置');
  }

  Future<void> _pickFromMap() async {
    Haptics.light();
    final result = await context.push<LocationPickedResult>(
      '/location-picker',
      extra: {
        'lat': _latitude,
        'lng': _longitude,
        'query': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      if (result.address.isNotEmpty) {
        _locationCtrl.text = result.address;
      }
    });
    AppSnackbar.success(context, '已選擇地點');
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _lostAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_lostAt),
    );
    if (time == null) return;
    setState(() {
      _lostAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _next() async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    if (_uploading.isNotEmpty) {
      AppSnackbar.error(context, '照片還在上傳中，請稍候…');
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);

    final urls = _uploadedUrls.whereType<String>().toList();
    final draft = Item(
      id: '',
      type: _type,
      title: _titleCtrl.text.trim(),
      category: _category ?? '其他',
      description: _descCtrl.text.trim(),
      color: _color ?? '',
      images: urls,
      latitude: _latitude ?? 0,
      longitude: _longitude ?? 0,
      locationName: _locationCtrl.text.trim(),
      lostAt: _lostAt,
      hasReward: _hasReward,
      reward: _hasReward ? _reward.toInt() : 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created = await ref.read(createItemProvider.notifier).submit(draft);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (created == null) {
      final err = ref.read(createItemProvider).error;
      AppSnackbar.error(context, '發佈失敗：${_humanizeError(err)}');
      return;
    }

    Haptics.light();
    AppSnackbar.success(context, '已發佈到社群，謝謝你！');

    // 通知首頁與搜尋頁刷新
    ref.invalidate(itemsProvider);
    ref.invalidate(itemStatsProvider);

    if (mounted) context.pop(created);
  }

  String _humanizeError(Object? e) {
    if (e == null) return '請檢查網路或稍後再試';
    if (e is DioException) {
      final code = e.response?.statusCode;
      // 從後端 AllExceptionsFilter 統一回傳 { success, statusCode, message }
      final body = e.response?.data;
      String? backendMsg;
      if (body is Map) {
        final m = body['message'];
        if (m is String) backendMsg = m;
        if (m is List && m.isNotEmpty) backendMsg = m.first.toString();
      }
      if (code == 401) return '請先登入';
      if (code == 413) return '檔案過大，請壓縮後再試';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return '無法連線到伺服器，請確認網路或後端 IP';
      }
      if (backendMsg != null && backendMsg.isNotEmpty) return backendMsg;
      return '伺服器回傳 $code';
    }
    final s = e.toString();
    if (s.contains('connection') || s.contains('Network')) {
      return '無法連線到伺服器';
    }
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: _step, onBack: _back),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: c,
                  ),
                ),
                child: _buildStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: GradientButton(
                key: ValueKey(_step),
                label: _submitting
                    ? '發佈中…'
                    : _step == 2
                        ? '發佈'
                        : '下一步',
                icon: _submitting
                    ? null
                    : _step == 2
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                onPressed:
                    !_submitting && _canNext() ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canNext() {
    switch (_step) {
      case 0:
        return true;
      case 1:
        return _titleCtrl.text.trim().isNotEmpty && _category != null;
      case 2:
        return true;
      default:
        return true;
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepType(
          key: const ValueKey('s0'),
          selected: _type,
          onChange: (t) => setState(() => _type = t),
        );
      case 1:
        return _StepDetail(
          key: const ValueKey('s1'),
          titleCtrl: _titleCtrl,
          descCtrl: _descCtrl,
          category: _category,
          color: _color,
          picked: _picked,
          uploadedUrls: _uploadedUrls,
          uploading: _uploading,
          onAddPhoto: _pickImage,
          onRemovePhoto: _removeImage,
          onCategory: (v) => setState(() => _category = v),
          onColor: (v) => setState(() => _color = v),
          onChanged: () => setState(() {}),
        );
      case 2:
        return _StepLocation(
          key: const ValueKey('s2'),
          locationCtrl: _locationCtrl,
          lostAt: _lostAt,
          hasReward: _hasReward,
          reward: _reward,
          latitude: _latitude,
          longitude: _longitude,
          gettingLocation: _gettingLocation,
          onUseCurrentLocation: _useCurrentLocation,
          onPickFromMap: _pickFromMap,
          onPickTime: _pickDateTime,
          onRewardToggle: (v) => setState(() => _hasReward = v),
          onRewardChange: (v) => setState(() => _reward = v),
          onChanged: () => setState(() {}),
        );
      default:
        return const SizedBox();
    }
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.allLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('新增照片',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.primary),
              title: const Text('打開相機'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary),
              title: const Text('從相簿選擇'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, required this.onBack});
  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const total = 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
          ),
          Expanded(
            child: Row(
              children: List.generate(total, (i) {
                final active = i <= step;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.neutral200,
                      borderRadius: AppRadius.allRound,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${step + 1} / $total',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepType extends StatelessWidget {
  const _StepType({super.key, required this.selected, required this.onChange});
  final ItemType selected;
  final ValueChanged<ItemType> onChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('這是…', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text('請選擇要登記的類型',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          _TypeCard(
            type: ItemType.lost,
            title: '我遺失了東西',
            subtitle: '幫助尋找、發佈懸賞',
            gradient: AppColors.sunsetGradient,
            icon: Icons.search_rounded,
            selected: selected == ItemType.lost,
            onTap: () => onChange(ItemType.lost),
          ),
          const SizedBox(height: 14),
          _TypeCard(
            type: ItemType.found,
            title: '我撿到了東西',
            subtitle: '讓失主快點聯繫到您',
            gradient: AppColors.mintGradient,
            icon: Icons.handshake_rounded,
            selected: selected == ItemType.found,
            onTap: () => onChange(ItemType.found),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ItemType type;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: AppRadius.allLg,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: (type == ItemType.lost
                            ? AppColors.lost
                            : AppColors.found)
                        .withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: selected ? 3 : 0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: AppRadius.allMd,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      )),
                  Text(subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                      )),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDetail extends StatelessWidget {
  const _StepDetail({
    super.key,
    required this.titleCtrl,
    required this.descCtrl,
    required this.category,
    required this.color,
    required this.picked,
    required this.uploadedUrls,
    required this.uploading,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onCategory,
    required this.onColor,
    required this.onChanged,
  });

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String? category;
  final String? color;
  final List<XFile> picked;
  final List<String?> uploadedUrls;
  final Set<int> uploading;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onColor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('描述一下',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text('越詳細越容易配對到',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _PhotoPicker(
            picked: picked,
            uploadedUrls: uploadedUrls,
            uploading: uploading,
            onAdd: onAddPhoto,
            onRemove: onRemovePhoto,
          ),
          const SizedBox(height: 20),
          _Label('標題'),
          const SizedBox(height: 8),
          TextField(
            controller: titleCtrl,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(hintText: '例：黑色皮夾'),
          ),
          const SizedBox(height: 20),
          _Label('分類'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.itemCategories.map((c) {
              final sel = c.name == category;
              return _WrapChip(
                label: '${c.emoji} ${c.name}',
                selected: sel,
                onTap: () => onCategory(c.name),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _Label('顏色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.itemColors.map((c) {
              final sel = c == color;
              return _WrapChip(
                label: c,
                selected: sel,
                onTap: () => onColor(c),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _Label('詳細描述'),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => onChanged(),
            decoration:
                const InputDecoration(hintText: '外觀特徵、品牌、內容物等…'),
          ),
        ],
      ),
    );
  }
}

class _StepLocation extends StatelessWidget {
  const _StepLocation({
    super.key,
    required this.locationCtrl,
    required this.lostAt,
    required this.hasReward,
    required this.reward,
    required this.latitude,
    required this.longitude,
    required this.gettingLocation,
    required this.onUseCurrentLocation,
    required this.onPickFromMap,
    required this.onPickTime,
    required this.onRewardToggle,
    required this.onRewardChange,
    required this.onChanged,
  });

  final TextEditingController locationCtrl;
  final DateTime lostAt;
  final bool hasReward;
  final double reward;
  final double? latitude;
  final double? longitude;
  final bool gettingLocation;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPickFromMap;
  final VoidCallback onPickTime;
  final ValueChanged<bool> onRewardToggle;
  final ValueChanged<double> onRewardChange;
  final VoidCallback onChanged;

  String _formatDateTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${t.year}/${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('地點與時間',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text('最後看到 / 撿到的位置',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          _Label('地點'),
          const SizedBox(height: 8),
          TextField(
            controller: locationCtrl,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: '例：台北車站 M3 出口、忠孝復興捷運站、新光三越 A11…',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: AppColors.primary50,
                  borderRadius: AppRadius.allMd,
                  child: InkWell(
                    borderRadius: AppRadius.allMd,
                    onTap: onPickFromMap,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.map_rounded,
                              color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '在地圖上選擇 / 搜尋',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            color: latitude != null
                ? AppColors.found50
                : AppColors.surfaceSoft,
            borderRadius: AppRadius.allMd,
            child: InkWell(
              borderRadius: AppRadius.allMd,
              onTap: gettingLocation ? null : onUseCurrentLocation,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    if (gettingLocation)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      Icon(
                        latitude != null
                            ? Icons.check_circle_rounded
                            : Icons.my_location_rounded,
                        color: latitude != null
                            ? AppColors.found
                            : AppColors.primary,
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        gettingLocation
                            ? '正在取得位置…'
                            : latitude != null
                                ? '已選位置：${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}'
                                : '使用我目前的位置（建議啟用）',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: latitude != null
                              ? AppColors.found
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (latitude == null && !gettingLocation)
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Label('時間'),
          const SizedBox(height: 8),
          Material(
            color: AppColors.surfaceSoft,
            borderRadius: AppRadius.allMd,
            child: InkWell(
              onTap: onPickTime,
              borderRadius: AppRadius.allMd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(_formatDateTime(lostAt),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        )),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.rewardGradient,
              borderRadius: AppRadius.allLg,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('懸賞',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              )),
                          Text('提高被找回的機率',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ),
                    Switch(
                      value: hasReward,
                      onChanged: onRewardToggle,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                if (hasReward) ...[
                  Row(
                    children: [
                      const Text('NT\$',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 6),
                      Text(
                        reward.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      min: 100,
                      max: 10000,
                      divisions: 99,
                      value: reward,
                      onChanged: onRewardChange,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.picked,
    required this.uploadedUrls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> picked;
  final List<String?> uploadedUrls;
  final Set<int> uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final hasAny = picked.isNotEmpty;
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add button
          Material(
            color: AppColors.primary50,
            borderRadius: AppRadius.allMd,
            child: InkWell(
              borderRadius: AppRadius.allMd,
              onTap: onAdd,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.allMd,
                  border: Border.all(
                    color: AppColors.primary200,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.primary,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasAny ? '加更多' : '新增照片',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${picked.length}/5',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (int i = 0; i < picked.length; i++) ...[
            const SizedBox(width: 10),
            _PhotoTile(
              file: picked[i],
              uploadedUrl: uploadedUrls[i],
              isUploading: uploading.contains(i),
              onRemove: () => onRemove(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.file,
    required this.uploadedUrl,
    required this.isUploading,
    required this.onRemove,
  });

  final XFile file;
  final String? uploadedUrl;
  final bool isUploading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(borderRadius: AppRadius.allMd),
          child: _buildPreview(),
        ),
        if (isUploading)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: AppRadius.allMd,
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (!isUploading && uploadedUrl == null)
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: AppRadius.allMd,
            ),
            alignment: Alignment.center,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '上傳失敗\n請刪除重試',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    // 一律用本地檔案做預覽（最快、最可靠）。
    // 上傳成功與否只影響「能否提交」，不影響預覽顯示。
    return Image.file(
      File(file.path),
      fit: BoxFit.cover,
      width: 120,
      height: 120,
      errorBuilder: (_, __, ___) => Container(
        width: 120,
        height: 120,
        color: AppColors.neutral100,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textTertiary),
      ),
    );
  }
}

class _WrapChip extends StatelessWidget {
  const _WrapChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceSoft,
      borderRadius: AppRadius.allRound,
      child: InkWell(
        borderRadius: AppRadius.allRound,
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

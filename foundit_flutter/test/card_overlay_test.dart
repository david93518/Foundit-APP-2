import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/widgets/foundit_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 回歸：iPhone 清單卡的照片只有 104px 寬，收藏鈕的圓壓在「協尋中」的「中」上。
// 這裡在各種照片寬度與字級下量實際位置，確認圓與任何標籤都不重疊。

final _now = DateTime(2026, 10, 1, 9);

Item _item(
  String id,
  ItemType type, {
  ItemStatus status = ItemStatus.active,
  int reward = 0,
}) => Item(
  id: id,
  type: type,
  title: '黑色皮革長夾 $id',
  category: '錢包',
  locationName: '台北車站 M3 出口',
  lostAt: _now,
  reward: reward,
  hasReward: reward > 0,
  status: status,
  createdAt: _now,
  updatedAt: _now,
);

final _items = [
  _item('lost', ItemType.lost, reward: 1500),
  _item('found', ItemType.found),
  _item('done', ItemType.lost, status: ItemStatus.resolved, reward: 300),
];

final _ring = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
      w.constraints?.maxWidth == 36,
);

Future<void> _pumpCard(
  WidgetTester tester,
  Item item, {
  required double width,
  required bool horizontal,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        useMockProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: FoundItemCard(item: item, horizontal: horizontal),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 量出照片、狀態、酬謝與收藏鈕的圓，並檢查彼此不重疊、都在照片內。
({Rect photo, Rect status, Rect ring, Rect? reward}) _expectApart(
  WidgetTester tester,
  Item item,
  String label,
) {
  expect(tester.takeException(), isNull, reason: label);
  final photo = tester.getRect(find.byType(ItemPhoto));
  final status = tester.getRect(find.byType(StatusTag));
  final ring = tester.getRect(_ring);
  // 極端情況下酬謝會收起來（不畫也不能點），只檢查畫出來的那個。
  final rewardText = find.textContaining('酬謝').hitTestable();
  final reward = rewardText.evaluate().isEmpty
      ? null
      : tester.getRect(
          find.ancestor(of: rewardText, matching: find.byType(Container)).first,
        );
  expect(ring.size, const Size.square(36), reason: label);
  expect(
    status.overlaps(ring),
    isFalse,
    reason: '$label: status $status overlaps bookmark $ring',
  );
  if (reward != null) {
    expect(
      reward.overlaps(ring),
      isFalse,
      reason: '$label: reward $reward overlaps bookmark $ring',
    );
    expect(
      reward.overlaps(status),
      isFalse,
      reason: '$label: reward $reward overlaps status $status',
    );
  }
  for (final rect in [status, ring, ?reward]) {
    expect(
      photo.expandToInclude(rect),
      photo,
      reason: '$label: $rect leaves the photo $photo',
    );
  }
  // 看得見的圓可以小，但觸控區要維持 48px。
  final hit = tester.getSize(find.byTooltip('收藏 ${item.title}'));
  expect(hit.width, greaterThanOrEqualTo(48), reason: label);
  expect(hit.height, greaterThanOrEqualTo(48), reason: label);
  return (photo: photo, status: status, ring: ring, reward: reward);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('NotoSansTC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansTC.ttf'));
    await font.load();
  });

  testWidgets('list card: 104px photo keeps 協尋中 readable and tappable', (
    tester,
  ) async {
    final item = _items.first;
    await _pumpCard(tester, item, width: 358, horizontal: true);
    final rects = _expectApart(tester, item, 'horizontal 1.0');
    expect(rects.photo.width, 104);
    // 標籤完整顯示，不是靠截斷來避開按鈕。
    final label = tester.renderObject<RenderParagraph>(find.text('協尋中'));
    expect(label.didExceedMaxLines, isFalse);
    // 窄照片時收藏鈕移到右下，仍然按得到。
    expect(rects.ring.top, greaterThan(rects.status.bottom));
    await tester.tapAt(rects.ring.center);
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏 ${item.title}'), findsOneWidget);
  });

  testWidgets('wide grid photo keeps the bookmark at the top right', (
    tester,
  ) async {
    final item = _items.first;
    await _pumpCard(tester, item, width: 220, horizontal: false);
    final rects = _expectApart(tester, item, 'grid 220 1.0');
    expect(rects.ring.top, lessThan(rects.status.bottom));
    expect(rects.ring.right, closeTo(rects.photo.right - 8, .5));
    // 酬謝維持在左下。
    expect(rects.reward!.bottom, closeTo(rects.photo.bottom - 10, .5));
  });

  for (final scale in [1.0, 1.3, 2.0, 3.0]) {
    testWidgets('status, reward and bookmark never collide at ${scale}x text', (
      tester,
    ) async {
      for (final item in _items) {
        for (final (width, horizontal) in [
          (358.0, true),
          (72.0, false),
          (120.0, false),
          (150.0, false),
          (165.0, false),
          (220.0, false),
        ]) {
          await _pumpCard(
            tester,
            item,
            width: width,
            horizontal: horizontal,
            scale: scale,
          );
          final label =
              '${item.id} ${horizontal ? 'list' : 'grid'} $width @ ${scale}x';
          final rects = _expectApart(tester, item, label);
          // 一般手機尺寸與常見的放大字級下，標籤完整、酬謝也照樣顯示。
          if (scale <= 1.3 && (horizontal || width >= 150)) {
            final text = tester.renderObject<RenderParagraph>(
              find.text(itemStatusLabel(item)),
            );
            expect(text.didExceedMaxLines, isFalse, reason: label);
            if (item.hasReward) expect(rects.reward, isNotNull, reason: label);
          }
        }
      }
    });
  }
}

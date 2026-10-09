import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/data/repositories/item_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'local create, resolve and delete survive repository recreation',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var repo = MockItemRepository(prefs: prefs);
      final now = DateTime(2026, 10, 3, 12);
      final created = await repo.create(
        Item(
          id: '',
          type: ItemType.found,
          title: '藍色水壺',
          category: '其他',
          description: '公園長椅旁找到',
          color: '藍色',
          images: const ['assets/images/tote.jpg'],
          latitude: 25.03,
          longitude: 121.53,
          locationName: '台北市大安區・公園',
          lostAt: now,
          storageLocation: '服務台',
          handedToPolice: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final id = created!.id;

      repo = MockItemRepository(prefs: prefs);
      final restored = await repo.detail(id);
      expect(restored?.userId, 'me');
      expect(restored?.title, '藍色水壺');
      expect(restored?.lostAt, now);
      expect(restored?.images, ['assets/images/tote.jpg']);
      expect(restored?.latitude, 25.03);
      expect(restored?.storageLocation, '服務台');
      expect(restored?.handedToPolice, isTrue);
      final located = await repo.updateLocation(id, 22.998, 120.217, '成大光復校區');
      expect(located?.hasMapPosition, isTrue);
      repo = MockItemRepository(prefs: prefs);
      expect((await repo.detail(id))?.latitude, 22.998);
      expect((await repo.detail(id))?.locationName, '成大光復校區');
      expect((await repo.detail(id))?.storageLocation, '服務台');
      expect(
        await repo.updateLocation('not-owned', 22.99, 120.21, '成大'),
        isNull,
      );

      expect(await repo.resolve(id), isTrue);
      repo = MockItemRepository(prefs: prefs);
      expect((await repo.detail(id))?.status, ItemStatus.resolved);
      expect(
        (await repo.list(const ItemFilter())).any((i) => i.id == id),
        isFalse,
      );
      expect((await repo.stats()).totalResolved, 1);

      expect(await repo.delete(id), isTrue);
      repo = MockItemRepository(prefs: prefs);
      expect(await repo.detail(id), isNull);
      expect(await repo.resolve('missing-item'), isFalse);
      expect(await repo.delete('missing-item'), isFalse);
    },
  );

  test('city, keyword, radius and pagination filter actual results', () async {
    final repo = MockItemRepository();
    final taipei = await repo.list(
      const ItemFilter(type: ItemType.found, area: '臺北市', pageSize: 2),
    );
    expect(taipei.map((i) => i.title), ['橘色編織手提包', 'AirPods Pro']);

    final nextPage = await repo.list(
      const ItemFilter(type: ItemType.found, area: '台北市', page: 2, pageSize: 2),
    );
    expect(nextPage.map((i) => i.title), ['棕色短夾', '一串鑰匙']);
    expect(await repo.list(const ItemFilter(area: '台北市', page: 9)), isEmpty);

    final earbuds = await repo.list(const ItemFilter(keyword: ' airpods PRO '));
    expect(earbuds.single.title, 'AirPods Pro');
    final nearby = await repo.list(
      const ItemFilter(lat: 25.0338, lng: 121.5290, radius: 0.1),
    );
    expect(nearby.single.title, '橘色編織手提包');
    final newTaipei = await repo.list(const ItemFilter(area: '新北市'));
    expect(newTaipei.length, 2);
    expect(
      newTaipei.every((item) => item.locationName.startsWith('新北市')),
      isTrue,
    );
  });

  test(
    'saved empty collections remain empty and filter fields can be cleared',
    () async {
      SharedPreferences.setMockInitialValues({'foundit_demo_items_v1': '[]'});
      final prefs = await SharedPreferences.getInstance();
      final repo = MockItemRepository(prefs: prefs);
      expect(await repo.list(const ItemFilter()), isEmpty);

      final filter = const ItemFilter(
        type: ItemType.found,
        area: '台北市',
      ).copyWith(type: null, area: null, pageSize: 8);
      expect(filter.type, isNull);
      expect(filter.area, isNull);
      expect(filter.pageSize, 8);
      expect(filter.toQuery()['page_size'], 8);
      expect(const ItemFilter(hasReward: true).toQuery()['has_reward'], isTrue);
    },
  );
}

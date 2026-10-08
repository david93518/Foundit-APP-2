import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/router/app_router.dart';
import 'package:foundit/data/models/item.dart';
import 'package:foundit/data/models/user.dart';
import 'package:foundit/data/repositories/item_repository.dart';
import 'package:foundit/presentation/providers/auth_provider.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/items_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _PagedRepo extends MockItemRepository {
  _PagedRepo(this.total);
  final int total;
  final requested = <ItemFilter>[];
  @override
  Future<List<Item>> list(ItemFilter filter) async {
    requested.add(filter);
    final start = (filter.page - 1) * filter.pageSize;
    final count = (total - start).clamp(0, filter.pageSize);
    return [
      for (var i = start; i < start + count; i++)
        Item(
          id: 'i$i',
          type: ItemType.found,
          title: 'item $i',
          category: '其他',
          lostAt: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ];
  }
}

void main() {
  final user = AppUser(id: 'u1', name: '測試', createdAt: DateTime(2026));

  group('authRedirect', () {
    test('waits on splash until the cached session is read', () {
      const loading = AuthState();
      expect(authRedirect(loading, '/home'), '/splash');
      expect(authRedirect(loading, '/splash'), isNull);
    });

    test('guests can only reach login before seeing any item', () {
      const guest = AuthState(ready: true);
      for (final path in ['/splash', '/home', '/map', '/item/abc', '/chats']) {
        expect(authRedirect(guest, path), '/login', reason: path);
      }
      expect(authRedirect(guest, '/login'), isNull);
      expect(authRedirect(guest, '/otp'), isNull);
    });

    test('signed-in users skip login and keep their destination', () {
      final member = AuthState(ready: true, user: user);
      expect(authRedirect(member, '/login'), '/home');
      expect(authRedirect(member, '/splash'), '/home');
      expect(authRedirect(member, '/map'), isNull);
      expect(authRedirect(member, '/item/abc'), isNull);
    });
  });

  test('item queries never exceed the backend page_size limit', () {
    final query = const ItemFilter(pageSize: 100, page: 0).toQuery();
    expect(query['page_size'], 50);
    expect(query['page'], 1);
    final long = ItemFilter(keyword: '找' * 150).toQuery();
    expect((long['keyword'] as String).length, 100);
  });

  test('map loads every page in 50-item batches', () async {
    final repo = _PagedRepo(120);
    final container = ProviderContainer(
      overrides: [itemRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final items = await container.read(mapItemsProvider(null).future);
    expect(items, hasLength(120));
    expect(repo.requested.map((f) => f.pageSize).toSet(), {50});
    expect(repo.requested.map((f) => f.page), [1, 2, 3]);
  });
}

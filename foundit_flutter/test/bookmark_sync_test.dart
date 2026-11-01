import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/data/api/api_client.dart';
import 'package:foundit/data/models/user.dart';
import 'package:foundit/data/repositories/auth_repository.dart';
import 'package:foundit/presentation/providers/auth_provider.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/widgets/foundit_ui.dart';

class SessionRepository extends MockAuthRepository {
  SessionRepository(super.prefs);
  final user = AppUser(id: 'owner', createdAt: DateTime(2026));
  @override
  Future<AppUser?> cachedUser() async => user;
  @override
  Future<AppUser?> getMe() async => user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('legacy phone bookmarks merge once; Web deletions remain deleted and failed writes keep local state', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefUserId: 'owner',
      'bookmark:owner:legacy': true,
      'bookmark:other:private': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(prefs);
    final remote = <String>{'web'};
    final writes = <String>[];
    var failWrites = false;
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final id = options.path.split('/').last;
          if (options.method != 'GET' && failWrites) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          }
          if (options.method == 'PUT') {
            remote.add(id);
            writes.add(id);
          }
          if (options.method == 'DELETE') remote.remove(id);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': remote.toList()},
            ),
          );
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        useMockProvider.overrideWithValue(false),
        authRepositoryProvider.overrideWithValue(SessionRepository(prefs)),
      ],
    );
    addTearDown(container.dispose);
    container.read(authProvider);
    await Future<void>.delayed(Duration.zero);
    final notifier = container.read(savedItemsProvider.notifier);
    await notifier.ready;
    expect(container.read(savedItemsProvider), {'legacy', 'web'});
    expect(writes, ['legacy']);
    expect(prefs.getBool('bookmark:other:private'), true);
    remote.remove('legacy'); // Another client removed this bookmark.
    await notifier.synchronize();
    expect(container.read(savedItemsProvider), {'web'});
    expect(writes, [
      'legacy',
    ], reason: 'never restore a server-deleted bookmark on a later refresh');
    failWrites = true;
    await expectLater(notifier.toggle('web'), throwsA(isA<DioException>()));
    expect(container.read(savedItemsProvider), {'web'});
    failWrites = false;
    await notifier.toggle('web');
    expect(remote, isEmpty);
    expect(container.read(savedItemsProvider), isEmpty);
  });
}

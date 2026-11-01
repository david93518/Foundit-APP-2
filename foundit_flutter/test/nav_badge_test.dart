import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/theme/app_theme.dart';
import 'package:foundit/presentation/providers/chat_provider.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/providers/notifications_provider.dart';
import 'package:foundit/presentation/screens/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpShell(WidgetTester tester, {required int unread}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          useMockProvider.overrideWithValue(true),
          chatUnreadTotalProvider.overrideWith((ref) async => unread),
          unreadCountAsyncProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MainShell(location: '/home', child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('messages tab shows the unread count without opening the list', (
    tester,
  ) async {
    await pumpShell(tester, unread: 3);
    expect(find.widgetWithText(UnreadCountBadge, '3'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('訊息')), findsWidgets);
    final semantics = tester.getSemantics(
      find
          .ancestor(of: find.text('訊息'), matching: find.byType(Semantics))
          .first,
    );
    expect(semantics.value, '3 則未讀');
  });

  testWidgets('no badge when everything is read', (tester) async {
    await pumpShell(tester, unread: 0);
    expect(find.byType(UnreadCountBadge), findsNothing);
  });

  testWidgets('large counts are capped', (tester) async {
    await pumpShell(tester, unread: 120);
    expect(find.widgetWithText(UnreadCountBadge, '99+'), findsOneWidget);
  });

  testWidgets('publish sheet offers scanning a tag for finders', (
    tester,
  ) async {
    await pumpShell(tester, unread: 0);
    await tester.tap(find.bySemanticsLabel('刊登物品').first);
    await tester.pumpAndSettle();
    expect(find.text('掃描防丟牌'), findsOneWidget);
    expect(find.text('物品上有 FOUND !T QR？直接聯絡物主'), findsOneWidget);
  });
}

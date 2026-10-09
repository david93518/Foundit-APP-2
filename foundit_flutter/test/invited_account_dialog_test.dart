import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/presentation/widgets/invited_account_dialog.dart';

void main() {
  testWidgets('validates credentials, preserves error and permits retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvitedAccountDialog(
            onSubmit: (username, password) async {
              attempts++;
              expect(username, 'review-test');
              expect(password, 'test-password-123');
              return '登入未完成';
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('登入'));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'review-test');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'test-password-123',
    );
    await tester.tap(find.text('登入'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('登入未完成'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('顯示密碼'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isFalse,
    );
  });

  testWidgets(
    'small screen, enlarged text and keyboard can scroll without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 667),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 290),
            ),
            child: Scaffold(
              body: InvitedAccountDialog(
                username: 'review-test',
                onSubmit: (_, _) async => null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('確認刪除'), findsOneWidget);
    },
  );
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundit/core/constants/app_constants.dart';
import 'package:foundit/core/services/auth_token_store.dart';
import 'package:foundit/data/api/api_client.dart';
import 'package:foundit/presentation/providers/core_providers.dart';
import 'package:foundit/presentation/widgets/private_chat_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'private image requests are confined to the protected API origin and path',
    () {
      expect(
        isPrivateChatImageUrl(
          'https://api.foundit.tw/api/v1/upload/chat-images/11111111-1111-4111-8111-111111111111.jpg',
        ),
        isTrue,
      );
      for (final value in [
        'https://evil.example/api/v1/upload/chat-images/x.jpg',
        'https://api.foundit.tw/uploads/x.jpg',
        'javascript:alert(1)',
        'https://api.foundit.tw@evil.example/api/v1/upload/chat-images/x.jpg',
      ]) {
        expect(isPrivateChatImageUrl(value), isFalse);
      }
    },
  );

  testWidgets(
    'private images render bytes through the authenticated API client',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await AuthTokenStore.enableMemoryStorage(prefs);
      await AuthTokenStore.write(prefs, 'private-image-test-session');
      addTearDown(() => AuthTokenStore.clear(prefs));
      final client = ApiClient(prefs);
      RequestOptions? request;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<List<int>>(
                requestOptions: options,
                statusCode: 200,
                data: base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
                ),
              ),
            );
          },
        ),
      );
      final url =
          '${Uri.parse(AppConstants.baseUrl).origin}/api/v1/upload/chat-images/11111111-1111-4111-8111-111111111111.jpg';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: MaterialApp(home: PrivateChatImage(url: url)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        request?.headers['Authorization'],
        'Bearer private-image-test-session',
      );
      expect(request?.responseType, ResponseType.bytes);
      expect(request?.followRedirects, isFalse);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('圖片無法載入'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an external image URL fails before a request can expose the session',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      var requests = 0;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: const MaterialApp(
            home: PrivateChatImage(
              url: 'https://untrusted.example/tracker.jpg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(find.text('圖片無法載入'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
}

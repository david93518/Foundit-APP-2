import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/app_constants.dart';

class GoogleIdentityService {
  late final GoogleSignIn client = GoogleSignIn(
    scopes: const ['email', 'profile'],
    clientId: kIsWeb
        ? AppConstants.googleWebClientId
        : (defaultTargetPlatform == TargetPlatform.iOS &&
                  AppConstants.googleIosClientId.isNotEmpty
              ? AppConstants.googleIosClientId
              : null),
    serverClientId: kIsWeb ? null : AppConstants.googleWebClientId,
  );

  Future<String?> signIn() async {
    // Always present an account choice, including when confirming deletion.
    await client.signOut();
    final account = await client.signIn();
    if (account == null) return null;
    return tokenFor(account);
  }

  Future<String> tokenFor(GoogleSignInAccount account) async {
    final token = (await account.authentication).idToken;
    if (token == null || token.isEmpty) throw StateError('Google 未回傳身分驗證');
    return token;
  }
}

final googleIdentityProvider = Provider<GoogleIdentityService>(
  (ref) => GoogleIdentityService(),
);

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../../core/services/google_identity_service.dart';

class GoogleAccountButton extends ConsumerStatefulWidget {
  const GoogleAccountButton({
    super.key,
    required this.onToken,
    required this.onError,
  });
  final Future<void> Function(String token) onToken;
  final void Function(String message) onError;
  @override
  ConsumerState<GoogleAccountButton> createState() =>
      _GoogleAccountButtonState();
}

class _GoogleAccountButtonState extends ConsumerState<GoogleAccountButton> {
  StreamSubscription<GoogleSignInAccount?>? _subscription;
  bool _ready = false;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final service = ref.read(googleIdentityProvider);
    try {
      await service.client.signOut();
      if (!mounted) return;
      _subscription = service.client.onCurrentUserChanged.listen((
        account,
      ) async {
        if (account == null || _busy) return;
        setState(() => _busy = true);
        try {
          final token = await service.tokenFor(account);
          if (mounted) await widget.onToken(token);
        } catch (_) {
          if (mounted) widget.onError('Google 登入未完成，請再試一次。');
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      });
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) widget.onError('Google 登入暫時無法載入，請確認網路後重新開啟。');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_ready || _busy
      ? const Center(child: CircularProgressIndicator())
      : Center(
          child: google_web.renderButton(
            configuration: google_web.GSIButtonConfiguration(
              text: google_web.GSIButtonText.continueWith,
              size: google_web.GSIButtonSize.large,
            ),
          ),
        );
}

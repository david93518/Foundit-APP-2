import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/google_identity_service.dart';

class GoogleAccountButton extends ConsumerStatefulWidget {
  const GoogleAccountButton({super.key, required this.onToken, required this.onError});
  final Future<void> Function(String token) onToken;
  final void Function(String message) onError;
  @override
  ConsumerState<GoogleAccountButton> createState() => _GoogleAccountButtonState();
}

class _GoogleAccountButtonState extends ConsumerState<GoogleAccountButton> {
  bool _busy = false;
  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token = await ref.read(googleIdentityProvider).signIn();
      if (mounted && token != null) await widget.onToken(token);
    } catch (_) {
      if (mounted) widget.onError('Google 登入未完成，請確認網路後再試一次。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _signIn,
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1F1F1F),
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: _busy
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Image.asset('assets/icons/google_g.png', width: 20, height: 20),
    label: const Text('使用 Google 帳號繼續'),
  );
}

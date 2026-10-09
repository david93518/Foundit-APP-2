import 'package:flutter/material.dart';

/// Public, explicitly provisioned account login; credentials are never bundled.
class InvitedAccountDialog extends StatefulWidget {
  const InvitedAccountDialog({
    super.key,
    required this.onSubmit,
    this.username,
  });
  final Future<String?> Function(String username, String password) onSubmit;
  final String? username;

  @override
  State<InvitedAccountDialog> createState() => _InvitedAccountDialogState();
}

class _InvitedAccountDialogState extends State<InvitedAccountDialog> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.username);
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  bool get _deleting => widget.username != null;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onSubmit(_username.text.trim(), _password.text);
    } catch (_) {
      error = '目前無法連線，請稍後重試。';
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(_deleting ? '刪除帳號' : '受邀帳號登入'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _deleting
                  ? '確認後，刊登會移除、聊天內容會匿名化，而且帳號不能再登入。請輸入密碼確認刪除。'
                  : '使用收到的受邀帳號與密碼，登入後即可使用完整的刊登與聯絡功能。',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _username,
              readOnly: _deleting,
              enabled: !_busy,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: '帳號',
                errorMaxLines: 3,
              ),
              validator: (value) =>
                  RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : '請輸入收到的受邀帳號',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '密碼',
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: _obscure ? '顯示密碼' : '隱藏密碼',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  (value?.length ?? 0) >= 12 && (value?.length ?? 0) <= 128
                  ? null
                  : '請輸入完整的受邀帳號密碼',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? '處理中…'
                : _deleting
                ? '確認刪除'
                : '登入',
          ),
        ),
      ],
    ),
  );
}

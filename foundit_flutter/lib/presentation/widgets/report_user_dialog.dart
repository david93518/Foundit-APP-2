import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../providers/safety_provider.dart';

class ReportUserDialog extends ConsumerStatefulWidget {
  const ReportUserDialog({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends ConsumerState<ReportUserDialog> {
  final _details = TextEditingController();
  static const _reasons = ['騷擾或不當言語', '疑似詐騙或冒領', '傳送垃圾訊息', '其他問題'];
  String _reason = _reasons.first;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = _details.text.trim();
      await ref
          .read(safetyRepositoryProvider)
          .reportUser(
            widget.userId,
            detail.isEmpty ? _reason : '$_reason：$detail',
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = apiErrorMessage(e) ?? '檢舉尚未送出，請檢查網路後重試。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: const Text('檢舉這位使用者'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('請描述發生的情況，供管理員查看。檢舉不會自動封鎖對方。'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(labelText: '原因'),
            items: _reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _reason = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _details,
            enabled: !_busy,
            maxLength: 800,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '補充說明（選填）',
              hintText: '例如時間、對方提出的要求。請勿填密碼或驗證碼。',
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? '送出中…' : '送出檢舉'),
        ),
      ],
    ),
  );
}

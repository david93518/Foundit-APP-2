import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../data/api/api_client.dart';
import '../../providers/core_providers.dart';
import '../../providers/safety_provider.dart';

const handoverChecklist =
    '1. 請對方說出照片中沒公開的特徵，例如內容物、刮痕或遺失時間，再確認歸還。\n\n'
    '2. 約在服務台、警衛室或有人管理的公共場所交接。\n\n'
    '3. 不提供登入驗證碼，不點陌生付款連結；遇到要求先付「解鎖費」或押金，先停止聯絡。\n\n'
    '4. 交還完成後，記得在自己的刊登標記已尋回／已歸還。';

Future<void> showHandoverChecklist(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    scrollable: true,
    title: const Text('交還前，先確認這些'),
    content: const Text(handoverChecklist),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了')),
    ],
  ),
);

Future<bool> confirmContactBlock(
  BuildContext context, {
  required bool unblock,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: Text(unblock ? '解除封鎖聯絡？' : '封鎖這位使用者？'),
        content: Text(
          unblock
              ? '解除後，若對方也沒有封鎖你，就可以再次傳送訊息。'
              : '封鎖後，彼此無法再傳送訊息。已有對話會保留，公開刊登不會因此隱藏。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(unblock ? '解除封鎖' : '封鎖聯絡'),
          ),
        ],
      ),
    ) ??
    false;

class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});
  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  String? _busyId;

  Future<void> _unblock(String id) async {
    if (_busyId != null ||
        !await confirmContactBlock(context, unblock: true) ||
        !mounted) {
      return;
    }
    setState(() => _busyId = id);
    try {
      await ref.read(safetyRepositoryProvider).unblock(id);
      if (!mounted) return;
      ref.invalidate(blockedContactsProvider);
      AppSnackbar.success(context, '已解除封鎖聯絡');
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, apiErrorMessage(e) ?? '尚未解除封鎖，請檢查網路後重試');
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(blockedContactsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('安全與封鎖')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '安心交還',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(handoverChecklist, style: TextStyle(height: 1.6)),
          const SizedBox(height: 28),
          const Text(
            '已封鎖聯絡',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('封鎖會停止彼此傳送訊息；公開刊登和已有對話仍保留。'),
          const SizedBox(height: 12),
          if (ref.watch(useMockProvider))
            const Text('體驗模式不會封鎖真實使用者。')
          else
            contacts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('封鎖名單暫時載入不了。'),
                  TextButton(
                    onPressed: () => ref.invalidate(blockedContactsProvider),
                    child: const Text('重試'),
                  ),
                ],
              ),
              data: (rows) => rows.isEmpty
                  ? const Text('目前沒有封鎖任何人。')
                  : Column(
                      children: rows
                          .map(
                            (person) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      person.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _busyId != null
                                            ? null
                                            : () => _unblock(person.id),
                                        child: Text(
                                          _busyId == person.id
                                              ? '處理中…'
                                              : '解除封鎖',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
        ],
      ),
    );
  }
}

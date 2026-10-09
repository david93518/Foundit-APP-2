import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../providers/core_providers.dart';

bool isPrivateChatImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.origin == Uri.parse(AppConstants.baseUrl).origin &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      RegExp(r'^/api/v1/upload/chat-images/[0-9a-f-]+(?:_[0-9a-f-]+)?\.jpg$')
          .hasMatch(uri.path);
}

/// Bytes are fetched with the current session and kept only in this widget's memory.
class PrivateChatImage extends ConsumerStatefulWidget {
  const PrivateChatImage({super.key, required this.url});
  final String url;
  @override
  ConsumerState<PrivateChatImage> createState() => _PrivateChatImageState();
}

class _PrivateChatImageState extends ConsumerState<PrivateChatImage> {
  late Future<Uint8List> _bytes;
  final _cancel = CancelToken();
  @override
  void initState() {
    super.initState();
    _bytes = _load();
  }

  Future<Uint8List> _load() async {
    if (!isPrivateChatImageUrl(widget.url))
      throw StateError('Invalid private image');
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get<List<int>>(
          widget.url,
          options: Options(responseType: ResponseType.bytes),
          cancelToken: _cancel,
        );
    return Uint8List.fromList(response.data ?? []);
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (_, state) {
      if (state.hasError) return const Text('圖片無法載入');
      if (!state.hasData)
        return const SizedBox(
          width: 120,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        );
      return Image.memory(
        state.data!,
        width: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stack) => const Text('圖片無法載入'),
      );
    },
  );
}

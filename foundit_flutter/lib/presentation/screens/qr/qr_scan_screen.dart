import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../providers/core_providers.dart';

/// Accept a standalone identifier or a FOUND !T `/qr/<code>` URL.
/// Query parameters and fragments are never sent as part of the identifier.
String? parseQrCode(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  if (uri.hasScheme &&
      ((!{'http', 'https'}.contains(uri.scheme)) || uri.host.isEmpty)) {
    return null;
  }
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  final index = segments.lastIndexOf('qr');
  final String? code;
  if (index >= 0 && index == segments.length - 2) {
    code = segments.last;
  } else if (!uri.hasScheme && segments.length == 1) {
    code = segments.single;
  } else {
    return null;
  }
  return RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(code) ? code : null;
}

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key, this.cameraPreview});

  /// Optional non-camera surface for layout tests; production uses MobileScanner.
  final Widget? cameraPreview;
  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  MobileScannerController? _scanner;
  MobileScannerController get _controller =>
      _scanner ??= MobileScannerController();
  bool _handled = false;
  bool _togglingTorch = false;

  @override
  void dispose() {
    _scanner?.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/qr');

  Future<void> _toggleTorch() async {
    if (_togglingTorch || _scanner == null) return;
    setState(() => _togglingTorch = true);
    try {
      await _controller.toggleTorch();
      // The icon follows controller.value.torchState, not an assumed toggle.
    } catch (_) {
      if (mounted) AppSnackbar.error(context, '目前無法使用手電筒。');
    } finally {
      if (mounted) setState(() => _togglingTorch = false);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || ref.read(useMockProvider)) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    setState(() => _handled = true);
    try {
      await _controller.stop();
      final code = parseQrCode(raw);
      if (code == null) {
        if (mounted) {
          AppSnackbar.error(context, '無法識別這個 QR 碼，請掃描 FOUND !T 防丟牌。');
        }
        return;
      }
      final result = await ref.read(qrRepositoryProvider).scanByCode(code);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => QrScanResultSheet(
          itemName: result.qrItem.name,
          ownerName: result.ownerName,
          ownerPhone: result.ownerPhone,
          onContinue: () => Navigator.pop(sheetContext),
        ),
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, '暫時無法查詢這張防丟牌，請確認網路後再試。');
    } finally {
      if (mounted) {
        setState(() => _handled = false);
        try {
          await _controller.start();
        } catch (_) {
          if (mounted) AppSnackbar.error(context, '相機暫時無法開啟，請確認相機權限後重新進入。');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // A direct /qr/scan visit must not request camera permission in demo mode.
    if (ref.watch(useMockProvider)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回防丟牌',
            onPressed: _back,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  '掃描 FOUND !T 防丟牌',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  '體驗模式不會開啟相機，也不會查詢真實物主的資料。你可以返回防丟牌頁，體驗建立與管理標籤。',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _back,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('返回防丟牌'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final camera =
        widget.cameraPreview ??
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (_, __, ___) => const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                '相機暫時無法開啟。\n請確認相機權限後重新進入。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          camera,
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _ScanButton(
                        key: const ValueKey('qr-back'),
                        label: '返回防丟牌',
                        icon: Icons.arrow_back_rounded,
                        onTap: _back,
                      ),
                      const Spacer(),
                      if (_scanner == null)
                        const _ScanButton(
                          key: ValueKey('qr-torch'),
                          label: '手電筒無法使用',
                          icon: Icons.flashlight_off_rounded,
                        )
                      else
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (_, state, __) {
                            final on = state.torchState == TorchState.on;
                            final available =
                                state.isRunning &&
                                state.torchState != TorchState.unavailable;
                            return _ScanButton(
                              key: const ValueKey('qr-torch'),
                              label: !available
                                  ? '手電筒無法使用'
                                  : on
                                  ? '關閉手電筒'
                                  : '開啟手電筒',
                              icon: on
                                  ? Icons.flashlight_on_rounded
                                  : Icons.flashlight_off_rounded,
                              onTap: available && !_togglingTorch
                                  ? _toggleTorch
                                  : null,
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final size = math.max(
                        0.0,
                        math.min(
                          300.0,
                          math.min(
                            constraints.maxWidth - 48,
                            constraints.maxHeight - 32,
                          ),
                        ),
                      );
                      return IgnorePointer(
                        child: Center(
                          child: SizedBox(
                            key: const ValueKey('qr-scan-frame'),
                            width: size,
                            height: size,
                            child: CustomPaint(painter: _CornerPainter()),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _handled ? '正在查詢防丟牌…' : '對準 FOUND !T QR 碼，自動掃描',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable, camera-independent scan result, including long names and contacts.
class QrScanResultSheet extends StatelessWidget {
  const QrScanResultSheet({
    super.key,
    required this.itemName,
    required this.ownerName,
    required this.ownerPhone,
    required this.onContinue,
  });
  final String itemName;
  final String ownerName;
  final String ownerPhone;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '找到防丟牌資料',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ResultField(label: '物品名稱', value: itemName),
                _ResultField(
                  label: '物主',
                  value: ownerName.isEmpty ? '未提供姓名' : ownerName,
                ),
                if (ownerPhone.isNotEmpty)
                  _ResultField(label: '聯絡方式', value: ownerPhone),
                const Text(
                  '請先核對物品特徵，再與物主約定領回方式。',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('繼續掃描'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResultField extends StatelessWidget {
  const _ResultField({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white54,
      backgroundColor: Colors.black.withValues(alpha: .55),
    ),
    icon: Icon(icon, size: 23),
  );
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary400
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final length = math.min(26.0, size.shortestSide / 4);
    for (final corner in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      canvas.drawLine(
        corner,
        corner.translate(corner.dx == 0 ? length : -length, 0),
        paint,
      );
      canvas.drawLine(
        corner,
        corner.translate(0, corner.dy == 0 ? length : -length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/floating_bottom_nav.dart';

/// 底部導航容器，包住主要四個頁面
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  int get _currentIndex {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/map')) return 1;
    if (location.startsWith('/chats')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/map');
        break;
      case 2:
        _showAddMenu(context);
        break;
      case 3:
        context.go('/chats');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => _onTap(context, i),
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMenu(),
    );
  }
}

class _AddMenu extends StatelessWidget {
  const _AddMenu();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(
              title: '我遺失了東西',
              subtitle: '建立尋物啟事',
              gradient: const LinearGradient(
                colors: [Color(0xFFFB923C), Color(0xFFF97316)],
              ),
              icon: Icons.search_rounded,
              onTap: () {
                Navigator.pop(context);
                context.push('/add/lost');
              },
            ),
            const SizedBox(height: 8),
            _MenuRow(
              title: '我撿到了東西',
              subtitle: '通知失主來領取',
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF10B981)],
              ),
              icon: Icons.handshake_rounded,
              onTap: () {
                Navigator.pop(context);
                context.push('/add/found');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Gradient gradient;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

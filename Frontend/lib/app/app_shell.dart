import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _indexForLocation(String l) {
    if (l.startsWith('/dashboard')) return 0;
    if (l.startsWith('/diary')) return 1;
    return 2; // settings
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: SafeArea(
    top: false,      
    bottom: true,
    child: child,
  ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: currentIndex,
        onChanged: (i) {
          switch (i) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/diary');
              break;
            case 2:
              context.go('/settings');
              break;
          }
        },
      ),
    );
  }
}
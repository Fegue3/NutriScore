// lib/main.dart
import 'package:flutter/material.dart';
import 'app/di.dart';
import 'app/router/app_router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const NutriScoreApp());
}

class NutriScoreApp extends StatelessWidget {
  const NutriScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildAppRouter(di.authRepository);
    return MaterialApp.router(
      title: 'NutriScore',
      debugShowCheckedModeBanner: false,
      theme: NutriTheme.light,
      routerConfig: router,
    );
  }
}

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
    return MaterialApp.router(
      title: 'NutriScore',
      debugShowCheckedModeBanner: false,
      theme: NutriTheme.light,   // mantém o teu tema
      routerConfig: appRouter,
    );
  }
}

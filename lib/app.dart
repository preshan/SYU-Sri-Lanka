import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/router/app_router.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

class SyuApp extends ConsumerWidget {
  const SyuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SYU Sri Lanka',
      debugShowCheckedModeBanner: false,
      theme: SyuTheme.dark(),
      darkTheme: SyuTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

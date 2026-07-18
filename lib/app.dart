import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/core/router/app_router.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class SyuApp extends ConsumerWidget {
  const SyuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'SYU Sri Lanka',
      debugShowCheckedModeBanner: false,
      theme: SyuTheme.light(),
      darkTheme: SyuTheme.light(),
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

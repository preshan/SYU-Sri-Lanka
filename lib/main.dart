import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syu_sri_lanka/app.dart';
import 'package:syu_sri_lanka/core/analytics/clarity_bootstrap.dart';
import 'package:syu_sri_lanka/core/config/env.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await dotenv.load(fileName: '.env');
  Env.validate();
  await SupabaseBootstrap.init();

  // Web: Clarity JS tag in web/index.html. Mobile: Clarity Flutter SDK.
  runApp(wrapWithClarity(const ProviderScope(child: SyuApp())));
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/features/auth/presentation/confirm_email_screen.dart';
import 'package:syu_sri_lanka/features/auth/presentation/login_screen.dart';
import 'package:syu_sri_lanka/features/auth/presentation/register_screen.dart';
import 'package:syu_sri_lanka/features/home/presentation/home_shell.dart';
import 'package:syu_sri_lanka/features/splash/presentation/splash_screen.dart';

final _authRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);
  final sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
    notifier.value++;
  });
  ref.onDispose(() {
    sub.cancel();
    notifier.dispose();
  });
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_authRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/splash' ||
          loc == '/confirm-email';

      if (session == null && !isAuthRoute) return '/login';
      if (session != null &&
          (loc == '/login' || loc == '/register' || loc == '/confirm-email')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          initialEmail: state.uri.queryParameters['email'],
          notice: state.uri.queryParameters['notice'],
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/confirm-email',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return ConfirmEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),
    ],
  );
});

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_shell.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_tabs.dart';
import 'package:syu_sri_lanka/features/auth/presentation/confirm_email_screen.dart';
import 'package:syu_sri_lanka/features/auth/presentation/forgot_password_screen.dart';
import 'package:syu_sri_lanka/features/auth/presentation/login_screen.dart';
import 'package:syu_sri_lanka/features/auth/presentation/register_screen.dart';
import 'package:syu_sri_lanka/features/home/presentation/home_shell.dart';
import 'package:syu_sri_lanka/features/messaging/presentation/conversations_list_screen.dart';
import 'package:syu_sri_lanka/features/notifications/presentation/notification_center_screen.dart';
import 'package:syu_sri_lanka/features/profile/presentation/edit_profile_screen.dart';
import 'package:syu_sri_lanka/features/registration/presentation/registration_wizard_screen.dart';
import 'package:syu_sri_lanka/features/settings/presentation/settings_screen.dart';
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
      final isPublicAuth = loc == '/login' ||
          loc == '/register' ||
          loc == '/splash' ||
          loc == '/confirm-email' ||
          loc == '/forgot-password';

      if (session == null && !isPublicAuth) return '/login';
      // Allow /confirm-email while signed in (app email OTP gate).
      if (session != null && (loc == '/login' || loc == '/register')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginScreen(
          initialEmail: state.uri.queryParameters['email'],
          notice: state.uri.queryParameters['notice'],
        ),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/confirm-email',
        builder: (_, state) => ConfirmEmailScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
      GoRoute(
        path: '/admin',
        pageBuilder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          final index = adminTabIndexFromName(tab) ?? 1;
          // Zero-duration page avoids web back leaving a tap-blocking barrier.
          return NoTransitionPage<void>(
            key: ValueKey(
              'admin-$index-${state.uri.queryParameters['member'] ?? ''}',
            ),
            child: AdminShell(
              key: ValueKey(
                'admin-shell-$index-${state.uri.queryParameters['member'] ?? ''}',
              ),
              initialTab: index,
              initialMemberId: state.uri.queryParameters['member'],
              initialMemberName: state.uri.queryParameters['name'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/registration',
        builder: (_, _) => const RegistrationWizardScreen(),
      ),
      GoRoute(
        path: '/messages',
        builder: (_, _) => const ConversationsListScreen(active: true),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationCenterScreen(),
      ),
    ],
  );
});

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/permissions/app_permissions.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

/// White splash: logo → type "Socialist Youth Union" → Welcome!, then route.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _orgName = 'Socialist Youth Union';
  static const _welcomeText = 'Welcome!';

  late final AnimationController _logoCtrl;
  late final AnimationController _welcomeCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _welcomeFade;
  late final Animation<Offset> _welcomeSlide;

  String _typedOrg = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _welcomeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );

    _welcomeFade = CurvedAnimation(parent: _welcomeCtrl, curve: Curves.easeOut);
    _welcomeSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _welcomeCtrl, curve: Curves.easeOutCubic));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    await _logoCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    // Fast typewriter for org name (~32ms / char).
    for (var i = 1; i <= _orgName.length; i++) {
      if (!mounted) return;
      setState(() => _typedOrg = _orgName.substring(0, i));
      await Future<void>.delayed(const Duration(milliseconds: 32));
    }

    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _welcomeCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Prompt for notification permission on first runs (Android 13+ / iOS only).
    if (!kIsWeb) {
      await AppPermissions.ensureNotifications();
      if (!mounted) return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      context.go('/login');
      return;
    }
    try {
      final verified =
          await Supabase.instance.client.rpc('is_app_email_verified');
      if (!mounted) return;
      if (verified == true) {
        context.go('/home');
      } else {
        final email = session.user.email ?? '';
        context.go(
          '/confirm-email?email=${Uri.encodeComponent(email)}',
        );
      }
    } catch (_) {
      if (!mounted) return;
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _welcomeCtrl.dispose();
    super.dispose();
  }

  /// Brush-script look close to "Awesome" (commercial); Satisfy is free via Google Fonts.
  TextStyle get _scriptStyle => GoogleFonts.satisfy(
        fontSize: 36,
        height: 1.15,
        letterSpacing: 0.4,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: SizedBox(
                      height: 120,
                      child: Image.asset(
                        'assets/brand/syu_logo.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Reserve height so typing doesn't jump layout.
                SizedBox(
                  height: 52,
                  child: Text(
                    _typedOrg,
                    textAlign: TextAlign.center,
                    style: _scriptStyle.copyWith(color: SyuColors.crimson),
                  ),
                ),
                const SizedBox(height: 6),
                FadeTransition(
                  opacity: _welcomeFade,
                  child: SlideTransition(
                    position: _welcomeSlide,
                    child: Text(
                      _welcomeText,
                      textAlign: TextAlign.center,
                      style: _scriptStyle.copyWith(
                        fontSize: 40,
                        color: SyuColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

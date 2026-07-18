import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';

/// White splash: logo → Welcome → SYU Sri Lanka, then route by session.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _welcomeCtrl;
  late final AnimationController _brandCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _welcomeFade;
  late final Animation<Offset> _welcomeSlide;
  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;

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
      duration: const Duration(milliseconds: 750),
    );
    _brandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );

    _welcomeFade = CurvedAnimation(parent: _welcomeCtrl, curve: Curves.easeOut);
    _welcomeSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _welcomeCtrl, curve: Curves.easeOutCubic));

    _brandFade = CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOut);
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _brandCtrl, curve: Curves.easeOutCubic));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    await _logoCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    await _welcomeCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    await _brandCtrl.forward();

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    context.go(session == null ? '/login' : '/home');
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _welcomeCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final welcomeStyle = GoogleFonts.bebasNeue(
      fontSize: 56,
      height: 1.05,
      letterSpacing: 1.4,
      color: SyuColors.ink,
    );
    final brandStyle = GoogleFonts.outfit(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: SyuColors.crimson,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                const SizedBox(height: 36),
                FadeTransition(
                  opacity: _welcomeFade,
                  child: SlideTransition(
                    position: _welcomeSlide,
                    child: Text(
                      'Welcome',
                      textAlign: TextAlign.center,
                      style: welcomeStyle,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _brandFade,
                  child: SlideTransition(
                    position: _brandSlide,
                    child: Text(
                      'SYU Sri Lanka',
                      textAlign: TextAlign.center,
                      style: brandStyle,
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

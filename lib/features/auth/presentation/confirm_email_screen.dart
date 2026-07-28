import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/auth/data/auth_repository.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class ConfirmEmailScreen extends ConsumerStatefulWidget {
  const ConfirmEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends ConsumerState<ConfirmEmailScreen> {
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  bool _verifying = false;
  bool _resending = false;
  bool _switchingEmail = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // Never trust a hand-edited ?email= when a session exists — sync URL to
    // the signed-in account so the UI cannot imply deleting someone else.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEmailToSession());
  }

  @override
  void dispose() {
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  /// Prefer the signed-in user's email; URL query is display/fallback only.
  String get _accountEmail {
    final sessionEmail =
        SupabaseBootstrap.client.auth.currentUser?.email?.trim();
    if (sessionEmail != null && sessionEmail.isNotEmpty) {
      return sessionEmail;
    }
    return widget.email.trim();
  }

  void _syncEmailToSession() {
    if (!mounted) return;
    final sessionEmail =
        SupabaseBootstrap.client.auth.currentUser?.email?.trim();
    if (sessionEmail == null || sessionEmail.isEmpty) return;
    if (sessionEmail.toLowerCase() == widget.email.trim().toLowerCase()) {
      return;
    }
    context.go(
      '/confirm-email?email=${Uri.encodeComponent(sessionEmail)}',
    );
  }

  String get _code => _pin.text.trim();

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    if (_code.length != 6) {
      setState(() => _message = l10n.invalidVerificationCode);
      return;
    }
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      final email = _accountEmail;
      await ref.read(authRepositoryProvider).verifySignupOtp(
            email: email,
            token: _code,
          );
      if (!mounted) return;
      final hasSession =
          SupabaseBootstrap.client.auth.currentSession != null;
      if (hasSession) {
        context.go('/home');
      } else {
        context.go(
          '/login?email=${Uri.encodeComponent(email)}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _resending = true;
      _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resendSignupEmail(_accountEmail);
      if (!mounted) return;
      setState(() => _message = l10n.codeResent);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = l10n.codeResendFailed);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Confirm, delete only the signed-in unverified account, then Create account.
  Future<void> _useDifferentEmail() async {
    final l10n = AppLocalizations.of(context);
    final session = SupabaseBootstrap.client.auth.currentSession;
    final sessionEmail =
        SupabaseBootstrap.client.auth.currentUser?.email?.trim() ?? '';

    // Without a session we cannot delete an Auth user; never imply we can.
    if (session == null || sessionEmail.isEmpty) {
      context.go('/register');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.useDifferentEmailTitle),
        content: Text(l10n.useDifferentEmailConfirm(sessionEmail)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.useDifferentEmailYes),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _switchingEmail = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).abandonUnverifiedSignup();
      if (!mounted) return;
      // Wait for GoRouter's auth refreshListenable to settle before navigating.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      context.go('/register');
    } catch (e) {
      if (!mounted) return;
      AppErrorMapper.showSnackBar(context, e);
      setState(() => _switchingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SyuBackScope(
      fallbackLocation: '/login',
      child: SyuGradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SyuBrandMark(height: 56, showWordmark: false),
                      const SizedBox(height: 28),
                      const SyuIcon(
                        SyuIcons.mailUnread,
                        size: 56,
                        color: SyuColors.crimsonSoft,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.confirmEmail,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.sentLinkTo,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _accountEmail,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: SyuColors.paper,
                                  fontWeight: FontWeight.w700,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.openLinkPrompt,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _pin,
                        focusNode: _pinFocus,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              letterSpacing: 10,
                              fontWeight: FontWeight.w700,
                              color: SyuColors.paper,
                            ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: l10n.enterVerificationCode,
                          hintText: '••••••',
                          hintStyle: TextStyle(
                            letterSpacing: 10,
                            color: SyuColors.paper.withValues(alpha: 0.35),
                          ),
                        ),
                        onChanged: (v) {
                          if (v.length == 6) _verify();
                        },
                        onSubmitted: (_) => _verify(),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _message!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: SyuColors.crimsonSoft,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed:
                            _verifying || _switchingEmail ? null : _verify,
                        child: _verifying
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: SyuColors.paper,
                                ),
                              )
                            : Text(l10n.verifyAndContinue),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _resending || _verifying || _switchingEmail
                            ? null
                            : _resend,
                        child: _resending
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: SyuColors.paper,
                                ),
                              )
                            : Text(l10n.resendEmail),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _verifying || _resending || _switchingEmail
                            ? null
                            : _useDifferentEmail,
                        child: _switchingEmail
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: SyuColors.paper,
                                ),
                              )
                            : Text(l10n.useDifferentEmail),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

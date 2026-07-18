import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
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
  String? _message;

  @override
  void dispose() {
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
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
      final res = await ref.read(authRepositoryProvider).verifySignupOtp(
            email: widget.email,
            token: _code,
          );
      if (!mounted) return;
      if (res.session != null) {
        context.go('/home');
        return;
      }
      context.go('/login');
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
      await ref.read(authRepositoryProvider).resendSignupEmail(widget.email);
      if (!mounted) return;
      setState(() => _message = l10n.codeResent);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = l10n.codeResendFailed);
    } finally {
      if (mounted) setState(() => _resending = false);
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
                        widget.email,
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
                        onPressed: _verifying ? null : _verify,
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
                        onPressed: _resending || _verifying ? null : _resend,
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
                        onPressed: () => context.go('/register'),
                        child: Text(l10n.useDifferentEmail),
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

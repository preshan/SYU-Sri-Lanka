import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/localization/language_picker.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/auth/data/auth_repository.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialEmail, this.notice});

  final String? initialEmail;
  final String? notice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _banner;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
    _banner = switch (widget.notice) {
      'confirm' =>
        'Confirm your email before signing in. Check your inbox for the link.',
      _ => null,
    };
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      final msg = AppErrorMapper.message(e);
      if (msg.contains('Confirm your email')) {
        context.go(
          '/confirm-email?email=${Uri.encodeComponent(_email.text.trim())}',
        );
        return;
      }
      AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SyuBackScope(
      allowExit: true,
      child: SyuGradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: const [
              LanguagePicker(isCompact: true, onLightBackground: false),
              SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SyuBrandMark(height: 64, showWordmark: false),
                        const SizedBox(height: 28),
                        Text(
                          l10n.welcomeBack,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.signInPrompt,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_banner != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: SyuColors.crimson.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    SyuColors.crimson.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _banner!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: SyuColors.ink,
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: l10n.email,
                            prefixIcon: const SyuFieldIcon(SyuIcons.mail),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.emailRequired;
                            }
                            if (!v.contains('@')) return l10n.validEmail;
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: l10n.password,
                            prefixIcon: const SyuFieldIcon(SyuIcons.lock),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: SyuIcon(
                                _obscure ? SyuIcons.view : SyuIcons.viewOff,
                                size: 18,
                                strokeWidth: 1.25,
                                color: SyuColors.mist,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return l10n.passwordRequired;
                            }
                            if (v.length < 6) return l10n.passwordMinLength(6);
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.go(
                              '/forgot-password?email=${Uri.encodeComponent(_email.text.trim())}',
                            ),
                            child: Text(l10n.forgotPassword),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: SyuColors.paper,
                                  ),
                                )
                              : Text(l10n.signIn),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.newToSyu,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text(l10n.createAccount),
                            ),
                          ],
                        ),
                      ],
                    ),
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

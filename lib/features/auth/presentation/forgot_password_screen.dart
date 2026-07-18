import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/auth/data/auth_repository.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  bool _loading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(_email.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SyuBackScope(
      fallbackLocation: '/login',
      child: SyuGradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: const SyuIcon(SyuIcons.back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/login');
                }
              },
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _sent ? _success() : _form(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SyuIcon(SyuIcons.mailOpen,
            size: 56, color: SyuColors.crimsonSoft),
        const SizedBox(height: 16),
        Text(
          l10n.checkYourEmail,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.resetLinkSent(_email.text.trim()),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: Text(l10n.backToSignIn),
        ),
      ],
    );
  }

  Widget _form() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SyuBrandMark(height: 48, showWordmark: false),
          const SizedBox(height: 24),
          Text(
            l10n.resetPassword,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.resetPasswordPrompt,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l10n.email,
              prefixIcon: const SyuFieldIcon(SyuIcons.mail),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.emailRequired;
              if (!v.contains('@')) return l10n.validEmail;
              return null;
            },
          ),
          const SizedBox(height: 22),
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
                : Text(l10n.sendResetLink),
          ),
        ],
      ),
    );
  }
}

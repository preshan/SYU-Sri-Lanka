import 'package:flutter/material.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Super-admin: Gmail SMTP credentials stored in `app_mail_settings`,
/// then synced to Supabase Auth via `sync-auth-smtp`.
class AdminMailSettingsPanel extends StatefulWidget {
  const AdminMailSettingsPanel({super.key});

  @override
  State<AdminMailSettingsPanel> createState() => _AdminMailSettingsPanelState();
}

class _AdminMailSettingsPanelState extends State<AdminMailSettingsPanel> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _fromNameCtrl = TextEditingController();
  final _fromEmailCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _passwordSet = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fromNameCtrl.dispose();
    _fromEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SupabaseBootstrap.client.rpc('get_mail_settings');
      final list = List<Map<String, dynamic>>.from(rows as List? ?? const []);
      if (list.isNotEmpty) {
        final r = list.first;
        _userCtrl.text = (r['smtp_user'] as String?) ?? '';
        _fromEmailCtrl.text = (r['from_email'] as String?) ?? '';
        _fromNameCtrl.text = (r['from_name'] as String?) ?? 'SYU Sri Lanka';
        _passwordSet = r['password_set'] == true;
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final user = _userCtrl.text.trim();
    if (user.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mailSettingsEmailRequired)),
      );
      return;
    }
    if (!_passwordSet && _passCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mailSettingsPasswordRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await SupabaseBootstrap.client.rpc(
        'upsert_mail_settings',
        params: {
          'p_smtp_user': user,
          'p_smtp_pass': _passCtrl.text.trim().isEmpty
              ? null
              : _passCtrl.text.trim(),
          'p_from_email': _fromEmailCtrl.text.trim().isEmpty
              ? user
              : _fromEmailCtrl.text.trim(),
          'p_from_name': _fromNameCtrl.text.trim().isEmpty
              ? 'SYU Sri Lanka'
              : _fromNameCtrl.text.trim(),
          'p_smtp_host': 'smtp.gmail.com',
          'p_smtp_port': 465,
        },
      );

      final res = await SupabaseBootstrap.client.functions.invoke(
        'sync-auth-smtp',
      );
      final data = res.data;
      if (res.status != 200) {
        final err = data is Map ? data['error'] : data;
        throw Exception(err ?? 'SMTP sync failed (${res.status})');
      }
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }

      _passCtrl.clear();
      if (mounted) {
        setState(() => _passwordSet = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mailSettingsSaved)),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SyuColors.crimson),
      );
    }

    return ListView(
      padding: AdminPanelChrome.listPadding,
      children: [
        Text(
          l10n.mailSettingsIntro,
          style: AdminPanelChrome.hintStyle(context),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _userCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            labelText: l10n.mailSettingsGmail,
            hintText: 'you@gmail.com',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.mailSettingsAppPassword,
            hintText: _passwordSet
                ? l10n.mailSettingsPasswordHintSet
                : l10n.mailSettingsPasswordHintNew,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fromEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.mailSettingsFromEmail,
            hintText: l10n.mailSettingsFromEmailHint,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fromNameCtrl,
          decoration: InputDecoration(
            labelText: l10n.mailSettingsFromName,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.mailSettingsSaveAndApply),
        ),
      ],
    );
  }
}

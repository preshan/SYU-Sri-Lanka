import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/home/presentation/home_shell.dart';
import 'package:syu_sri_lanka/features/profile/domain/profile_completeness.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _preferred = TextEditingController();
  final _phone = TextEditingController();
  final _occupation = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  ProfileCompleteness? _completeness;

  List<Map<String, dynamic>> _qualifications = [];
  final Set<String> _qualificationIds = {};
  final _otherQualification = TextEditingController();
  bool _speaksSinhala = false;
  bool _speaksTamil = false;
  bool _speaksEnglish = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _preferred.dispose();
    _phone.dispose();
    _occupation.dispose();
    _otherQualification.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return;

      final results = await Future.wait([
        SupabaseBootstrap.client.from('profiles').select(
              'full_name,preferred_name,phone,nic,date_of_birth,district_id,status,'
              'speaks_sinhala,speaks_tamil,speaks_english,other_qualification,'
              'occupation',
            ).eq('id', uid).maybeSingle(),
        SupabaseBootstrap.client
            .from('qualifications')
            .select('id,code,name_en,level_order')
            .eq('is_active', true)
            .order('level_order'),
        SupabaseBootstrap.client
            .from('member_qualifications')
            .select('qualification_id')
            .eq('profile_id', uid),
      ]);

      if (!mounted) return;

      final row = results[0] as Map<String, dynamic>?;
      final quals = List<Map<String, dynamic>>.from(results[1] as List);
      final mine = List<Map<String, dynamic>>.from(results[2] as List);

      _fullName.text = row?['full_name'] as String? ?? '';
      _preferred.text = row?['preferred_name'] as String? ?? '';
      _phone.text = row?['phone'] as String? ?? '';
      _occupation.text = row?['occupation'] as String? ?? '';
      _completeness = ProfileCompleteness.fromProfile(row);
      _qualifications = quals;
      _qualificationIds
        ..clear()
        ..addAll(
          mine.map((m) => m['qualification_id'] as String),
        );
      _speaksSinhala = row?['speaks_sinhala'] == true;
      _speaksTamil = row?['speaks_tamil'] == true;
      _speaksEnglish = row?['speaks_english'] == true;
      _otherQualification.text =
          row?['other_qualification'] as String? ?? '';
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _qualificationLabel(Map<String, dynamic> q) {
    final code = (q['code'] as String?)?.toLowerCase();
    if (code == 'ol') return 'O/L';
    if (code == 'al') return 'A/L';
    return q['name_en'] as String? ?? code ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser!.id;
      await SupabaseBootstrap.client.from('profiles').update({
        'full_name': _fullName.text.trim(),
        'preferred_name': _preferred.text.trim().isEmpty
            ? null
            : _preferred.text.trim(),
        'phone': _phone.text.trim(),
        'occupation': _occupation.text.trim().isEmpty
            ? null
            : _occupation.text.trim(),
        'speaks_sinhala': _speaksSinhala,
        'speaks_tamil': _speaksTamil,
        'speaks_english': _speaksEnglish,
        'other_qualification': _otherQualification.text.trim().isEmpty
            ? null
            : _otherQualification.text.trim(),
      }).eq('id', uid);

      await SupabaseBootstrap.client
          .from('member_qualifications')
          .delete()
          .eq('profile_id', uid);

      if (_qualificationIds.isNotEmpty) {
        await SupabaseBootstrap.client.from('member_qualifications').insert(
              _qualificationIds
                  .map(
                    (qid) => {
                      'profile_id': uid,
                      'qualification_id': qid,
                    },
                  )
                  .toList(),
            );
      }

      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ref.read(profileStatusTickProvider.notifier).state++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdated)),
      );
      context.pop();
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SyuBackScope(
      fallbackLocation: '/home',
      child: SyuGradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l10n.editProfile),
            leading: IconButton(
              icon: const SyuIcon(SyuIcons.back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: SyuColors.crimson),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: SyuColors.inkSoft,
                          child: SyuIcon(
                            SyuIcons.user,
                            size: 36,
                            color: SyuColors.mist,
                            strokeWidth: 1.25,
                          ),
                        ),
                      ),
                      if (_completeness != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.completenessPercent(_completeness!.percent),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _completeness!.percent / 100,
                          color: SyuColors.crimson,
                          backgroundColor: SyuColors.inkSoft,
                        ),
                        if (_completeness!.missingKeys.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.missingPrefix(
                              _completeness!.localizedMissing(l10n),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _fullName,
                        decoration: InputDecoration(labelText: l10n.fullName),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? l10n.fieldRequired
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _preferred,
                        decoration:
                            InputDecoration(labelText: l10n.preferredName),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _occupation,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: l10n.occupation,
                          hintText: l10n.occupationHint,
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.length > 120) return l10n.occupationTooLong;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: l10n.phone),
                        validator: (v) {
                          if (v == null || v.trim().length < 9) {
                            return l10n.validPhone;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.qualifications,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.selectAllThatApply,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._qualifications.map((q) {
                        final id = q['id'] as String;
                        final selected = _qualificationIds.contains(id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selected,
                          activeColor: SyuColors.crimson,
                          title: Text(_qualificationLabel(q)),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _qualificationIds.add(id);
                              } else {
                                _qualificationIds.remove(id);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _otherQualification,
                        maxLength: 250,
                        maxLines: 3,
                        minLines: 2,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: l10n.otherQualification,
                          hintText: l10n.otherQualificationHint,
                          alignLabelWithHint: true,
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.length > 250) {
                            return l10n.otherQualificationTooLong;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.languageSkills,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.selectLanguagesYouSpeak,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _speaksSinhala,
                        activeColor: SyuColors.crimson,
                        title: Text(l10n.langSinhala),
                        onChanged: (v) =>
                            setState(() => _speaksSinhala = v == true),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _speaksTamil,
                        activeColor: SyuColors.crimson,
                        title: Text(l10n.langTamil),
                        onChanged: (v) =>
                            setState(() => _speaksTamil = v == true),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _speaksEnglish,
                        activeColor: SyuColors.crimson,
                        title: Text(l10n.langEnglish),
                        onChanged: (v) =>
                            setState(() => _speaksEnglish = v == true),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: SyuColors.paper,
                                ),
                              )
                            : Text(l10n.saveChanges),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

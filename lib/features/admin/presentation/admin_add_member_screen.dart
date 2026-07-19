import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/validation/nic_and_age.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/admin/presentation/admin_chrome.dart';
import 'package:syu_sri_lanka/features/location/presentation/cascading_location_picker.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

/// Staff-only form to provision a member account (separate from self-registration).
class AdminAddMemberScreen extends ConsumerStatefulWidget {
  const AdminAddMemberScreen({super.key});

  @override
  ConsumerState<AdminAddMemberScreen> createState() =>
      _AdminAddMemberScreenState();
}

class _AdminAddMemberScreenState extends ConsumerState<AdminAddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _nic = TextEditingController();
  final _nicFocus = FocusNode();
  final _occupation = TextEditingController();
  final _dobDisplay = TextEditingController();
  final _clubName = TextEditingController();
  final _clubRegistrationNo = TextEditingController();
  final _otherQualification = TextEditingController();

  DateTime? _dob;
  LocationSelection _location = const LocationSelection();
  String? _gender;
  String _clubMode = 'none';
  bool _speaksSinhala = false;
  bool _speaksTamil = false;
  bool _speaksEnglish = false;
  final Set<String> _qualificationCodes = {};
  List<Map<String, dynamic>> _qualifications = [];
  bool _loadingMeta = true;
  bool _submitting = false;
  bool _created = false;
  String? _createdEmail;
  bool _mailFailed = false;

  @override
  void initState() {
    super.initState();
    _nicFocus.addListener(_onNicFocusChange);
    _loadMeta();
  }

  @override
  void dispose() {
    _nicFocus.removeListener(_onNicFocusChange);
    _nicFocus.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _nic.dispose();
    _occupation.dispose();
    _dobDisplay.dispose();
    _clubName.dispose();
    _clubRegistrationNo.dispose();
    _otherQualification.dispose();
    super.dispose();
  }

  void _onNicFocusChange() {
    if (!_nicFocus.hasFocus) _applyNicDerivedFields();
  }

  void _applyNicDerivedFields() {
    final nic = _nic.text;
    if (!NicValidator.isValid(nic)) return;
    final dob = NicValidator.dobFromNic(nic);
    final gender = NicValidator.genderFromNic(nic);
    if (dob == null && gender == null) return;
    setState(() {
      if (dob != null) {
        _dob = dob;
        _dobDisplay.text =
            '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
      }
      if (gender != null && (_gender == null || _gender == 'prefer_not')) {
        _gender = gender;
      }
    });
  }

  Future<void> _loadMeta() async {
    try {
      final rows = await SupabaseBootstrap.client
          .from('qualifications')
          .select('id,code,name_en,level_order')
          .order('level_order');
      if (!mounted) return;
      setState(() {
        _qualifications = (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final selected = _qualifications
          .where((q) => _qualificationCodes.contains(q['code']))
          .map((q) => q['id'] as String)
          .toList();
      final res = await SupabaseBootstrap.client.functions.invoke(
        'admin-create-member',
        body: {
          'full_name': _fullName.text.trim(),
          'email': _email.text.trim().toLowerCase(),
          'phone': _phone.text.trim(),
          'nic': _nic.text.trim().isEmpty
              ? null
              : _nic.text.trim().toUpperCase(),
          'date_of_birth': _dob?.toIso8601String().split('T').first,
          'gender': _gender,
          'district_id': _location.districtId,
          'ds_division_id': _location.dsDivisionId,
          'gn_division_id': _location.gnDivisionId,
          'qualification_ids': selected.isEmpty ? null : selected,
          'requested_youth_club_name':
              _clubMode == 'yes' ? _clubName.text.trim() : null,
          'youth_club_registration_no':
              _clubMode == 'yes' ? _clubRegistrationNo.text.trim() : null,
          'speaks_sinhala': _speaksSinhala,
          'speaks_tamil': _speaksTamil,
          'speaks_english': _speaksEnglish,
          'other_qualification': _otherQualification.text.trim().isEmpty
              ? null
              : _otherQualification.text.trim(),
          'occupation': _occupation.text.trim().isEmpty
              ? null
              : _occupation.text.trim(),
        },
      );
      final data = res.data;
      if (res.status != 200 || data is! Map || data['ok'] != true) {
        final err = data is Map ? data['error'] : data;
        throw Exception(err ?? 'Could not create member (${res.status})');
      }
      if (!mounted) return;
      setState(() {
        _created = true;
        _createdEmail = data['email'] as String?;
        _mailFailed = data['mail_error'] != null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mailFailed
                ? l10n.adminMemberCreatedMailFailed
                : l10n.adminMemberCreated,
          ),
        ),
      );
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_created) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.pop(true);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.addMember),
            backgroundColor: SyuColors.paper,
            foregroundColor: SyuColors.ink,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(true),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _mailFailed
                      ? l10n.adminMemberCreatedMailFailed
                      : l10n.adminMemberCreated,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  _mailFailed
                      ? l10n.adminMemberTempPasswordMailFailedHint
                      : l10n.adminMemberTempPasswordSentHint,
                ),
                if (_createdEmail != null && _createdEmail!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    '${l10n.email}: $_createdEmail',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: () => context.pop(true),
                  child: Text(l10n.done),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SyuColors.paper,
      appBar: AppBar(
        title: Text(l10n.addMember),
        backgroundColor: SyuColors.paper,
        foregroundColor: SyuColors.ink,
        elevation: 0,
      ),
      body: _loadingMeta
          ? const Center(
              child: CircularProgressIndicator(color: SyuColors.crimson),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Text(
                    l10n.adminAddMemberSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SyuColors.mist,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: '${l10n.fullName} *'),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? l10n.nameRequired : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: '${l10n.email} *'),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty || !t.contains('@')) {
                        return l10n.emailRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: '${l10n.phone} *'),
                    validator: (v) =>
                        (v == null || v.trim().length < 9) ? l10n.phoneRequired : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _occupation,
                    decoration: InputDecoration(
                      labelText: l10n.occupation,
                      hintText: l10n.occupationHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nic,
                    focusNode: _nicFocus,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(labelText: l10n.nic),
                    onChanged: (_) => _applyNicDerivedFields(),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      return NicValidator.isValid(t) ? null : l10n.nic;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _dobDisplay,
                    readOnly: true,
                    decoration: InputDecoration(labelText: l10n.dob),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dob ?? DateTime(now.year - 20),
                        firstDate: DateTime(now.year - 40),
                        lastDate: DateTime(now.year - 14),
                      );
                      if (picked == null) return;
                      setState(() {
                        _dob = picked;
                        _dobDisplay.text =
                            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _gender,
                    decoration: InputDecoration(labelText: l10n.gender),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(
                        value: 'prefer_not',
                        child: Text('Prefer not to say'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.location,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  CascadingLocationPicker(
                    initial: _location,
                    onChanged: (v) => setState(() => _location = v),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.youthClub,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'none',
                        label: Text(l10n.youthClubMemberNo),
                      ),
                      ButtonSegment(
                        value: 'yes',
                        label: Text(l10n.youthClubMemberYes),
                      ),
                    ],
                    selected: {_clubMode},
                    onSelectionChanged: (s) =>
                        setState(() => _clubMode = s.first),
                  ),
                  if (_clubMode == 'yes') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _clubName,
                      decoration: InputDecoration(labelText: l10n.youthClubName),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _clubRegistrationNo,
                      decoration: InputDecoration(
                        labelText: l10n.youthClubRegistrationNo,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.qualifications,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final q in _qualifications)
                        FilterChip(
                          label: Text(q['name_en'] as String? ?? ''),
                          selected: _qualificationCodes.contains(q['code']),
                          onSelected: (sel) {
                            setState(() {
                              final code = q['code'] as String;
                              if (sel) {
                                _qualificationCodes.add(code);
                              } else {
                                _qualificationCodes.remove(code);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _otherQualification,
                    decoration: InputDecoration(
                      labelText: l10n.otherQualification,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.languageSkills,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sinhala'),
                    value: _speaksSinhala,
                    onChanged: (v) =>
                        setState(() => _speaksSinhala = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tamil'),
                    value: _speaksTamil,
                    onChanged: (v) => setState(() => _speaksTamil = v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('English'),
                    value: _speaksEnglish,
                    onChanged: (v) =>
                        setState(() => _speaksEnglish = v ?? false),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: AdminPanelChrome.compactFilled.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SyuColors.paper,
                            ),
                          )
                        : const SyuIcon(
                            SyuIcons.userAdd,
                            size: 16,
                            color: SyuColors.paper,
                          ),
                    label: Text(
                      _submitting ? '…' : l10n.createMemberAccount,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

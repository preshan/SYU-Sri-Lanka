import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/validation/nic_and_age.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/features/home/presentation/home_shell.dart';
import 'package:syu_sri_lanka/features/location/presentation/cascading_location_picker.dart';
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
  final _nic = TextEditingController();
  final _nicFocus = FocusNode();
  final _dobDisplay = TextEditingController();
  final _clubName = TextEditingController();
  final _clubRegistrationNo = TextEditingController();
  final _otherQualification = TextEditingController();

  DateTime? _dob;
  String? _gender;
  LocationSelection _location = const LocationSelection();
  /// none | yes
  String _clubMode = 'none';

  bool _loading = true;
  bool _saving = false;
  ProfileCompleteness? _completeness;

  List<Map<String, dynamic>> _qualifications = [];
  final Set<String> _qualificationIds = {};
  bool _speaksSinhala = false;
  bool _speaksTamil = false;
  bool _speaksEnglish = false;

  @override
  void initState() {
    super.initState();
    _nicFocus.addListener(_onNicFocusChange);
    _load();
  }

  @override
  void dispose() {
    _nicFocus.removeListener(_onNicFocusChange);
    _nicFocus.dispose();
    _fullName.dispose();
    _preferred.dispose();
    _phone.dispose();
    _occupation.dispose();
    _nic.dispose();
    _dobDisplay.dispose();
    _clubName.dispose();
    _clubRegistrationNo.dispose();
    _otherQualification.dispose();
    super.dispose();
  }

  void _onNicFocusChange() {
    if (!_nicFocus.hasFocus) _applyNicDerivedFields();
  }

  void _syncDobDisplay() {
    _dobDisplay.text = _dob == null
        ? ''
        : '${_dob!.toIso8601String().split('T').first}'
            '  ·  age ${AgeRules.ageOn(_dob!)}';
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
        _syncDobDisplay();
      }
      if (gender != null && (_gender == null || _gender == 'prefer_not')) {
        _gender = gender;
      }
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - AgeRules.minAge),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: SyuColors.crimson,
              surface: SyuColors.paper,
              onSurface: SyuColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _syncDobDisplay();
      });
    }
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return;

      final results = await Future.wait([
        SupabaseBootstrap.client.from('profiles').select(
              'full_name,preferred_name,phone,nic,date_of_birth,gender,'
              'district_id,ds_division_id,gn_division_id,status,'
              'speaks_sinhala,speaks_tamil,speaks_english,other_qualification,'
              'occupation,requested_youth_club_name,youth_club_registration_no,'
              'youth_club_id',
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
      _nic.text = row?['nic'] as String? ?? '';
      _gender = row?['gender'] as String?;
      final dobRaw = row?['date_of_birth'] as String?;
      if (dobRaw != null && dobRaw.isNotEmpty) {
        _dob = DateTime.tryParse(dobRaw);
        _syncDobDisplay();
      }
      _location = LocationSelection(
        districtId: row?['district_id'] as int?,
        dsDivisionId: row?['ds_division_id'] as int?,
        gnDivisionId: row?['gn_division_id'] as int?,
      );
      final clubName = row?['requested_youth_club_name'] as String? ?? '';
      final clubReg = row?['youth_club_registration_no'] as String? ?? '';
      if (clubName.isNotEmpty || clubReg.isNotEmpty) {
        _clubMode = 'yes';
        _clubName.text = clubName;
        _clubRegistrationNo.text = clubReg;
      } else {
        _clubMode = 'none';
      }
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

  static bool _isValidClubRegistrationNo(String value) {
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/ ]{0,39}$').hasMatch(value);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final ageErr = AgeRules.eligibilityError(_dob, l10n);
    if (ageErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ageErr)));
      return;
    }
    if (_location.districtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.district)),
      );
      return;
    }
    if (_clubMode == 'yes') {
      if (_clubName.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.youthClubNameRequired)),
        );
        return;
      }
      final reg = _clubRegistrationNo.text.trim();
      if (reg.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.youthClubRegistrationNoRequired)),
        );
        return;
      }
      if (!_isValidClubRegistrationNo(reg)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.youthClubRegistrationNoInvalid)),
        );
        return;
      }
    }

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
        'nic': _nic.text.trim().toUpperCase(),
        'date_of_birth': _dob!.toIso8601String().split('T').first,
        'gender': _gender,
        'district_id': _location.districtId,
        'ds_division_id': _location.dsDivisionId,
        'gn_division_id': _location.gnDivisionId,
        'requested_youth_club_name':
            _clubMode == 'yes' ? _clubName.text.trim() : null,
        'youth_club_registration_no':
            _clubMode == 'yes' ? _clubRegistrationNo.text.trim() : null,
        'youth_club_id': null,
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
                            ? l10n.nameRequired
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
                          counterText: '',
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
                            return l10n.phoneRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nic,
                        focusNode: _nicFocus,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(labelText: l10n.nic),
                        validator: (v) => NicValidator.errorText(v, l10n),
                        onEditingComplete: () {
                          _applyNicDerivedFields();
                          FocusScope.of(context).nextFocus();
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _gender,
                        decoration: InputDecoration(labelText: l10n.gender),
                        items: [
                          DropdownMenuItem(
                            value: 'female',
                            child: Text(l10n.genderFemale),
                          ),
                          DropdownMenuItem(
                            value: 'male',
                            child: Text(l10n.genderMale),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text(l10n.genderOther),
                          ),
                          DropdownMenuItem(
                            value: 'prefer_not',
                            child: Text(l10n.genderPreferNot),
                          ),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        readOnly: true,
                        controller: _dobDisplay,
                        onTap: _pickDob,
                        decoration: InputDecoration(
                          labelText: l10n.dob,
                          hintText: l10n.dob,
                          suffixIcon: const SyuFieldIcon(SyuIcons.calendar),
                          filled: true,
                          fillColor: SyuColors.inkSoft,
                        ),
                        validator: (_) =>
                            _dob == null ? l10n.dobRequired : null,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.location,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      CascadingLocationPicker(
                        // Stable key so district/DS/GN changes don't remount mid-edit.
                        key: const ValueKey('edit-profile-location'),
                        initial: _location,
                        onChanged: (sel) => setState(() => _location = sel),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.youthClub,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.alreadyYouthClubMember,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      RadioListTile<String>(
                        value: 'none',
                        // ignore: deprecated_member_use
                        groupValue: _clubMode,
                        title: Text(l10n.youthClubMemberNo),
                        // ignore: deprecated_member_use
                        onChanged: (v) => setState(() {
                          _clubMode = v!;
                          _clubName.clear();
                          _clubRegistrationNo.clear();
                        }),
                      ),
                      RadioListTile<String>(
                        value: 'yes',
                        // ignore: deprecated_member_use
                        groupValue: _clubMode,
                        title: Text(l10n.youthClubMemberYes),
                        // ignore: deprecated_member_use
                        onChanged: (v) => setState(() => _clubMode = v!),
                      ),
                      if (_clubMode == 'yes') ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _clubName,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: l10n.youthClubName,
                            hintText: l10n.youthClubNameHint,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _clubRegistrationNo,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 40,
                          decoration: InputDecoration(
                            labelText: l10n.youthClubRegistrationNo,
                            hintText: l10n.youthClubRegistrationNoHint,
                            counterText: '',
                          ),
                        ),
                      ],
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
                          counterText: '',
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

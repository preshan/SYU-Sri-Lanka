import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/navigation/syu_back_scope.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_icon.dart';
import 'package:syu_sri_lanka/core/validation/nic_and_age.dart';
import 'package:syu_sri_lanka/features/home/presentation/home_shell.dart';
import 'package:syu_sri_lanka/features/location/presentation/cascading_location_picker.dart';
import 'package:syu_sri_lanka/l10n/app_localizations.dart';

class RegistrationWizardScreen extends ConsumerStatefulWidget {
  const RegistrationWizardScreen({super.key});

  @override
  ConsumerState<RegistrationWizardScreen> createState() =>
      _RegistrationWizardScreenState();
}

class _RegistrationWizardScreenState
    extends ConsumerState<RegistrationWizardScreen> {
  final _pageController = PageController();
  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _nic = TextEditingController();
  final _nicFocus = FocusNode();
  final _occupation = TextEditingController();
  final _dobDisplay = TextEditingController();
  DateTime? _dob;
  LocationSelection _location = const LocationSelection();
  String? _gender;
  final Set<String> _qualificationCodes = {};
  bool _speaksSinhala = false;
  bool _speaksTamil = false;
  bool _speaksEnglish = false;
  /// none | yes (already a member)
  String _clubMode = 'none';
  final _clubName = TextEditingController();
  final _clubRegistrationNo = TextEditingController();
  final _otherQualification = TextEditingController();
  List<Map<String, dynamic>> _qualifications = [];
  bool _loadingMeta = true;
  bool _submitting = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _nicFocus.addListener(_onNicFocusChange);
    _loadMeta();
  }

  void _onNicFocusChange() {
    if (!_nicFocus.hasFocus) {
      _applyNicDerivedFields();
    }
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

  void _syncDobDisplay() {
    _dobDisplay.text = _dob == null
        ? ''
        : '${_dob!.toIso8601String().split('T').first}'
            '  ·  age ${AgeRules.ageOn(_dob!)}';
  }

  Future<void> _loadMeta() async {
    try {
      final q = await SupabaseBootstrap.client
          .from('qualifications')
          .select('id,code,name_en')
          .eq('is_active', true)
          .order('level_order');
      setState(() {
        _qualifications = List<Map<String, dynamic>>.from(q as List);
      });
    } catch (e) {
      AppErrorMapper.log(e);
    } finally {
      if (mounted) setState(() => _loadingMeta = false);
    }
  }

  @override
  void dispose() {
    _nicFocus.removeListener(_onNicFocusChange);
    _nicFocus.dispose();
    _pageController.dispose();
    _fullName.dispose();
    _phone.dispose();
    _nic.dispose();
    _occupation.dispose();
    _dobDisplay.dispose();
    _clubName.dispose();
    _clubRegistrationNo.dispose();
    _otherQualification.dispose();
    super.dispose();
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

  void _next() {
    if (!_formKeys[_step].currentState!.validate()) return;
    if (_step == 0 && AgeRules.eligibilityError(_dob, AppLocalizations.of(context)) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AgeRules.eligibilityError(_dob, AppLocalizations.of(context))!,
          ),
        ),
      );
      return;
    }
    if (_step == 1 && _location.districtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your district')),
      );
      return;
    }
    if (_step == 1 && _clubMode == 'yes') {
      final l10n = AppLocalizations.of(context);
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
    if (_step < 3) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  bool _handleSystemBack() {
    if (_step == 0) return false;
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final user = SupabaseBootstrap.client.auth.currentUser;
      if (user == null) {
        context.go('/login');
        return;
      }

      final selected = _qualifications
          .where((q) => _qualificationCodes.contains(q['code']))
          .toList();

      await SupabaseBootstrap.client.rpc(
        'submit_member_registration',
        params: {
          'p_full_name': _fullName.text.trim(),
          'p_phone': _phone.text.trim(),
          'p_nic': _nic.text.trim().toUpperCase(),
          'p_date_of_birth': _dob!.toIso8601String().split('T').first,
          'p_gender': _gender,
          'p_district_id': _location.districtId,
          'p_ds_division_id': _location.dsDivisionId,
          'p_gn_division_id': _location.gnDivisionId,
          'p_youth_club_id': null,
          'p_qualification_ids':
              selected.map((q) => q['id'] as String).toList(),
          'p_requested_youth_club_name':
              _clubMode == 'yes' ? _clubName.text.trim() : null,
          'p_youth_club_registration_no':
              _clubMode == 'yes' ? _clubRegistrationNo.text.trim() : null,
          'p_speaks_sinhala': _speaksSinhala,
          'p_speaks_tamil': _speaksTamil,
          'p_speaks_english': _speaksEnglish,
          'p_other_qualification': _otherQualification.text.trim().isEmpty
              ? null
              : _otherQualification.text.trim(),
          'p_occupation': _occupation.text.trim().isEmpty
              ? null
              : _occupation.text.trim(),
        },
      );

      if (!mounted) return;
      ref.read(profileStatusTickProvider.notifier).state++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration complete. Your membership is active.'),
        ),
      );
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [
      l10n.personal,
      l10n.location,
      l10n.qualifications,
      l10n.review
    ];
    return SyuBackScope(
      onBack: _handleSystemBack,
      fallbackLocation: '/home',
      child: Scaffold(
        appBar: AppBar(
          title: Text('Registration · ${titles[_step]}'),
          leading: IconButton(
            icon: const SyuIcon(SyuIcons.back),
            onPressed: _back,
          ),
        ),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: (_step + 1) / 4,
              color: SyuColors.crimson,
              backgroundColor: SyuColors.inkSoft,
            ),
            Expanded(
              child: _loadingMeta
                  ? const Center(
                      child: CircularProgressIndicator(color: SyuColors.crimson),
                    )
                  : PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _personalStep(),
                        _locationStep(),
                        _qualificationsStep(),
                        _reviewStep(),
                      ],
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton(
                  onPressed: _submitting ? null : _next,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: SyuColors.paper,
                          ),
                        )
                      : Text(_step == 3 ? l10n.submitRegistration : l10n.next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalStep() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKeys[0],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.fullName),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
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
            decoration: InputDecoration(
              labelText: l10n.phoneHint,
              prefixIcon: const SyuFieldIcon(SyuIcons.phone),
            ),
            validator: (v) {
              if (v == null || v.trim().length < 9) {
                return l10n.validPhone;
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
            onFieldSubmitted: (_) => _applyNicDerivedFields(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _gender,
            decoration: InputDecoration(labelText: l10n.gender),
            items: [
              DropdownMenuItem(value: 'female', child: Text(l10n.genderFemale)),
              DropdownMenuItem(value: 'male', child: Text(l10n.genderMale)),
              DropdownMenuItem(value: 'other', child: Text(l10n.genderOther)),
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SyuColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: SyuColors.crimson, width: 1.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: SyuColors.border),
              ),
            ),
            validator: (_) => _dob == null ? l10n.dobRequired : null,
          ),
        ],
      ),
    );
  }

  Widget _locationStep() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKeys[1],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.locationBasedTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.locationBasedSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          CascadingLocationPicker(
            onChanged: (sel) {
              setState(() {
                _location = sel;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.youthClub,
            style: Theme.of(context).textTheme.titleMedium,
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
            onChanged: (v) => setState(() {
              _clubMode = v!;
            }),
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
              validator: (v) {
                if (_clubMode != 'yes') return null;
                if (v == null || v.trim().isEmpty) {
                  return l10n.youthClubNameRequired;
                }
                return null;
              },
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
              validator: (v) {
                if (_clubMode != 'yes') return null;
                final t = v?.trim() ?? '';
                if (t.isEmpty) return l10n.youthClubRegistrationNoRequired;
                if (!_isValidClubRegistrationNo(t)) {
                  return l10n.youthClubRegistrationNoInvalid;
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  static bool _isValidClubRegistrationNo(String value) {
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/ ]{0,39}$').hasMatch(value);
  }

  Widget _qualificationsStep() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKeys[2],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.qualifications,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.selectAllThatApply,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ..._qualifications.map((q) {
            final code = q['code'] as String;
            final selected = _qualificationCodes.contains(code);
            return CheckboxListTile(
              value: selected,
              activeColor: SyuColors.crimson,
              title: Text(_qualificationLabel(q)),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _qualificationCodes.add(code);
                  } else {
                    _qualificationCodes.remove(code);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 16),
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
              if (t.length > 250) return l10n.otherQualificationTooLong;
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text(
            l10n.languageSkills,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.selectLanguagesYouSpeak,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _speaksSinhala,
            activeColor: SyuColors.crimson,
            title: Text(l10n.langSinhala),
            onChanged: (v) => setState(() => _speaksSinhala = v == true),
          ),
          CheckboxListTile(
            value: _speaksTamil,
            activeColor: SyuColors.crimson,
            title: Text(l10n.langTamil),
            onChanged: (v) => setState(() => _speaksTamil = v == true),
          ),
          CheckboxListTile(
            value: _speaksEnglish,
            activeColor: SyuColors.crimson,
            title: Text(l10n.langEnglish),
            onChanged: (v) => setState(() => _speaksEnglish = v == true),
          ),
        ],
      ),
    );
  }

  /// Always show O/L and A/L in capitals regardless of stored casing.
  String _qualificationLabel(Map<String, dynamic> q) {
    final code = (q['code'] as String?)?.toLowerCase();
    if (code == 'ol') return 'O/L';
    if (code == 'al') return 'A/L';
    return q['name_en'] as String? ?? code ?? '';
  }

  Widget _reviewStep() {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKeys[3],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Review & submit', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _row('Name', _fullName.text),
          if (_occupation.text.trim().isNotEmpty)
            _row(l10n.occupation, _occupation.text.trim()),
          _row('Phone', _phone.text),
          _row('NIC', _nic.text.toUpperCase()),
          _row(
            'DOB',
            _dob == null ? '-' : _dob!.toIso8601String().split('T').first,
          ),
          _row(
            l10n.district,
            _location.districtName ?? '-',
          ),
          _row(
            l10n.dsDivision,
            _location.dsDivisionName ?? '-',
          ),
          _row(
            l10n.gnDivision,
            _location.gnDivisionName ?? '-',
          ),
          _row(
            l10n.youthClub,
            _clubMode == 'yes'
                ? [
                    _clubName.text.trim(),
                    if (_clubRegistrationNo.text.trim().isNotEmpty)
                      _clubRegistrationNo.text.trim(),
                  ].join(' · ')
                : l10n.youthClubMemberNo,
          ),
          _row(
            l10n.qualifications,
            _qualificationCodes.isEmpty
                ? 'None'
                : _qualifications
                    .where((q) => _qualificationCodes.contains(q['code']))
                    .map(_qualificationLabel)
                    .join(', '),
          ),
          if (_otherQualification.text.trim().isNotEmpty)
            _row(
              l10n.otherQualification,
              _otherQualification.text.trim(),
            ),
          _row(
            l10n.languageSkills,
            [
              if (_speaksSinhala) l10n.langSinhala,
              if (_speaksTamil) l10n.langTamil,
              if (_speaksEnglish) l10n.langEnglish,
            ].isEmpty
                ? 'None'
                : [
                    if (_speaksSinhala) l10n.langSinhala,
                    if (_speaksTamil) l10n.langTamil,
                    if (_speaksEnglish) l10n.langEnglish,
                  ].join(', '),
          ),
          const SizedBox(height: 16),
          Text(
            'After submit, your membership becomes active immediately.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

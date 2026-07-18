import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syu_sri_lanka/core/errors/app_error_mapper.dart';
import 'package:syu_sri_lanka/core/supabase/supabase_bootstrap.dart';
import 'package:syu_sri_lanka/core/theme/syu_theme.dart';
import 'package:syu_sri_lanka/core/widgets/syu_brand_mark.dart';
import 'package:syu_sri_lanka/features/profile/domain/profile_completeness.dart';

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
  String? _avatarPath;
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  ProfileCompleteness? _completeness;

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
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await SupabaseBootstrap.client
          .from('profiles')
          .select(
            'full_name,preferred_name,phone,avatar_path,nic,date_of_birth,district_id,status',
          )
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      _fullName.text = row?['full_name'] as String? ?? '';
      _preferred.text = row?['preferred_name'] as String? ?? '';
      _phone.text = row?['phone'] as String? ?? '';
      _avatarPath = row?['avatar_path'] as String?;
      _completeness = ProfileCompleteness.fromProfile(row);
      if (_avatarPath != null && _avatarPath!.isNotEmpty) {
        _avatarUrl = SupabaseBootstrap.client.storage
            .from('avatars')
            .getPublicUrl(_avatarPath!);
      }
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser!.id;
      final bytes = await file.readAsBytes();
      final path = '$uid/avatar.jpg';
      await SupabaseBootstrap.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      await SupabaseBootstrap.client
          .from('profiles')
          .update({'avatar_path': path}).eq('id', uid);
      setState(() {
        _avatarPath = path;
        _avatarUrl = SupabaseBootstrap.client.storage
            .from('avatars')
            .getPublicUrl(path);
      });
    } catch (e) {
      if (mounted) AppErrorMapper.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
      }).eq('id', uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
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
    return SyuGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Edit profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
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
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: SyuColors.inkElevated,
                            backgroundImage: _avatarUrl == null
                                ? null
                                : NetworkImage(_avatarUrl!),
                            child: _avatarUrl == null
                                ? const Icon(Icons.person,
                                    size: 40, color: SyuColors.mist)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton.filled(
                              onPressed: _uploading ? null : _pickAvatar,
                              icon: _uploading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: SyuColors.paper,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_completeness != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Completeness ${_completeness!.percent}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: _completeness!.percent / 100,
                        color: SyuColors.crimson,
                        backgroundColor: SyuColors.inkSoft,
                      ),
                      if (_completeness!.missing.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Missing: ${_completeness!.missing.join(', ')}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullName,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _preferred,
                      decoration:
                          const InputDecoration(labelText: 'Preferred name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      validator: (v) {
                        if (v == null || v.trim().length < 9) {
                          return 'Enter a valid phone';
                        }
                        return null;
                      },
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
                          : const Text('Save changes'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

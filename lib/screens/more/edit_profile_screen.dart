import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/student.dart';
import '../../repositories/student_repository.dart';
import '../../core/data_refresh_bus.dart';
import '../../services/avatar_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final Student student;

  const EditProfileScreen({super.key, required this.student});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _schoolController;
  late final TextEditingController _programController;
  late final TextEditingController _levelController;
  final _repo = StudentRepository();
  bool _saving = false;

  // V2 Step 15: profile photo.
  String? _avatarPath;
  bool _photoBusy = false;
  bool _photoChanged = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _schoolController = TextEditingController(text: widget.student.school);
    _programController = TextEditingController(text: widget.student.program);
    _levelController = TextEditingController(text: widget.student.level);
    _avatarPath = widget.student.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _programController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final updated = widget.student.copyWith(
      name: _nameController.text.trim(),
      school: _schoolController.text.trim(),
      program: _programController.text.trim(),
      level: _levelController.text.trim(),
    );
    await _repo.update(updated);
    DataRefreshBus.instance.notify(RefreshScope.all);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);

    try {
      final newPath = await AvatarService.pickAndUpload(source);
      if (!mounted) return;
      if (newPath != null) {
        setState(() {
          _avatarPath = newPath;
          _photoChanged = true;
        });
      }
    } on AvatarException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      debugPrint('Photo pick failed: $e');
      if (mounted)
        _showMessage('Could not change the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);

    try {
      await AvatarService.removePhoto();
      if (!mounted) return;
      setState(() {
        _avatarPath = null;
        _photoChanged = true;
      });
    } on AvatarException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      debugPrint('Photo remove failed: $e');
      if (mounted)
        _showMessage('Could not remove the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _showPhotoOptions() {
    // The camera is only available on phones/tablets.
    final canUseCamera = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (canUseCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickPhoto(ImageSource.camera);
                },
              ),
            if (_avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _photoBusy ? null : _showPhotoOptions,
          child: Stack(
            children: [
              UserAvatar(
                name: widget.student.name,
                avatarPath: _avatarPath,
                size: 96,
                fontSize: 36,
              ),
              if (_photoBusy)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black38,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap to change photo',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the photo was changed, leaving with the back button must still
    // tell the previous screen to reload (pop with true).
    return PopScope<Object?>(
      canPop: !_photoChanged,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                    title: const Text('Edit profile'),
                    leading: const BackButton()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: _photoSection()),
                        const SizedBox(height: AppSpacing.lg),
                        _field('Name', _nameController),
                        const SizedBox(height: AppSpacing.lg),
                        _field('School', _schoolController),
                        const SizedBox(height: AppSpacing.lg),
                        _field('Program', _programController),
                        const SizedBox(height: AppSpacing.lg),
                        _field('Level', _levelController),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: PrimaryButton(
                    label: _saving ? 'Saving...' : 'Save',
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

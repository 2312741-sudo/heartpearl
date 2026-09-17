import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../common/app_text_field.dart';
import '../../common/gradient_button.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  final UserModel user;

  const EditProfileSheet({super.key, required this.user});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  final _picker = ImagePicker();

  File? _newAvatarFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _usernameController = TextEditingController(text: widget.user.username);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    HapticHelper.light();
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() => _newAvatarFile = File(picked.path));
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên hiển thị không được để trống')),
      );
      return;
    }

    if (username.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username phải có ít nhất 3 ký tự')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final photoService = ref.read(photoServiceProvider);

    try {
      if (username != widget.user.username) {
        final available = await authService.isUsernameAvailable(username);
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username này đã có người sử dụng!')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      String? avatarUrl = widget.user.avatarUrl;
      if (_newAvatarFile != null) {
        avatarUrl = await photoService.uploadPhoto(
          file: _newAvatarFile!,
          userId: widget.user.uid,
        );
      }

      await authService.updateUserDocument(widget.user.uid, {
        'displayName': name,
        'username': username,
        'avatarUrl': ?avatarUrl,
      });

      HapticHelper.success();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã cập nhật hồ sơ thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceXl,
        left: AppDimens.spaceXl,
        right: AppDimens.spaceXl,
        top: AppDimens.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorderLight : AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: AppDimens.spaceBase),

          Text(
            'Chỉnh sửa hồ sơ',
            style: AppTypography.h3(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // Avatar edit
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                ClipOval(
                  child: Container(
                    width: 90,
                    height: 90,
                    color: AppColors.darkSurfaceLight,
                    child: _newAvatarFile != null
                        ? Image.file(_newAvatarFile!, fit: BoxFit.cover)
                        : (widget.user.avatarUrl != null
                            ? Image.network(widget.user.avatarUrl!, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  widget.user.displayName.isNotEmpty
                                      ? widget.user.displayName[0].toUpperCase()
                                      : '?',
                                  style: AppTypography.h1(color: AppColors.white),
                                ),
                              )),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.camera, size: 14, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.spaceLg),

          AppTextField(
            controller: _nameController,
            label: 'Tên hiển thị',
          ),

          const SizedBox(height: AppDimens.spaceBase),

          AppTextField(
            controller: _usernameController,
            label: 'Username',
            prefixIcon: const Padding(
              padding: EdgeInsets.all(14.0),
              child: Text(
                '@',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight),
              ),
            ),
          ),

          const SizedBox(height: AppDimens.space2Xl),

          GradientButton(
            text: 'Lưu thay đổi',
            isLoading: _isLoading,
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }
}

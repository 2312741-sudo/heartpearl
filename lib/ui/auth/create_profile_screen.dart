import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/settings_provider.dart';
import '../common/app_text_field.dart';
import '../common/gradient_button.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _picker = ImagePicker();

  File? _avatarFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
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
      setState(() {
        _avatarFile = File(picked.path);
      });
    }
  }

  Future<void> _handleSave() async {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (displayName.isEmpty) {
      _showError('Vui lòng nhập tên hiển thị');
      return;
    }

    if (username.length < 3) {
      _showError('Username phải có ít nhất 3 ký tự');
      return;
    }

    final validUsernameRegex = RegExp(r'^[a-z0-9_.]+$');
    if (!validUsernameRegex.hasMatch(username)) {
      _showError('Username chỉ chứa chữ thường, số, dấu gạch dưới (_) và chấm (.)');
      return;
    }

    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final photoService = ref.read(photoServiceProvider);
    final user = authService.currentUser;

    if (user == null) {
      _showError('Không tìm thấy phiên đăng nhập');
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Check username availability
      final isAvailable = await authService.isUsernameAvailable(username);
      if (!isAvailable) {
        _showError('Username này đã được sử dụng. Vui lòng chọn tên khác!');
        setState(() => _isLoading = false);
        return;
      }

      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await photoService.uploadPhoto(
          file: _avatarFile!,
          userId: user.uid,
        );
      }

      await user.updateDisplayName(displayName);
      if (avatarUrl != null) {
        await user.updatePhotoURL(avatarUrl);
      }

      await authService.updateUserDocument(user.uid, {
        'displayName': displayName,
        'username': username,
        'avatarUrl': ?avatarUrl,
      });

      HapticHelper.success();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showError('Không thể lưu hồ sơ: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    HapticHelper.heavy();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.space2Xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppDimens.spaceLg),

              // Title
              Text(
                AppStrings.tr('profile_create_title', lang: lang),
                style: AppTypography.h1(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),

              const SizedBox(height: AppDimens.spaceSm),

              Text(
                AppStrings.tr('profile_create_sub', lang: lang),
                style: AppTypography.body(
                  color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.7) : AppColors.lightTextMuted,
                ),
              ),

              const SizedBox(height: AppDimens.space2Xl),

              // Avatar picker
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        boxShadow: AppDimens.glowShadow(AppColors.primary, opacity: 0.3),
                      ),
                      child: ClipOval(
                        child: _avatarFile != null
                            ? Image.file(
                                _avatarFile!,
                                width: 98,
                                height: 98,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: AppColors.darkSurfaceLight,
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.user,
                                    size: 48,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkBackground : AppColors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          size: 16,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimens.space2Xl),

              // Display Name
              AppTextField(
                controller: _displayNameController,
                label: AppStrings.tr('profile_display_name', lang: lang),
                hintText: 'Nhập tên hiển thị của bạn',
                prefixIcon: Icon(
                  LucideIcons.smile,
                  size: 20,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),

              const SizedBox(height: AppDimens.spaceLg),

              // Username
              AppTextField(
                controller: _usernameController,
                label: AppStrings.tr('profile_username', lang: lang),
                hintText: 'tamnguyen',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Text(
                    '@',
                    style: AppTypography.bold.copyWith(
                      fontSize: 18,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
                onChanged: (text) {
                  final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
                  if (cleaned != text) {
                    _usernameController.value = TextEditingValue(
                      text: cleaned,
                      selection: TextSelection.collapsed(offset: cleaned.length),
                    );
                  }
                },
              ),

              const SizedBox(height: AppDimens.space3Xl),

              // Submit Button
              GradientButton(
                text: AppStrings.tr('profile_save_continue', lang: lang),
                isLoading: _isLoading,
                onPressed: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_typography.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../common/app_text_field.dart';
import '../common/gradient_button.dart';
import 'create_profile_screen.dart';
import 'phone_login_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.heavy();
      return;
    }

    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final lang = ref.read(settingsProvider).language;

    try {
      if (_isSignUp) {
        await authService.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: 'Người dùng',
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const CreateProfileScreen(),
            ),
          );
        }
      } else {
        await authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = AppStrings.tr('auth.error.default', lang: lang);
      if (e.code == 'user-not-found') {
        message = 'Tài khoản không tồn tại trên hệ thống.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Mật khẩu hoặc thông tin đăng nhập không chính xác.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email này đã được sử dụng bởi một tài khoản khác.';
      } else if (e.code == 'weak-password') {
        message = 'Mật khẩu quá yếu, vui lòng chọn ít nhất 6 ký tự.';
      }

      HapticHelper.heavy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    try {
      final userCred = await authService.signInWithGoogle();
      if (userCred != null && mounted) {
        HapticHelper.success();
        final user = userCred.user;
        if (user != null) {
          final userDoc = await authService.getUserDocument(user.uid);
          if (!mounted) return;
          if (userDoc == null || userDoc.username.startsWith('user_')) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
            );
            return;
          }
        }
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng nhập Google: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    try {
      final userCred = await authService.signInWithApple();
      if (userCred != null && mounted) {
        HapticHelper.success();
        final user = userCred.user;
        if (user != null) {
          final userDoc = await authService.getUserDocument(user.uid);
          if (!mounted) return;
          if (userDoc == null || userDoc.username.startsWith('user_')) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
            );
            return;
          }
        }
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng nhập Apple: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPhoneLogin() {
    HapticHelper.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PhoneLoginSheet(),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? backgroundColor,
    Color? textColor,
    Border? border,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor ?? (isDark ? AppColors.darkSurfaceLight : AppColors.lightSurfaceLight),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: border ?? Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTypography.bodyBold(
                  color: textColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevronLeft,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.space2Xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    boxShadow: AppDimens.glowShadow(AppColors.primary, opacity: 0.3),
                  ),
                  child: Center(
                    child: Text(
                      _isSignUp ? '✨' : '👋',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // Screen title
                Text(
                  _isSignUp
                      ? AppStrings.tr('login_title_up', lang: lang)
                      : AppStrings.tr('login_title_in', lang: lang),
                  style: AppTypography.h1(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),

                const SizedBox(height: AppDimens.spaceSm),

                Text(
                  _isSignUp
                      ? AppStrings.tr('login_sub_up', lang: lang)
                      : AppStrings.tr('login_sub_in', lang: lang),
                  style: AppTypography.body(
                    color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.7) : AppColors.lightTextMuted,
                  ),
                ),

                const SizedBox(height: AppDimens.spaceXl),

                // 1. Social & Phone Sign In Buttons
                _buildSocialButton(
                  icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                  label: 'Tiếp tục với Apple',
                  onTap: _handleAppleSignIn,
                  isDark: isDark,
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                  border: Border.all(color: Colors.white24),
                ),

                const SizedBox(height: AppDimens.spaceSm),

                _buildSocialButton(
                  icon: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ),
                  label: 'Tiếp tục với Google',
                  onTap: _handleGoogleSignIn,
                  isDark: isDark,
                ),

                const SizedBox(height: AppDimens.spaceSm),

                _buildSocialButton(
                  icon: const Icon(LucideIcons.phone, color: AppColors.primaryLight, size: 20),
                  label: 'Đăng nhập bằng Số điện thoại',
                  onTap: _openPhoneLogin,
                  isDark: isDark,
                ),

                const SizedBox(height: AppDimens.spaceXl),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'hoặc sử dụng email',
                        style: AppTypography.caption(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // Email input
                AppTextField(
                  controller: _emailController,
                  label: AppStrings.tr('login_email', lang: lang),
                  hintText: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icon(
                    LucideIcons.mail,
                    size: 20,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // Password input
                AppTextField(
                  controller: _passwordController,
                  label: AppStrings.tr('login_password', lang: lang),
                  hintText: AppStrings.tr('login_password_min', lang: lang),
                  obscureText: _obscurePassword,
                  prefixIcon: Icon(
                    LucideIcons.lock,
                    size: 20,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 20,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Mật khẩu phải có ít nhất 6 ký tự';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppDimens.space2Xl),

                // Submit button
                GradientButton(
                  text: _isSignUp
                      ? AppStrings.tr('login_btn_up', lang: lang)
                      : AppStrings.tr('login_btn_in', lang: lang),
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
                ),

                const SizedBox(height: AppDimens.spaceLg),

                // Toggle sign in / sign up
                Center(
                  child: TextButton(
                    onPressed: () {
                      HapticHelper.selection();
                      setState(() => _isSignUp = !_isSignUp);
                    },
                    child: RichText(
                      text: TextSpan(
                        text: _isSignUp
                            ? AppStrings.tr('login_toggle_up', lang: lang)
                            : AppStrings.tr('login_toggle_in', lang: lang),
                        style: AppTypography.body(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: _isSignUp
                                ? AppStrings.tr('login_toggle_link_up', lang: lang)
                                : AppStrings.tr('login_toggle_link_in', lang: lang),
                            style: AppTypography.bodyBold(color: AppColors.primaryLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

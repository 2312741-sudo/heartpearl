import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/haptic_helper.dart';
import '../../providers/auth_provider.dart';
import '../common/gradient_button.dart';
import 'create_profile_screen.dart';

class PhoneLoginSheet extends ConsumerStatefulWidget {
  const PhoneLoginSheet({super.key});

  @override
  ConsumerState<PhoneLoginSheet> createState() => _PhoneLoginSheetState();
}

class _PhoneLoginSheetState extends ConsumerState<PhoneLoginSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;

  int _countdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _focusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatPhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.startsWith('0')) {
      clean = '+84${clean.substring(1)}';
    } else if (!clean.startsWith('+')) {
      clean = '+84$clean';
    }
    return clean;
  }

  Future<void> _sendOtp() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty || raw.length < 8) {
      setState(() => _errorMessage = 'Vui lòng nhập số điện thoại hợp lệ');
      HapticHelper.heavy();
      return;
    }

    final formattedPhone = _formatPhoneNumber(raw);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);

    try {
      await authService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        resendToken: _resendToken,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isCodeSent = true;
            _isLoading = false;
          });
          _startCountdown();
          _focusNode.requestFocus();
          HapticHelper.medium();
        },
        onVerificationCompleted: (credential) async {
          // Auto-resolution (instant verification)
          if (!mounted) return;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) Navigator.of(context).pop();
          } catch (_) {}
        },
        onVerificationFailed: (e) {
          if (!mounted) return;
          HapticHelper.heavy();
          String msg = e.message ?? 'Không thể gửi mã OTP. Vui lòng thử lại.';
          if (e.code == 'operation-not-allowed') {
            msg = 'Chưa bật phương thức Số điện thoại trong Firebase Console.\nVui lòng vào Authentication > Sign-in method và bật Phone.';
          } else if (e.code == 'invalid-phone-number') {
            msg = 'Số điện thoại không đúng định dạng. Vui lòng kiểm tra lại.';
          } else if (e.code == 'too-many-requests') {
            msg = 'Bạn đã yêu cầu quá nhiều lần. Vui lòng chờ ít phút rồi thử lại.';
          } else if (e.code == 'quota-exceeded') {
            msg = 'Đã đạt giới hạn gửi SMS hàng ngày của Firebase.';
          } else if (e.code == 'captcha-check-failed') {
            msg = 'Xác minh an toàn reCAPTCHA không thành công.';
          }
          setState(() {
            _isLoading = false;
            _errorMessage = msg;
          });
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Lỗi kết nối: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6 || _verificationId == null) {
      setState(() => _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã OTP');
      HapticHelper.heavy();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);

    try {
      final userCred = await authService.signInWithSmsCode(
        verificationId: _verificationId!,
        smsCode: code,
      );

      if (mounted) {
        HapticHelper.success();
        final user = userCred.user;
        if (user != null) {
          final userDoc = await authService.getUserDocument(user.uid);
          if (!mounted) return;
          if (userDoc == null || userDoc.username.startsWith('user_')) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const CreateProfileScreen(),
              ),
            );
            return;
          }
        }
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      HapticHelper.heavy();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.code == 'invalid-verification-code'
              ? 'Mã OTP không chính xác. Vui lòng kiểm tra lại.'
              : (e.message ?? 'Xác thực thất bại.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Lỗi xác thực: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceXl,
        AppDimens.spaceLg,
        AppDimens.spaceXl,
        AppDimens.spaceXl + bottomInset,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.radius2Xl),
        ),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.phone, color: AppColors.primaryLight, size: 22),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCodeSent ? 'Xác thực mã OTP' : 'Đăng nhập Số điện thoại',
                      style: AppTypography.h3(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      _isCodeSent
                          ? 'Nhập 6 số gửi đến ${_formatPhoneNumber(_phoneController.text)}'
                          : 'Mã xác thực SMS sẽ được gửi về số này',
                      style: AppTypography.caption(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceXl),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              margin: const EdgeInsets.only(bottom: AppDimens.spaceLg),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.caption(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!_isCodeSent) ...[
            // Step 1: Input Phone
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceLight : AppColors.lightSurfaceLight,
                    borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🇻🇳', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '+84',
                        style: AppTypography.bodyBold(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    style: AppTypography.bodyBold(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '912 345 678',
                      hintStyle: AppTypography.body(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceLight : AppColors.lightSurfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceXl),
            GradientButton(
              text: 'Nhận mã xác thực OTP',
              isLoading: _isLoading,
              onPressed: _sendOtp,
            ),
          ] else ...[
            // Step 2: Input 6-digit OTP
            Stack(
              children: [
                // Hidden textfield for native keyboard
                Opacity(
                  opacity: 0.0,
                  child: TextFormField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (val) {
                      setState(() {});
                      if (val.length == 6) {
                        _verifyOtp();
                      }
                    },
                  ),
                ),
                // Custom 6-digit boxes
                GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      final text = _otpController.text;
                      final char = index < text.length ? text[index] : '';
                      final isFocused = index == text.length;

                      return Container(
                        width: 46,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceLight : AppColors.lightSurfaceLight,
                          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          border: Border.all(
                            color: isFocused
                                ? AppColors.primary
                                : (char.isNotEmpty
                                    ? AppColors.primaryLight.withValues(alpha: 0.5)
                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                            width: isFocused ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: AppTypography.h2(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimens.spaceXl),

            GradientButton(
              text: 'Xác nhận & Tiếp tục',
              isLoading: _isLoading,
              onPressed: _verifyOtp,
            ),

            const SizedBox(height: AppDimens.spaceMd),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isCodeSent = false;
                      _otpController.clear();
                      _errorMessage = null;
                    });
                  },
                  child: const Text('Đổi số điện thoại', style: TextStyle(color: AppColors.pearl)),
                ),
                TextButton(
                  onPressed: _countdown == 0 ? _sendOtp : null,
                  child: Text(
                    _countdown > 0 ? 'Gửi lại mã (${_countdown}s)' : 'Gửi lại mã ngay',
                    style: TextStyle(
                      color: _countdown == 0 ? AppColors.primaryLight : AppColors.darkTextMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

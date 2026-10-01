import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/forgot_password_model.dart';
import '../services/forgot_password_service.dart';
import '../constants/app_constants.dart';
import '../widgets/logo_widget.dart';
import '../widgets/gradient_button.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Controllers
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // States
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isEmailVerified = false;

  // Step management
  int _currentStep = 0; // 0 = Email, 1 = OTP, 2 = Reset Password

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Send OTP
  Future<void> _sendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Error', 'Please enter your email');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showErrorDialog('Error', 'Please enter a valid email');
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final request = ForgotPasswordSendOtpRequest(
        email: _emailController.text.trim(),
      );

      final response = await ForgotPasswordService.sendOtp(request);

      setState(() {
        _isSendingOtp = false;
        _currentStep = 1; // Move to OTP verification step
      });

      _showSuccessDialog('OTP Sent', 'OTP has been sent to your email address');
    } catch (e) {
      setState(() {
        _isSendingOtp = false;
      });
      _showErrorDialog('Failed', e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Verify OTP
  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      _showErrorDialog('Error', 'Please enter the OTP');
      return;
    }

    if (_otpController.text.length < 6) {
      _showErrorDialog('Error', 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final request = ForgotPasswordVerifyOtpRequest(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );

      final response = await ForgotPasswordService.verifyOtp(request);

      setState(() {
        _isVerifyingOtp = false;
        _isEmailVerified = true;
        _currentStep = 2; // Move to reset password step
      });

      _showSuccessDialog('Verified', 'OTP verified successfully!');
    } catch (e) {
      setState(() {
        _isVerifyingOtp = false;
      });
      _showErrorDialog('Verification Failed', e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Reset Password
  Future<void> _resetPassword() async {
    // Validate passwords
    if (_passwordController.text.trim().isEmpty) {
      _showErrorDialog('Error', 'Please enter a new password');
      return;
    }

    if (_passwordController.text.length < 8) {
      _showErrorDialog('Error', 'Password must be at least 8 characters');
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(_passwordController.text)) {
      _showErrorDialog('Error', 'Password must contain at least 1 uppercase letter');
      return;
    }

    if (!RegExp(r'[0-9]').hasMatch(_passwordController.text)) {
      _showErrorDialog('Error', 'Password must contain at least 1 digit');
      return;
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_passwordController.text)) {
      _showErrorDialog('Error', 'Password must contain at least 1 special character');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog('Error', 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = ForgotPasswordResetRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
      );

      final response = await ForgotPasswordService.resetPassword(request);

      setState(() {
        _isLoading = false;
      });

      _showSuccessDialog(
        'Password Reset Successful',
        'Your password has been reset. Please sign in.',
        onOk: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Reset Failed', e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Dialog Helpers
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppConstants.error,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppConstants.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppConstants.success,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppConstants.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppConstants.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppConstants.textPrimary,
            size: 20,
          ),
        ),
        title: Text(
          'Forgot Password',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Glossy Elements
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: GlossyDecoration.glossyCircle,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: GlossyDecoration.glossyCircleAccent,
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        const LogoWidget(size: 40, showSubtitle: false, useImage: true),
                        const SizedBox(height: 6),
                        Text(
                          _currentStep == 0
                              ? 'Reset Your Password'
                              : (_currentStep == 1
                              ? 'Verify OTP'
                              : 'Create New Password'),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          _currentStep == 0
                              ? 'Enter your email to receive OTP'
                              : (_currentStep == 1
                              ? 'Enter the OTP sent to your email'
                              : 'Enter your new password'),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppConstants.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Step Indicator
                  Row(
                    children: [
                      _buildStepIndicator(0, 'Email', _currentStep >= 0),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 1
                              ? AppConstants.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      _buildStepIndicator(1, 'OTP', _currentStep >= 1),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 2
                              ? AppConstants.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      _buildStepIndicator(2, 'Reset', _currentStep >= 2),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Step 0: Email
                  if (_currentStep == 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Enter your registered email',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: AppConstants.textLight,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Step 1: OTP Verification
                  if (_currentStep == 1)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppConstants.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppConstants.primary.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: AppConstants.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'OTP sent to ${_emailController.text}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppConstants.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Enter OTP',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            hintText: 'Enter 6-digit OTP',
                            prefixIcon: Icon(
                              Icons.password_outlined,
                              color: AppConstants.textLight,
                            ),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _isSendingOtp ? null : _sendOtp,
                              child: Text(
                                _isSendingOtp ? 'Sending...' : 'Resend OTP',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.primary,
                                ),
                              ),
                            ),
                            if (_isEmailVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppConstants.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppConstants.success,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppConstants.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                  // Step 2: Reset Password
                  if (_currentStep == 2)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Password',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Enter new password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppConstants.textLight,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppConstants.textLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Confirm Password',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: 'Confirm new password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppConstants.textLight,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppConstants.textLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppConstants.primary.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password Requirements:',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppConstants.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Minimum 8 characters\n'
                                    '• At least 1 uppercase letter\n'
                                    '• At least 1 digit\n'
                                    '• At least 1 special character (@\$!%*?&)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppConstants.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Submit Button
                  GradientButton(
                    text: _currentStep == 0
                        ? 'Send OTP'
                        : (_currentStep == 1
                        ? 'Verify OTP'
                        : 'Reset Password'),
                    onPressed: _currentStep == 0
                        ? _sendOtp
                        : (_currentStep == 1
                        ? _verifyOtp
                        : _resetPassword),
                    isLoading: _isLoading || _isSendingOtp || _isVerifyingOtp,
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Remember your password?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppConstants.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppConstants.primary : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppConstants.textPrimary : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
// lib/screens/register_screen.dart
//
// Register – designed to match the login screen (brand blue #1A68FA, dark blue
// #0D3880, accent #FF5722, page #F6F8FC, white cards, slate inputs).
// Logic unchanged: send OTP -> verify OTP -> complete registration.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/registration_model.dart';
import '../services/registration_service.dart';
import '../utils/shared_preferences_helper.dart';
import '../widgets/product_ui.dart';
import 'login_screen.dart';
import 'terms_conditions_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  // States
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeTerms = false;
  bool _isEmailVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  // Step management
  int _currentStep = 0; // 0 = Registration Form, 1 = OTP Verification

  static const _brand = Color(0xFF1A68FA);
  static const _brandDark = Color(0xFF0D3880);
  static const _accent = Color(0xFFFF5722);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // =====================================================================
  // LOGIC (unchanged)
  // =====================================================================
  Future<void> _sendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog('Error', 'Please enter your email first');
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final request = SendOtpRequest(
        email: _emailController.text.trim(),
      );

      final response = await RegistrationService.sendOtp(request);

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

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      _showErrorDialog('Error', 'Please enter the OTP');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final request = VerifyOtpRequest(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
      );

      final response = await RegistrationService.verifyOtp(request);

      setState(() {
        _isVerifyingOtp = false;
        _isEmailVerified = true;
      });

      _showSuccessDialog('Verified', 'Email verified successfully!');
    } catch (e) {
      setState(() {
        _isVerifyingOtp = false;
      });
      _showErrorDialog(
          'Verification Failed', e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _register() async {
    if (_currentStep == 0) {
      // Validate form first
      if (_formKey.currentState!.validate() && _agreeTerms) {
        // Send OTP
        await _sendOtp();
      } else if (!_agreeTerms) {
        _showErrorDialog(
            'Terms Required', 'Please agree to the Terms & Conditions');
      }
      return;
    }

    // Step 1: Verify OTP first
    if (_currentStep == 1 && !_isEmailVerified) {
      await _verifyOtp();
      return;
    }

    // Step 2: Complete Registration
    if (_isEmailVerified) {
      setState(() {
        _isLoading = true;
      });

      try {
        final request = RegisterRequest(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final response = await RegistrationService.register(request);

        setState(() {
          _isLoading = false;
        });

        _showSuccessDialog(
          'Registration Complete',
          'Your account has been created. Please sign in.',
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
        _showErrorDialog(
            'Registration Failed', e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _openTerms() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
    );
    if (result == true && mounted) {
      setState(() => _agreeTerms = true);
    }
  }

  // =====================================================================
  // DIALOG HELPERS
  // =====================================================================
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration:
          const BoxDecoration(color: DT.errorBg, shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded,
              color: DT.error, size: 26),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: DT.text(size: 17, weight: FontWeight.w700, color: DT.onyx900),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: DT.text(size: 13.5, color: DT.slate500, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('OK',
                  style: DT.text(
                      size: 14, weight: FontWeight.w700, color: Colors.white)),
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
        icon: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
              color: DT.emerald50, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: Color(0xFF059669), size: 28),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: DT.text(size: 17, weight: FontWeight.w700, color: DT.onyx900),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: DT.text(size: 13.5, color: DT.slate500, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (onOk != null) onOk();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('OK',
                  style: DT.text(
                      size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _hero(context),
              Transform.translate(
                offset: const Offset(0, -34),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _formCard(),
                      const SizedBox(height: 18),
                      _loginCard(),
                      const SizedBox(height: 18),
                      _footer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero (brand gradient, same as login) ────────────────
  Widget _hero(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, top + 22, 22, 62),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandDark, Color(0xFF1557D0), _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -18,
            bottom: -46,
            child: Icon(Icons.storefront_rounded,
                size: 150, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Image.asset(
                      'lib/assets/images/qnx_mart_logo.png',
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('QNX', style: DT.text(size: 20, weight: FontWeight.w900, color: _brandDark, letterSpacing: -0.8)),
                          const SizedBox(width: 3),
                          Text('MART', style: DT.text(size: 20, weight: FontWeight.w800, color: _accent, letterSpacing: -0.4)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text('B2B',
                        style: DT.text(size: 10, weight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Market chalega nahi, daudega',
                  style: DT.text(size: 11, weight: FontWeight.w600, color: Colors.white60)),
              Text('Market chalega nahi, daudega',
                  style: DT.text(
                      size: 11,
                      weight: FontWeight.w600,
                      color: Colors.white60)),
              const SizedBox(height: 26),
              Text('Create your account ✨',
                  style: DT.text(
                      size: 26,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(
                  'Join QNXMart B2B to buy, sell and grow your business.',
                  style: DT.text(
                      size: 13.5,
                      color: const Color(0xFFBFDBFE),
                      height: 1.45)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip(Icons.shopping_bag_outlined, 'Products'),
                  _heroChip(Icons.apartment_rounded, 'Real Estate'),
                  _heroChip(Icons.recycling_rounded, 'ReMart'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 5),
        Text(label,
            style: DT.text(
                size: 11.5, weight: FontWeight.w700, color: Colors.white)),
      ],
    ),
  );

  // ── Form card ───────────────────────────────────────────
  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DT.slate200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 6)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentStep == 0 ? 'Register' : 'Verify email',
                          style: DT.text(
                              size: 18,
                              weight: FontWeight.w800,
                              color: DT.onyx900)),
                      const SizedBox(height: 2),
                      Text(
                        _currentStep == 0
                            ? 'Fill in your details to get started'
                            : 'Enter the OTP sent to your email',
                        style: DT.text(size: 12, color: DT.slate500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step indicator
            _stepIndicator(),
            const SizedBox(height: 18),

            // Step 0: Registration form
            if (_currentStep == 0) ...[
              const PxLabel('Full name', required: true),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style:
                DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
                decoration: pxInputDecoration(
                  hint: 'Enter your full name',
                  icon: Icons.person_outline_rounded,
                  iconColor: _brand,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const PxLabel('Email address', required: true),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style:
                DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
                decoration: pxInputDecoration(
                  hint: 'Enter your email',
                  icon: Icons.mail_outline_rounded,
                  iconColor: _brand,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const PxLabel('Phone number', required: true),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                style:
                DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
                decoration: pxInputDecoration(
                  hint: 'Enter your phone number',
                  icon: Icons.phone_outlined,
                  iconColor: _brand,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const PxLabel('Address', required: true),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style:
                DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
                decoration: pxInputDecoration(
                  hint: 'Enter your address',
                  icon: Icons.location_on_outlined,
                  iconColor: _brand,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const PxLabel('Username', required: true),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                style:
                DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
                decoration: pxInputDecoration(
                  hint: 'Choose a username',
                  icon: Icons.account_circle_outlined,
                  iconColor: _brand,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please choose a username';
                  }
                  if (value.length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const PxLabel('Password', required: true),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                style:
                DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
                decoration: pxInputDecoration(
                  hint: 'Create a strong password',
                  icon: Icons.lock_outline_rounded,
                  iconColor: _brand,
                  suffix: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: DT.slate400,
                      size: 20,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please create a password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'Must contain at least 1 uppercase letter';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Must contain at least 1 digit';
                  }
                  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
                    return 'Must contain at least 1 special character';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const PxLabel('Confirm password', required: true),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isLoading && !_isSendingOtp) _register();
                },
                style:
                DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
                decoration: pxInputDecoration(
                  hint: 'Re-enter your password',
                  icon: Icons.lock_outline_rounded,
                  iconColor: _brand,
                  suffix: IconButton(
                    tooltip: _obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () => setState(() =>
                    _obscureConfirmPassword = !_obscureConfirmPassword),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: DT.slate400,
                      size: 20,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],

            // Step 1: OTP verification
            if (_currentStep == 1) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _brand.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded,
                        color: _brand, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OTP sent to ${_emailController.text}',
                        style: DT.text(size: 12.5, color: DT.slate500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const PxLabel('Enter OTP', required: true),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isVerifyingOtp) _register();
                },
                style: DT.text(
                    size: 16,
                    weight: FontWeight.w700,
                    color: DT.onyx900,
                    letterSpacing: 6),
                decoration:
                pxInputDecoration(hint: '6-digit OTP', icon: Icons.password_outlined, iconColor: _brand)
                    .copyWith(counterText: ''),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton(
                    onPressed: _isSendingOtp ? null : _sendOtp,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isSendingOtp ? 'Sending…' : 'Resend OTP',
                      style: DT.text(
                          size: 13, weight: FontWeight.w700, color: _brand),
                    ),
                  ),
                  const Spacer(),
                  if (_isEmailVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF059669), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: DT.text(
                                size: 12,
                                weight: FontWeight.w700,
                                color: const Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // Terms & Conditions (only on step 0)
            if (_currentStep == 0) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _agreeTerms,
                          onChanged: (value) =>
                              setState(() => _agreeTerms = value ?? false),
                          activeColor: _brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: DT.text(size: 12.5, color: DT.slate500),
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: _openTerms,
                                    child: Text(
                                      'Terms & Conditions',
                                      style: DT.text(
                                        size: 12.5,
                                        weight: FontWeight.w700,
                                        color: _brand,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                TextSpan(
                                    text: ' and ',
                                    style: DT.text(
                                        size: 12.5, color: DT.slate500)),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap: _openTerms,
                                    child: Text(
                                      'Privacy Policy',
                                      style: DT.text(
                                        size: 12.5,
                                        weight: FontWeight.w700,
                                        color: _brand,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
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
            ],

            const SizedBox(height: 20),

            // Primary submit button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed:
                (_isLoading || _isSendingOtp || _isVerifyingOtp)
                    ? null
                    : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  disabledBackgroundColor: _brand.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0x401A68FA),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: (_isLoading || _isSendingOtp || _isVerifyingOtp)
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _currentStep == 0
                          ? 'Sending OTP…'
                          : (_isEmailVerified
                          ? 'Creating account…'
                          : 'Verifying…'),
                      style: DT.text(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentStep == 0
                          ? 'Continue'
                          : (_isEmailVerified
                          ? 'Complete Registration'
                          : 'Verify OTP'),
                      style: DT.text(
                          size: 15,
                          weight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step indicator ──────────────────────────────────────
  Widget _stepIndicator() {
    Widget dot(int step, String label) {
      final isActive = _currentStep >= step;
      return Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _brand : DT.slate200,
            ),
            child: Text(
              '${step + 1}',
              style: DT.text(
                  size: 12,
                  weight: FontWeight.w700,
                  color: isActive ? Colors.white : DT.slate500),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: DT.text(
              size: 10,
              weight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? DT.onyx900 : DT.slate400,
            ),
          ),
        ],
      );
    }

    Widget connector(bool active) => Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: active ? _brand : DT.slate200,
      ),
    );

    return Row(
      children: [
        dot(0, 'Details'),
        connector(_currentStep >= 1),
        dot(1, 'OTP'),
      ],
    );
  }

  // ── Login card ──────────────────────────────────────────
  Widget _loginCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DT.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.login_rounded,
                    color: _brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Already have an account?',
                        style: DT.text(
                            size: 14,
                            weight: FontWeight.w800,
                            color: DT.onyx900)),
                    Text('Sign in to continue',
                        style: DT.text(size: 12, color: DT.slate500)),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Text('Login',
                    style: DT.text(
                        size: 12.5, weight: FontWeight.w800, color: _brand)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────
  Widget _footer() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_outlined,
                size: 15, color: DT.slate400),
            const SizedBox(width: 6),
            Text('Your details are encrypted and secure',
                style: DT.text(size: 11.5, color: DT.slate400)),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
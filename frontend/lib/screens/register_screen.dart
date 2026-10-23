// lib/screens/register_screen.dart
//
// Register – colours matched to the QNX MART logo:
//   brand blue #093C71 (primary, logo "QNX") · red "MART" = errors · orange arrow = permission / condition
//
// Flow on one card:
//   1. Email      -> "Send OTP"           (RegistrationService.sendOtp)
//   2. OTP        appears below the email (RegistrationService.verifyOtp, auto-verifies at 6 digits)
//   3. Details    form opens after the email is verified (RegistrationService.register)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/registration_model.dart';
import '../services/registration_service.dart';
import 'login_screen.dart';
import 'terms_conditions_screen.dart';

// ── Logo-matched palette (private to this screen) ─────────────
const _brand = Color(0xFF093C71); // #093C71 – primary (logo "QNX" blue)
const _brandDark = Color(0xFF062A50);
const _brandLight = Color(0xFF1E5A9C);
const _brandTint = Color(0xFFEAF1F9);
const _brandLine = Color(0xFFC9DBEE);
const _brandSoft = Color(0xFFA3C1E0);
const _navy = Color(0xFF093C71); // logo "QNX"
const _red = Color(0xFFC62828); // logo "MART" – errors
const _redBg = Color(0xFFFEF2F2);
const _orange = Color(0xFFF7931E); // logo arrow – permission / condition
const _orangeDark = Color(0xFFC2410C);
const _orangeBg = Color(0xFFFFF7ED);
const _orangeLine = Color(0xFFFED7AA);
const _green = Color(0xFF10B981);

const _heroGradient = LinearGradient(
  colors: [_brandDark, _brand, _brandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _otpLength = 6;
const _resendSeconds = 30;

enum _Stage { email, otp, details }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _Stage _stage = _Stage.email;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _registering = false;
  bool _agreeTerms = false;
  bool _showTermsError = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _otpError;
  int _resendIn = 0;
  Timer? _timer;

  bool get _busy => _sendingOtp || _verifyingOtp || _registering;
  String get _email => _emailController.text.trim();

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _emailController,
      _otpController,
      _nameController,
      _phoneController,
      _addressController,
      _usernameController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.dispose();
    }
    _otpFocus.dispose();
    super.dispose();
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '').trim();

  // =====================================================================
  // LOGIC
  // =====================================================================
  Future<void> _sendOtp({bool resend = false}) async {
    FocusScope.of(context).unfocus();
    if (!resend && !_emailFormKey.currentState!.validate()) return;

    setState(() {
      _sendingOtp = true;
      _otpError = null;
    });
    try {
      await RegistrationService.sendOtp(SendOtpRequest(email: _email));
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _sendingOtp = false;
        _stage = _Stage.otp;
      });
      _startResendTimer();
      _snack(resend ? 'A new OTP has been sent to $_email' : 'OTP sent to $_email');
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _otpFocus.requestFocus();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingOtp = false);
      _showErrorDialog('Could not send OTP', _clean(e));
    }
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != _otpLength) {
      setState(() => _otpError = 'Enter the $_otpLength-digit OTP');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _verifyingOtp = true;
      _otpError = null;
    });
    try {
      await RegistrationService.verifyOtp(VerifyOtpRequest(email: _email, otp: otp));
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _verifyingOtp = false;
        _stage = _Stage.details;
      });
      _snack('Email verified. Complete your details.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyingOtp = false;
        _otpError = _clean(e);
      });
      _otpController.clear();
      _otpFocus.requestFocus();
    }
  }

  void _changeEmail() {
    _timer?.cancel();
    _otpController.clear();
    setState(() {
      _stage = _Stage.email;
      _otpError = null;
      _resendIn = 0;
    });
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    final ok = _detailsFormKey.currentState!.validate();
    setState(() => _showTermsError = !_agreeTerms);
    if (!ok) return;
    if (!_agreeTerms) {
      _showConditionDialog('Terms required', 'Please agree to the Terms & Conditions to continue.');
      return;
    }

    setState(() => _registering = true);
    try {
      await RegistrationService.register(RegisterRequest(
        name: _nameController.text.trim(),
        email: _email,
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      ));
      if (!mounted) return;
      setState(() => _registering = false);
      _showSuccessDialog(
        'Account created 🎉',
        'Welcome to QNXMart B2B, ${_nameController.text.trim().split(' ').first}! Please sign in to continue.',
        onOk: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _registering = false);
      _showErrorDialog('Registration failed', _clean(e));
    }
  }

  Future<void> _openTerms() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
    );
    if (result == true && mounted) {
      setState(() {
        _agreeTerms = true;
        _showTermsError = false;
      });
    }
  }

  Future<bool> _confirmLeave() async {
    if (_stage == _Stage.email) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave registration?', style: DT.text(size: 17, weight: FontWeight.w800)),
        content: Text('You will need to verify your email again.',
            style: DT.text(size: 13.5, color: DT.slate500, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Leave', style: DT.text(size: 14, weight: FontWeight.w700, color: _red)),
          ),
        ],
      ),
    );
    return leave == true;
  }

  // =====================================================================
  // FEEDBACK
  // =====================================================================
  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white))),
          ],
        ),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  /// Real errors (server / OTP / registration) → logo red.
  void _showErrorDialog(String title, String message) => _dialog(
    icon: Icons.error_outline_rounded,
    iconColor: _red,
    iconBg: _redBg,
    title: title,
    message: message,
  );

  /// Permission / condition not met (terms, rules) → logo orange.
  void _showConditionDialog(String title, String message) => _dialog(
    icon: Icons.warning_amber_rounded,
    iconColor: _orange,
    iconBg: _orangeBg,
    title: title,
    message: message,
  );

  void _showSuccessDialog(String title, String message, {VoidCallback? onOk}) => _dialog(
    icon: Icons.check_rounded,
    iconColor: _green,
    iconBg: DT.emerald50,
    title: title,
    message: message,
    dismissible: false,
    onOk: onOk,
  );

  void _dialog({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String message,
    bool dismissible = true,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: dismissible,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        title: Text(title,
            textAlign: TextAlign.center, style: DT.text(size: 17, weight: FontWeight.w800, color: DT.onyx900)),
        content: Text(message,
            textAlign: TextAlign.center, style: DT.text(size: 13.5, color: DT.slate500, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onOk?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand, // buttons: only #093C71
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('OK', style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
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
    return PopScope(
      canPop: _stage == _Stage.email && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: DT.background,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                _hero(context),
                Transform.translate(
                  offset: const Offset(0, -34),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _card(),
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
      ),
    );
  }

  // ── Hero ────────────────────────────────────────────────
  Widget _hero(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, top + 18, 22, 62),
      decoration: const BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -18,
            bottom: -46,
            child: Icon(Icons.storefront_rounded, size: 150, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Image.asset(
                      'lib/assets/images/qnx_mart_logo.png',
                      height: 30,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('QNX',
                              style: DT.text(size: 19, weight: FontWeight.w900, color: _navy, letterSpacing: -0.8)),
                          const SizedBox(width: 3),
                          Text('MART',
                              style: DT.text(size: 19, weight: FontWeight.w800, color: _red, letterSpacing: -0.4)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('B2B',
                        style: DT.text(size: 10, weight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Market chalega nahi, daudega',
                  style: DT.text(size: 11, weight: FontWeight.w700, color: const Color(0xFFFFD8A8))),
              const SizedBox(height: 22),
              Text('Create your account ✨',
                  style: DT.text(size: 26, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(
                switch (_stage) {
                  _Stage.email => 'Start with your email – we\'ll send you a one-time code.',
                  _Stage.otp => 'Check your inbox and enter the 6-digit code.',
                  _Stage.details => 'Almost done! Tell us a little about you.',
                },
                style: DT.text(size: 13.5, color: _brandLine, height: 1.45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Main card ───────────────────────────────────────────
  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DT.slate200),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stepper(),
            const SizedBox(height: 20),
            _emailBlock(),
            if (_stage == _Stage.otp) ...[
              const SizedBox(height: 18),
              _otpBlock(),
            ],
            if (_stage == _Stage.details) ...[
              const SizedBox(height: 18),
              _detailsBlock(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Stepper ─────────────────────────────────────────────
  Widget _stepper() {
    final current = _stage.index;
    Widget dot(int i, String label, IconData icon) {
      final done = current > i;
      final active = current == i;
      return Expanded(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? _green : (active ? _brand : DT.slate100),
                boxShadow: active
                    ? const [BoxShadow(color: Color(0x40093C71), blurRadius: 10, offset: Offset(0, 3))]
                    : null,
              ),
              child: Icon(done ? Icons.check_rounded : icon,
                  size: 18, color: done || active ? Colors.white : DT.slate400),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(
                    size: 11.5,
                    weight: active || done ? FontWeight.w700 : FontWeight.w500,
                    color: active ? DT.onyx900 : (done ? _green : DT.slate400))),
          ],
        ),
      );
    }

    Widget line(int afterStep) => Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          color: current > afterStep ? _green : DT.slate200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    return Row(
      children: [
        dot(0, 'Email', Icons.mail_outline_rounded),
        line(0),
        dot(1, 'Verify', Icons.password_rounded),
        line(1),
        dot(2, 'Details', Icons.person_outline_rounded),
      ],
    );
  }

  // ── Step 1: email ───────────────────────────────────────
  Widget _emailBlock() {
    final locked = _stage != _Stage.email;
    final verified = _stage == _Stage.details;
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _label('Email address', required: !locked)),
              if (locked && !verified)
                _linkButton('Change', Icons.edit_outlined, _busy ? null : _changeEmail),
            ],
          ),
          TextFormField(
            controller: _emailController,
            readOnly: locked,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) {
              if (!_busy && !locked) _sendOtp();
            },
            style: _inputStyle.copyWith(color: locked ? DT.onyx700 : DT.onyx900),
            decoration: _input(
              hint: 'you@company.com',
              icon: Icons.mail_outline_rounded,
              filled: locked ? DT.slate50 : Colors.white,
              suffix: verified
                  ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: _green, size: 18),
                    const SizedBox(width: 4),
                    Text('Verified', style: DT.text(size: 12, weight: FontWeight.w800, color: _green)),
                  ],
                ),
              )
                  : null,
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w\-.+]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(t)) return 'Please enter a valid email';
              return null;
            },
          ),
          if (!locked) ...[
            const SizedBox(height: 16),
            _primaryButton(
              label: 'Send OTP',
              busyLabel: 'Sending OTP…',
              icon: Icons.send_rounded,
              busy: _sendingOtp,
              onPressed: _busy ? null : _sendOtp,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: DT.slate400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('We\'ll send a 6-digit code to verify this email.',
                      style: DT.text(size: 11.5, color: DT.slate500)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 2: OTP ─────────────────────────────────────────
  Widget _otpBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: _brandTint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.mark_email_read_outlined, color: _brand, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enter verification code',
                        style: DT.text(size: 14, weight: FontWeight.w800, color: DT.onyx900)),
                    Text.rich(
                      TextSpan(
                        text: 'Sent to ',
                        style: DT.text(size: 12, color: DT.slate500),
                        children: [
                          TextSpan(text: _email, style: DT.text(size: 12, weight: FontWeight.w700, color: DT.onyx800)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _OtpBoxes(
            controller: _otpController,
            focusNode: _otpFocus,
            length: _otpLength,
            hasError: _otpError != null,
            enabled: !_verifyingOtp,
            onChanged: (v) {
              if (_otpError != null) setState(() => _otpError = null);
              if (v.length == _otpLength && !_verifyingOtp) _verifyOtp();
            },
          ),
          if (_otpError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 15, color: _red),
                const SizedBox(width: 6),
                Expanded(child: Text(_otpError!, style: DT.text(size: 12, weight: FontWeight.w600, color: _red))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Didn\'t get it?', style: DT.text(size: 12.5, color: DT.slate500)),
              const SizedBox(width: 4),
              if (_resendIn > 0)
                Text('Resend in ${_resendIn}s', style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.slate400))
              else
                _linkButton(_sendingOtp ? 'Sending…' : 'Resend OTP', Icons.refresh_rounded,
                    _busy ? null : () => _sendOtp(resend: true)),
            ],
          ),
          const SizedBox(height: 14),
          _primaryButton(
            label: 'Verify OTP',
            busyLabel: 'Verifying…',
            icon: Icons.verified_user_outlined,
            busy: _verifyingOtp,
            onPressed: _busy ? null : _verifyOtp,
          ),
        ],
      ),
    );
  }

  // ── Step 3: details ─────────────────────────────────────
  Widget _detailsBlock() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.badge_outlined, 'Your details'),
          const SizedBox(height: 12),
          _label('Full name', required: true),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            style: _inputStyle,
            decoration: _input(hint: 'Enter your full name', icon: Icons.person_outline_rounded),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 14),
          _label('Mobile number', required: true),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: _inputStyle,
            decoration: _input(hint: '10-digit mobile number', icon: Icons.phone_outlined).copyWith(
              prefixText: '+91  ',
              prefixStyle: DT.text(size: 14, weight: FontWeight.w700, color: DT.slate500),
            ),
            validator: (v) =>
            RegExp(r'^[6-9]\d{9}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid 10-digit mobile number',
          ),
          const SizedBox(height: 14),
          _label('Address', required: true),
          TextFormField(
            controller: _addressController,
            minLines: 2,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: _inputStyle.copyWith(fontWeight: FontWeight.w500),
            decoration: _input(hint: 'Shop / office, area, city', icon: Icons.location_on_outlined, filled: DT.slate50),
            validator: (v) => (v ?? '').trim().length < 5 ? 'Please enter your address' : null,
          ),
          const SizedBox(height: 20),
          _sectionTitle(Icons.lock_outline_rounded, 'Login details'),
          const SizedBox(height: 12),
          _label('Username', required: true),
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            style: _inputStyle,
            decoration: _input(hint: 'Choose a username', icon: Icons.alternate_email_rounded),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Please choose a username';
              if (t.length < 3) return 'Username must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _label('Password', required: true),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            style: _inputStyle,
            decoration: _input(
              hint: 'Create a strong password',
              icon: Icons.lock_outline_rounded,
              suffix: _eye(_obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)),
            ),
            validator: (v) {
              final p = v ?? '';
              if (p.isEmpty) return 'Please create a password';
              if (_passwordRules.any((r) => !r.$2(p))) return 'Password does not meet all the rules below';
              return null;
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final r in _passwordRules) _ruleChip(r.$1, r.$2(_passwordController.text))],
          ),
          const SizedBox(height: 14),
          _label('Confirm password', required: true),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) {
              if (!_busy) _register();
            },
            style: _inputStyle,
            decoration: _input(
              hint: 'Re-enter your password',
              icon: Icons.lock_outline_rounded,
              suffix: _confirmPasswordController.text.isNotEmpty &&
                  _confirmPasswordController.text == _passwordController.text
                  ? const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.check_circle_rounded, color: _green, size: 20),
              )
                  : _eye(_obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
            ),
            validator: (v) {
              if ((v ?? '').isEmpty) return 'Please confirm your password';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _termsRow(),
          const SizedBox(height: 18),
          _primaryButton(
            label: 'Create account',
            busyLabel: 'Creating account…',
            icon: Icons.arrow_forward_rounded,
            busy: _registering,
            onPressed: _busy ? null : _register,
          ),
        ],
      ),
    );
  }

  static final List<(String, bool Function(String))> _passwordRules = [
    ('8+ characters', (p) => p.length >= 8),
    ('1 uppercase', (p) => RegExp(r'[A-Z]').hasMatch(p)),
    ('1 number', (p) => RegExp(r'[0-9]').hasMatch(p)),
    ('1 special character', (p) => RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]\\/;]').hasMatch(p)),
  ];

  /// Green = rule met · orange = condition still missing (after typing starts) · grey = not started.
  Widget _ruleChip(String label, bool ok) {
    final pending = !ok && _passwordController.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? DT.emerald50 : (pending ? _orangeBg : DT.slate50),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ok ? DT.emerald200 : (pending ? _orangeLine : DT.slate200)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_rounded : (pending ? Icons.priority_high_rounded : Icons.circle_outlined),
              size: 13, color: ok ? _green : (pending ? _orange : DT.slate400)),
          const SizedBox(width: 4),
          Text(label,
              style: DT.text(
                  size: 11,
                  weight: FontWeight.w700,
                  color: ok ? DT.emerald700 : (pending ? _orangeDark : DT.slate500))),
        ],
      ),
    );
  }

  Widget _termsRow() {
    final err = _showTermsError && !_agreeTerms;
    final row = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _agreeTerms = !_agreeTerms;
        if (_agreeTerms) _showTermsError = false;
      }),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: err ? _orangeBg : DT.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: err ? _orange : DT.slate200, width: err ? 1.4 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _agreeTerms,
                onChanged: (v) => setState(() {
                  _agreeTerms = v ?? false;
                  if (_agreeTerms) _showTermsError = false;
                }),
                activeColor: _brand,
                side: BorderSide(color: err ? _orange : DT.slate400, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    style: DT.text(size: 12.5, color: DT.slate500, height: 1.4),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _openTerms,
                          child: Text('Terms & Conditions',
                              style: DT.text(
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: _brand,
                                  decoration: TextDecoration.underline)),
                        ),
                      ),
                      TextSpan(text: ' and ', style: DT.text(size: 12.5, color: DT.slate500)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _openTerms,
                          child: Text('Privacy Policy',
                              style: DT.text(
                                  size: 12.5,
                                  weight: FontWeight.w700,
                                  color: _brand,
                                  decoration: TextDecoration.underline)),
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
    );
    if (!err) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: _orange),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Please accept the Terms & Conditions to continue',
                  style: DT.text(size: 12, weight: FontWeight.w600, color: _orangeDark)),
            ),
          ],
        ),
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
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
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
                decoration: BoxDecoration(color: _brandTint, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.login_rounded, color: _brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Already have an account?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14, weight: FontWeight.w800, color: DT.onyx900)),
                    Text('Sign in to continue', style: DT.text(size: 12, color: DT.slate500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Login', style: DT.text(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined, size: 15, color: DT.slate400),
          const SizedBox(width: 6),
          Flexible(
            child: Text('Your details are encrypted and secure',
                style: DT.text(size: 11.5, color: DT.slate400)),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ],
  );

  // =====================================================================
  // Small design helpers (private to this screen)
  // =====================================================================
  static final TextStyle _inputStyle = DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900);

  InputDecoration _input({required String hint, required IconData icon, Widget? suffix, Color? filled}) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: DT.text(size: 13.5, color: DT.slate400),
      prefixIcon: Icon(icon, size: 19, color: _brand),
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
      filled: true,
      fillColor: filled ?? Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: b(DT.slate200),
      focusedBorder: b(_brand, 2),
      errorBorder: b(_red),
      focusedErrorBorder: b(_red, 2),
      errorStyle: DT.text(size: 11.5, weight: FontWeight.w600, color: _red),
      errorMaxLines: 2,
    );
  }

  Widget _eye(bool obscure, VoidCallback onTap) => IconButton(
    tooltip: obscure ? 'Show password' : 'Hide password',
    onPressed: onTap,
    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: DT.slate400, size: 20),
  );

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700),
        children: [
          if (required) TextSpan(text: ' *', style: DT.text(size: 12, color: _red)),
        ],
      ),
    ),
  );

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: _brandTint, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 17, color: _brand),
      ),
      const SizedBox(width: 10),
      Text(title, style: DT.text(size: 14.5, weight: FontWeight.w800, color: DT.onyx900)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(height: 1, color: DT.slate100)),
    ],
  );

  Widget _linkButton(String label, IconData icon, VoidCallback? onTap) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15),
    label: Text(label, style: DT.text(size: 12.5, weight: FontWeight.w700, color: onTap == null ? DT.slate400 : _brand)),
    style: TextButton.styleFrom(
      foregroundColor: _brand,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  Widget _primaryButton({
    required String label,
    required String busyLabel,
    required IconData icon,
    required bool busy,
    required VoidCallback? onPressed,
  }) =>
      SizedBox(
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _brand, // buttons: only #093C71
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x40093C71), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                else
                  Icon(icon, size: 19),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(busy ? busyLabel : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 15, weight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
}

// =====================================================================
// 6-box OTP input (one hidden TextField under the boxes – paste works)
// =====================================================================
class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _OtpBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final text = controller.text;
        return Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _box(i, text)),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: false,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  onChanged: onChanged,
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _box(int i, String text) {
    final filled = i < text.length;
    final active = focusNode.hasFocus && (i == text.length || (i == length - 1 && text.length == length));
    final color = hasError ? _red : (active ? _brand : (filled ? _brandSoft : DT.slate200));
    return AspectRatio(
      aspectRatio: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasError ? _redBg : (filled ? _brandTint : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: active || hasError ? 2 : 1.2),
        ),
        child: Text(
          filled ? text[i] : '',
          style: DT.text(size: 22, weight: FontWeight.w800, color: hasError ? _red : DT.onyx900),
        ),
      ),
    );
  }
}
// lib/screens/login_screen.dart
//
// Login – designed to match the home screen (brand blue #1A68FA, dark blue
// #0D3880, accent #FF5722, page #F6F8FC, white cards, slate inputs).
// Logic unchanged: LoginService.login -> save session -> HomeScreen.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/login_model.dart';
import '../services/login_service.dart';
import '../utils/shared_preferences_helper.dart';
import '../widgets/product_ui.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'terms_conditions_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;

  static const _brand = Color(0xFF1A68FA);
  static const _brandDark = Color(0xFF0D3880);
  static const _accent = Color(0xFFFF5722);

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final request = LoginRequest(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final response = await LoginService.login(request);

      await SharedPreferencesHelper.saveLoginData(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.user.id,
        username: response.user.username,
        email: response.user.email,
        address: response.user.address,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog('Login failed', e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: DT.errorBg, shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline_rounded, color: DT.error, size: 26),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Try again')),
          ),
        ],
      ),
    );
  }

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
                      _registerCard(),
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

  // ── Hero (brand gradient, like the home loan card) ──────────
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
            child: Icon(Icons.storefront_rounded, size: 150, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // White rounded chip behind the logo so the colorful logo reads on the blue hero
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
              const SizedBox(height: 26),
              Text('Welcome back 👋',
                  style: DT.text(size: 26, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text('Log in to buy, sell and manage your business on QNXMart.',
                  style: DT.text(size: 13.5, color: const Color(0xFFBFDBFE), height: 1.45)),
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
        Text(label, style: DT.text(size: 11.5, weight: FontWeight.w700, color: Colors.white)),
      ],
    ),
  );

  // ── Form card ───────────────────────────────────────────────
  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DT.slate200),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log in', style: DT.text(size: 18, weight: FontWeight.w800, color: DT.onyx900)),
            const SizedBox(height: 2),
            Text('Use your QNXMart username and password', style: DT.text(size: 12, color: DT.slate500)),
            const SizedBox(height: 18),
            const PxLabel('Username', required: true),
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
              decoration: pxInputDecoration(
                hint: 'Enter your username',
                icon: Icons.person_outline_rounded,
                iconColor: _brand,
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your username' : null,
            ),
            const SizedBox(height: 14),
            PxLabel(
              'Password',
              required: true,
              trailing: PxLinkButton(
                label: 'Forgot password?',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                ),
              ),
            ),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) {
                if (!_isLoading) _login();
              },
              style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
              decoration: pxInputDecoration(
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                iconColor: _brand,
                suffix: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: DT.slate400,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter your password';
                if (v.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  disabledBackgroundColor: _brand.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0x401A68FA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text('Logging in…', style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Log in', style: DT.text(size: 15, weight: FontWeight.w800, color: Colors.white)),
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

  // ── Register card ───────────────────────────────────────────
  Widget _registerCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
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
                decoration: BoxDecoration(color: const Color(0xFFFFF1EB), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_add_alt_1_rounded, color: _accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New to QNXMart?', style: DT.text(size: 14, weight: FontWeight.w800, color: DT.onyx900)),
                    Text('Create a free account in a minute', style: DT.text(size: 12, color: DT.slate500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Text('Register', style: DT.text(size: 12.5, weight: FontWeight.w800, color: _brand)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_outlined, size: 15, color: DT.slate400),
            const SizedBox(width: 6),
            Text('Your login is encrypted and secure', style: DT.text(size: 11.5, color: DT.slate400)),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsConditionsScreen())),
          child: Text.rich(
            TextSpan(
              text: 'By continuing you agree to our ',
              style: DT.text(size: 11.5, color: DT.slate400),
              children: [
                TextSpan(
                  text: 'Terms & Conditions',
                  style: DT.text(
                      size: 11.5, weight: FontWeight.w700, color: _brand, decoration: TextDecoration.underline),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
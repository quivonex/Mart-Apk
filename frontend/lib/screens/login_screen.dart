// lib/screens/login_screen.dart
//
// Login – colours matched to the QNX MART logo:
//   brand blue #093C71 (primary, logo "QNX") · red "MART" (errors) · orange arrow (permission / condition)
// Logic unchanged: LoginService.login -> save session -> HomeScreen.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/login_model.dart';
import '../services/login_service.dart';
import '../utils/shared_preferences_helper.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'terms_conditions_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';

/// Logo-matched palette (private to this screen).
class _C {
  static const brand = Color(0xFF093C71); // #093C71 – primary (logo "QNX" blue)
  static const brandDark = Color(0xFF062A50);
  static const brandLight = Color(0xFF1E5A9C);
  static const brandLine = Color(0xFFC9DBEE);
  static const navy = Color(0xFF093C71); // logo "QNX"
  static const red = Color(0xFFC62828); // logo "MART" – errors
  static const redBg = Color(0xFFFEF2F2);
  static const redLine = Color(0xFFFECACA);
  static const orange = Color(0xFFF7931E); // logo arrow – permission / condition
  static const orangeBg = Color(0xFFFFF7ED);

  static const hero = LinearGradient(
    colors: [brandDark, brand, brandLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

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
      _showErrorDialog(tr('Login failed'), e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _C.redLine),
        ),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: _C.redBg, shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline_rounded, color: _C.red, size: 28),
        ),
        title: Text(tr(title),
            textAlign: TextAlign.center, style: DT.text(size: 17, weight: FontWeight.w800, color: _C.red)),
        content: Text(tr(message),
            textAlign: TextAlign.center, style: DT.text(size: 13.5, color: DT.slate500, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(tr('Try again'), style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
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
        gradient: _C.hero,
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
                          Text(tr('QNX'), style: DT.text(size: 20, weight: FontWeight.w900, color: _C.navy, letterSpacing: -0.8)),
                          const SizedBox(width: 3),
                          Text(tr('MART'), style: DT.text(size: 20, weight: FontWeight.w800, color: _C.red, letterSpacing: -0.4)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _C.orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(tr('B2B'),
                        style: DT.text(size: 10, weight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              Text(tr('Market chalega nahi, daudega'),
                  style: DT.text(size: 11, weight: FontWeight.w700, color: const Color(0xFFFFD8A8))),
              const SizedBox(height: 26),
              Text(tr('Welcome back 👋'),
                  style: DT.text(size: 26, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Text(tr('Log in to buy, sell and manage your business on QNXMart.'),
                  style: DT.text(size: 13.5, color: _C.brandLine, height: 1.45)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip(Icons.shopping_bag_outlined, tr('Products')),
                  _heroChip(Icons.apartment_rounded, tr('Real Estate')),
                  _heroChip(Icons.recycling_rounded, tr('ReMart')),
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
        Text(tr(label), style: DT.text(size: 11.5, weight: FontWeight.w700, color: Colors.white)),
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
            Text(tr('Log in'), style: DT.text(size: 18, weight: FontWeight.w800, color: DT.onyx900)),
            const SizedBox(height: 2),
            Text(tr('Use your QNXMart username and password'), style: DT.text(size: 12, color: DT.slate500)),
            const SizedBox(height: 18),
            _label(tr('Username')),
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
              decoration: _input(hint: tr('Enter your username'), icon: Icons.person_outline_rounded),
              validator: (v) => (v == null || v.isEmpty) ? tr('Please enter your username') : null,
            ),
            const SizedBox(height: 14),
            _label(
              tr('Password'),
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _C.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(tr('Forgot password?'),
                    style: DT.text(size: 12.5, weight: FontWeight.w700, color: _C.brand)),
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
              decoration: _input(
                hint: tr('Enter your password'),
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscurePassword ? tr('Show password') : tr('Hide password'),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: DT.slate400,
                    size: 20,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return tr('Please enter your password');
                if (v.length < 6) return tr('Password must be at least 6 characters');
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _C.brand, // buttons: only #093C71
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Color(0x40093C71), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
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
                      Text(tr('Logging in…'), style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tr('Log in'), style: DT.text(size: 15, weight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 19),
                    ],
                  ),
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
                decoration: BoxDecoration(color: _C.orangeBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.person_add_alt_1_rounded, color: _C.orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('New to QNXMart?'), style: DT.text(size: 14, weight: FontWeight.w800, color: DT.onyx900)),
                    Text(tr('Create a free account in a minute'), style: DT.text(size: 12, color: DT.slate500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(tr('Register'), style: DT.text(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
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
            Text(tr('Your login is encrypted and secure'), style: DT.text(size: 11.5, color: DT.slate400)),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsConditionsScreen())),
          child: Text.rich(
            TextSpan(
              text: tr('By continuing you agree to our '),
              style: DT.text(size: 11.5, color: DT.slate400),
              children: [
                TextSpan(
                  text: tr('Terms & Conditions'),
                  style: DT.text(
                      size: 11.5, weight: FontWeight.w700, color: _C.brand, decoration: TextDecoration.underline),
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

  // ── Small helpers (private to this screen) ─────────────────
  Widget _label(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: tr(text),
              style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700),
              children: [TextSpan(text: ' *', style: DT.text(size: 12, color: _C.red))],
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );

  InputDecoration _input({required String hint, required IconData icon, Widget? suffix}) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: tr(hint),
      hintStyle: DT.text(size: 13.5, color: DT.slate400),
      prefixIcon: Icon(icon, size: 19, color: _C.brand),
      prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: b(DT.slate200),
      focusedBorder: b(_C.brand, 2),
      errorBorder: b(_C.red),
      focusedErrorBorder: b(_C.red, 2),
      errorStyle: DT.text(size: 11.5, weight: FontWeight.w600, color: _C.red),
      errorMaxLines: 2,
    );
  }
}
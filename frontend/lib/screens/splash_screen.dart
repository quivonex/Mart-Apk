import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/shared_preferences_helper.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
//
// Splash layout (like the reference design):
//   background (navy gradient + orange shapes)   lib/assets/images/splash_bg.jpg
//   [ logo card ]  QNX MART
//   B2B E-Commerce Platform · Grow Together, Sell Better
//   illustration: phone shop + cart + boxes + plant
//       lib/assets/images/splash_phone.png / splash_cart.png
//       lib/assets/images/splash_boxes.png / splash_plant.png
// Every image has a fallback, so a missing file never breaks the splash.

const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);

const _imgDir = 'lib/assets/images';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load the pictures early so they appear together.
    for (final f in const [
      'splash_bg.jpg',
      'splash_phone.png',
      'splash_cart.png',
      'splash_boxes.png',
      'splash_plant.png',
      'qnx_mart_logo.png',
    ]) {
      precacheImage(AssetImage('$_imgDir/$f'), context, onError: (_, __) {});
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final loggedIn = await SharedPreferencesHelper.isLoggedIn();
    if (!mounted) return;

    // Splash → Home (logged in) or Login. Language is changed from the
    // 🌐 button on the Home header (saved language is loaded in main()).
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  /// Fade + slide up, starting at [from] (0..1) of the animation.
  Widget _reveal(double from, Widget child) {
    final curve = CurvedAnimation(
      parent: _anim,
      curve: Interval(from, (from + 0.55).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBrand,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── background ───────────────────────────────────
            Image.asset(
              '$_imgDir/splash_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kBrandDark, _kBrand, _kBrandLight],
                  ),
                ),
              ),
            ),
            // ── content ──────────────────────────────────────
            SafeArea(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth.clamp(0.0, 440.0);
                  final short = c.maxHeight < 640;
                  return Center(
                    child: SizedBox(
                      width: w,
                      child: Column(
                        children: [
                          Spacer(flex: short ? 2 : 3),
                          _reveal(0.0, _logoCard(short ? 0.8 : 1)),
                          SizedBox(height: short ? 12 : 18),
                          _reveal(0.1, _title(short)),
                          Spacer(flex: short ? 1 : 2),
                          _reveal(0.3, _illustration(w * 0.92)),
                          const Spacer(flex: 2),
                          _reveal(
                            0.45,
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: short ? 20 : 36),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Your logo, small, on a white rounded card (in place of the "Q" mark).
  Widget _logoCard(double scale) {
    return Container(
      width: 132 * scale,
      height: 92 * scale,
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26 * scale),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Image.asset(
        '$_imgDir/qnx_mart_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Text(tr('QNX'),
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: _kBrand)),
        ),
      ),
    );
  }

  Widget _title(bool short) {
    return Column(
      children: [
        Text(
          tr('QNX MART'),
          style: TextStyle(
            fontSize: short ? 28 : 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
            height: 1.1,
          ),
        ),
        SizedBox(height: short ? 8 : 12),
        Text(
          tr('B2B E-Commerce Platform'),
          style: TextStyle(
            fontSize: short ? 15 : 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('Grow Together, Sell Better'),
          style: TextStyle(
            fontSize: short ? 13 : 14.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFDCE6F2),
          ),
        ),
      ],
    );
  }

  /// Phone shop in the middle, cart + boxes on the left, plant on the right.
  Widget _illustration(double w) {
    final h = w * 0.82;
    Widget img(String file, double width) => Image.asset(
      '$_imgDir/$file',
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(width: width),
    );
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // soft floor shadow
          Positioned(
            left: w * 0.08,
            right: w * 0.08,
            bottom: -6,
            height: 26,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                gradient: const RadialGradient(
                  colors: [Color(0x55000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          Positioned(left: w * 0.36, top: 0, child: img('splash_phone.png', w * 0.42)),
          Positioned(right: w * 0.03, bottom: w * 0.02, child: img('splash_plant.png', w * 0.16)),
          Positioned(left: w * 0.27, bottom: 0, child: img('splash_boxes.png', w * 0.27)),
          Positioned(left: w * 0.0, bottom: w * 0.01, child: img('splash_cart.png', w * 0.40)),
        ],
      ),
    );
  }
}

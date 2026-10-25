// lib/widgets/home_drawer.dart
//
// App drawer – same options and order as the QNXMart website drawer:
//
//   [blue header]  👤 <user>                                       ✕
//   Home
//   🔍 Nearby Search  (NEW)
//   My Profile · Seller Profile · My Chats · My Enquiries · My Subscription
//   Trending & Quick Links : All Products · Cart (n)
//   Sell & Management      : Add Company · Add Product · Add Branch · Add Category
//                            Add SubCategory · Add Brand · Add Unit
//   Property               : Add Property · All Properties · My Properties
//   QNX ReMart             : Add Product · All Products · My Items
//   Help & Support         : For Buying · For Selling · FAQ · About Us · Contact Us
//   Logout (at the very bottom)
//   ✉ qnxmartb2b@gmail.com
//
// Pure UI: every tap calls onNavigate(route); HomeScreen owns the navigation.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../screens/chat_list_screen.dart';
import '../screens/language_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions

/// Route keys handled by HomeScreen._navigate.
class DrawerRoutes {
  static const home = 'home';
  static const myProfile = 'account';
  static const sellerProfile = 'seller_profile';
  static const allProducts = 'products';
  static const cart = 'cart';
  static const addCompany = 'add_company';
  static const addProduct = 'add_product';
  static const addBranch = 'add_branch';
  static const addCategory = 'add_category';
  static const addSubCategory = 'add_subcategory';
  static const addBrand = 'add_brand';
  static const addUnit = 'add_unit';
  static const addProperty = 'add_property';
  static const allProperties = 'properties';
  static const remartAdd = 'remart_add';
  static const remartAll = 'remart_products';
  static const forBuying = 'help_buying';
  static const forSelling = 'help_selling';
  static const faq = 'help_faq';
  static const aboutUs = 'help_about';
  static const contactUs = 'help_contact';
  static const myEnquiries = 'my_enquiries';
  static const mySubscription = 'my_subscription';
  static const myProperties = 'my_properties';
  static const remartMine = 'remart_mine';
  static const nearbySearch = 'nearby_search';
}

class HomeDrawerData {
  final bool loggedIn;
  final String userName;
  final int cartCount;

  const HomeDrawerData({
    required this.loggedIn,
    required this.userName,
    required this.cartCount,
  });
}

class HomeDrawer extends StatelessWidget {
  final HomeDrawerData data;
  final void Function(String route) onNavigate;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const HomeDrawer({
    super.key,
    required this.data,
    required this.onNavigate,
    required this.onLogin,
    required this.onLogout,
  });

  static const String supportEmail = 'qnxmartb2b@gmail.com';

  // Header background (brand blue)
  static const _headerBg = Color(0xFF093C71);
  static const _red = Color(0xFFC62828);
  static const _text = Color(0xFF212529);
  static const _divider = Color(0xFFDEE2E6);

  // Different colours for each icon
  static const _iconHome = Color(0xFF093C71); // brand
  static const _iconProfile = Color(0xFF1E5A9C); // brand light
  static const _iconSeller = Color(0xFF10B981); // green
  static const _iconProducts = Color(0xFFF7931E); // orange
  static const _iconCart = Color(0xFFC62828); // red
  static const _iconCompany = Color(0xFF093C71); // brand
  static const _iconProduct = Color(0xFF1E5A9C); // brand light
  static const _iconBranch = Color(0xFF06B6D4); // cyan
  static const _iconCategory = Color(0xFFF7931E); // orange
  static const _iconSubCategory = Color(0xFF14B8A6); // teal
  static const _iconBrand = Color(0xFFEC4899); // pink
  static const _iconUnit = Color(0xFF093C71); // brand
  static const _iconProperty = Color(0xFF0EA5E9); // sky
  static const _iconAllProperties = Color(0xFF22C55E); // green
  static const _iconRemartAdd = Color(0xFF1E5A9C); // brand light
  static const _iconRemartAll = Color(0xFFC62828); // red
  static const _iconBuying = Color(0xFF10B981); // emerald
  static const _iconSelling = Color(0xFFF7931E); // orange
  static const _iconFaq = Color(0xFF093C71); // brand
  static const _iconAbout = Color(0xFF093C71); // brand
  static const _iconContact = Color(0xFFC62828); // red
  static const _iconNearby = Color(0xFFF7931E); // orange

  @override
  Widget build(BuildContext context) {
    void go(String route) {
      Navigator.of(context).pop();
      onNavigate(route);
    }

    return Drawer(
      width: (MediaQuery.of(context).size.width * 0.82).clamp(280.0, 400.0),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: Column(
        children: [
          _header(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                // ── Home ───────────────────────────────────────
                _item(Icons.home_rounded, tr('Home'), () => go(DrawerRoutes.home),
                    bold: true, color: _iconHome),
                // ── Nearby Search (Google Places) ──────────────
                _item(Icons.travel_explore_rounded, tr('Nearby Search'), () => go(DrawerRoutes.nearbySearch),
                    color: _iconNearby, badge: tr('NEW')),
                const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18, color: _divider),
                // ── Account ────────────────────────────────────
                _item(Icons.person_rounded, tr('My Profile'), () => go(DrawerRoutes.myProfile),
                    color: _iconProfile),
                _item(Icons.badge_rounded, tr('Seller Profile'), () => go(DrawerRoutes.sellerProfile),
                    color: _iconSeller),
                // Opens the chat list directly (no HomeScreen route needed).
                _item(Icons.chat_rounded, tr('My Chats'), () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
                }, color: _iconHome, badge: tr('NEW')),
                _item(Icons.forum_rounded, tr('My Enquiries'), () => go(DrawerRoutes.myEnquiries),
                    color: _iconProfile),
                _item(Icons.workspace_premium_rounded, tr('My Subscription'), () => go(DrawerRoutes.mySubscription),
                    color: _iconSeller),

                _section(tr('Trending & Quick Links')),
                _item(Icons.grid_view_rounded, tr('All Products'), () => go(DrawerRoutes.allProducts),
                    color: _iconProducts),
                _item(Icons.shopping_cart_outlined, tr('Cart ({0})', [data.cartCount]),
                        () => go(DrawerRoutes.cart), color: _iconCart),

                _section(tr('Sell & Management')),
                _item(Icons.domain_add_rounded, tr('Add Company'), () => go(DrawerRoutes.addCompany),
                    color: _iconCompany),
                _item(Icons.inventory_2_rounded, tr('Add Product'), () => go(DrawerRoutes.addProduct),
                    color: _iconProduct),
                _item(Icons.account_tree_rounded, tr('Add Branch'), () => go(DrawerRoutes.addBranch),
                    color: _iconBranch),
                _item(Icons.apps_rounded, tr('Add Category'), () => go(DrawerRoutes.addCategory),
                    color: _iconCategory),
                _item(Icons.segment_rounded, tr('Add SubCategory'),
                        () => go(DrawerRoutes.addSubCategory), color: _iconSubCategory),
                _item(Icons.sell_rounded, tr('Add Brand'), () => go(DrawerRoutes.addBrand),
                    color: _iconBrand),
                _item(Icons.straighten_rounded, tr('Add Unit'), () => go(DrawerRoutes.addUnit),
                    color: _iconUnit),

                _section(tr('Property')),
                _item(Icons.add_box_outlined, tr('Add Property'), () => go(DrawerRoutes.addProperty),
                    color: _iconProperty),
                _item(Icons.apps_outlined, tr('All Properties'), () => go(DrawerRoutes.allProperties),
                    color: _iconAllProperties),
                _item(Icons.home_work_outlined, tr('My Properties'), () => go(DrawerRoutes.myProperties),
                    color: _iconProperty),

                _section(tr('QNX ReMart')),
                _item(Icons.add_box_outlined, tr('Add Product'), () => go(DrawerRoutes.remartAdd),
                    color: _iconRemartAdd),
                _item(Icons.apps_outlined, tr('All Products'), () => go(DrawerRoutes.remartAll),
                    color: _iconRemartAll),
                _item(Icons.inventory_outlined, tr('My Items'), () => go(DrawerRoutes.remartMine),
                    color: _iconRemartAdd),

                _section(tr('Help & Support')),
                _item(Icons.shopping_cart_checkout_rounded, tr('For Buying'),
                        () => go(DrawerRoutes.forBuying), color: _iconBuying),
                _item(Icons.storefront_outlined, tr('For Selling'), () => go(DrawerRoutes.forSelling),
                    color: _iconSelling),
                _item(Icons.help_outline_rounded, 'FAQ', () => go(DrawerRoutes.faq),
                    color: _iconFaq),
                _item(Icons.info_outline_rounded, tr('About Us'), () => go(DrawerRoutes.aboutUs),
                    color: _iconAbout),
                _item(Icons.chat_rounded, tr('Contact Us'), () => go(DrawerRoutes.contactUs),
                    color: _iconContact),

                // ── Language (English / मराठी / हिंदी) ──────────
                _item(Icons.translate_rounded, '${tr('Language')} · ${AppLanguage.current.nativeName}',
                    () => showLanguagePicker(context), color: _iconProfile),

                // ── Logout at the very bottom ──────────────────
                const Divider(height: 24, thickness: 1, indent: 18, endIndent: 18, color: _divider),
                if (data.loggedIn)
                  _item(Icons.logout_rounded, tr('Logout'), () {
                    Navigator.of(context).pop();
                    onLogout();
                  }, color: _red)
                else
                  _item(Icons.login_rounded, tr('Login / Register'), () {
                    Navigator.of(context).pop();
                    onLogin();
                  }, color: _iconHome),

                const Divider(height: 24, thickness: 1, indent: 12, endIndent: 18, color: _divider),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('mailto:$supportEmail')),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 18, 24),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded, size: 18, color: _text),
                        const SizedBox(width: 8),
                        Text(tr(supportEmail), style: DT.text(size: 14, weight: FontWeight.w400, color: _text)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Header shows only the user name on a blue background.
  Widget _header(BuildContext context) {
    return Container(
      color: _headerBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: data.loggedIn
                      ? null
                      : () {
                    Navigator.of(context).pop();
                    onLogin();
                  },
                  child: Text(
                    data.loggedIn
                        ? (data.userName.isEmpty ? tr('My Account') : data.userName)
                        : tr('Login / Register'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 18, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),
      const Divider(height: 1, thickness: 1, color: _divider),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
        child: Text(tr(title), style: DT.text(size: 16, weight: FontWeight.w700, color: _text)),
      ),
    ],
  );

  Widget _item(IconData icon, String label, VoidCallback onTap,
      {bool bold = false, Color? color, String? badge}) {
    final iconColor = color ?? _iconHome;
    final textColor = _text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 18),
            Expanded(
              child: Text(tr(label),
                  style: DT.text(
                      size: bold ? 18 : 17,
                      weight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: textColor)),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(20)),
                child: Text(tr(badge), style: DT.text(size: 10, weight: FontWeight.w800, color: Colors.white)),
              ),
            Icon(Icons.chevron_right_rounded, color: const Color(0xFF6C757D), size: 22),
          ],
        ),
      ),
    );
  }
}
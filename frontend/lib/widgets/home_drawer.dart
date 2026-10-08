// lib/widgets/home_drawer.dart
//
// App drawer – same options and order as the QNXMart website drawer:
//
//   [dark header]  Quivonex Solutions Pvt. Ltd. / 👤 <user>            ✕
//   Home
//   My Profile · Seller Profile · Logout
//   Trending & Quick Links : All Products · Cart (n)
//   Sell & Management      : Add Company · Add Product · Add Branch · Add Category
//                            Add SubCategory · Add Brand · Add Unit
//   Property               : Add Property · All Properties
//   QNX ReMart             : Add Product · All Products
//   Help & Support         : For Buying · For Selling · FAQ · About Us · Contact Us
//   ✉ qnxmartb2b@gmail.com
//
// Pure UI: every tap calls onNavigate(route); HomeScreen owns the navigation.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';

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

  static const String companyName = 'Quivonex Solutions Pvt. Ltd.';
  static const String supportEmail = 'qnxmartb2b@gmail.com';

  static const _headerBg = Color(0xFF212529); // website: Bootstrap dark
  static const _blue = Color(0xFF0D6EFD); // website: Bootstrap primary
  static const _red = Color(0xFFDC3545);
  static const _text = Color(0xFF212529);
  static const _divider = Color(0xFFDEE2E6);

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
                _item(Icons.home_rounded, 'Home', () => go(DrawerRoutes.home), bold: true),
                const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18, color: _divider),
                // ── Account ────────────────────────────────────
                _item(Icons.person_rounded, 'My Profile', () => go(DrawerRoutes.myProfile)),
                _item(Icons.badge_rounded, 'Seller Profile', () => go(DrawerRoutes.sellerProfile)),
                if (data.loggedIn)
                  _item(Icons.logout_rounded, 'Logout', () {
                    Navigator.of(context).pop();
                    onLogout();
                  }, color: _red)
                else
                  _item(Icons.login_rounded, 'Login', () {
                    Navigator.of(context).pop();
                    onLogin();
                  }),

                _section('Trending & Quick Links'),
                _item(Icons.grid_view_rounded, 'All Products', () => go(DrawerRoutes.allProducts)),
                _item(Icons.shopping_cart_outlined, 'Cart (${data.cartCount})',
                        () => go(DrawerRoutes.cart)),

                _section('Sell & Management'),
                _item(Icons.domain_add_rounded, 'Add Company', () => go(DrawerRoutes.addCompany)),
                _item(Icons.inventory_2_rounded, 'Add Product', () => go(DrawerRoutes.addProduct)),
                _item(Icons.account_tree_rounded, 'Add Branch', () => go(DrawerRoutes.addBranch)),
                _item(Icons.apps_rounded, 'Add Category', () => go(DrawerRoutes.addCategory)),
                _item(Icons.segment_rounded, 'Add SubCategory',
                        () => go(DrawerRoutes.addSubCategory)),
                _item(Icons.sell_rounded, 'Add Brand', () => go(DrawerRoutes.addBrand)),
                _item(Icons.straighten_rounded, 'Add Unit', () => go(DrawerRoutes.addUnit)),

                _section('Property'),
                _item(Icons.add_box_outlined, 'Add Property', () => go(DrawerRoutes.addProperty)),
                _item(Icons.apps_outlined, 'All Properties', () => go(DrawerRoutes.allProperties)),

                _section('QNX ReMart'),
                _item(Icons.add_box_outlined, 'Add Product', () => go(DrawerRoutes.remartAdd)),
                _item(Icons.apps_outlined, 'All Products', () => go(DrawerRoutes.remartAll)),

                _section('Help & Support'),
                _item(Icons.shopping_cart_checkout_rounded, 'For Buying',
                        () => go(DrawerRoutes.forBuying)),
                _item(Icons.storefront_outlined, 'For Selling', () => go(DrawerRoutes.forSelling)),
                _item(Icons.help_outline_rounded, 'FAQ', () => go(DrawerRoutes.faq)),
                _item(Icons.info_outline_rounded, 'About Us', () => go(DrawerRoutes.aboutUs)),
                _item(Icons.chat_rounded, 'Contact Us', () => go(DrawerRoutes.contactUs)),

                const Divider(height: 24, thickness: 1, indent: 12, endIndent: 18, color: _divider),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('mailto:$supportEmail')),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 18, 24),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline_rounded, size: 18, color: _text),
                        const SizedBox(width: 8),
                        Text(supportEmail, style: DT.text(size: 14, weight: FontWeight.w400, color: _text)),
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

  Widget _header(BuildContext context) {
    return Container(
      color: _headerBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(companyName,
                  style: DT.text(size: 16, weight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 10),
              Container(height: 1, margin: const EdgeInsets.only(right: 10), color: Colors.white38),
              const SizedBox(height: 4),
              Row(
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
                            ? (data.userName.isEmpty ? 'My Account' : data.userName)
                            : 'Login / Register',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 18, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  ),
                ],
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
        child: Text(title, style: DT.text(size: 16, weight: FontWeight.w700, color: _text)),
      ),
    ],
  );

  Widget _item(IconData icon, String label, VoidCallback onTap,
      {bool bold = false, Color? color}) {
    final c = color ?? _text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? _blue),
            const SizedBox(width: 18),
            Expanded(
              child: Text(label,
                  style: DT.text(
                      size: bold ? 18 : 17,
                      weight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: c)),
            ),
            Icon(Icons.chevron_right_rounded, color: color ?? const Color(0xFF6C757D), size: 22),
          ],
        ),
      ),
    );
  }
}
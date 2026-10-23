// lib/screens/home_screen.dart
//
// Visual design: QNXMart mobile design (code.html / screen.png) – brand blue #1a68fa,
// dark blue #0d3880, accent #ff5722, page #f6f8fc. Product cards open a quick view
// with Enquiry / Add to cart (the design card itself has no buttons).
//
// Home – matches the QNXMart website (mobile view):
//
//   Header      logo · cart · profile
//   Pills       QNXMart — Shopping & Products | Real Estate — Buy, Sell & Rent |
//               QNXRemart — Used & Resale            (with ‹ › arrows)
//   ☰ drawer + category chips (All Categories, …)     (with › arrow)
//   Search bar (with filter icon at the end)
//   Hero banner carousel        <- accounts/banners/ placement=home_hero, section=<pill>
//   Bank / finance logo strip   <- accounts/banners/ placement=finance_partner
//                                  (each card includes loan info + opens loan form)
//   Filters button
//   Live Reels & Demos          <- product videos from the same list
//   Marketing Partner · Info Partner · Info Company
//   Product grid (Franchise badge, stock, price/MRP, Enquiry, Cart)
//   ↑ scroll-to-top

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../models/admin_image_model.dart';
import '../models/home_models.dart';
import '../models/product_model.dart';
import '../models/property_model.dart';
import '../services/admin_image_service.dart';
import '../services/home_service.dart';
import '../services/real_estate_service.dart';
import '../utils/cart_helper.dart';
import '../utils/shared_preferences_helper.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/auto_image_carousel.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/home_drawer.dart';
import '../widgets/property_filter_panel.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'company_list_screen.dart';
import 'company_products_list_screen.dart';
import 'brand_create_edit_screen.dart';
import 'company_create_edit_screen.dart';
import 'franchise_plans_screen.dart';
import 'help_screens.dart';
import 'loan_enquiry_screen.dart';
import 'login_screen.dart';
import 'marketing_partner_enquiry_screen.dart';
import 'order_screen.dart';
import 'product_enquiry_screen.dart';
import 'product_create_screen.dart';
import 'product_reels_screen.dart';
import 'property_create_screen.dart';
import 'property_detail_screen.dart';
import 'property_enquiry_screen.dart';
import 'quick_add_flows.dart';
import 'remart_screens.dart';
import 'products_screen.dart' as products;
import 'seller_profile_screen.dart';
import 'unit_screens.dart';
import 'terms_conditions_screen.dart';
import '../utils/login_gate.dart';
import 'customer_subscription_screen.dart';
import 'my_enquiries_screen.dart';
import 'my_properties_screen.dart';
import 'my_remart_screen.dart';
import 'nearby_search_screen.dart';
import 'ai_chat_screen.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kRed = Color(0xFFC62828);

/// Colours from the QNXMart mobile design (code.html).
class _HC {
  static const blue = Color(0xFF093C71); // brand.blue
  static const darkBlue = Color(0xFF062A50); // brand.darkblue
  static const accent = Color(0xFFF7931E); // brand.accent
  static const blueText = Color(0xFF093C71);
  static const pillBg = Color(0xFFEAF1F9); // blue-50
  static const pillBorder = Color(0xFFC9DBEE); // blue-100
  static const slatePill = Color(0xFFF8FAFC); // slate-50
  static const line = Color(0xFFE2E8F0); // slate-200
  static const hairline = Color(0xFFF1F5F9); // slate-100
  static const navy = Color(0xFF093C71); // chat button
  static const navy2 = Color(0xFF062A50);
  static const bg = Color(0xFFF8FAFC);
  static const amber = Color(0xFFFBBF24); // amber-400
  static const red = Color(0xFFC62828); // red-600
  static const green = Color(0xFF10B981);
  static const cardShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 6, offset: Offset(0, 2)),
  ];
}

// =====================================================================
// SHELL (bottom tabs + drawer)
// =====================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _homeKey = GlobalKey<HomeContentState>();

  int _currentIndex = 0;
  int _cartCount = 0;
  bool _loggedIn = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _refreshUser();
    _refreshCart();
  }

  Future<void> _refreshUser() async {
    final logged = await SharedPreferencesHelper.isLoggedIn();
    final name = await SharedPreferencesHelper.getUsername();
    if (!mounted) return;
    setState(() {
      _loggedIn = logged;
      _userName = name ?? '';
    });
  }

  Future<void> _refreshCart() async {
    final n = await HomeService.getCartCount();
    if (mounted) setState(() => _cartCount = n);
  }

  void _goToTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _refreshCart();
  }

  Future<void> _push(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _refreshCart();
  }

  /// Routes that need a logged-in user (seller tools, cart, orders, profile).
  static const _needsLogin = {
    DrawerRoutes.myProfile,
    DrawerRoutes.cart,
    'orders',
    DrawerRoutes.sellerProfile,
    DrawerRoutes.addCompany,
    DrawerRoutes.addProduct,
    DrawerRoutes.addBranch,
    DrawerRoutes.addCategory,
    DrawerRoutes.addSubCategory,
    DrawerRoutes.addBrand,
    DrawerRoutes.addUnit,
    DrawerRoutes.addProperty,
    DrawerRoutes.myEnquiries,
    DrawerRoutes.mySubscription,
    DrawerRoutes.myProperties,
    DrawerRoutes.remartMine,
    'company_list',
    'my_products',
  };

  Future<void> _navigate(String route) async {
    if (_needsLogin.contains(route) && !_loggedIn) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login required'),
          content: const Text('Please log in to continue.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Login')),
          ],
        ),
      );
      if (go == true) _login();
      return;
    }
    if (!mounted) return;

    switch (route) {
    // ── tabs ──
      case DrawerRoutes.home:
        _goToTab(0);
      case DrawerRoutes.allProducts:
        _goToTab(1);
      case DrawerRoutes.cart:
        _goToTab(2);
      case 'orders':
        _goToTab(3);
      case DrawerRoutes.myProfile:
        _goToTab(4);

    // ── account / business ──
      case DrawerRoutes.sellerProfile:
        _push(const SellerProfileScreen());
      case 'company_list':
        _push(const CompanyListScreen());
      case 'my_products':
        _push(const CompanyProductsListScreen());
      case 'marketing_partner':
        _push(const MarketingPartnerEnquiryScreen());
      case 'loan_enquiry':
        _push(const LoanEnquiryScreen());

    // ── Sell & Management ──
      case DrawerRoutes.addCompany:
        _push(const CompanyCreateEditScreen());
      case DrawerRoutes.addProduct:
        _push(const ProductCreateScreen());
      case DrawerRoutes.addBranch:
        await startAddBranch(context);
      case DrawerRoutes.addCategory:
        await startAddCategory(context);
      case DrawerRoutes.addSubCategory:
        await startAddSubCategory(context);
      case DrawerRoutes.addBrand:
        _push(const BrandCreateEditScreen());
      case DrawerRoutes.addUnit:
        _push(const UnitFormScreen());

    // ── Property ──
      case DrawerRoutes.addProperty:
      // In-app property form (photos + PDF documents).
        final created = await Navigator.push<bool>(
            context, MaterialPageRoute(builder: (_) => const PropertyCreateScreen()));
        if (created == true) _showMarketplace(Marketplace.realEstate);
      case DrawerRoutes.allProperties:
        _showMarketplace(Marketplace.realEstate);

    // ── QNX ReMart ──
      case DrawerRoutes.remartAdd:
        await openRemartPosting(context);
      case DrawerRoutes.remartAll:
        _showMarketplace(Marketplace.remart);
      case DrawerRoutes.remartMine:
        _push(const MyRemartScreen());

    // ── My activity ──
      case DrawerRoutes.myEnquiries:
        _push(const MyEnquiriesScreen());
      case DrawerRoutes.mySubscription:
        await openCustomerSubscription(context);
      case DrawerRoutes.myProperties:
        _push(const MyPropertiesScreen());
      case DrawerRoutes.nearbySearch:
        _push(const NearbySearchScreen());

    // ── Help & Support ──
      case DrawerRoutes.forBuying:
        _push(const HelpInfoScreen(topic: HelpTopic.buying));
      case DrawerRoutes.forSelling:
        _push(const HelpInfoScreen(topic: HelpTopic.selling));
      case DrawerRoutes.faq:
        _push(const HelpInfoScreen(topic: HelpTopic.faq));
      case DrawerRoutes.aboutUs:
        _push(const HelpInfoScreen(topic: HelpTopic.about));
      case DrawerRoutes.contactUs:
        _push(const ContactUsScreen());
    }
  }

  /// Home tab + switch the marketplace pill (Real Estate / QNXRemart).
  void _showMarketplace(Marketplace m) {
    _goToTab(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _homeKey.currentState?.setMarketplace(m));
  }

  Future<void> _login() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    _refreshUser();
    _refreshCart();
  }

  Future<void> _logout() async {
    await SharedPreferencesHelper.clearAll();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  void _openDrawer() {
    setState(() {}); // rebuild so the drawer shows the latest home state
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _tab(int index) => switch (index) {
    1 => const products.ProductsScreen(),
    2 => const CartScreen(),
    3 => const OrdersScreen(),
    4 => AccountScreen(onNavigate: _navigate),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _currentIndex == 0 ? _HC.bg : DT.background,
      drawerEnableOpenDragGesture: true,
      drawer: HomeDrawer(
        data: HomeDrawerData(
          loggedIn: _loggedIn,
          userName: _userName,
          cartCount: _cartCount,
        ),
        onNavigate: _navigate,
        onLogin: _login,
        onLogout: _logout,
      ),
      // Home has its own header (inside HomeContent); other tabs use the same top bar.
      appBar: _currentIndex == 0
          ? null
          : PreferredSize(
        preferredSize: Size.fromHeight(56 + MediaQuery.of(context).padding.top),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _topBar(),
                Container(height: 1, color: _HC.hairline),
              ],
            ),
          ),
        ),
      ),
      // Home stays alive (keeps carousel/filter state); other tabs rebuild on each visit.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeContent(
            key: _homeKey,
            cartCount: _cartCount,
            loggedIn: _loggedIn,
            userName: _userName,
            onOpenDrawer: _openDrawer,
            onNavigate: _navigate,
            onLogin: _login,
            onLogout: _logout,
            onCartChanged: _refreshCart,
          ),
          for (var i = 1; i <= 4; i++)
            _currentIndex == i ? _tab(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        cartCount: _cartCount,
        onTap: _goToTab,
      ),
    );
  }

  // Same top bar as the Home screen header (logo · cart · profile).
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _goToTab(0),
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              'lib/assets/images/qnx_mart_logo.png',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('QNX', style: DT.text(size: 15, weight: FontWeight.w900, color: _HC.darkBlue, letterSpacing: -0.6)),
                  const SizedBox(width: 3),
                  Text('MART', style: DT.text(size: 15, weight: FontWeight.w800, color: _HC.red, letterSpacing: -0.3)),
                ],
              ),
            ),
          ),
          const Spacer(),
          _roundIcon(
            icon: Icons.shopping_cart_outlined,
            badge: _cartCount,
            onTap: () => _goToTab(2),
          ),
          const SizedBox(width: 8),
          _profileButton(),
        ],
      ),
    );
  }

  Widget _roundIcon({required IconData icon, required VoidCallback onTap, int badge = 0}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: DT.slate100, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: DT.onyx700),
            ),
            if (badge > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _HC.red,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(badge > 99 ? '99+' : '$badge',
                      style: DT.text(size: 9, weight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileButton() {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        switch (v) {
          case 'login':
            _login();
          case 'logout':
            _logout();
          default:
            _navigate(v);
        }
      },
      itemBuilder: (_) => [
        if (_loggedIn)
          PopupMenuItem(
            enabled: false,
            child: Text(_userName.isEmpty ? 'My account' : 'Hi, $_userName',
                style: DT.text(size: 13, weight: FontWeight.w800, color: DT.onyx900)),
          ),
        _menu('account', Icons.person_outline_rounded, 'My account'),
        _menu('orders', Icons.receipt_long_outlined, 'My orders'),
        _menu('company_list', Icons.apartment_rounded, 'My companies'),
        _menu('my_products', Icons.inventory_2_outlined, 'My products'),
        const PopupMenuDivider(),
        _loggedIn
            ? _menu('logout', Icons.logout_rounded, 'Log out', color: _kRed)
            : _menu('login', Icons.login_rounded, 'Login / Register', color: _HC.blue),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
        decoration: BoxDecoration(color: DT.slate100, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: DT.slate200, shape: BoxShape.circle),
              child: Icon(
                _loggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                size: 16,
                color: DT.onyx700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: DT.onyx600),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menu(String v, IconData icon, String label, {Color? color}) =>
      PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 19, color: color ?? DT.onyx700),
          const SizedBox(width: 10),
          Text(label, style: DT.text(size: 13.5, weight: FontWeight.w600, color: color ?? DT.onyx900)),
        ]),
      );
}

// =====================================================================
// HOME CONTENT
// =====================================================================
enum _Sort { newest, priceLow, priceHigh, nameAz }

class HomeContent extends StatefulWidget {
  final int cartCount;
  final bool loggedIn;
  final String userName;
  final VoidCallback onOpenDrawer;
  final void Function(String route) onNavigate;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onCartChanged;

  const HomeContent({
    super.key,
    required this.cartCount,
    required this.loggedIn,
    required this.userName,
    required this.onOpenDrawer,
    required this.onNavigate,
    required this.onLogin,
    required this.onLogout,
    required this.onCartChanged,
  });

  @override
  State<HomeContent> createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent> {
  // Scroll
  final _scroll = ScrollController();
  final _pillScroll = ScrollController();
  final _chipScroll = ScrollController();
  final _financeScroll = ScrollController();
  final _productsKey = GlobalKey();
  final _searchCtrl = TextEditingController();

  // Marketplace / filters
  Marketplace _marketplace = Marketplace.shopping;
  String? _category; // null = All Categories
  String _query = '';
  _Sort _sort = _Sort.newest;
  bool _franchiseOnly = false;
  bool _inStockOnly = false;
  int _visibleCount = 10;

  // Hero banners
  final _heroPage = PageController();
  List<HomeBanner> _hero = [];
  bool _heroLoading = true;
  int _heroIndex = 0;
  Timer? _heroTimer;

  // Admin-uploaded banner images (from admin_profile/upload_image_list/)
  List<AdminImage> _adminImages = [];
  bool _adminImagesLoading = true;

  // Finance logos
  List<HomeBanner> _finance = [];
  Timer? _financeTimer;

  // Products / categories
  List<Product> _products = [];
  List<HomeCategory> _categories = [];
  bool _productsLoading = true;
  String? _productsError;

  // Reels
  final _reelPage = PageController();
  int _reelIndex = 0;

  // Real estate (loaded the first time the pill is opened)
  List<Property> _props = [];
  bool _propsLoading = false;
  bool _propsLoaded = false;
  String? _propsError;
  String? _propType; // null = All Properties (chips and the panel's Property Type)
  PropertyFilters _pf = PropertyFilters.empty; // price, state, district, transaction, amenities

  // QNXRemart (loaded the first time the pill is opened)
  List<RemartListing> _remart = [];
  List<(int, String)> _remartCats = [];
  bool _remartLoading = false;
  bool _remartLoaded = false;
  String? _remartError;
  int? _remartCat; // null = All Remart Items
  _Sort _rmSort = _Sort.newest;
  String? _rmCondition;
  String? _rmSeller;
  bool _rmNegotiable = false;
  String _rmCity = '';
  int? _myUserId; // to mark the user's own ReMart listings

  // Public for the drawer
  Marketplace get marketplace => _marketplace;
  List<HomeCategory> get categories => _categories;
  String? get selectedCategory => _category;

  @override
  void initState() {
    super.initState();
    _pillScroll.addListener(() => setState(() {}));
    _chipScroll.addListener(() => setState(() {}));
    _refreshAll(cart: false);
    _loadAdminImages();
    SharedPreferencesHelper.getUserId().then((id) {
      if (mounted) setState(() => _myUserId = id);
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _financeTimer?.cancel();
    for (final c in [_scroll, _pillScroll, _chipScroll, _financeScroll]) {
      c.dispose();
    }
    _heroPage.dispose();
    _reelPage.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // =================================================================
  // DATA
  // =================================================================
  Future<void> _refreshAll({bool cart = true}) async {
    if (cart) widget.onCartChanged(); // the shell already loads it on start
    switch (_marketplace) {
      case Marketplace.realEstate:
        await _loadProperties();
      case Marketplace.remart:
        await _loadRemart();
      case Marketplace.shopping:
        await Future.wait([_loadHero(), _loadFinance(), _loadProducts()]);
    }
  }

  Future<void> _loadProperties() async {
    setState(() {
      _propsLoading = true;
      _propsError = null;
    });
    final r = await RealEstateService.getApprovedProperties();
    if (!mounted) return;
    setState(() {
      _propsLoading = false;
      _propsLoaded = true;
      if (r.status) {
        _props = r.data;
      } else {
        _propsError = r.message ?? 'Could not load properties';
      }
    });
  }

  Future<void> _loadRemart() async {
    setState(() {
      _remartLoading = true;
      _remartError = null;
    });
    final results = await Future.wait([RemartApi.listings(), RemartApi.categories()]);
    if (!mounted) return;
    final (items, err) = results[0] as (List<RemartListing>, String?);
    final cats = results[1] as List<(int, String)>;
    setState(() {
      _remartLoading = false;
      _remartLoaded = true;
      _remart = items;
      _remartError = err;
      if (cats.isNotEmpty) _remartCats = cats;
    });
  }

  Future<void> _loadHero() async {
    setState(() => _heroLoading = true);
    final r = await HomeService.getBanners(
        placement: 'home_hero', section: _marketplace.apiSection);
    if (!mounted) return;
    setState(() {
      _heroLoading = false;
      _hero = r.data;
      _heroIndex = 0;
    });
    if (_heroPage.hasClients) _heroPage.jumpToPage(0);
    _startHeroTimer();
  }

  /// Admin-uploaded banner images (used when the banner API has none).
  Future<void> _loadAdminImages() async {
    setState(() => _adminImagesLoading = true);
    final r = await AdminImageService.getUploadedImages();
    if (!mounted) return;
    setState(() {
      _adminImagesLoading = false;
      _adminImages = r.data;
    });
    // If the API banners are empty, the admin images become the slides:
    // reset the page and (re)start the auto-rotate timer.
    if (_hero.isEmpty && _adminImages.isNotEmpty) {
      if (_heroPage.hasClients) _heroPage.jumpToPage(0);
      setState(() => _heroIndex = 0);
      _startHeroTimer();
    }
  }

  Future<void> _loadFinance() async {
    final r = await HomeService.getBanners(placement: 'finance_partner');
    if (!mounted) return;
    setState(() => _finance = r.data);
    _startFinanceTimer();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    final r = await HomeService.getProducts();
    if (!mounted) return;
    setState(() {
      _productsLoading = false;
      _products = r.data;
      _productsError = r.ok ? null : r.message;
    });
    final c = await HomeService.getCategories(products: r.data);
    if (mounted) setState(() => _categories = c.data);
  }

  /// Priority: API banners > admin-uploaded images > built-in fallback slides.
  int get _heroCount {
    if (_hero.isNotEmpty) return _hero.length;
    if (_adminImages.isNotEmpty) return _adminImages.length;
    return _fallbackSlides.length;
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (_heroCount < 2) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroPage.hasClients) return;
      _heroPage.animateToPage((_heroIndex + 1) % _heroCount,
          duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  void _startFinanceTimer() {
    _financeTimer?.cancel();
    _financeTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || !_financeScroll.hasClients) return;
      final pos = _financeScroll.position;
      final next = pos.pixels + 160; // card 150 + gap 10
      _financeScroll.animateTo(next >= pos.maxScrollExtent + 10 ? 0 : next,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  // =================================================================
  // ACTIONS
  // =================================================================
  void setMarketplace(Marketplace m) {
    if (m == _marketplace) return;
    _searchCtrl.clear();
    setState(() {
      _marketplace = m;
      _query = '';
    });
    _scrollPillIntoView(m);
    if (_chipScroll.hasClients) _chipScroll.jumpTo(0);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    switch (m) {
      case Marketplace.realEstate:
        if (!_propsLoaded && !_propsLoading) _loadProperties();
      case Marketplace.remart:
        if (!_remartLoaded && !_remartLoading) _loadRemart();
      case Marketplace.shopping:
        break;
    }
  }

  void selectCategory(String? name, {bool scroll = false}) {
    setState(() {
      _category = name;
      _visibleCount = 10;
      if (_marketplace != Marketplace.shopping) _marketplace = Marketplace.shopping;
    });
    if (scroll) _scrollToProducts();
  }

  void _goHome() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _category = null;
      _franchiseOnly = false;
      _inStockOnly = false;
      _sort = _Sort.newest;
      _visibleCount = 10;
    });
    if (_marketplace != Marketplace.shopping) setMarketplace(Marketplace.shopping);
    _scrollTop();
  }

  void _scrollTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    }
  }

  /// Chat button (bottom right) -> QNX AI Assistant. Needs login.
  Future<void> _openAssistant() async {
    if (!await ensureLoggedIn(context, reason: 'chat with QNX Assistant')) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
  }

  void _scrollToProducts() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _productsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
      }
    });
  }

  void _scrollPillIntoView(Marketplace m) {
    if (!_pillScroll.hasClients) return;
    final target = (m.index * 260.0).clamp(0.0, _pillScroll.position.maxScrollExtent);
    _pillScroll.animateTo(target,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  void _nudge(ScrollController c, double by) {
    if (!c.hasClients) return;
    final t = (c.offset + by).clamp(0.0, c.position.maxScrollExtent);
    c.animateTo(t, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _applySearch(String q) {
    FocusScope.of(context).unfocus();
    setState(() {
      _query = q.trim();
      _visibleCount = 10;
    });
    if (_marketplace == Marketplace.shopping) {
      _scrollToProducts();
    } else if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _onBannerTap(HomeBanner b) async {
    switch (b.target) {
      case BannerTarget.url:
        final uri = Uri.tryParse(b.targetValue);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      case BannerTarget.products:
        widget.onNavigate('products');
      case BannerTarget.category:
        selectCategory(b.targetValue, scroll: true);
      case BannerTarget.realEstate:
        setMarketplace(Marketplace.realEstate);
      case BannerTarget.remart:
        setMarketplace(Marketplace.remart);
      case BannerTarget.loan:
        widget.onNavigate('loan_enquiry');
      case BannerTarget.none:
        break;
    }
  }

  void _openFranchise(Product p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FranchisePlansScreen(productSlug: p.slug, productName: p.name),
      ),
    );
  }

  void _openEnquiry(Product p) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEnquiryScreen(product: p)));
  }

  Future<void> _addToCart(Product p) async {
    await CartHelper.addToCart(context: context, product: p);
    widget.onCartChanged();
  }

  // =================================================================
  // FILTERING
  // =================================================================
  double _num(String s) => double.tryParse(s) ?? 0;

  List<Product> get _filtered {
    final q = _query.toLowerCase();
    final cat = _category?.toLowerCase();
    final list = _products.where((p) {
      if (cat != null && p.categoryName.trim().toLowerCase() != cat) return false;
      if (_franchiseOnly && !p.isFranchiseAvailable) return false;
      if (_inStockOnly && (p.stockQuantity ?? 1) <= 0) return false;
      if (q.isEmpty) return true;
      return [p.name, p.categoryName, p.brandName, p.companyName, p.subcategoryName]
          .any((s) => s.toLowerCase().contains(q));
    }).toList();
    switch (_sort) {
      case _Sort.newest:
        break; // API order is newest first
      case _Sort.priceLow:
        list.sort((a, b) => _num(a.finalPrice).compareTo(_num(b.finalPrice)));
      case _Sort.priceHigh:
        list.sort((a, b) => _num(b.finalPrice).compareTo(_num(a.finalPrice)));
      case _Sort.nameAz:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  bool get _hasFilters =>
      _category != null || _query.isNotEmpty || _franchiseOnly || _inStockOnly || _sort != _Sort.newest;

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _category = null;
      _query = '';
      _franchiseOnly = false;
      _inStockOnly = false;
      _sort = _Sort.newest;
      _visibleCount = 10;
    });
  }

  Future<void> _openFilters() async {
    var sort = _sort;
    var franchise = _franchiseOnly;
    var inStock = _inStockOnly;
    String? cat = _category;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget sortTile(_Sort s, String label) => RadioListTile<_Sort>(
            value: s,
            groupValue: sort,
            dense: true,
            activeColor: _HC.blue,
            contentPadding: EdgeInsets.zero,
            title: Text(label, style: DT.text(size: 13.5, weight: FontWeight.w600)),
            onChanged: (v) => setSheet(() => sort = v!),
          );
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('Filters', style: DT.text(size: 18, weight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSheet(() {
                          sort = _Sort.newest;
                          franchise = false;
                          inStock = false;
                          cat = null;
                        }),
                        child: Text('Reset',
                            style: DT.text(size: 13, weight: FontWeight.w700, color: _HC.blue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Sort by', style: DT.text(size: 12, weight: FontWeight.w700, color: DT.slate500)),
                  sortTile(_Sort.newest, 'Newest first'),
                  sortTile(_Sort.priceLow, 'Price: low to high'),
                  sortTile(_Sort.priceHigh, 'Price: high to low'),
                  sortTile(_Sort.nameAz, 'Name: A to Z'),
                  const Divider(),
                  SwitchListTile(
                    value: franchise,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Colors.white,
                    activeTrackColor: _HC.blue,
                    title: Text('Franchise available',
                        style: DT.text(size: 13.5, weight: FontWeight.w600)),
                    onChanged: (v) => setSheet(() => franchise = v),
                  ),
                  SwitchListTile(
                    value: inStock,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Colors.white,
                    activeTrackColor: _HC.blue,
                    title: Text('In stock only', style: DT.text(size: 13.5, weight: FontWeight.w600)),
                    onChanged: (v) => setSheet(() => inStock = v),
                  ),
                  if (_categories.isNotEmpty) ...[
                    const Divider(),
                    Text('Category',
                        style: DT.text(size: 12, weight: FontWeight.w700, color: DT.slate500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in [null, ..._categories.map((e) => e.name)])
                          ChoiceChip(
                            label: Text(c ?? 'All'),
                            selected: cat == c,
                            showCheckmark: false,
                            selectedColor: _HC.blue,
                            backgroundColor: _HC.pillBg,
                            side: BorderSide(color: cat == c ? _HC.blue : _HC.pillBorder),
                            labelStyle: DT.text(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: cat == c ? Colors.white : _HC.blueText),
                            onSelected: (_) => setSheet(() => cat = c),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _kBrand, // buttons: only #093C71
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Color(0x40093C71), blurRadius: 12, offset: Offset(0, 4))],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Show products',
                            style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (apply != true) return;
    setState(() {
      _sort = sort;
      _franchiseOnly = franchise;
      _inStockOnly = inStock;
      _category = cat;
      _visibleCount = 10;
    });
    _scrollToProducts();
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                color: _HC.blue,
                onRefresh: _refreshAll,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Real Estate / ReMart dark bands are full width and flush with the chips.
                  padding: _marketplace != Marketplace.shopping
                      ? const EdgeInsets.only(bottom: 96)
                      : const EdgeInsets.fromLTRB(14, 16, 14, 96),
                  children: switch (_marketplace) {
                    Marketplace.shopping => [
                      _heroCarousel(),
                      const SizedBox(height: 8), // 🆕 Reduced from 10 to 8
                      _financeStrip(),
                      const SizedBox(height: 12), // 🆕 Reduced from 16 to 12
                      _reelsSection(),
                      const SizedBox(height: 16),
                      _partnerCards(),
                      const SizedBox(height: 20),
                      _productsSection(),
                    ],
                    Marketplace.realEstate => [_propertiesSection()],
                    Marketplace.remart => [_remartSection()],
                  },
                ),
              ),
            ),
          ],
        ),
        // Chat with QNX Assistant – animated chatbot logo (same 56 x 56 size)
        Positioned(
          right: 20,
          bottom: 16,
          child: _ChatBotButton(onTap: _openAssistant),
        ),
      ],
    );
  }

  // =================================================================
  // HEADER
  // =================================================================
  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _topBar(),
            Container(height: 1, color: _HC.hairline),
            _marketplacePills(),
            Container(height: 1, color: _HC.hairline),
            _categoryRow(),
            _searchBar(),
            Container(height: 1, color: _HC.hairline),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      child: Row(
        children: [
          GestureDetector(
            onTap: _goHome,
            behavior: HitTestBehavior.opaque,
            child: Image.asset(
              'lib/assets/images/qnx_mart_logo.png',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('QNX', style: DT.text(size: 15, weight: FontWeight.w900, color: _HC.darkBlue, letterSpacing: -0.6)),
                  const SizedBox(width: 3),
                  Text('MART', style: DT.text(size: 15, weight: FontWeight.w800, color: _HC.red, letterSpacing: -0.3)),
                ],
              ),
            ),
          ),
          const Spacer(),
          _roundIcon(
            icon: Icons.shopping_cart_outlined,
            badge: widget.cartCount,
            onTap: () => widget.onNavigate('cart'),
          ),
          const SizedBox(width: 8),
          _profileButton(),
        ],
      ),
    );
  }

  Widget _roundIcon({required IconData icon, required VoidCallback onTap, int badge = 0}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: DT.slate100, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: DT.onyx700),
            ),
            if (badge > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _HC.red,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(badge > 99 ? '99+' : '$badge',
                      style: DT.text(size: 9, weight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileButton() {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        switch (v) {
          case 'login':
            widget.onLogin();
          case 'logout':
            widget.onLogout();
          default:
            widget.onNavigate(v);
        }
      },
      itemBuilder: (_) => [
        if (widget.loggedIn)
          PopupMenuItem(
            enabled: false,
            child: Text(widget.userName.isEmpty ? 'My account' : 'Hi, ${widget.userName}',
                style: DT.text(size: 13, weight: FontWeight.w800, color: DT.onyx900)),
          ),
        _menu('account', Icons.person_outline_rounded, 'My account'),
        _menu('orders', Icons.receipt_long_outlined, 'My orders'),
        _menu('company_list', Icons.apartment_rounded, 'My companies'),
        _menu('my_products', Icons.inventory_2_outlined, 'My products'),
        const PopupMenuDivider(),
        widget.loggedIn
            ? _menu('logout', Icons.logout_rounded, 'Log out', color: _kRed)
            : _menu('login', Icons.login_rounded, 'Login / Register', color: _HC.blue),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
        decoration: BoxDecoration(color: DT.slate100, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: DT.slate200, shape: BoxShape.circle),
              child: Icon(
                widget.loggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                size: 16,
                color: DT.onyx700,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: DT.onyx600),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menu(String v, IconData icon, String label, {Color? color}) =>
      PopupMenuItem(
        value: v,
        child: Row(children: [
          Icon(icon, size: 19, color: color ?? DT.onyx700),
          const SizedBox(width: 10),
          Text(label, style: DT.text(size: 13.5, weight: FontWeight.w600, color: color ?? DT.onyx900)),
        ]),
      );

  // ── Marketplace pills ───────────────────────────────────
  Widget _marketplacePills() {
    final canLeft = _pillScroll.hasClients && _pillScroll.offset > 4;
    final canRight =
        !_pillScroll.hasClients || _pillScroll.offset < _pillScroll.position.maxScrollExtent - 4;
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListView(
            controller: _pillScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 9, 40, 9),
            children: [
              for (final m in Marketplace.values)
                Padding(padding: const EdgeInsets.only(right: 8), child: _pill(m)),
            ],
          ),
          if (canLeft) Positioned(left: 8, child: _arrow(Icons.chevron_left_rounded, () => _nudge(_pillScroll, -220))),
          if (canRight)
            Positioned(right: 10, child: _arrow(Icons.chevron_right_rounded, () => _nudge(_pillScroll, 220))),
        ],
      ),
    );
  }

  Widget _pill(Marketplace m) {
    final sel = m == _marketplace;
    return GestureDetector(
      onTap: () => setMarketplace(m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? _HC.blue : _HC.slatePill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? _HC.blue : _HC.line),
          boxShadow: sel ? const [BoxShadow(color: Color(0x33093C71), blurRadius: 6, offset: Offset(0, 2))] : null,
        ),
        // Active pill shows the full name, the others a short one (as in the design).
        child: Text(sel ? m.title : m.shortTitle,
            style: DT.text(
                size: 12.5,
                weight: FontWeight.w700,
                color: sel ? Colors.white : DT.onyx700,
                letterSpacing: sel ? 0.2 : 0)),
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Material(
    color: Colors.white,
    shape: const CircleBorder(side: BorderSide(color: _HC.line)),
    elevation: 3,
    shadowColor: const Color(0x330F172A),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 26, height: 26, child: Icon(icon, size: 18, color: DT.onyx800)),
    ),
  );

  // ── ☰ + category chips ──────────────────────────────────
  Widget _categoryRow() {
    final chips = _marketChips();
    final canRight =
        !_chipScroll.hasClients || _chipScroll.offset < _chipScroll.position.maxScrollExtent - 4;
    final canLeft = _chipScroll.hasClients && _chipScroll.offset > 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 0, 8),
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _HC.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onOpenDrawer,
                child: const SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(Icons.menu_rounded, color: DT.onyx700, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ListView(
                    controller: _chipScroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 40),
                    children: chips,
                  ),
                  if (canLeft)
                    Positioned(left: 0, child: _arrow(Icons.chevron_left_rounded, () => _nudge(_chipScroll, -180))),
                  if (canRight && chips.length > 1)
                    Positioned(
                        right: 10, child: _arrow(Icons.chevron_right_rounded, () => _nudge(_chipScroll, 180))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar (with Filter icon at the end) ────────────
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _applySearch,
              onChanged: (v) => setState(() {
                if (v.isEmpty) _query = ''; // also refreshes the clear (✕) button
              }),
              style: DT.text(size: 13, weight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: switch (_marketplace) {
                  Marketplace.shopping => 'Search products, services...',
                  Marketplace.realEstate => 'Search city, area or property...',
                  Marketplace.remart => 'Search used & resale items...',
                },
                hintStyle: DT.text(size: 13, color: DT.slate400),
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, color: DT.slate400, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 42),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close_rounded, color: DT.slate400, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: _HC.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: _HC.blue, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter icon moved into the search row
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _hasFilters ? _HC.blue : _HC.line, width: _hasFilters ? 1.5 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openFilters,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.tune_rounded, color: _HC.blue, size: 22),
                    if (_hasFilters)
                      Positioned(
                        top: 8,
                        right: 9,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: _HC.red, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _marketChips() => switch (_marketplace) {
    Marketplace.shopping => [
      _chip(null, 'All Categories', Icons.grid_view_rounded),
      for (final c in _categories) _chip(c.name, c.name, Icons.sell_outlined),
    ],
    Marketplace.realEstate => [
      _pillChip(
        label: 'All Properties',
        icon: Icons.apartment_rounded,
        selected: _propType == null,
        onTap: () => setState(() => _propType = null),
      ),
      for (final t in _propertyTypes)
        _pillChip(
          label: _typeLabel(t),
          icon: _typeIcon(t),
          selected: _propType == t,
          onTap: () => setState(() => _propType = t),
        ),
    ],
    Marketplace.remart => [
      _pillChip(
        label: 'All Remart Items',
        icon: Icons.recycling_rounded,
        selected: _remartCat == null,
        onTap: () => setState(() => _remartCat = null),
      ),
      for (final (id, name) in _remartCats)
        _pillChip(
          label: name,
          icon: Icons.sell_rounded,
          selected: _remartCat == id,
          onTap: () => setState(() => _remartCat = id),
        ),
    ],
  };

  Widget _pillChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _HC.blue : _HC.pillBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? _HC.blue : _HC.pillBorder),
            boxShadow:
            selected ? const [BoxShadow(color: Color(0x26093C71), blurRadius: 4, offset: Offset(0, 1))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : _HC.blue),
              const SizedBox(width: 6),
              Text(label,
                  style: DT.text(size: 12.5, weight: FontWeight.w700, color: selected ? Colors.white : _HC.blue)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String? value, String label, IconData icon) {
    final sel = (value == null && _category == null) ||
        (value != null && _category?.toLowerCase() == value.toLowerCase());
    return _pillChip(
      label: label,
      icon: icon,
      selected: sel,
      onTap: () => selectCategory(value, scroll: true),
    );
  }

  // =================================================================
  // CONTENT SECTIONS
  // =================================================================
  BoxDecoration get _panel => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _HC.line),
    boxShadow: _HC.cardShadow,
  );

  // ── Hero carousel (contain fit, no zoom) ────────────────
  Widget _heroCarousel() {
    final stillLoading = (_heroLoading || _adminImagesLoading) &&
        _hero.isEmpty &&
        _adminImages.isEmpty;
    // 🆕 Padding reduced to 2 (from 4) to bring banner closer to the search bar
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            // 🆕 Changed from 1.6 to 1.85 so the banner height is reduced even more
            aspectRatio: 1.85,
            child: stillLoading
                ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE2E8F0), Color(0xFFF1F5F9)]),
              ),
            )
                : Stack(
              children: [
                PageView.builder(
                  controller: _heroPage,
                  itemCount: _heroCount,
                  onPageChanged: (i) => setState(() => _heroIndex = i),
                  itemBuilder: (_, i) {
                    // Priority: API banners > admin images > fallback slides.
                    if (_hero.isNotEmpty && i < _hero.length) {
                      return _heroImage(_hero[i]);
                    }
                    if (_adminImages.isNotEmpty && i < _adminImages.length) {
                      return _adminImageSlide(_adminImages[i]);
                    }
                    return _fallbackSlides[i % _fallbackSlides.length]();
                  },
                ),
                if (_heroCount > 1) ...[
                  Positioned(
                      left: 10, top: 0, bottom: 0, child: Center(child: _glassArrow(Icons.chevron_left_rounded, -1))),
                  Positioned(
                      right: 10, top: 0, bottom: 0, child: Center(child: _glassArrow(Icons.chevron_right_rounded, 1))),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _heroCount; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _heroIndex ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _heroIndex ? Colors.white : Colors.white54,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassArrow(IconData icon, int dir) => Material(
    color: Colors.white.withValues(alpha: 0.82),
    shape: const CircleBorder(),
    elevation: 2,
    shadowColor: const Color(0x330F172A),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () {
        if (!_heroPage.hasClients) return;
        final next = (_heroIndex + dir + _heroCount) % _heroCount;
        _heroPage.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        _startHeroTimer();
      },
      child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 22, color: DT.onyx800)),
    ),
  );

  Widget _heroImage(HomeBanner b) => GestureDetector(
    onTap: () => _onBannerTap(b),
    // Contain fit keeps the whole banner visible (no zoom/crop).
    child: Container(
      color: const Color(0xFFF1F5F9),
      child: Image.network(
        b.imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (c, child, p) => p == null ? child : Container(color: const Color(0xFFE2E8F0)),
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFE2E8F0),
          alignment: Alignment.center,
          child: Text(b.title.isEmpty ? 'QNXMart' : b.title,
              style: DT.text(size: 16, weight: FontWeight.w700, color: DT.slate500)),
        ),
      ),
    ),
  );

  /// Slide built from an admin-uploaded image (admin_profile/upload_image_list/).
  /// Shown when the banner API has no home_hero banners.
  /// The "BANNER" label overlay has been removed as requested.
  Widget _adminImageSlide(AdminImage img) {
    return GestureDetector(
      onTap: () => widget.onNavigate('products'),
      child: Container(
        color: const Color(0xFFF1F5F9),
        child: Image.network(
          img.imageUrl,
          fit: BoxFit.contain, // no zoom
          loadingBuilder: (c, child, p) => p == null
              ? child
              : Container(
            color: const Color(0xFFE2E8F0),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: _HC.blue,
            ),
          ),
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFE2E8F0),
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF94A3B8),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  /// Shown until banners are added through the banner API / Django admin.
  List<Widget Function()> get _fallbackSlides => [
        () => _fallbackSlide(
      colors: const [Color(0xFFA43A08), Color(0xFFD8500C), Color(0xFFB23B05)],
      kicker: 'NEW · Buy · Sell · Rent · Invest',
      kickerColor: const Color(0xFFFED7AA),
      title: 'Properties',
      subtitle: 'Explore verified properties from trusted corporate partners.',
      icon: Icons.apartment_rounded,
      onTap: () => setMarketplace(Marketplace.realEstate),
    ),
        () => _fallbackSlide(
      colors: const [Color(0xFF062A50), Color(0xFF093C71)],
      kicker: 'QNXMART B2B · Small business. Stronger together.',
      kickerColor: const Color(0xFFC9DBEE),
      title: 'Fresh Look.\nBigger Possibilities.',
      subtitle: 'Trusted marketplace for products, services and properties.',
      icon: Icons.storefront_rounded,
      onTap: () => widget.onNavigate('products'),
    ),
        () => _fallbackSlide(
      colors: const [Color(0xFF093C71), Color(0xFF062A50)],
      kicker: 'Easy bank loans',
      kickerColor: const Color(0xFFFDE68A),
      title: '9.99% p.a.',
      subtitle: 'Minimum documentation · Quick approval · Flexible repayment.',
      icon: Icons.account_balance_rounded,
      onTap: () => widget.onNavigate('loan_enquiry'),
    ),
  ];

  Widget _fallbackSlide({
    required List<Color> colors,
    required String kicker,
    required Color kickerColor,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 14,
              bottom: 14,
              child: Icon(icon, size: 96, color: Colors.white.withValues(alpha: 0.2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 56, 0),
              child: Align(
                alignment: const Alignment(-1, -0.15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kicker.toUpperCase(),
                        style: DT.text(size: 10.5, weight: FontWeight.w800, color: kickerColor, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text(title,
                        style: DT.text(
                            size: 26, weight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text(subtitle,
                        style: DT.text(size: 12.5, color: Colors.white.withValues(alpha: 0.88), height: 1.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _fallbackBanks = <(String, String)>[
    ('Axis Bank', 'lib/assets/icon/axis bank.jpeg'),
    ('Bajaj Finance', 'lib/assets/icon/bajaj finance.jpeg'),
    ('Chola Finance', 'lib/assets/icon/chola finance.jpeg'),
    ('HDFC Bank', 'lib/assets/icon/hdfc bank.jpeg'),
    ('ICICI Bank', 'lib/assets/icon/icici bank.jpeg'),
    ('IndusInd Bank', 'lib/assets/icon/indusland bank.jpeg'),
    ('Kotak Bank', 'lib/assets/icon/kotak bank.jpeg'),
    ('L&T Finance', 'lib/assets/icon/l&t finance.jpeg'),
    ('Mahindra Finance', 'lib/assets/icon/mahindra finance.jpeg'),
    ('Tata Capital', 'lib/assets/icon/tata capital.jpeg'),
  ];

  Widget _financeStrip() {
    final useApi = _finance.isNotEmpty;
    final count = useApi ? _finance.length : _fallbackBanks.length;
    return SizedBox(
      height: 95, // 🆕 Reduced from 112 to 95 to remove extra white space
      child: ListView.separated(
        controller: _financeScroll,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final String bankName;
          final Widget logoWidget;
          final VoidCallback onTap;

          if (useApi) {
            final b = _finance[i];
            bankName = b.title;
            onTap = () => widget.onNavigate('loan_enquiry');
            logoWidget = Image.network(
              b.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  b.title,
                  textAlign: TextAlign.center,
                  style: DT.text(size: 10, weight: FontWeight.w800, color: _HC.darkBlue),
                ),
              ),
            );
          } else {
            final (name, path) = _fallbackBanks[i];
            bankName = name;
            onTap = () => widget.onNavigate('loan_enquiry');
            logoWidget = Image.asset(
              path,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: DT.text(size: 9.5, weight: FontWeight.w800, color: _HC.darkBlue, height: 1.15),
                ),
              ),
            );
          }

          return GestureDetector(
            // Tap anywhere on the card → loan enquiry form
            onTap: onTap,
            child: Container(
              width: 150,
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6), // 🆕 Reduced from 8 to 6
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _HC.line),
                boxShadow: const [
                  BoxShadow(color: Color(0x080F172A), blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Bank logo (fixed height) ─────────────────
                  SizedBox(
                    height: 36, // 🆕 Reduced from 42 to 36
                    child: logoWidget,
                  ),
                  const SizedBox(height: 2), // 🆕 Reduced from 4 to 2
                  // ── Loan info + arrow ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '9.99%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(
                                size: 11,
                                weight: FontWeight.w900,
                                color: _HC.darkBlue,
                              ),
                            ),
                            Text(
                              'Get Your Loan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(
                                size: 8.5,
                                weight: FontWeight.w700,
                                color: _HC.darkBlue,
                              ),
                            ),
                            Text(
                              'Fast approval',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(size: 7.5, color: DT.slate500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: _HC.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Partner cards ───────────────────────────────────────
  Widget _partnerCards() {
    return Row(
      children: [
        Expanded(
          child: _partnerCard(Icons.groups_rounded, 'Marketing Partner', 'Partner catalogs',
                  () => widget.onNavigate('marketing_partner'), big: true),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _partnerCard(Icons.apartment_rounded, 'Info Company', 'Governance profile', _openInfoCompany, big: true),
        ),
      ],
    );
  }

  Widget _partnerCard(IconData icon, String title, String subtitle, VoidCallback onTap, {bool big = false}) {
    return Material(
      color: big ? const Color(0xFF093C71) : const Color(0xFF062A50),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(big ? 10 : 12),
          child: Row(
            children: [
              Container(
                width: big ? 36 : 38,
                height: big ? 36 : 38,
                decoration: BoxDecoration(
                  color: big ? const Color(0x991E5A9C) : const Color(0xCC062A50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: big ? 18 : 19),
              ),
              SizedBox(width: big ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: big ? 12 : 13, weight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(
                            size: big ? 10 : 10.5,
                            color: big ? const Color(0xFFC9DBEE) : DT.slate300)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _infoSheet({
    required IconData icon,
    required String title,
    required String body,
    required List<(String, IconData, VoidCallback)> actions,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: _HC.pillBg, shape: BoxShape.circle),
                  child: Icon(icon, color: _HC.blue),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: DT.text(size: 18, weight: FontWeight.w800))),
              ]),
              const SizedBox(height: 12),
              Text(body, style: DT.text(size: 13.5, color: DT.onyx600, height: 1.55)),
              const SizedBox(height: 16),
              for (final (label, ic, onTap) in actions) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onTap();
                  },
                  icon: Icon(ic, size: 18),
                  label: Text(label, style: DT.text(size: 13.5, weight: FontWeight.w700, color: _HC.navy)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _HC.navy,
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: _HC.pillBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openInfoCompany() => _infoSheet(
    icon: Icons.business_rounded,
    title: 'Info Company',
    body: 'QNXMart B2B connects verified companies, buyers and partners. Sellers are '
        'registered companies, products are approved by our team before they go live, '
        'and payments are processed securely.',
    actions: [
      ('Terms & Conditions', Icons.description_outlined, () {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TermsConditionsScreen()));
      }),
      ('Register your company', Icons.apartment_rounded,
          () => widget.onNavigate('company_list')),
    ],
  );

  // ── Products ────────────────────────────────────────────
  Widget _productsSection() {
    final list = _filtered;
    final shown = list.take(_visibleCount).toList();
    final title = _query.isNotEmpty ? 'Results for "$_query"' : (_category ?? 'Latest products');

    return Column(
      key: _productsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 15, weight: FontWeight.w900, color: DT.onyx900, letterSpacing: -0.2)),
                  if (!_productsLoading)
                    Text('${list.length} product${list.length == 1 ? '' : 's'}',
                        style: DT.text(size: 11.5, color: DT.slate500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: _hasFilters ? _clearFilters : () => widget.onNavigate('products'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(_hasFilters ? 'CLEAR' : 'VIEW ALL',
                    style: DT.text(size: 12.5, weight: FontWeight.w800, color: _HC.blue, letterSpacing: 1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_productsLoading)
          _productGrid(itemCount: 4, builder: (_) => _skeletonCard())
        else if (_productsError != null && _products.isEmpty)
          _messageCard(Icons.cloud_off_rounded, 'Could not load products', _productsError!,
              action: 'Retry', onAction: _loadProducts)
        else if (list.isEmpty)
            _messageCard(Icons.search_off_rounded, 'No products found', 'Try another category or clear the filters.',
                action: _hasFilters ? 'Clear filters' : null, onAction: _clearFilters)
          else ...[
              _productGrid(itemCount: shown.length, builder: (i) => _productCard(shown[i])),
              if (list.length > shown.length) ...[
                const SizedBox(height: 12),
                Center(
                  child: Material(
                    color: const Color(0x80EAF1F9),
                    shape: const StadiumBorder(side: BorderSide(color: Color(0xFFC9DBEE))),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => setState(() => _visibleCount += 10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        child: Text('Load more (${list.length - shown.length} left)',
                            style: DT.text(size: 12.5, weight: FontWeight.w700, color: _HC.blue)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
      ],
    );
  }

  Widget _productGrid({required int itemCount, required Widget Function(int) builder}) {
    return LayoutBuilder(builder: (context, c) {
      final cardWidth = (c.maxWidth - 12) / 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: cardWidth + 105,
        ),
        itemBuilder: (_, i) => builder(i),
      );
    });
  }

  String _price(String raw) {
    final v = double.tryParse(raw);
    if (v == null) return raw;
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  Widget _productCard(Product p) {
    final fp = double.tryParse(p.finalPrice) ?? 0;
    final mrp = double.tryParse(p.price) ?? 0;
    final showMrp = mrp > fp && fp > 0;
    final stock = p.stockQuantity;
    final sub = [
      if (p.brandName.isNotEmpty) p.brandName,
      if (stock != null)
        stock <= 0 ? 'Out of stock' : '$stock${p.unitName.isEmpty ? '' : ' ${p.unitName.toUpperCase()}'}'
      else if (p.categoryName.isNotEmpty)
        p.categoryName,
    ].join(' · ');

    Widget placeholder() => Container(
      color: DT.slate100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(
        p.brandName.isNotEmpty ? p.brandName : p.name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: DT.text(size: 22, weight: FontWeight.w900, color: DT.onyx800, letterSpacing: -1),
      ),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openProductQuickView(p),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _HC.line),
            boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 2, offset: Offset(0, 1))],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      p.thumbnail.isEmpty
                          ? placeholder()
                          : Image.network(p.thumbnail,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, prog) => prog == null ? child : Container(color: DT.slate100),
                          errorBuilder: (_, __, ___) => placeholder()),
                      if (p.isFranchiseAvailable)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: GestureDetector(
                            onTap: () => _openFranchise(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _HC.blue,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🏪', style: TextStyle(fontSize: 9)),
                                  const SizedBox(width: 4),
                                  Text('Franchise',
                                      style: DT.text(size: 9.5, weight: FontWeight.w800, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 12.5, weight: FontWeight.w800, color: DT.onyx800)),
              const SizedBox(height: 1),
              Text(sub.isEmpty ? ' ' : sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(
                      size: 10.5, color: stock != null && stock <= 0 ? _kRed : DT.slate400)),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text('₹${_price(p.finalPrice)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 13, weight: FontWeight.w900, color: DT.onyx900)),
                  ),
                  if (showMrp) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text('₹${_price(p.price)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 10, color: DT.slate400, decoration: TextDecoration.lineThrough)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openEnquiry(p),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DT.onyx800,
                        side: const BorderSide(color: DT.slate300),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DT.rMd),
                        ),
                      ),
                      child: Text(
                        'Enquiry',
                        style: DT.text(
                          size: 10,
                          weight: FontWeight.w700,
                          color: DT.onyx800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _addToCart(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBrand, // buttons: only #093C71
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DT.rMd),
                        ),
                      ),
                      child: Text(
                        'Cart',
                        style: DT.text(
                          size: 10,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a bottom sheet showing product details (no extra actions).
  Future<void> _openProductQuickView(Product p) {
    final fp = double.tryParse(p.finalPrice) ?? 0;
    final mrp = double.tryParse(p.price) ?? 0;
    final off = (mrp > fp && fp > 0) ? (((mrp - fp) / mrp) * 100).round() : 0;
    final stock = p.stockQuantity;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          // Height reduced to 60% of screen so it doesn't cover the whole screen
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              // Product image – BoxFit.contain so the full product is visible
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  child: AspectRatio(
                    aspectRatio: 4 / 3, // wider, shorter image
                    child: p.thumbnail.isEmpty
                        ? Container(
                        color: DT.slate100,
                        child: const Icon(Icons.inventory_2_outlined, size: 48, color: DT.slate300))
                        : Image.network(
                      p.thumbnail,
                      fit: BoxFit.contain, // full product visible
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : Container(
                        color: DT.slate100,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: _HC.blue),
                        ),
                      ),
                      errorBuilder: (_, __, ___) => Container(
                          color: DT.slate100,
                          child: const Icon(Icons.broken_image_outlined, size: 40, color: DT.slate300)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [p.categoryName, p.brandName].where((s) => s.isNotEmpty).join(' · ').toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 10.5, weight: FontWeight.w800, color: DT.slate500, letterSpacing: 0.6),
                    ),
                  ),
                  if (p.isFranchiseAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _HC.pillBg, borderRadius: BorderRadius.circular(999)),
                      child: Text('🏪 Franchise',
                          style: DT.text(size: 10.5, weight: FontWeight.w800, color: _HC.blue)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(p.name, style: DT.text(size: 18, weight: FontWeight.w800, color: DT.onyx900, height: 1.25)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${_price(p.finalPrice)}',
                      style: DT.text(size: 22, weight: FontWeight.w900, color: DT.onyx900)),
                  if (off > 0) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('₹${_price(p.price)}',
                          style: DT.text(size: 13, color: DT.slate400, decoration: TextDecoration.lineThrough)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: DT.emerald50, borderRadius: BorderRadius.circular(4)),
                      child: Text('$off% off',
                          style: DT.text(size: 11, weight: FontWeight.w800, color: DT.emerald700)),
                    ),
                  ],
                ],
              ),
              if (stock != null) ...[
                const SizedBox(height: 6),
                Text(
                  stock <= 0
                      ? 'Out of stock'
                      : 'In stock: $stock${p.unitName.isEmpty ? '' : ' ${p.unitName.toUpperCase()}'}',
                  style: DT.text(
                      size: 12.5, weight: FontWeight.w700, color: stock <= 0 ? _kRed : _HC.green),
                ),
              ],
              if (p.companyName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.storefront_outlined, size: 15, color: DT.slate400),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text('Sold by ${p.companyName}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: DT.text(size: 12.5, color: DT.onyx600)),
                  ),
                ]),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool compact = false,
  }) {
    return Material(
      color: primary ? _HC.blue : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: primary ? _HC.blue : DT.onyx700),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: compact ? 28 : 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 13 : 15, color: primary ? Colors.white : DT.onyx900),
              SizedBox(width: compact ? 3 : 5),
              Text(label,
                  style: DT.text(
                      size: compact ? 11 : 12.5, weight: FontWeight.w800, color: primary ? Colors.white : DT.onyx900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonCard() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFE9EEF8),
      borderRadius: BorderRadius.circular(24),
    ),
  );

  Widget _messageCard(IconData icon, String title, String body,
      {String? action, VoidCallback? onAction}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panel,
      child: Column(
        children: [
          Icon(icon, size: 36, color: DT.slate400),
          const SizedBox(height: 8),
          Text(title, style: DT.text(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: DT.text(size: 12.5, color: DT.slate500)),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: _HC.blue,
                side: const BorderSide(color: _HC.pillBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: Text(action, style: DT.text(size: 13, weight: FontWeight.w700, color: _HC.blue)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Live Reels & Demos (now in the old loan section position) ──
  Widget _reelsSection() {
    final reels = buildReels(_products);
    if (reels.isEmpty) return const SizedBox.shrink();

    void openFull(int i) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductReelsScreen(reels: reels, initialIndex: i)),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _PulseDot(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Reels & Demos',
                        style: DT.text(size: 13, weight: FontWeight.w900, color: DT.onyx900)),
                    Text('Tap to shop while watching', style: DT.text(size: 10.5, color: DT.slate500)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => openFull(0),
                child: Text('VIEW ALL',
                    style: DT.text(size: 12.5, weight: FontWeight.w800, color: _HC.blue, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 176,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PageView.builder(
                controller: _reelPage,
                itemCount: reels.length,
                onPageChanged: (i) => setState(() => _reelIndex = i),
                itemBuilder: (_, i) {
                  final r = reels[i];
                  final kicker = [r.product.categoryName, r.product.brandName]
                      .where((s) => s.isNotEmpty)
                      .join(' · ')
                      .toUpperCase();
                  return GestureDetector(
                    onTap: () => openFull(i),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
                            ),
                          ),
                        ),
                        if (r.product.thumbnail.isNotEmpty)
                          Opacity(
                            opacity: 0.55,
                            child: Image.network(r.product.thumbnail,
                                fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                        const Center(
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Color(0x66000000),
                            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 12,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0x33FFFFFF)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Color(0xFFC62828), shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('PRODUCT VIDEO',
                                        style: DT.text(
                                            size: 10,
                                            weight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 0.8)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${i + 1}/${reels.length}',
                                    style: DT.text(size: 10.5, weight: FontWeight.w700, color: DT.slate300)),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Color(0x66000000), Color(0xCC000000)],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (kicker.isNotEmpty)
                                  Text(kicker,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DT.text(
                                          size: 10,
                                          weight: FontWeight.w700,
                                          color: const Color(0xFFFCD34D),
                                          letterSpacing: 0.8)),
                                Text(r.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DT.text(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
                                Text('₹${_price(r.product.finalPrice)}',
                                    style: DT.text(size: 12.5, weight: FontWeight.w900, color: _HC.amber)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // REAL ESTATE  (pill: Real Estate — Buy, Sell & Rent)
  // =================================================================
  static const _typeOrder = ['flat', 'villa', 'plot', 'commercial', 'shop', 'office', 'warehouse', 'other'];

  List<String> get _propertyTypes {
    final present = _props.map((p) => p.propertyType).where((t) => t.isNotEmpty).toSet();
    return [
      for (final t in _typeOrder) if (present.contains(t)) t,
      for (final t in present) if (!_typeOrder.contains(t)) t,
    ];
  }

  String _typeLabel(String t) => switch (t) {
    'flat' => 'Flat / Apartment',
    'villa' => 'Villa / Bungalow',
    'plot' => 'Plot / Land',
    'commercial' => 'Commercial Space',
    'shop' => 'Shop / Retail',
    'office' => 'Office Space',
    'warehouse' => 'Warehouse',
    'other' => 'Other',
    _ => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1),
  };

  IconData _typeIcon(String t) => switch (t) {
    'flat' => Icons.apartment_rounded,
    'villa' => Icons.villa_rounded,
    'plot' => Icons.landscape_rounded,
    'commercial' => Icons.business_rounded,
    'shop' => Icons.storefront_rounded,
    'office' => Icons.work_outline_rounded,
    'warehouse' => Icons.warehouse_rounded,
    _ => Icons.home_work_outlined,
  };

  PropertyFilters get _activePropFilters => _pf.withType(_propType);

  bool _propMatchesQuery(Property p) {
    final q = _query.toLowerCase();
    if (q.isEmpty) return true;
    return [p.displayTitle, p.city, p.area, p.address, p.typeLabel, p.transactionLabel]
        .any((s) => s.toLowerCase().contains(q));
  }

  List<Property> _propsFor(PropertyFilters f) =>
      _props.where((p) => f.matches(p) && _propMatchesQuery(p)).toList();

  List<Property> get _filteredProps => _propsFor(_activePropFilters);

  Future<void> _openPropertyFilters() async {
    final result = await showPropertyFilterPanel(
      context,
      initial: _activePropFilters,
      countFor: (f) => _propsFor(f).length,
    );
    if (result == null || !mounted) return;
    setState(() {
      _pf = result.withType(null);
      _propType = result.type;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _clearPropertyFilters() {
    _searchCtrl.clear();
    setState(() {
      _pf = PropertyFilters.empty;
      _propType = null;
      _query = '';
    });
  }

  Widget _propertiesSection() {
    final list = _filteredProps;
    final filtersOn = _activePropFilters.activeCount;
    Widget body;
    if (_propsLoading && _props.isEmpty) {
      body = _cardGrid(itemCount: 4, extent: 330, builder: (_) => _skeletonCard());
    } else if (_propsError != null && _props.isEmpty) {
      body = _messageCard(Icons.cloud_off_rounded, 'Could not load properties', _propsError!,
          action: 'Retry', onAction: _loadProperties);
    } else if (list.isEmpty) {
      body = _messageCard(
        Icons.search_off_rounded,
        _props.isEmpty ? 'No properties yet' : 'No properties match',
        _props.isEmpty ? 'Approved properties will appear here.' : 'Try changing the filters or search.',
        action: (filtersOn > 0 || _query.isNotEmpty) ? 'Clear all filters' : null,
        onAction: _clearPropertyFilters,
      );
    } else {
      body = _cardGrid(itemCount: list.length, extent: 330, builder: (i) => _propertyCard(list[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _darkBand(
          icon: Icons.apartment_rounded,
          title: 'Properties',
          subtitle: _propsLoading && _props.isEmpty
              ? 'Loading…'
              : '${list.length} propert${list.length == 1 ? 'y' : 'ies'} found',
          activeFilters: filtersOn,
          onFilters: _openPropertyFilters,
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: body),
      ],
    );
  }

  Widget _darkBand({
    required IconData icon,
    required String title,
    required String subtitle,
    required int activeFilters,
    required VoidCallback onFilters,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF475569), Color(0xFF334155)]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 24, weight: FontWeight.w800, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(subtitle, style: DT.text(size: 14, color: Colors.white70)),
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.white38),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onFilters,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text('Filters', style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
                    if (activeFilters > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: _HC.amber, borderRadius: BorderRadius.circular(999)),
                        child: Text('$activeFilters',
                            textAlign: TextAlign.center,
                            style: DT.text(size: 11, weight: FontWeight.w800, color: _HC.navy)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardGrid({required int itemCount, required double extent, required Widget Function(int) builder}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        mainAxisExtent: extent,
      ),
      itemBuilder: (_, i) => builder(i),
    );
  }

  Widget _frostedPanel(Widget child, {double pad = 12}) => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: const Border(top: BorderSide(color: Color(0x99FFFFFF))),
        ),
        padding: EdgeInsets.all(pad),
        child: child,
      ),
    ),
  );

  Widget _photoCardShell({required Widget carousel, required Widget panel}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
        boxShadow: _HC.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Stack(
          fit: StackFit.expand,
          children: [
            carousel,
            Positioned(left: 0, right: 0, bottom: 0, child: panel),
          ],
        ),
      ),
    );
  }

  Widget _outlineChip(String text, {Color fg = DT.onyx700, Color border = DT.slate300, Color bg = Colors.white}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: 10.5, weight: FontWeight.w700, color: fg)),
      );

  Widget _pinLine(String text, {bool compact = false}) => Row(
    children: [
      Icon(Icons.location_on_rounded, size: compact ? 12 : 15, color: const Color(0xFF0EA5E9)),
      SizedBox(width: compact ? 2 : 4),
      Expanded(
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: compact ? 10.5 : 13, weight: FontWeight.w700, color: DT.onyx900)),
      ),
    ],
  );

  Widget _detailsEnquiryRow({required VoidCallback onDetails, required VoidCallback onEnquiry, bool compact = false}) => Row(
    children: [
      Expanded(
          child: _cardButton(
              icon: Icons.visibility_outlined, label: 'Details', compact: compact, onTap: onDetails)),
      SizedBox(width: compact ? 4 : 6),
      Expanded(
        child: _cardButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Enquiry',
            primary: true,
            compact: compact,
            onTap: onEnquiry),
      ),
    ],
  );

  Widget _propertyCard(Property p) {
    final location = [p.area, p.city].where((s) => s.trim().isNotEmpty).join(', ');
    return _photoCardShell(
      carousel: AutoImageCarousel(
        images: p.imageUrls,
        bottomInset: 138,
        placeholderIcon: Icons.apartment_rounded,
        onTap: () => _openPropertyDetails(p),
      ),
      panel: _frostedPanel(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.typeLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 8.5, weight: FontWeight.w800, color: DT.onyx800, letterSpacing: 0.3)),
              ),
              if (p.transactionLabel.isNotEmpty) _miniChip(p.transactionLabel),
            ],
          ),
          const SizedBox(height: 3),
          Text(p.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 12.5, weight: FontWeight.w800, color: DT.onyx900, height: 1.25)),
          const SizedBox(height: 3),
          _pinLine(location.isEmpty ? '—' : location, compact: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Divider(height: 1, color: Color(0x33000000)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(p.formattedMinPrice,
                style: DT.text(size: 14.5, weight: FontWeight.w900, color: DT.onyx900)),
          ),
          const SizedBox(height: 6),
          _detailsEnquiryRow(
            compact: true,
            onDetails: () => _openPropertyDetails(p),
            onEnquiry: () => _openPropertyEnquiry(p),
          ),
        ],
      ), pad: 9),
    );
  }

  Widget _miniChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: DT.slate300),
    ),
    child: Text(text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DT.text(size: 9, weight: FontWeight.w700, color: DT.onyx700)),
  );



  void _openPropertyDetails(Property p) {
    if (p.slug.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumPropertyDetailScreen(slug: p.slug, previewName: p.displayTitle),
      ),
    );
  }

  Future<void> _openPropertyEnquiry(Property p) async {
    if (p.slug.isEmpty) return;
    if (!await ensureLoggedIn(context, reason: 'send an enquiry')) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _HC.blue)),
    );
    final r = await RealEstateService.getPropertyDetail(p.slug);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (r.isSuccess && r.data != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PropertyEnquiryScreen(property: r.data!)));
    } else {
      _snack(r.message ?? 'Could not open the enquiry form');
    }
  }

  // =================================================================
  // QNXREMART  (pill: QNXRemart — Used & Resale)
  // =================================================================
  List<RemartListing> get _filteredRemart {
    final q = _query.toLowerCase();
    final city = _rmCity.toLowerCase();
    final cat = _remartCats.where((c) => c.$1 == _remartCat).map((c) => c.$2.toLowerCase()).firstOrNull;
    final list = _remart.where((l) {
      if (cat != null && l.categoryName.toLowerCase() != cat) return false;
      if (_rmCondition != null && l.condition != _rmCondition) return false;
      if (_rmSeller != null && l.sellerType != _rmSeller) return false;
      if (_rmNegotiable && !l.negotiable) return false;
      if (city.isNotEmpty && !'${l.city} ${l.area}'.toLowerCase().contains(city)) return false;
      if (q.isEmpty) return true;
      return [l.title, l.description, l.categoryName, l.subcategoryName, l.city, l.area]
          .any((s) => s.toLowerCase().contains(q));
    }).toList();
    switch (_rmSort) {
      case _Sort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
      case _Sort.nameAz:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Sort.newest:
        break;
    }
    return list;
  }

  Widget _remartSection() {
    final list = _filteredRemart;
    Widget body;
    if (_remartLoading && _remart.isEmpty) {
      body = _cardGrid(itemCount: 4, extent: 400, builder: (_) => _skeletonCard());
    } else if (_remartError != null && _remart.isEmpty) {
      body = _messageCard(Icons.cloud_off_rounded, 'Could not load items', _remartError!,
          action: 'Retry', onAction: _loadRemart);
    } else if (list.isEmpty) {
      body = _messageCard(
        Icons.search_off_rounded,
        _remart.isEmpty ? 'No items yet' : 'No items found',
        _remart.isEmpty ? 'Used & resale listings will appear here.' : 'Try another category, search or filter.',
        action: _remart.isEmpty ? 'Sell an item' : 'Clear filters',
        onAction: _remart.isEmpty ? () => openRemartPosting(context) : _clearRemartFilters,
      );
    } else {
      body = _cardGrid(itemCount: list.length, extent: 400, builder: (i) => _remartCard(list[i]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _darkBand(
          icon: Icons.storefront_outlined,
          title: 'Products',
          subtitle: _remartLoading && _remart.isEmpty
              ? 'Loading…'
              : '${list.length} product${list.length == 1 ? '' : 's'} found',
          activeFilters: [
            _rmSort != _Sort.newest,
            _rmCondition != null,
            _rmSeller != null,
            _rmNegotiable,
            _rmCity.isNotEmpty,
          ].where((x) => x).length,
          onFilters: _openRemartFilters,
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: body),
      ],
    );
  }

  String _rupeeSpaced(double v) {
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    final parts = s.split('.');
    var n = parts[0];
    if (n.length > 3) {
      final last3 = n.substring(n.length - 3);
      var rest = n.substring(0, n.length - 3);
      final g = <String>[];
      while (rest.length > 2) {
        g.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) g.insert(0, rest);
      n = '${g.join(',')},$last3';
    }
    return '₹ $n${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  Widget _remartCard(RemartListing l) {
    return _photoCardShell(
      carousel: AutoImageCarousel(
        images: l.images,
        bottomInset: 200,
        placeholderIcon: Icons.recycling_rounded,
        onTap: () => _openRemartDetails(l),
      ),
      panel: _frostedPanel(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.categoryName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 11, weight: FontWeight.w800, color: DT.onyx900)),
              ),
              if (_myUserId != null && l.userId == _myUserId) ...[
                _outlineChip('Your listing', fg: _HC.blue, border: _HC.pillBorder, bg: _HC.pillBg),
                const SizedBox(width: 4),
              ],
              if (l.conditionLabel.isNotEmpty)
                _outlineChip(l.conditionLabel,
                    fg: const Color(0xFF15803D), border: const Color(0xFF86EFAC), bg: const Color(0xFFF0FDF4)),
            ],
          ),
          const SizedBox(height: 5),
          Text(l.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 15, weight: FontWeight.w800, color: DT.onyx900)),
          if (l.description.isNotEmpty)
            Text(l.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(size: 12.5, color: DT.onyx600)),
          const SizedBox(height: 6),
          _pinLine(l.location.isEmpty ? '—' : l.location),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0x33000000)),
          ),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_rupeeSpaced(l.price),
                      style: DT.text(size: 18, weight: FontWeight.w900, color: DT.onyx900)),
                ),
              ),
              if (l.negotiable) ...[
                const SizedBox(width: 6),
                _outlineChip('Negotiable',
                    fg: const Color(0xFFB45309), border: const Color(0xFFFCD34D), bg: const Color(0xFFFFFBEB)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _detailsEnquiryRow(
            onDetails: () => _openRemartDetails(l),
            onEnquiry: () => startRemartEnquiry(context, l),
          ),
        ],
      )),
    );
  }

  void _openRemartDetails(RemartListing l) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => RemartListingDetailScreen(listing: l)));

  void _clearRemartFilters() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _remartCat = null;
      _rmSort = _Sort.newest;
      _rmCondition = null;
      _rmSeller = null;
      _rmNegotiable = false;
      _rmCity = '';
    });
  }

  Future<void> _openRemartFilters() async {
    var sort = _rmSort;
    String? condition = _rmCondition;
    String? seller = _rmSeller;
    var negotiable = _rmNegotiable;
    final cityCtrl = TextEditingController(text: _rmCity);

    const conditions = <(String?, String)>[
      (null, 'Any'),
      ('new', 'New'),
      ('like_new', 'Like new'),
      ('good', 'Good'),
      ('fair', 'Fair'),
      ('used', 'Used'),
    ];
    const sellers = <(String?, String)>[(null, 'Any'), ('individual', 'Individual'), ('business', 'Business')];

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget choice(String label, bool sel, VoidCallback onTap) => ChoiceChip(
            label: Text(label),
            selected: sel,
            showCheckmark: false,
            selectedColor: _HC.blue,
            backgroundColor: _HC.pillBg,
            side: BorderSide(color: sel ? _HC.blue : _HC.pillBorder),
            labelStyle: DT.text(size: 12.5, weight: FontWeight.w600, color: sel ? Colors.white : _HC.blueText),
            onSelected: (_) => onTap(),
          );
          Widget title(String t) => Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(t, style: DT.text(size: 12, weight: FontWeight.w700, color: DT.slate500)),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  children: [
                    Row(children: [
                      Text('Filters', style: DT.text(size: 18, weight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setSheet(() {
                          sort = _Sort.newest;
                          condition = null;
                          seller = null;
                          negotiable = false;
                          cityCtrl.clear();
                        }),
                        child: Text('Reset', style: DT.text(size: 13, weight: FontWeight.w700, color: _HC.blue)),
                      ),
                    ]),
                    title('Sort by'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      choice('Newest', sort == _Sort.newest, () => setSheet(() => sort = _Sort.newest)),
                      choice('Price: low → high', sort == _Sort.priceLow, () => setSheet(() => sort = _Sort.priceLow)),
                      choice('Price: high → low', sort == _Sort.priceHigh, () => setSheet(() => sort = _Sort.priceHigh)),
                    ]),
                    title('Condition'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (v, label) in conditions)
                        choice(label, condition == v, () => setSheet(() => condition = v)),
                    ]),
                    title('Seller'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (v, label) in sellers) choice(label, seller == v, () => setSheet(() => seller = v)),
                    ]),
                    title('City / area'),
                    TextField(
                      controller: cityCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Satara',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      value: negotiable,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.white,
                      activeTrackColor: _HC.blue,
                      title: Text('Negotiable price only', style: DT.text(size: 13.5, weight: FontWeight.w600)),
                      onChanged: (v) => setSheet(() => negotiable = v),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _kBrand, // buttons: only #093C71
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Color(0x40093C71), blurRadius: 12, offset: Offset(0, 4))],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Show items',
                              style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final city = cityCtrl.text.trim();
    cityCtrl.dispose();
    if (apply != true || !mounted) return;
    setState(() {
      _rmSort = sort;
      _rmCondition = condition;
      _rmSeller = seller;
      _rmNegotiable = negotiable;
      _rmCity = city;
    });
  }
}

// =====================================================================
// Pulsing amber "live" dot (Live Reels & Demos header)
// =====================================================================
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Color(0xFFF59E0B),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x66F59E0B), blurRadius: 6)],
        ),
      ),
    );
  }
}


// =====================================================================
// CHATBOT BUTTON (bottom right of Home)
//   • logo: lib/assets/images/Friendly AI Chatbot Badge.png, 56 x 56
//   • always moving while the screen is open: floats up/down, tilts a little,
//     soft glow pulses behind it
//   • hover (web / desktop): grows + stronger glow; press (mobile): shrinks a bit
// =====================================================================
class _ChatBotButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ChatBotButton({required this.onTap});

  @override
  State<_ChatBotButton> createState() => _ChatBotButtonState();
}

class _ChatBotButtonState extends State<_ChatBotButton> with SingleTickerProviderStateMixin {
  static const double _size = 56; // same size as the old chat icon button
  static const String _logo = 'lib/assets/images/Friendly AI Chatbot Badge.png';

  // One loop of 2.4 s drives float, tilt and glow (repeats forever).
  late final AnimationController _loop =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  bool _hover = false;
  bool _pressed = false;

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.92 : (_hover ? 1.14 : 1.0);
    return Tooltip(
      message: 'Chat with QNX Assistant',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: Semantics(
            button: true,
            label: 'Chat with QNX Assistant',
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, child) {
                  final t = _loop.value * 2 * math.pi;
                  final dy = -4 * math.sin(t); // float up / down 4 px
                  final tilt = 0.06 * math.sin(t * 2); // ~3.5° wobble
                  final glow = 0.5 + 0.5 * math.sin(t); // 0..1 pulse
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.rotate(
                      angle: _hover ? 0 : tilt,
                      child: Container(
                        width: _size,
                        height: _size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E5A9C)
                                  .withValues(alpha: _hover ? 0.55 : 0.25 + 0.25 * glow),
                              blurRadius: _hover ? 22 : 10 + 10 * glow,
                              spreadRadius: _hover ? 3 : 1 + 2 * glow,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  _logo,
                  width: _size,
                  height: _size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  // logo file missing -> old round chat button, app keeps working
                  errorBuilder: (_, __, ___) => Container(
                    width: _size,
                    height: _size,
                    decoration: const BoxDecoration(color: _HC.navy, shape: BoxShape.circle),
                    child: const Icon(Icons.chat_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

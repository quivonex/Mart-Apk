import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/product_card.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'order_screen.dart';
import 'products_screen.dart' as products;
import 'cart_screen.dart';
import 'account_screen.dart';
import 'loan_enquiry_screen.dart';
import 'properties_screen.dart';
import 'seller_profile_screen.dart';
import 'company_list_screen.dart';
import 'company_products_list_screen.dart';
import 'branch_list_screen.dart';
import 'subcategory_list_screen.dart';
import 'brand_list_screen.dart';
import 'unit_list_screen.dart';
import 'marketing_partner_enquiry_screen.dart';

// =====================================================================
// HOME SCREEN (tabs shell)
// =====================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final int _cartCount = 2; // TODO: bind to your cart state

  void _goToTab(int index) => setState(() => _currentIndex = index);

  Widget _screenFor(int index) {
    switch (index) {
      case 1:
        return const products.ProductsScreen();
      case 2:
        return const CartScreen();
      case 3:
        return const OrdersScreen();
      case 4:
        return const AccountScreen();
      default:
        return HomeContent(onBrowseProducts: () => _goToTab(1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: AppBarWidget(
        // On Home, the app bar blends into the sticky search header below it.
        showDivider: _currentIndex != 0,
        actions: [
          AppBarIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            showDot: true,
            onPressed: () {},
          ),
          const SizedBox(width: 2),
          AppBarIconButton(
            icon: Icons.shopping_cart_outlined,
            tooltip: 'Cart',
            badgeCount: _cartCount,
            onPressed: () => _goToTab(2),
          ),
        ],
      ),
      body: _screenFor(_currentIndex),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        cartCount: _cartCount,
        onTap: _goToTab,
      ),
    );
  }
}

// =====================================================================
// HOME CONTENT
// =====================================================================
class HomeContent extends StatefulWidget {
  /// Called by "Explore catalog" and "View all" to jump to the Products tab.
  final VoidCallback? onBrowseProducts;

  const HomeContent({super.key, this.onBrowseProducts});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
  String _selectedCategory = 'All';

  static const List<String> _categories = [
    'All',
    'Industrial & Tools',
    'Electronics',
    'Agriculture',
    'Raw Materials',
    'Packaging',
    'Franchise',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ProductService.getLatestApprovedProducts();
      if (!mounted) return;
      setState(() {
        _products = response.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStickyHeader(),
        Expanded(
          child: RefreshIndicator(
            color: DT.blue900,
            onRefresh: _loadProducts,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _buildHeroBanner(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 20),
                _buildBankingPartners(),
                const SizedBox(height: 20),
                _buildEnterpriseServices(),
                const SizedBox(height: 20),
                _buildLatestProductsSection(),
                const SizedBox(height: 20),
                _buildBulkQuotationBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =================================================================
  // STICKY HEADER: location, search, category chips
  // =================================================================
  Widget _buildStickyHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: DT.border)),
      ),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDeliveryLocation(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSearchBar(),
          ),
          const SizedBox(height: 12),
          _buildCategoryChips(),
        ],
      ),
    );
  }

  Widget _buildDeliveryLocation() {
    return InkWell(
      onTap: () {}, // TODO: open location picker
      borderRadius: BorderRadius.circular(DT.rSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: DT.blue700, size: 18),
            const SizedBox(width: 6),
            Text(
              'Deliver to:',
              style: DT.text(size: 12, weight: FontWeight.w500, color: DT.onyx700),
            ),
            const SizedBox(width: 4),
            Text(
              'Mumbai 400001',
              style: DT.text(size: 12, weight: FontWeight.w700, color: DT.onyx900),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, color: DT.onyx600, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: DT.slate100,
              borderRadius: BorderRadius.circular(DT.rLg),
              border: Border.all(color: DT.slate200),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: DT.onyx600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: DT.text(size: 13, weight: FontWeight.w500),
                    cursorColor: DT.blue700,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search products, services, suppliers...',
                      hintStyle: DT.text(
                        size: 12.5,
                        weight: FontWeight.w500,
                        color: DT.onyx600,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {}, // TODO: voice search
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.mic_none_rounded,
                        color: DT.onyx600, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: DT.slate100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rLg),
            side: const BorderSide(color: DT.slate200),
          ),
          child: InkWell(
            onTap: () {}, // TODO: open filters
            borderRadius: BorderRadius.circular(DT.rLg),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.tune_rounded, color: DT.onyx700, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = _categories[i];
          final selected = category == _selectedCategory;
          return InkWell(
            onTap: () => setState(() => _selectedCategory = category),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? DT.onyx900 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? DT.onyx900 : DT.slate200,
                ),
                boxShadow: DT.shadowXs,
              ),
              child: Text(
                category,
                style: DT.text(
                  size: 12,
                  weight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : DT.onyx700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =================================================================
  // HERO BANNER
  // =================================================================
  Widget _buildHeroBanner() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: DT.heroGradient,
        borderRadius: BorderRadius.circular(DT.rXl),
        boxShadow: DT.shadowM3,
      ),
      child: Stack(
        children: [
          // Soft decorative glows
          Positioned(
            right: -32,
            top: -32,
            child: _glow(144, const Color(0x333B82F6)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _glow(112, const Color(0x332DD4BF)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_outlined,
                          color: DT.emerald300, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'GST verified suppliers',
                        style: DT.text(
                          size: 11,
                          weight: FontWeight.w600,
                          color: DT.emerald300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Direct Factory B2B Sourcing',
                  style: DT.text(
                    size: 20,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    'Connect with verified manufacturers & get bulk contract pricing directly at source.',
                    style: DT.text(
                      size: 12,
                      weight: FontWeight.w500,
                      color: const Color(0xFFE2E8F0),
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DT.rMd),
                  elevation: 3,
                  shadowColor: const Color(0x40000000),
                  child: InkWell(
                    onTap: widget.onBrowseProducts,
                    borderRadius: BorderRadius.circular(DT.rMd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore catalog',
                            style: DT.text(
                              size: 12,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: DT.onyx900, size: 16),
                        ],
                      ),
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

  Widget _glow(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
        ),
      ),
    );
  }

  // =================================================================
  // QUICK ACTIONS
  // =================================================================
  Widget _buildQuickActions() {
    const primary = [
      _QuickAction(Icons.handshake_outlined, 'Marketing Partner',
          DT.indigo50, DT.indigo700, 'marketing_partner'),
      _QuickAction(Icons.storefront_outlined, 'Become a Seller', DT.amber50,
          DT.amber700, 'seller_profile'),
      _QuickAction(Icons.apartment_outlined, 'My Companies', DT.emerald50,
          DT.emerald700, 'company_list'),
      _QuickAction(Icons.inventory_2_outlined, 'My Products', DT.blue50,
          DT.blue700, 'company_products'),
    ];

    const secondary = [
      _QuickAction(Icons.store_outlined, 'Branches', DT.orange50, DT.amber800,
          'branch_list'),
      _QuickAction(Icons.category_outlined, 'Categories', DT.teal50,
          DT.teal800, 'subcategory_list'),
      _QuickAction(Icons.verified_user_outlined, 'Brands', DT.amber50,
          DT.amber900, 'brand_list'),
      _QuickAction(Icons.straighten_outlined, 'Units', DT.sky50, DT.sky800,
          'unit_list'),
      _QuickAction(Icons.mail_outline_rounded, 'Enquiries', DT.purple50,
          DT.purple800, 'product_enquiry'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.bolt_rounded,
          title: 'Quick Actions',
          trailing: Text(
            'Frequently used',
            style: DT.text(size: 11, weight: FontWeight.w500, color: DT.onyx600),
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(
              primary.map((a) => Expanded(child: _primaryTile(a))).toList(),
              10,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _spaced(
            secondary.map((a) => Expanded(child: _secondaryTile(a))).toList(),
            8,
          ),
        ),
      ],
    );
  }

  Widget _primaryTile(_QuickAction a) {
    return _TapCard(
      radius: DT.rLg,
      onTap: () => _handleQuickAction(a.route),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: a.bg,
              borderRadius: BorderRadius.circular(DT.rMd),
            ),
            child: Icon(a.icon, color: a.fg, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            a.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DT.text(
              size: 11,
              weight: FontWeight.w600,
              color: DT.onyx800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secondaryTile(_QuickAction a) {
    return _TapCard(
      radius: DT.rMd,
      onTap: () => _handleQuickAction(a.route),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: a.bg,
              borderRadius: BorderRadius.circular(DT.rSm),
            ),
            child: Icon(a.icon, color: a.fg, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            a.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: 10, weight: FontWeight.w500, color: DT.onyx700),
          ),
        ],
      ),
    );
  }

  void _handleQuickAction(String? route) {
    Widget? page;
    switch (route) {
      case 'marketing_partner':
        page = const MarketingPartnerEnquiryScreen();
        break;
      case 'seller_profile':
        page = const SellerProfileScreen();
        break;
      case 'company_list':
        page = const CompanyListScreen();
        break;
      case 'company_products':
        page = const CompanyProductsListScreen();
        break;
      case 'branch_list':
        page = const BranchListScreen();
        break;
      case 'subcategory_list':
        page = const SubCategoryListScreen();
        break;
      case 'brand_list':
        page = const BrandListScreen();
        break;
      case 'unit_list':
        page = const UnitListScreen();
        break;
      case 'loan_enquiry':
        page = const LoanEnquiryScreen();
        break;
      case 'properties':
        page = const PropertiesScreen();
        break;
      case 'product_enquiry':
        _showSnack('Open a product to send an enquiry');
        return;
      default:
        _showSnack('This section is coming soon');
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: DT.onyx900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
          ),
        ),
      );
  }

  // =================================================================
  // BANKING PARTNERS
  // =================================================================
  Widget _buildBankingPartners() {
    const partners = [
      _Bank('SBI', 'State Bank', 'e-Settlement', DT.blue100, DT.blue900),
      _Bank('HDFC', 'HDFC Bank', 'Working Cap', DT.amber100, DT.amber900),
      _Bank('ICICI', 'ICICI Bank', 'Trade Credit', DT.orange100, DT.orange900),
      _Bank('AXIS', 'Axis Bank', 'Escrow Pay', DT.purple50, DT.purple800),
      _Bank('BOB', 'Bank of Baroda', 'MSME Loan', DT.teal50, DT.teal800),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.account_balance_outlined,
          title: 'Trusted Banking Partners',
          subtitle: 'Financial settlement & business credit support',
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: _spaced(partners.map(_bankCard).toList(), 10),
          ),
        ),
      ],
    );
  }

  Widget _bankCard(_Bank b) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.border),
        boxShadow: DT.shadowXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: b.bg, shape: BoxShape.circle),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Text(
                  b.code,
                  style: DT.text(size: 10, weight: FontWeight.w800, color: b.fg),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.name,
                style: DT.text(
                  size: 12,
                  weight: FontWeight.w700,
                  color: DT.onyx900,
                  height: 1.2,
                ),
              ),
              Text(
                b.service,
                style: DT.text(size: 10, weight: FontWeight.w500, color: DT.onyx600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =================================================================
  // ENTERPRISE SERVICES
  // =================================================================
  Widget _buildEnterpriseServices() {
    const services = [
      _Service(
        Icons.account_balance_wallet_outlined,
        'Loan Enquiry',
        'Instant business & working capital credit',
        'Check limits',
        DT.blue50,
        DT.blue700,
        'loan_enquiry',
      ),
      _Service(
        Icons.domain_outlined,
        'Properties',
        'Explore verified real estate & warehouse listings',
        'Browse now',
        DT.indigo50,
        DT.indigo700,
        'properties',
      ),
      _Service(
        Icons.loyalty_outlined,
        'Marketing Partner',
        'Join our certified partner distribution program',
        'Apply now',
        DT.amber50,
        DT.amber700,
        'marketing_partner',
      ),
      _Service(
        Icons.corporate_fare_outlined,
        'Info Company',
        'Corporate profile, vision & compliance records',
        'Overview',
        DT.emerald50,
        DT.emerald700,
        null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.business_center_outlined,
          title: 'Enterprise Services',
          trailing: Text(
            'Self serve',
            style: DT.text(size: 12, weight: FontWeight.w600, color: DT.blue700),
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 150, // fixed height = no overflow
          ),
          itemBuilder: (context, i) => _serviceCard(services[i]),
        ),
      ],
    );
  }

  Widget _serviceCard(_Service s) {
    return _TapCard(
      radius: DT.rLg,
      onTap: () => _handleQuickAction(s.route),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: s.bg,
                  borderRadius: BorderRadius.circular(DT.rMd),
                ),
                child: Icon(s.icon, color: s.fg, size: 19),
              ),
              const SizedBox(height: 8),
              Text(
                s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: DT.onyx900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                s.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DT.text(
                  size: 10.5,
                  weight: FontWeight.w500,
                  color: DT.onyx600,
                  height: 1.35,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                s.action,
                style: DT.text(size: 11, weight: FontWeight.w700, color: DT.blue700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  color: DT.blue700, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  // =================================================================
  // LATEST PRODUCTS
  // =================================================================
  static const double _productCardWidth = 210;
  static const double _productRowHeight = 296;

  Widget _buildLatestProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.inventory_outlined,
          title: 'Latest Products',
          subtitle: 'Freshly listed, approved verified suppliers',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DT.amber100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'New',
                  style: DT.text(size: 10, weight: FontWeight.w700, color: DT.amber800),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: widget.onBrowseProducts,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View all',
                  style: DT.text(size: 12, weight: FontWeight.w700, color: DT.blue700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoading)
          _buildProductsSkeleton()
        else if (_error != null)
          _buildErrorWidget()
        else if (_products.isEmpty)
            _buildEmptyProducts()
          else
            SizedBox(
              height: _productRowHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: _products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: _productCardWidth,
                  child: ProductCard(product: _products[i]),
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildProductsSkeleton() {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(4),
      ),
    );

    return SizedBox(
      height: _productRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: _productCardWidth,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(color: DT.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: DT.slate100,
                    borderRadius: BorderRadius.circular(DT.rMd),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              bar(70, 10),
              const SizedBox(height: 6),
              bar(150, 12),
              const SizedBox(height: 6),
              bar(100, 10),
              const SizedBox(height: 8),
              bar(60, 14),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: bar(double.infinity, 32)),
                  const SizedBox(width: 6),
                  Expanded(child: bar(double.infinity, 32)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProducts() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: DT.slate400, size: 34),
          const SizedBox(height: 8),
          Text(
            'No new products yet',
            style: DT.text(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Browse the full catalog or pull down to refresh.',
            textAlign: TextAlign.center,
            style: DT.text(size: 11, weight: FontWeight.w500, color: DT.onyx600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DT.errorBg,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.errorBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: DT.error, size: 34),
          const SizedBox(height: 8),
          Text(
            "Couldn't load products",
            style: DT.text(size: 14, weight: FontWeight.w700, color: DT.error),
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: DT.text(size: 12, weight: FontWeight.w500, color: DT.onyx600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Try again',
              style: DT.text(size: 12, weight: FontWeight.w700, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DT.onyx900,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DT.rMd),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // BULK QUOTATION (RFQ)
  // =================================================================
  Widget _buildBulkQuotationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DT.rfqGradient,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.amber200),
        boxShadow: DT.shadowXs,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DT.amber100,
              borderRadius: BorderRadius.circular(DT.rMd),
            ),
            child: const Icon(Icons.edit_note_rounded,
                color: DT.amber800, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Need bulk custom quotation?',
                  style: DT.text(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: DT.onyx900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Receive multiple vendor bids within 4 hrs',
                  style: DT.text(
                    size: 11,
                    weight: FontWeight.w500,
                    color: DT.onyx700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: DT.amber600,
            borderRadius: BorderRadius.circular(DT.rMd),
            child: InkWell(
              onTap: () {}, // TODO: open RFQ form
              borderRadius: BorderRadius.circular(DT.rMd),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text(
                  'Post RFQ',
                  style: DT.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // HELPERS
  // =================================================================
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: DT.blue700, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(size: 14, weight: FontWeight.w700, height: 1.2),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 10.5, weight: FontWeight.w500, color: DT.onyx600),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

  /// Inserts fixed horizontal gaps between widgets.
  List<Widget> _spaced(List<Widget> items, double gap) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) result.add(SizedBox(width: gap));
      result.add(items[i]);
    }
    return result;
  }
}

// =====================================================================
// SMALL PRIVATE WIDGETS & DATA CLASSES
// =====================================================================

/// White bordered card with ink ripple.
class _TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;

  const _TapCard({
    required this.child,
    required this.radius,
    required this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(color: DT.borderSoft),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: DT.shadowXs,
      ),
      child: Material(
        color: Colors.white,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final String route;
  const _QuickAction(this.icon, this.label, this.bg, this.fg, this.route);
}

class _Bank {
  final String code;
  final String name;
  final String service;
  final Color bg;
  final Color fg;
  const _Bank(this.code, this.name, this.service, this.bg, this.fg);
}

class _Service {
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final Color bg;
  final Color fg;
  final String? route;
  const _Service(this.icon, this.title, this.subtitle, this.action, this.bg,
      this.fg, this.route);
}

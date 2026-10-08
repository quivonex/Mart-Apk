// lib/models/home_models.dart
//
// Data for the redesigned home screen.
//   HomeBanner      <- GET/POST accounts/banners/ {placement, section}
//   HomeCategory    <- product/category/all/  (deduped by name, active only)
//   Marketplace     the three top pills (QNXMart / Real Estate / QNXRemart)

enum Marketplace { shopping, realEstate, remart }

extension MarketplaceX on Marketplace {
  /// Value the banner API filters on (Banner.section).
  String get apiSection => switch (this) {
    Marketplace.shopping => 'shopping',
    Marketplace.realEstate => 'real_estate',
    Marketplace.remart => 'remart',
  };

  String get title => switch (this) {
    Marketplace.shopping => 'QNXMart — Shopping & Products',
    Marketplace.realEstate => 'Real Estate — Buy, Sell & Rent',
    Marketplace.remart => 'QNXRemart — Used & Resale',
  };

  String get shortTitle => switch (this) {
    Marketplace.shopping => 'QNXMart',
    Marketplace.realEstate => 'Real Estate',
    Marketplace.remart => 'QNXRemart',
  };
}

/// What happens when a banner is tapped (Banner.target on the backend).
enum BannerTarget { none, url, products, category, realEstate, remart, loan }

BannerTarget _target(String v) => switch (v) {
  'url' => BannerTarget.url,
  'products' => BannerTarget.products,
  'category' => BannerTarget.category,
  'real_estate' => BannerTarget.realEstate,
  'remart' => BannerTarget.remart,
  'loan' => BannerTarget.loan,
  _ => BannerTarget.none,
};

class HomeBanner {
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String placement; // home_hero | finance_partner
  final String section; // all | shopping | real_estate | remart
  final BannerTarget target;
  final String targetValue;

  HomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.placement,
    required this.section,
    required this.target,
    required this.targetValue,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> j) => HomeBanner(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    title: (j['title'] ?? '').toString(),
    subtitle: (j['subtitle'] ?? '').toString(),
    imageUrl: (j['image_url'] ?? '').toString(),
    placement: (j['placement'] ?? '').toString(),
    section: (j['section'] ?? 'all').toString(),
    target: _target((j['target'] ?? 'none').toString()),
    targetValue: (j['target_value'] ?? '').toString(),
  );
}

class HomeCategory {
  final String name;
  final int productCount;
  const HomeCategory(this.name, {this.productCount = 0});
}

class HomeResult<T> {
  final bool ok;
  final String? message;
  final T data;
  const HomeResult(this.data, {this.ok = true, this.message});
}
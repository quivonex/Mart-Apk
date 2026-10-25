// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QNX MART';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseLanguageHint =>
      'You can change it any time from Account → Language.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get languageChanged => 'Language changed';

  @override
  String get currentLanguage => 'English';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Try again';

  @override
  String get loading => 'Loading…';

  @override
  String get close => 'Close';

  @override
  String get newBadge => 'NEW';

  @override
  String get navHome => 'Home';

  @override
  String get navProducts => 'Products';

  @override
  String get navCart => 'Cart';

  @override
  String get navOrders => 'Orders';

  @override
  String get navAccount => 'Account';

  @override
  String navItemsBadge(String label, int count) {
    return '$label, $count items';
  }

  @override
  String get drawerHome => 'Home';

  @override
  String get drawerNearby => 'Nearby Search';

  @override
  String get drawerMyProfile => 'My Profile';

  @override
  String get drawerSellerProfile => 'Seller Profile';

  @override
  String get drawerMyChats => 'My Chats';

  @override
  String get drawerMyEnquiries => 'My Enquiries';

  @override
  String get drawerMySubscription => 'My Subscription';

  @override
  String get drawerTrending => 'Trending & Quick Links';

  @override
  String get drawerAllProducts => 'All Products';

  @override
  String drawerCart(int count) {
    return 'Cart ($count)';
  }

  @override
  String get drawerSell => 'Sell & Management';

  @override
  String get drawerAddCompany => 'Add Company';

  @override
  String get drawerAddProduct => 'Add Product';

  @override
  String get drawerAddBranch => 'Add Branch';

  @override
  String get drawerAddCategory => 'Add Category';

  @override
  String get drawerAddSubCategory => 'Add SubCategory';

  @override
  String get drawerAddBrand => 'Add Brand';

  @override
  String get drawerAddUnit => 'Add Unit';

  @override
  String get drawerProperty => 'Property';

  @override
  String get drawerAddProperty => 'Add Property';

  @override
  String get drawerAllProperties => 'All Properties';

  @override
  String get drawerMyProperties => 'My Properties';

  @override
  String get drawerRemart => 'QNX ReMart';

  @override
  String get drawerRemartAdd => 'Add Product';

  @override
  String get drawerRemartAll => 'All Products';

  @override
  String get drawerRemartMine => 'My Items';

  @override
  String get drawerHelp => 'Help & Support';

  @override
  String get drawerForBuying => 'For Buying';

  @override
  String get drawerForSelling => 'For Selling';

  @override
  String get drawerFaq => 'FAQ';

  @override
  String get drawerAboutUs => 'About Us';

  @override
  String get drawerContactUs => 'Contact Us';

  @override
  String get drawerLogout => 'Logout';

  @override
  String get drawerLoginRegister => 'Login / Register';

  @override
  String get drawerMyAccount => 'My Account';

  @override
  String get accMyActivity => 'My activity';

  @override
  String get accMyOrders => 'My orders';

  @override
  String get accMyOrdersSub => 'Track, cancel or return';

  @override
  String get accMyEnquiries => 'My enquiries';

  @override
  String get accMyEnquiriesSub => 'Product enquiries and their status';

  @override
  String get accMyProperties => 'My properties';

  @override
  String get accMyPropertiesSub => 'Listings, status and plans';

  @override
  String get accMyRemart => 'My ReMart items';

  @override
  String get accMyRemartSub => 'Items you sell and enquiries you sent';

  @override
  String get accMySubscription => 'My subscription';

  @override
  String get accBuyPlan => 'Buy a plan to enquire on properties';

  @override
  String accEnquiriesLeft(int count) {
    return '$count enquiries left';
  }

  @override
  String get accAccount => 'Account';

  @override
  String get accProfileDetails => 'Profile details';

  @override
  String get accProfileDetailsSub => 'Name, email and mobile';

  @override
  String get accSavedAddresses => 'Saved addresses';

  @override
  String get accSavedAddressesSub => 'Delivery addresses for checkout';

  @override
  String get accChangePassword => 'Change password';

  @override
  String get accChangePasswordSub => 'Reset with an OTP on your email';

  @override
  String get accSellerProfile => 'Seller profile';

  @override
  String get accSellerProfileSub => 'Register or update your store';

  @override
  String accLanguageSub(String name) {
    return 'App language: $name';
  }

  @override
  String get accHelp => 'Help & support';

  @override
  String get accHelpFaq => 'Help & FAQ';

  @override
  String get accHelpFaqSub => 'Answers to common questions';

  @override
  String get accContactUs => 'Contact us';

  @override
  String get accContactUsSub => 'Call, email or send a message';

  @override
  String get accTerms => 'Terms & privacy';

  @override
  String get accTermsSub => 'How we use your data';

  @override
  String get accLogout => 'Log out';

  @override
  String get accLogoutTitle => 'Log out?';

  @override
  String get accLogoutBody =>
      'You will need to log in again to use your cart, orders and enquiries.';

  @override
  String get accWelcome => 'Welcome to QNX Mart';

  @override
  String get accWelcomeSub =>
      'Log in to see your orders, enquiries, properties and more.';

  @override
  String get accLoginRegister => 'Log in / Register';

  @override
  String get accDefaultUser => 'QNX Mart user';

  @override
  String get accStatOrders => 'Orders';

  @override
  String get accStatEnquiriesLeft => 'Enquiries left';

  @override
  String get accStatSubscription => 'Subscription';

  @override
  String get accStatNone => 'None';

  @override
  String get accStatActive => 'Active';

  @override
  String get accName => 'Name';

  @override
  String get accEmail => 'Email';

  @override
  String get accMobile => 'Mobile';

  @override
  String get accUsername => 'Username';

  @override
  String get accCompany => 'Company';

  @override
  String get accGstin => 'GSTIN';

  @override
  String get accContactSupport =>
      'To change these details, contact QNX Mart support.';
}

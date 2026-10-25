import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'QNX MART'**
  String get appTitle;

  /// Language menu title
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language screen title
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// Language screen subtitle
  ///
  /// In en, this message translates to:
  /// **'You can change it any time from Account → Language.'**
  String get chooseLanguageHint;

  /// Continue button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Snackbar after change
  ///
  /// In en, this message translates to:
  /// **'Language changed'**
  String get languageChanged;

  /// Name of the current language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get currentLanguage;

  /// Common
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Common
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Common
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Common
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Common
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Small badge
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get newBadge;

  /// Bottom nav
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom nav
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// Bottom nav
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// Bottom nav
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// Bottom nav
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// Screen reader label
  ///
  /// In en, this message translates to:
  /// **'{label}, {count} items'**
  String navItemsBadge(String label, int count);

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get drawerHome;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Nearby Search'**
  String get drawerNearby;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get drawerMyProfile;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Seller Profile'**
  String get drawerSellerProfile;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'My Chats'**
  String get drawerMyChats;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'My Enquiries'**
  String get drawerMyEnquiries;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'My Subscription'**
  String get drawerMySubscription;

  /// Drawer section
  ///
  /// In en, this message translates to:
  /// **'Trending & Quick Links'**
  String get drawerTrending;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get drawerAllProducts;

  /// Drawer cart with count
  ///
  /// In en, this message translates to:
  /// **'Cart ({count})'**
  String drawerCart(int count);

  /// Drawer section
  ///
  /// In en, this message translates to:
  /// **'Sell & Management'**
  String get drawerSell;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add Company'**
  String get drawerAddCompany;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get drawerAddProduct;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add Branch'**
  String get drawerAddBranch;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get drawerAddCategory;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add SubCategory'**
  String get drawerAddSubCategory;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add Brand'**
  String get drawerAddBrand;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add Unit'**
  String get drawerAddUnit;

  /// Drawer section
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get drawerProperty;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Add Property'**
  String get drawerAddProperty;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'All Properties'**
  String get drawerAllProperties;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'My Properties'**
  String get drawerMyProperties;

  /// Drawer section
  ///
  /// In en, this message translates to:
  /// **'QNX ReMart'**
  String get drawerRemart;

  /// Drawer ReMart
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get drawerRemartAdd;

  /// Drawer ReMart
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get drawerRemartAll;

  /// Drawer ReMart
  ///
  /// In en, this message translates to:
  /// **'My Items'**
  String get drawerRemartMine;

  /// Drawer section
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get drawerHelp;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'For Buying'**
  String get drawerForBuying;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'For Selling'**
  String get drawerForSelling;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get drawerFaq;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get drawerAboutUs;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get drawerContactUs;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get drawerLogout;

  /// Drawer
  ///
  /// In en, this message translates to:
  /// **'Login / Register'**
  String get drawerLoginRegister;

  /// Drawer header
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get drawerMyAccount;

  /// Account section
  ///
  /// In en, this message translates to:
  /// **'My activity'**
  String get accMyActivity;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get accMyOrders;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Track, cancel or return'**
  String get accMyOrdersSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'My enquiries'**
  String get accMyEnquiries;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Product enquiries and their status'**
  String get accMyEnquiriesSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'My properties'**
  String get accMyProperties;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Listings, status and plans'**
  String get accMyPropertiesSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'My ReMart items'**
  String get accMyRemart;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Items you sell and enquiries you sent'**
  String get accMyRemartSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'My subscription'**
  String get accMySubscription;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Buy a plan to enquire on properties'**
  String get accBuyPlan;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'{count} enquiries left'**
  String accEnquiriesLeft(int count);

  /// Account section
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accAccount;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Profile details'**
  String get accProfileDetails;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Name, email and mobile'**
  String get accProfileDetailsSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get accSavedAddresses;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Delivery addresses for checkout'**
  String get accSavedAddressesSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accChangePassword;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Reset with an OTP on your email'**
  String get accChangePasswordSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Seller profile'**
  String get accSellerProfile;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Register or update your store'**
  String get accSellerProfileSub;

  /// Account language row
  ///
  /// In en, this message translates to:
  /// **'App language: {name}'**
  String accLanguageSub(String name);

  /// Account section
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get accHelp;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get accHelpFaq;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Answers to common questions'**
  String get accHelpFaqSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get accContactUs;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Call, email or send a message'**
  String get accContactUsSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Terms & privacy'**
  String get accTerms;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'How we use your data'**
  String get accTermsSub;

  /// Account
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accLogout;

  /// Logout dialog
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get accLogoutTitle;

  /// Logout dialog
  ///
  /// In en, this message translates to:
  /// **'You will need to log in again to use your cart, orders and enquiries.'**
  String get accLogoutBody;

  /// Guest card
  ///
  /// In en, this message translates to:
  /// **'Welcome to QNX Mart'**
  String get accWelcome;

  /// Guest card
  ///
  /// In en, this message translates to:
  /// **'Log in to see your orders, enquiries, properties and more.'**
  String get accWelcomeSub;

  /// Guest card
  ///
  /// In en, this message translates to:
  /// **'Log in / Register'**
  String get accLoginRegister;

  /// Profile card
  ///
  /// In en, this message translates to:
  /// **'QNX Mart user'**
  String get accDefaultUser;

  /// Stats
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get accStatOrders;

  /// Stats
  ///
  /// In en, this message translates to:
  /// **'Enquiries left'**
  String get accStatEnquiriesLeft;

  /// Stats
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get accStatSubscription;

  /// Stats
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get accStatNone;

  /// Stats
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accStatActive;

  /// Profile sheet
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accName;

  /// Profile sheet
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accEmail;

  /// Profile sheet
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get accMobile;

  /// Profile sheet
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get accUsername;

  /// Profile sheet
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get accCompany;

  /// Profile sheet
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get accGstin;

  /// Profile sheet
  ///
  /// In en, this message translates to:
  /// **'To change these details, contact QNX Mart support.'**
  String get accContactSupport;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

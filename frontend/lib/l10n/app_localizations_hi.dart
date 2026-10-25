// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'QNX MART';

  @override
  String get language => 'भाषा';

  @override
  String get chooseLanguage => 'अपनी भाषा चुनें';

  @override
  String get chooseLanguageHint => 'आप इसे कभी भी खाता → भाषा से बदल सकते हैं।';

  @override
  String get continueLabel => 'आगे बढ़ें';

  @override
  String get languageChanged => 'भाषा बदल दी गई';

  @override
  String get currentLanguage => 'हिंदी';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सेव करें';

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get loading => 'लोड हो रहा है…';

  @override
  String get close => 'बंद करें';

  @override
  String get newBadge => 'नया';

  @override
  String get navHome => 'होम';

  @override
  String get navProducts => 'उत्पाद';

  @override
  String get navCart => 'कार्ट';

  @override
  String get navOrders => 'ऑर्डर';

  @override
  String get navAccount => 'खाता';

  @override
  String navItemsBadge(String label, int count) {
    return '$label, $count आइटम';
  }

  @override
  String get drawerHome => 'होम';

  @override
  String get drawerNearby => 'आस-पास खोजें';

  @override
  String get drawerMyProfile => 'मेरी प्रोफ़ाइल';

  @override
  String get drawerSellerProfile => 'विक्रेता प्रोफ़ाइल';

  @override
  String get drawerMyChats => 'मेरी चैट';

  @override
  String get drawerMyEnquiries => 'मेरी पूछताछ';

  @override
  String get drawerMySubscription => 'मेरी सदस्यता';

  @override
  String get drawerTrending => 'ट्रेंडिंग और क्विक लिंक';

  @override
  String get drawerAllProducts => 'सभी उत्पाद';

  @override
  String drawerCart(int count) {
    return 'कार्ट ($count)';
  }

  @override
  String get drawerSell => 'बिक्री और प्रबंधन';

  @override
  String get drawerAddCompany => 'कंपनी जोड़ें';

  @override
  String get drawerAddProduct => 'उत्पाद जोड़ें';

  @override
  String get drawerAddBranch => 'शाखा जोड़ें';

  @override
  String get drawerAddCategory => 'श्रेणी जोड़ें';

  @override
  String get drawerAddSubCategory => 'उपश्रेणी जोड़ें';

  @override
  String get drawerAddBrand => 'ब्रांड जोड़ें';

  @override
  String get drawerAddUnit => 'यूनिट जोड़ें';

  @override
  String get drawerProperty => 'प्रॉपर्टी';

  @override
  String get drawerAddProperty => 'प्रॉपर्टी जोड़ें';

  @override
  String get drawerAllProperties => 'सभी प्रॉपर्टी';

  @override
  String get drawerMyProperties => 'मेरी प्रॉपर्टी';

  @override
  String get drawerRemart => 'QNX ReMart';

  @override
  String get drawerRemartAdd => 'सामान बेचें';

  @override
  String get drawerRemartAll => 'सभी सामान';

  @override
  String get drawerRemartMine => 'मेरे सामान';

  @override
  String get drawerHelp => 'सहायता और सपोर्ट';

  @override
  String get drawerForBuying => 'खरीदने के लिए';

  @override
  String get drawerForSelling => 'बेचने के लिए';

  @override
  String get drawerFaq => 'अक्सर पूछे जाने वाले प्रश्न';

  @override
  String get drawerAboutUs => 'हमारे बारे में';

  @override
  String get drawerContactUs => 'संपर्क करें';

  @override
  String get drawerLogout => 'लॉगआउट';

  @override
  String get drawerLoginRegister => 'लॉगिन / रजिस्टर';

  @override
  String get drawerMyAccount => 'मेरा खाता';

  @override
  String get accMyActivity => 'मेरी गतिविधि';

  @override
  String get accMyOrders => 'मेरे ऑर्डर';

  @override
  String get accMyOrdersSub => 'ट्रैक, रद्द या वापस करें';

  @override
  String get accMyEnquiries => 'मेरी पूछताछ';

  @override
  String get accMyEnquiriesSub => 'उत्पाद पूछताछ और उनकी स्थिति';

  @override
  String get accMyProperties => 'मेरी प्रॉपर्टी';

  @override
  String get accMyPropertiesSub => 'लिस्टिंग, स्थिति और प्लान';

  @override
  String get accMyRemart => 'मेरे ReMart सामान';

  @override
  String get accMyRemartSub => 'आपके बेचे जा रहे सामान और भेजी गई पूछताछ';

  @override
  String get accMySubscription => 'मेरी सदस्यता';

  @override
  String get accBuyPlan => 'प्रॉपर्टी पूछताछ के लिए प्लान लें';

  @override
  String accEnquiriesLeft(int count) {
    return '$count पूछताछ बाकी';
  }

  @override
  String get accAccount => 'खाता';

  @override
  String get accProfileDetails => 'प्रोफ़ाइल विवरण';

  @override
  String get accProfileDetailsSub => 'नाम, ईमेल और मोबाइल';

  @override
  String get accSavedAddresses => 'सेव किए गए पते';

  @override
  String get accSavedAddressesSub => 'चेकआउट के लिए डिलीवरी पते';

  @override
  String get accChangePassword => 'पासवर्ड बदलें';

  @override
  String get accChangePasswordSub => 'ईमेल पर OTP से रीसेट करें';

  @override
  String get accSellerProfile => 'विक्रेता प्रोफ़ाइल';

  @override
  String get accSellerProfileSub => 'अपना स्टोर रजिस्टर या अपडेट करें';

  @override
  String accLanguageSub(String name) {
    return 'ऐप की भाषा: $name';
  }

  @override
  String get accHelp => 'सहायता और सपोर्ट';

  @override
  String get accHelpFaq => 'सहायता और FAQ';

  @override
  String get accHelpFaqSub => 'सामान्य प्रश्नों के उत्तर';

  @override
  String get accContactUs => 'संपर्क करें';

  @override
  String get accContactUsSub => 'कॉल, ईमेल या संदेश भेजें';

  @override
  String get accTerms => 'नियम और गोपनीयता';

  @override
  String get accTermsSub => 'हम आपका डेटा कैसे उपयोग करते हैं';

  @override
  String get accLogout => 'लॉग आउट';

  @override
  String get accLogoutTitle => 'लॉग आउट करें?';

  @override
  String get accLogoutBody =>
      'कार्ट, ऑर्डर और पूछताछ के लिए फिर से लॉगिन करना होगा।';

  @override
  String get accWelcome => 'QNX Mart में आपका स्वागत है';

  @override
  String get accWelcomeSub =>
      'अपने ऑर्डर, पूछताछ, प्रॉपर्टी और बहुत कुछ देखने के लिए लॉगिन करें।';

  @override
  String get accLoginRegister => 'लॉगिन / रजिस्टर';

  @override
  String get accDefaultUser => 'QNX Mart उपयोगकर्ता';

  @override
  String get accStatOrders => 'ऑर्डर';

  @override
  String get accStatEnquiriesLeft => 'पूछताछ बाकी';

  @override
  String get accStatSubscription => 'सदस्यता';

  @override
  String get accStatNone => 'नहीं';

  @override
  String get accStatActive => 'सक्रिय';

  @override
  String get accName => 'नाम';

  @override
  String get accEmail => 'ईमेल';

  @override
  String get accMobile => 'मोबाइल';

  @override
  String get accUsername => 'यूज़रनेम';

  @override
  String get accCompany => 'कंपनी';

  @override
  String get accGstin => 'GSTIN';

  @override
  String get accContactSupport =>
      'ये विवरण बदलने के लिए QNX Mart सपोर्ट से संपर्क करें।';
}

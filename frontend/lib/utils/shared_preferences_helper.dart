import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHelper {
  static const String _accessTokenKey  = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey       = 'user_id';
  static const String _usernameKey     = 'username';
  static const String _userEmailKey    = 'user_email';
  static const String _userAddressKey  = 'user_address';
  static const String _isLoggedInKey   = 'is_logged_in';

  // 🆕 New keys
  static const String _gstNumberKey    = 'gst_number';
  static const String _companyNameKey  = 'company_name';

  // ─────────────────────────────────────────────
  // Save login data
  // ─────────────────────────────────────────────
  static Future<void> saveLoginData({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String username,
    required String email,
    required String address,
    String? gstNumber,        // 🆕 optional
    String? companyName,      // 🆕 optional
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userAddressKey, address);
    await prefs.setBool(_isLoggedInKey, true);

    // 🆕 Save GST & Company Name (if provided)
    if (gstNumber != null && gstNumber.isNotEmpty) {
      await prefs.setString(_gstNumberKey, gstNumber);
    }
    if (companyName != null && companyName.isNotEmpty) {
      await prefs.setString(_companyNameKey, companyName);
    }
  }

  // ─────────────────────────────────────────────
  // Get access token
  // ─────────────────────────────────────────────
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Get user ID
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  // Get username
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // Get user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Get user address
  static Future<String?> getUserAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userAddressKey);
  }

  // 🆕 Get GST number
  static Future<String?> getGstNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gstNumberKey);
  }

  // 🆕 Get Company Name
  static Future<String?> getCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyNameKey);
  }

  // 🆕 Save GST number separately (for edit profile)
  static Future<void> saveGstNumber(String gst) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gstNumberKey, gst);
  }

  // 🆕 Save Company Name separately (for edit profile)
  static Future<void> saveCompanyName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyNameKey, name);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // ─────────────────────────────────────────────
  // Clear all data (logout)
  // ─────────────────────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userAddressKey);
    await prefs.remove(_gstNumberKey);       // 🆕
    await prefs.remove(_companyNameKey);     // 🆕
    await prefs.setBool(_isLoggedInKey, false);
  }

  // Save access token (for refreshing)
  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }
}
class ApiUrls {
  // Base URL - Change this to your actual server IP

  static const String baseUrl = 'http://192.168.31.247:16000';
 // static const String baseUrl = "https://api.qnxmartb2b.com";

  // Auth Endpoints
  static const String login = '/accounts/login/';
  static const String sendOtp = '/accounts/send-otp/';
  static const String verifyOtp = '/accounts/verify-otp/';
  static const String register = '/accounts/register/';

  // Forgot Password Endpoints
  static const String forgotPasswordSendOtp = '/accounts/forgot-password/send-otp/';
  static const String forgotPasswordVerifyOtp = '/accounts/forgot-password/verify-otp/';
  static const String forgotPasswordReset = '/accounts/forgot-password/reset/';

  // Product Endpoints
  static const String latestApprovedProducts = '/product/products/latest-approved/';
  static const String approvedProductList = '/product/product/approved-list/';
  // ✅ Product Enquiry Endpoints (NEW)
  static const String productEnquiry = '/enquiry/product-enquiry/';

  // Cart Endpoints
  static const String addToCart = '/cart/cart/add/';
  static const String getCartList = '/cart/cart/list/';
  static const String updateCartQuantity = '/cart/cart/update/';
  static const String removeFromCart = '/cart/cart/delete/';

  // Loan Enquiry Endpoints
  static const String createLoanEnquiry = '/loan/loan-enquiry/create/';

  //  Franchise Endpoints (NEW)
  static const String productFranchisePlans = '/franchicies/product-franchise-plans/';
  static const String franchiseCreate = '/franchicies/franchise/create/';

  // Order Endpoints
  static const String myOrders = '/shiprocket/my-orders/';
  static const String myOrderDetail = '/shiprocket/my-order-detail/';
  static const String cancelOrder = '/shiprocket/cancel-order/';
  static const String trackShipment = '/shiprocket/track-shipment/';
  static const String returnOrder = '/shiprocket/return-order/';

  // ✅ Real Estate Endpoints (NEW)
  static const String approvedProperties = '/real_estate/properties/approved/';
  static const String propertyDetail = '/real_estate/properties/detail/';
  static const String amenitiesList = '/real_estate/amenities/list/';
  static const String createPropertyEnquiry = '/real_estate/create/enquiry/';  // ✅ NEW

  // ✅ Seller Endpoints (NEW)
  static const String sellerList = '/seller/seller/list/';
  static const String sellerCreate = '/seller/seller/create/';
  static const String sellerUpdate = '/seller/seller/update/';

  // ✅ Company Endpoints (NEW)
  static const String companyList = '/company/company/list/';
  static const String companyCreate = '/company/company/create/';
  static const String companyUpdate = '/company/company/update/';
  static const String companyPaymentOrder = '/company/create-company-payment-order/';
  static const String companyVerifyPayment = '/company/verify-payment/';

  // ✅ Company Product Endpoints (NEW)
  static const String companyProductsList = '/product/company/products-list/';
  static const String companyProductCreate = '/product/api/products/create/';
  static const String companyProductUpdate = '/product/company/product/update-request/';

  // ✅ Branch Endpoints (NEW)
  static const String companyNames = '/company/company/names/';
  static const String branchList = '/branch/company/branches-list/';
  static const String branchCreate = '/branch/branch/create/';
  static const String branchUpdate = '/branch/branch/update/';
  static const String branchSoftDelete = '/branch/branch/soft-delete/';
  static const String branchRestore = '/branch/branch/restore/';

  // ✅ Sub Category Endpoints (NEW)
  static const String categoryAll = '/product/category/all/';
  static const String subcategoryList = '/product/subcategory/by-user/list/';
  static const String subcategoryCreate = '/product/subcategory/create/';
  static const String subcategoryUpdate = '/product/subcategory/update/';
  static const String subcategorySoftDelete = '/product/subcategory/soft-delete/';
  static const String subcategoryRestore = '/product/subcategory/restore/';

  // ✅ Brand Endpoints (NEW)
  //static const String categoryAll = '/product/category/all/';
  static const String subcategoryByCategory = '/product/subcategory/by-category/';
  static const String brandList = '/product/brand/list/';
  static const String brandCreate = '/product/api/brands/create/';
  static const String brandUpdate = '/product/api/brands/update/';
  static const String brandSoftDelete = '/product/brand/soft-delete/';
  static const String brandRestore = '/product/brand/restore/';

  // ✅ Unit Endpoints (NEW)
  static const String unitList = '/product/unit/list/';
  static const String unitCreate = '/product/unit/create/';
  static const String unitUpdate = '/product/unit/update/';
  static const String unitSoftDelete = '/product/unit/soft-delete/';
  static const String unitRestore = '/product/unit/restore/';

  // ... existing code ...
  // ✅ Location Endpoints (NEW)
  static const String stateRetrieveAll = '/state/state_retrieveAll/';
  static const String getDistricts = '/state/get_districts/';
  static const String getTalukas = '/state/get_talukas/';
  static const String getVillages = '/state/get_villages/';

  // Marketing Partner Enquiry Endpoint
  static const String createMarketingPartnerEnquiry = '/enquiry/marketing-partner/create/';


  // Full URL getters
  static String get loginUrl => '$baseUrl$login';
  static String get sendOtpUrl => '$baseUrl$sendOtp';
  static String get verifyOtpUrl => '$baseUrl$verifyOtp';
  static String get registerUrl => '$baseUrl$register';
  static String get forgotPasswordSendOtpUrl => '$baseUrl$forgotPasswordSendOtp';
  static String get forgotPasswordVerifyOtpUrl => '$baseUrl$forgotPasswordVerifyOtp';
  static String get forgotPasswordResetUrl => '$baseUrl$forgotPasswordReset';
  static String get latestApprovedProductsUrl => '$baseUrl$latestApprovedProducts';
  static String get approvedProductListUrl => '$baseUrl$approvedProductList';
  static String get addToCartUrl => '$baseUrl$addToCart';
  static String get getCartListUrl => '$baseUrl$getCartList';
  static String get updateCartQuantityUrl => '$baseUrl$updateCartQuantity';
  static String get removeFromCartUrl => '$baseUrl$removeFromCart';
  static String get createLoanEnquiryUrl => '$baseUrl$createLoanEnquiry';
  static String get productFranchisePlansUrl => '$baseUrl$productFranchisePlans';
  static String get franchiseCreateUrl => '$baseUrl$franchiseCreate';
  static String get productEnquiryUrl => '$baseUrl$productEnquiry';
  static String get myOrdersUrl => '$baseUrl$myOrders';
  static String get myOrderDetailUrl => '$baseUrl$myOrderDetail';
  static String get cancelOrderUrl => '$baseUrl$cancelOrder';
  static String get trackShipmentUrl => '$baseUrl$trackShipment';
  static String get returnOrderUrl => '$baseUrl$returnOrder';
  static String get approvedPropertiesUrl => '$baseUrl$approvedProperties';
  static String get propertyDetailUrl => '$baseUrl$propertyDetail';
  static String get amenitiesListUrl => '$baseUrl$amenitiesList';
  static String get createPropertyEnquiryUrl => '$baseUrl$createPropertyEnquiry';  // ✅ NEW
  static String get sellerListUrl => '$baseUrl$sellerList';
  static String get sellerCreateUrl => '$baseUrl$sellerCreate';
  static String get sellerUpdateUrl => '$baseUrl$sellerUpdate';
  static String get companyListUrl => '$baseUrl$companyList';
  static String get companyCreateUrl => '$baseUrl$companyCreate';
  static String get companyUpdateUrl => '$baseUrl$companyUpdate';
  static String get companyPaymentOrderUrl => '$baseUrl$companyPaymentOrder';
  static String get companyVerifyPaymentUrl => '$baseUrl$companyVerifyPayment';
  static String get companyProductsListUrl => '$baseUrl$companyProductsList';
  static String get companyProductCreateUrl => '$baseUrl$companyProductCreate';
  static String get companyProductUpdateUrl => '$baseUrl$companyProductUpdate';
  static String get companyNamesUrl => '$baseUrl$companyNames';
  static String get branchListUrl => '$baseUrl$branchList';
  static String get branchCreateUrl => '$baseUrl$branchCreate';
  static String get branchUpdateUrl => '$baseUrl$branchUpdate';
  static String get branchSoftDeleteUrl => '$baseUrl$branchSoftDelete';
  static String get branchRestoreUrl => '$baseUrl$branchRestore';
  static String get categoryAllUrl => '$baseUrl$categoryAll';
  static String get subcategoryListUrl => '$baseUrl$subcategoryList';
  static String get subcategoryCreateUrl => '$baseUrl$subcategoryCreate';
  static String get subcategoryUpdateUrl => '$baseUrl$subcategoryUpdate';
  static String get subcategorySoftDeleteUrl => '$baseUrl$subcategorySoftDelete';
  static String get subcategoryRestoreUrl => '$baseUrl$subcategoryRestore';
  //static String get categoryAllUrl => '$baseUrl$categoryAll';
  static String get subcategoryByCategoryUrl => '$baseUrl$subcategoryByCategory';
  static String get brandListUrl => '$baseUrl$brandList';
  static String get brandCreateUrl => '$baseUrl$brandCreate';
  static String get brandUpdateUrl => '$baseUrl$brandUpdate';
  static String get brandSoftDeleteUrl => '$baseUrl$brandSoftDelete';
  static String get brandRestoreUrl => '$baseUrl$brandRestore';
  static String get unitListUrl => '$baseUrl$unitList';
  static String get unitCreateUrl => '$baseUrl$unitCreate';
  static String get unitUpdateUrl => '$baseUrl$unitUpdate';
  static String get unitSoftDeleteUrl => '$baseUrl$unitSoftDelete';
  static String get unitRestoreUrl => '$baseUrl$unitRestore';
  // Add getters
  static String get stateRetrieveAllUrl => '$baseUrl$stateRetrieveAll';
  static String get getDistrictsUrl => '$baseUrl$getDistricts';
  static String get getTalukasUrl => '$baseUrl$getTalukas';
  static String get getVillagesUrl => '$baseUrl$getVillages';
  static String get createMarketingPartnerEnquiryUrl => '$baseUrl$createMarketingPartnerEnquiry';
}
class ApiUrls {
  // Base URL - Change this to your actual server IP

      static const String baseUrl = 'http://192.168.31.7:16000';
  //  static const String baseUrl = "https://api.qnxmartb2b.com";

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
  static const String removeFromCart = '/cart/cart/delete/';
  // No cart update API on the backend – quantity +/- uses addToCart with +1 / -1.

  // Loan Enquiry Endpoints
  static const String createLoanEnquiry = '/loan/loan-enquiry/create/';

  //  Franchise Endpoints (NEW)
  static const String productFranchisePlans = '/franchicies/product-franchise-plans/';
  static const String franchiseCreate = '/franchicies/franchise/create/';

  // Order Endpoints
  static const String myOrders = '/shipping/my-orders/';
  static const String myOrderDetail = '/shipping/my-order-detail/';
  static const String cancelOrder = '/shipping/cancel-order/';
  static const String trackShipment = '/shipping/track-shipment/';
  static const String returnOrder = '/shipping/return-order/';

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
  static const String companyDetail = '/company/company/single-retrieve/';
  static const String companySoftDelete = '/company/company/soft-delete/';
  static const String companyRestore = '/company/company/restore/';
  static const String companyStock = '/company/company/stock/';
  static const String companyLowStock = '/company/company/low-stock/';

  // ✅ Supplier Endpoints (NEW)
  static const String supplierList = '/company/suppliers/list/';
  static const String supplierCreate = '/company/suppliers/create/';
  static const String supplierUpdate = '/company/suppliers/update/';
  static const String supplierDelete = '/company/supplier/delete/';

  // ✅ S3 bucket for raw *_s3_key values (e.g. low-stock thumbnails).
  // Set this to your AWS_S3_CUSTOM_DOMAIN from backend settings.py:
  //   https://<AWS_STORAGE_BUCKET_NAME>.s3.amazonaws.com
  static const String s3BaseUrl = 'https://YOUR_BUCKET_NAME.s3.amazonaws.com';

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
// ✅ Admin uploaded images (home carousel)
  static const String adminImageList = '/admin_profile/upload_image_list/';

  static const String aiChat = '/AI/chat/';
  static const String aiConversations = '/AI/conversations/';
  static const String aiMessages = '/AI/messages/';


  // ✅ Nearby Search + its subscription (login token required)
  static const String nearbyPlaces = '/admin_profile/places/nearby/';
  static const String nearbySubscriptionPlans = '/admin_profile/subscription-plans/list/';
  static const String nearbySubscriptionCreateOrder = '/admin_profile/subscription/create-order/';
  static const String nearbySubscriptionVerify = '/admin_profile/subscription/verify-payment/';

  // ✅ Chat (buyer ↔ seller / agent) – shared by Product, Property and ReMart detail
  static const String chatCreate = '/olx/chats/create/';
  static const String chats = '/olx/chats/';
  static const String remartListingDetail = '/olx/listings/detail/';

  // ✅ QNX ReMart Communication Plan (chat / enquiry limits)
  static const String commPlans = '/olx/bazaar-communication-plans/list/';
  static const String commCreateOrder = '/payment/bazaar-communication/create-order/';
  static const String commVerifyPayment = '/payment/bazaar-communication/verify-payment/';
  static const String commMySubscriptions = '/olx/bazaar-communication-subscriptions/my/';
  static const String commChatUsage = '/olx/bazaar-communication-usage/chat/';
  static const String commEnquiryUsage = '/olx/bazaar-communication-usage/enquiry/';

  // ✅ Customer Subscription (property enquiries – My Subscription)
  static const String customerSubscriptionPlans = '/payment/customer-subscription-plans/';
  static const String customerMySubscriptions = '/payment/customer-subscriptions/my/';
  static const String customerSubscriptionCreateOrder = '/payment/customer-subscription/create-order/';
  static const String customerSubscriptionVerify = '/payment/customer-subscription/verify-payment/';







  // ✅ Product search (server side, saves search history when logged in)
  static const String productSearch = '/product/product/search/';

  // ✅ Edit my ReMart listing / my property (multipart, images add + delete)
  static const String remartListingUpdate = '/olx/listings/update/';
  static const String remartMyListings = '/olx/my-listings/';
  static const String propertyUpdate = '/real_estate/property-update/';

  // ✅ Orders extras
  static const String orderInvoice = '/shipping/download-invoice/';
  static const String returnOrders = '/shipping/return-orders/';
  static const String returnOrderTrack = '/shipping/return-order/track/';
  static const String addressUpdate = '/order/address/update/';

  // ✅ ReMart chat plan extras
  static const String commPaymentHistory = '/payment/bazaar-communication/history/';
  static const String commSubscriptionDetail = '/olx/bazaar-communication-subscriptions/detail/';

  // ✅ Offer discount filters (home filter sheet)
  static const String offerFilterOptions = '/offer/offers/filter-options/';

  // ✅ Instagram reels: list = my reels (login), list-all = all active reels (home)
  static const String instagramReels = '/accounts/instagram-reel/list/';
  static const String instagramReelsAll = '/accounts/instagram-reel/list-all/';

  // ✅ Language: backend text translation (product / property / ReMart names)
  //   POST {texts:[...], target:'mr'|'hi'} -> {translations:[...]}
  static const String translateTexts = '/accounts/translate/';

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
  static String get companyDetailUrl => '$baseUrl$companyDetail';
  static String get companySoftDeleteUrl => '$baseUrl$companySoftDelete';
  static String get companyRestoreUrl => '$baseUrl$companyRestore';
  static String get companyStockUrl => '$baseUrl$companyStock';
  static String get companyLowStockUrl => '$baseUrl$companyLowStock';
  static String get supplierListUrl => '$baseUrl$supplierList';
  static String get supplierCreateUrl => '$baseUrl$supplierCreate';
  static String get supplierUpdateUrl => '$baseUrl$supplierUpdate';
  static String get supplierDeleteUrl => '$baseUrl$supplierDelete';
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

  static String get adminImageListUrl => '$baseUrl$adminImageList';


  // AI Assistant
  static String get aiChatUrl => '$baseUrl$aiChat';
  static String get aiConversationsUrl => '$baseUrl$aiConversations';
  static String aiConversationUrl(String id) => '$baseUrl$aiConversations$id/';
  static String aiMessageFeedbackUrl(String messageId) => '$baseUrl$aiMessages$messageId/feedback/';


  // Nearby Search + subscription
  static String get nearbyPlacesUrl => '$baseUrl$nearbyPlaces';
  static String get nearbySubscriptionPlansUrl => '$baseUrl$nearbySubscriptionPlans';
  static String get nearbySubscriptionCreateOrderUrl => '$baseUrl$nearbySubscriptionCreateOrder';
  static String get nearbySubscriptionVerifyUrl => '$baseUrl$nearbySubscriptionVerify';


  // Chat
  static String get chatCreateUrl => '$baseUrl$chatCreate';
  static String get chatsUrl => '$baseUrl$chats';
  static String get remartListingDetailUrl => '$baseUrl$remartListingDetail';
  static String chatMessagesUrl(int chatId, {int page = 1, int pageSize = 100}) =>
      '$baseUrl$chats$chatId/messages/?page=$page&page_size=$pageSize';
  static String chatSendUrl(int chatId) => '$baseUrl$chats$chatId/messages/send/';
  static String chatOffersUrl(int chatId) => '$baseUrl$chats$chatId/offers/';
  static String chatOfferRespondUrl(int chatId, int messageId) =>
      '$baseUrl$chats$chatId/offers/$messageId/respond/';
  static String chatReadUrl(int chatId) => '$baseUrl$chats$chatId/read/';



  // Communication Plan
  static String get commPlansUrl => '$baseUrl$commPlans';
  static String get commCreateOrderUrl => '$baseUrl$commCreateOrder';
  static String get commVerifyPaymentUrl => '$baseUrl$commVerifyPayment';
  static String get commMySubscriptionsUrl => '$baseUrl$commMySubscriptions';
  static String get commChatUsageUrl => '$baseUrl$commChatUsage';
  static String get commEnquiryUsageUrl => '$baseUrl$commEnquiryUsage';

  // Customer Subscription (My Subscription)
  static String get customerSubscriptionPlansUrl => '$baseUrl$customerSubscriptionPlans';
  static String get customerMySubscriptionsUrl => '$baseUrl$customerMySubscriptions';
  static String get customerSubscriptionCreateOrderUrl => '$baseUrl$customerSubscriptionCreateOrder';
  static String get customerSubscriptionVerifyUrl => '$baseUrl$customerSubscriptionVerify';

  // Product search
  static String get productSearchUrl => '$baseUrl$productSearch';

  // Edit listing / property
  static String get remartListingUpdateUrl => '$baseUrl$remartListingUpdate';
  static String get remartMyListingsUrl => '$baseUrl$remartMyListings';
  static String get propertyUpdateUrl => '$baseUrl$propertyUpdate';

  // Orders extras
  static String get orderInvoiceUrl => '$baseUrl$orderInvoice';
  static String get returnOrdersUrl => '$baseUrl$returnOrders';
  static String get returnOrderTrackUrl => '$baseUrl$returnOrderTrack';
  static String get addressUpdateUrl => '$baseUrl$addressUpdate';

  // Chat plan extras
  static String get commPaymentHistoryUrl => '$baseUrl$commPaymentHistory';
  static String get commSubscriptionDetailUrl => '$baseUrl$commSubscriptionDetail';

  // Offers
  static String get offerFilterOptionsUrl => '$baseUrl$offerFilterOptions';

  // Instagram reels
  static String get instagramReelsUrl => '$baseUrl$instagramReels';
  static String get instagramReelsAllUrl => '$baseUrl$instagramReelsAll';
}

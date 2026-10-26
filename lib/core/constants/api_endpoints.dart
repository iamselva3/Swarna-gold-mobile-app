/// Customer-facing backend routes (Express, mounted under /api/client).
///
/// Every path here was checked against the backend route files; the backend
/// identifies the customer from the bearer token, never from a client field.
class ApiEndpoints {
  ApiEndpoints._();

  // Authentication (public)
  static const String login = '/api/client/customer/login';
  static const String signup = '/api/client/customer/signup';
  static const String generateOtp = '/api/client/customer/generate-otp';
  static const String verifyOtp = '/api/client/customer/verify-otp';
  static const String forgotPassword = '/api/client/customer/forgot-password';

  // Customer (owner only)
  static String customer(String id) => '/api/client/customer/$id';

  // Metal rates (public)
  static String todayRates(String branchId) => '/api/client/metalrate/today-rate/branchId/$branchId';
  static String previousRates(String branchId) => '/api/client/metalrate/current-previous/$branchId';

  // Schemes (public)
  static const String schemes = '/api/client/scheme';
  static String scheme(String id) => '/api/client/scheme/$id';
  static const String digiGoldScheme = '/api/client/scheme/digigold/10';

  // Scheme accounts and payments (customer token)
  static const String myAccounts = '/api/client/schemeaccount/mobile/schemeaccounts';
  static const String openAccount = '/api/client/schemeaccount';
  static String accountPayments(String accountId) => '/api/client/payment/schemeaccount/$accountId';
  static const String createOrder = '/api/client/payment/mobile/create-order';
  static const String digiGoldOrder = '/api/client/payment/mobile/digi-payment';
  static const String paymentStatus = '/api/client/payment/mobile/payment-status';

  // Wallet (customer token)
  static const String wallet = '/api/client/wallet';
  static const String walletHistory = '/api/client/wallet/history';
  static const String walletRate = '/api/client/wallet/get-rate';
}

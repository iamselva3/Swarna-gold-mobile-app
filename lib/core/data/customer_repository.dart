import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../utils/formatters.dart';
import 'models.dart';

/// Every read and write the customer app performs. All data comes from the
/// backend; when a call fails the [ApiException] propagates to the screen,
/// which shows an error with a retry — nothing is substituted or simulated.
class CustomerRepository {
  CustomerRepository(this._api);

  final ApiClient _api;

  // ── Authentication ─────────────────────────────────────────────────────────

  /// Returns the access token. The backend expects the mobile as a number.
  Future<String> signIn({required String mobile, required String password}) async {
    final res = await _api.post(ApiEndpoints.login,
        data: {'mobile': int.parse(mobile), 'password': password}, auth: false);
    final token = Parse.text(res['token']);
    if (token.isEmpty) {
      throw const ApiException('Sign-in did not return a session. Please try again.', kind: ApiFailure.server);
    }
    return token;
  }

  /// Sends a WhatsApp registration OTP to the customer's mobile number.
  Future<({String message, bool isDemo, String? demoOtp})> requestSignupOtp(String mobile) async {
    final cleanDigits = mobile.replaceAll(RegExp(r'\D'), '');
    final cleanMobile = cleanDigits.length > 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
    final res = await _api.post(
      ApiEndpoints.generateOtp,
      data: {'mobile': int.parse(cleanMobile), 'type': 'signup'},
      auth: false,
    );
    final message = Parse.text(res['message'], 'OTP sent via WhatsApp.');
    final isDemo = res['isDemo'] == true;
    final demoOtp = res['demoOtp']?.toString();
    return (message: message, isDemo: isDemo, demoOtp: demoOtp);
  }

  /// Verifies the 6-digit WhatsApp OTP entered during signup.
  Future<void> verifySignupOtp({required String mobile, required String otp}) async {
    final cleanDigits = mobile.replaceAll(RegExp(r'\D'), '');
    final cleanMobile = cleanDigits.length > 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
    await _api.post(
      ApiEndpoints.verifyOtp,
      data: {'mobile': int.parse(cleanMobile), 'otp': otp.trim(), 'type': 'signup'},
      auth: false,
    );
  }

  /// Registers a new customer on the backend and returns the active JWT session token.
  Future<String> signupCustomer({
    required String firstname,
    required String mobile,
    required String password,
    String? mpin,
    String? idBranch,
    String? email,
  }) async {
    final cleanDigits = mobile.replaceAll(RegExp(r'\D'), '');
    final cleanMobile = cleanDigits.length > 10 ? cleanDigits.substring(cleanDigits.length - 10) : cleanDigits;
    final res = await _api.post(
      ApiEndpoints.signup,
      data: {
        'firstname': firstname.trim(),
        'mobile': int.parse(cleanMobile),
        'password': password,
        'mpin': mpin ?? '1234',
        if (idBranch != null) 'id_branch': idBranch,
        if (email != null && email.isNotEmpty) 'email': email.trim(),
      },
      auth: false,
    );
    final token = Parse.text(res['token']);
    if (token.isEmpty) {
      // Fallback sign-in to retrieve token
      return signIn(mobile: cleanMobile, password: password);
    }
    return token;
  }

  /// Sends a password-reset OTP by SMS.
  Future<String> requestPasswordResetOtp(String mobile) async {
    final res = await _api.post(ApiEndpoints.generateOtp,
        data: {'mobile': int.parse(mobile), 'type': 'forgotpassword'}, auth: false);
    return Parse.text(res['message'], 'OTP sent.');
  }

  Future<void> verifyPasswordResetOtp({required String mobile, required String otp}) async {
    await _api.post(ApiEndpoints.verifyOtp,
        data: {'mobile': int.parse(mobile), 'otp': otp, 'type': 'forgotpassword'}, auth: false);
  }

  /// Sets a new password. The backend only accepts this after the OTP for
  /// this mobile has been verified.
  Future<String> resetPassword({required String mobile, required String password}) async {
    final res = await _api.post(ApiEndpoints.forgotPassword,
        data: {'mobile': int.parse(mobile), 'password': password}, auth: false);
    return Parse.text(res['message'], 'Password updated.');
  }

  // ── Customer ───────────────────────────────────────────────────────────────

  Future<CustomerProfile> fetchProfile(String customerId) async {
    final res = await _api.get(ApiEndpoints.customer(customerId));
    return CustomerProfile.fromJson(Parse.map(res['data']));
  }

  // ── Rates ──────────────────────────────────────────────────────────────────

  Future<RateBoard> fetchRates(String branchId) async {
    final results = await Future.wait([
      _api.get(ApiEndpoints.todayRates(branchId), auth: false),
      // The comparison is optional: if it fails, today's board still shows.
      _api.get(ApiEndpoints.previousRates(branchId), auth: false).catchError((_) => <String, dynamic>{}),
    ]);
    final today = Parse.list(results[0]['data']).map(MetalRate.fromJson).where((r) => r.rate > 0).toList();
    final previous = <String, double>{};
    for (final row in Parse.list(results[1]['data'])) {
      final purity = Parse.id(row['purity_id']);
      final rate = Parse.number(row['rate']);
      if (purity != null && rate > 0) previous[purity] = rate;
    }
    final board = today.map((r) => r.withPrevious(previous[r.purityId])).toList()
      ..sort((a, b) {
        if (a.isGold != b.isGold) return a.isGold ? -1 : 1;
        return b.purity.compareTo(a.purity);
      });
    return RateBoard(board);
  }

  // ── Plans ──────────────────────────────────────────────────────────────────

  Future<List<SchemeSummary>> fetchSchemes() async {
    final res = await _api.get(ApiEndpoints.schemes, auth: false);
    return Parse.list(res['data']).map(SchemeSummary.fromJson).toList();
  }

  Future<SchemeDetail> fetchScheme(String id) async {
    final res = await _api.get(ApiEndpoints.scheme(id), auth: false);
    return SchemeDetail.fromJson(Parse.map(res['data']));
  }

  /// The digital-gold plan configured by the jeweller, or null if none is active.
  Future<SchemeDetail?> fetchDigiGoldScheme() async {
    final res = await _api.get(ApiEndpoints.digiGoldScheme, auth: false);
    final rows = Parse.list(res['data']);
    if (rows.isEmpty) return null;
    return SchemeDetail.fromJson(rows.first);
  }

  /// Opens an instalment account. The backend binds it to the signed-in
  /// customer and their branch; the payload mirrors the admin form.
  Future<String> openAccount({
    required SchemeDetail scheme,
    required String customerId,
    required String branchId,
    required String accountName,
    double? committedAmount,
  }) async {
    final payload = <String, dynamic>{
      'id_scheme': scheme.id,
      'id_classification': scheme.classificationId,
      'id_customer': customerId,
      'id_branch': branchId,
      'account_name': accountName,
      'total_installments': scheme.totalInstallments,
      'maturity_period': scheme.maturityPeriod,
      'platform': 'android',
      // Explicitly "no referral": the backend refuses a missing value for
      // customers who were referred when they registered.
      'referral_id': null,
      if (scheme.commitsToAmount && committedAmount != null) 'flexFixed': committedAmount,
    };
    final res = await _api.post(ApiEndpoints.openAccount, data: payload);
    return Parse.text(res['message'], 'Account opened.');
  }

  // ── Holdings ───────────────────────────────────────────────────────────────

  Future<Holdings> fetchHoldings() async {
    final res = await _api.get(ApiEndpoints.myAccounts);
    return Holdings.fromJson(Parse.map(res['data']));
  }

  Future<List<PaymentRecord>> fetchPayments(String accountId) async {
    final res = await _api.get(ApiEndpoints.accountPayments(accountId));
    final list = Parse.list(res['data']).map(PaymentRecord.fromJson).toList()
      ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return list;
  }

  // ── Payments ───────────────────────────────────────────────────────────────

  /// Creates a gateway order for one instalment. Nothing is credited until the
  /// gateway reports the order as PAID (see [isOrderPaid]).
  Future<PaymentOrder> createInstallmentOrder({
    required String accountId,
    required double amount,
    required double convenienceFee,
  }) async {
    final res = await _api.post(ApiEndpoints.createOrder, data: {
      'schemes': [
        {'id_scheme_account': accountId, 'amount': amount, 'convenience_fee': convenienceFee},
      ],
      'grandTotal': _round(amount + convenienceFee),
      'totalConvenience': convenienceFee,
      'platform': 'android',
    });
    return _order(res);
  }

  /// Creates a gateway order for a digital-gold purchase at today's rate.
  Future<PaymentOrder> createDigiGoldOrder({
    required SchemeDetail scheme,
    required double amount,
    required double metalRate,
    required double convenienceFee,
  }) async {
    final res = await _api.post(ApiEndpoints.digiGoldOrder, data: {
      'idScheme': scheme.id,
      'idClassification': scheme.classificationId,
      'amount': amount,
      'metal_rate': metalRate,
      'convenienceFee': convenienceFee,
      'grandTotal': _round(amount + convenienceFee),
      'platform': 'android',
      'schemeType': scheme.schemeType,
    });
    return _order(res);
  }

  /// Asks the backend, which asks the gateway, whether the order is PAID.
  Future<bool> isOrderPaid(String orderId) async {
    final res = await _api.get(ApiEndpoints.paymentStatus, query: {'orderid': orderId});
    return res['paymentStatus'] == true;
  }

  PaymentOrder _order(Map<String, dynamic> res) {
    final data = Parse.map(res['data']);
    final orderId = Parse.text(data['orderId']);
    final session = Parse.text(data['session']);
    // The backend still answers 201 when the gateway refused the order; without
    // a payment session there is nothing the customer can pay.
    if (orderId.isEmpty || session.isEmpty) {
      throw const ApiException(
        'The payment gateway is not available right now. You have not been charged — please try again later.',
        kind: ApiFailure.server,
      );
    }
    return PaymentOrder(orderId: orderId, sessionId: session);
  }

  static double _round(double v) => double.parse(v.toStringAsFixed(2));

  // ── Wallet ─────────────────────────────────────────────────────────────────

  /// Null when the customer has no rewards wallet yet.
  Future<Wallet?> fetchWallet() async {
    final res = await _api.get(ApiEndpoints.wallet);
    final data = res['data'];
    if (data is! Map) return null;
    return Wallet.fromJson(Map<String, dynamic>.from(data));
  }

  /// Store redemptions against the customer's wallet, newest first.
  Future<List<WalletEntry>> fetchWalletHistory(String walletId) async {
    try {
      final res = await _api.get(ApiEndpoints.walletHistory, query: {'id': walletId, 'page': 1, 'limit': 50});
      final data = res['data'];
      final rows = data is Map ? Parse.list(data['history'] ?? data['data']) : Parse.list(data);
      return rows.map(WalletEntry.fromJson).toList();
    } on ApiException catch (e) {
      // "No wallet found" is an empty history, not an error.
      if (e.kind == ApiFailure.rejected && e.message.toLowerCase().contains('no wallet')) return const [];
      rethrow;
    }
  }

  Future<WalletRate?> fetchWalletRate() async {
    final res = await _api.get(ApiEndpoints.walletRate);
    final data = res['data'];
    return data is Map ? WalletRate.fromJson(Map<String, dynamic>.from(data)) : null;
  }
}

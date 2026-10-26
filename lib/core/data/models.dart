import '../utils/formatters.dart';

/// Joins the backend's upload base path with a stored file name.
String? _asset(String? base, dynamic file) {
  final name = Parse.text(file);
  if (name.isEmpty) return null;
  if (name.startsWith('http')) return name;
  if (base == null || base.isEmpty) return null;
  return base.endsWith('/') ? '$base$name' : '$base/$name';
}

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.mobile,
    this.email,
    this.whatsapp,
    this.address,
    this.pincode,
    this.branchName,
    this.city,
    this.state,
    this.photoUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String mobile;
  final String? email;
  final String? whatsapp;
  final String? address;
  final String? pincode;
  final String? branchName;
  final String? city;
  final String? state;
  final String? photoUrl;

  String get fullName => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final v = '$a$b'.toUpperCase();
    return v.isEmpty ? '•' : v;
  }

  factory CustomerProfile.fromJson(Map<String, dynamic> j) {
    String? opt(dynamic v) {
      final s = Parse.text(v);
      return s.isEmpty ? null : s;
    }

    return CustomerProfile(
      id: Parse.text(j['_id']),
      firstName: Parse.text(j['firstname']),
      lastName: Parse.text(j['lastname']),
      mobile: Parse.text(j['mobile']),
      email: opt(j['email']),
      whatsapp: opt(j['whatsapp']),
      address: opt(j['address']),
      pincode: opt(j['pincode']),
      branchName: opt(Parse.map(j['branchDetails'])['branch_name']),
      city: opt(Parse.map(j['cityDetails'])['city_name']),
      state: opt(Parse.map(j['stateDetails'])['state_name']),
      photoUrl: _asset(Parse.text(j['pathurl']), j['cus_img']),
    );
  }
}

class MetalRate {
  const MetalRate({
    required this.metal,
    required this.purity,
    required this.purityId,
    required this.rate,
    this.previousRate,
    this.updatedAt,
  });

  final String metal;
  final String purity;
  final String? purityId;
  final double rate;
  final double? previousRate;
  final DateTime? updatedAt;

  bool get isGold => metal.toLowerCase().contains('gold');

  String get label => '$purity $metal';

  double? get change => previousRate == null ? null : rate - previousRate!;

  MetalRate withPrevious(double? previous) => MetalRate(
      metal: metal, purity: purity, purityId: purityId, rate: rate, previousRate: previous, updatedAt: updatedAt);

  factory MetalRate.fromJson(Map<String, dynamic> j) {
    final purity = Parse.map(j['purity_id']);
    final metal = Parse.map(j['material_type_id']);
    return MetalRate(
      metal: Parse.text(metal['metal_name'], 'Metal'),
      purity: Parse.text(purity['purity_name']),
      purityId: Parse.id(j['purity_id']),
      rate: Parse.number(j['rate']),
      updatedAt: Parse.date(j['updatedAt'] ?? j['createdAt']),
    );
  }
}

/// Today's board for the customer's branch, gold first, highest purity first.
class RateBoard {
  const RateBoard(this.rates);

  final List<MetalRate> rates;

  bool get isEmpty => rates.isEmpty;

  /// The rate customers buy digital gold at (24K, else the first gold rate).
  MetalRate? get primaryGold {
    final gold = rates.where((r) => r.isGold).toList();
    if (gold.isEmpty) return null;
    return gold.firstWhere((r) => r.purity.contains('24'), orElse: () => gold.first);
  }

  MetalRate? forPurity(String? purityId) {
    if (purityId == null) return null;
    for (final r in rates) {
      if (r.purityId == purityId) return r;
    }
    return null;
  }

  DateTime? get updatedAt {
    DateTime? latest;
    for (final r in rates) {
      if (r.updatedAt != null && (latest == null || r.updatedAt!.isAfter(latest))) latest = r.updatedAt;
    }
    return latest;
  }
}

class SchemeSummary {
  const SchemeSummary({required this.id, required this.name, required this.schemeType, this.logoUrl});

  final String id;
  final String name;
  final int schemeType;
  final String? logoUrl;

  /// Digital gold (10) and digital silver (14) are bought from the Buy flow,
  /// not enrolled into like an instalment plan.
  bool get isDigital => schemeType == 10 || schemeType == 14;

  factory SchemeSummary.fromJson(Map<String, dynamic> j) => SchemeSummary(
        id: Parse.text(j['_id']),
        name: Parse.text(j['scheme_name'], 'Savings plan'),
        schemeType: Parse.integer(j['scheme_type']),
        logoUrl: _asset(Parse.text(j['pathurl']), j['logo']),
      );
}

class SchemeDetail {
  const SchemeDetail({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.terms,
    required this.classificationId,
    required this.classificationName,
    required this.classificationOrder,
    required this.metal,
    required this.purity,
    required this.purityId,
    required this.schemeType,
    required this.installmentType,
    required this.totalInstallments,
    required this.minAmount,
    required this.maxAmount,
    required this.fixedAmounts,
    required this.minWeight,
    required this.maxWeight,
    required this.maturityPeriod,
    required this.convenienceFeePercent,
    required this.active,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String code;
  final String description;
  final String terms;
  final String? classificationId;
  final String classificationName;
  final int classificationOrder;
  final String metal;
  final String purity;
  final String? purityId;
  final int schemeType;
  final int installmentType;
  final int totalInstallments;
  final double minAmount;
  final double maxAmount;
  final List<double> fixedAmounts;
  final double minWeight;
  final double maxWeight;
  final int maturityPeriod;
  final double convenienceFeePercent;
  final bool active;
  final String? imageUrl;

  bool get isDigital => schemeType == 10 || schemeType == 14;

  /// Weight-denominated plans (scheme types 3, 4 and 12 in the admin) are
  /// opened at the branch, where the weight commitment is recorded by staff.
  bool get isWeightBased => const {3, 4, 12}.contains(schemeType);

  /// Classification order 2/3 (Fixed / Fixed-flexi) commit to one amount per
  /// instalment, stored as `flexFixed` on the account.
  bool get commitsToAmount => classificationOrder == 2 || classificationOrder == 3;

  String get frequency => switch (installmentType) { 1 => 'Monthly', 2 => 'Weekly', 3 => 'Daily', _ => 'Periodic' };

  double convenienceFeeFor(double amount) =>
      convenienceFeePercent <= 0 ? 0 : double.parse((amount * convenienceFeePercent / 100).toStringAsFixed(2));

  factory SchemeDetail.fromJson(Map<String, dynamic> j) {
    final classification = Parse.map(j['id_classification']);
    final metal = Parse.map(j['id_metal']);
    final purity = Parse.map(j['id_purity']);
    final fixed = (j['fixed_amounts'] is List ? j['fixed_amounts'] as List : const [])
        .map(Parse.number)
        .where((v) => v > 0)
        .toList();
    return SchemeDetail(
      id: Parse.text(j['_id']),
      name: Parse.text(j['scheme_name'], 'Savings plan').trim(),
      code: Parse.text(j['code']),
      description: Parse.text(j['description'] is List ? '' : j['description']),
      terms: Parse.text(j['term_desc']),
      classificationId: Parse.id(j['id_classification']),
      classificationName: Parse.text(classification['name']),
      classificationOrder: Parse.integer(classification['order']),
      metal: Parse.text(metal['metal_name'], 'Gold'),
      purity: Parse.text(purity['purity_name']),
      purityId: Parse.id(j['id_purity']),
      schemeType: Parse.integer(j['scheme_type']),
      installmentType: Parse.integer(j['installment_type'], 1),
      totalInstallments: Parse.integer(j['total_installments']),
      minAmount: Parse.number(j['min_amount']),
      maxAmount: Parse.number(j['max_amount']),
      fixedAmounts: fixed,
      minWeight: Parse.number(j['min_weight']),
      maxWeight: Parse.number(j['max_weight']),
      maturityPeriod: Parse.integer(j['maturity_period']),
      convenienceFeePercent: Parse.number(j['convenience_fees']),
      active: j['active'] != false,
      imageUrl: _asset(Parse.text(j['pathurl']), j['desc_img'] ?? j['logo']),
    );
  }
}

class SchemeAccount {
  const SchemeAccount({
    required this.id,
    required this.accountNumber,
    required this.accountName,
    required this.schemeName,
    required this.schemeType,
    required this.statusLabel,
    required this.status,
    required this.active,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.overdueInstallments,
    required this.totalPaidAmount,
    required this.totalPaidWeight,
    required this.monthlyPayable,
    required this.minAmount,
    required this.maxAmount,
    required this.averageRate,
    this.startDate,
    this.maturityDate,
    this.nextDueDate,
  });

  final String id;
  final String accountNumber;
  final String accountName;
  final String schemeName;
  final int schemeType;
  final String statusLabel;
  final int status;
  final bool active;
  final int totalInstallments;
  final int paidInstallments;
  final int overdueInstallments;
  final double totalPaidAmount;
  final double totalPaidWeight;
  final double monthlyPayable;
  final double minAmount;
  final double maxAmount;
  final double averageRate;
  final DateTime? startDate;
  final DateTime? maturityDate;
  final DateTime? nextDueDate;

  bool get isDigital => schemeType == 10 || schemeType == 14;

  /// Open accounts (status 0) accept payments; closed/completed ones do not.
  bool get isOpen => status == 0;

  double get progress => totalInstallments <= 0 ? 0 : (paidInstallments / totalInstallments).clamp(0, 1).toDouble();

  int get remainingInstallments => (totalInstallments - paidInstallments).clamp(0, totalInstallments);

  factory SchemeAccount.fromJson(Map<String, dynamic> j) => SchemeAccount(
        id: Parse.text(j['_id']),
        accountNumber: Parse.text(j['scheme_acc_number'], 'Pending'),
        accountName: Parse.text(j['account_name']),
        schemeName: Parse.text(j['schemeName'], 'Savings plan').trim(),
        schemeType: Parse.integer(j['schemeType']),
        statusLabel: Parse.text(j['schemestatusName'], Parse.integer(j['status']) == 0 ? 'Active' : 'Closed'),
        status: Parse.integer(j['status']),
        active: j['active'] != false,
        totalInstallments: Parse.integer(j['total_installments']),
        paidInstallments: Parse.integer(j['total_paid_installments'] ?? j['paymentcount']),
        overdueInstallments: Parse.integer(j['overdueInstallments']),
        totalPaidAmount: Parse.number(j['total_paid_amount']),
        totalPaidWeight: Parse.number(j['total_paid_weight']),
        monthlyPayable: Parse.number(j['monthlyPayable'] ?? j['flexFixed']),
        minAmount: Parse.number(j['minAmount']),
        maxAmount: Parse.number(j['maxAmount']),
        averageRate: Parse.number(j['avgMetalRate']),
        startDate: Parse.date(j['startDate']),
        maturityDate: Parse.date(j['maturity_date']),
        nextDueDate: Parse.date(j['nextDueDate']),
      );
}

class Holdings {
  const Holdings({required this.accounts, required this.totalPaid, required this.totalWeight, required this.installments});

  final List<SchemeAccount> accounts;
  final double totalPaid;
  final double totalWeight;
  final int installments;

  List<SchemeAccount> get openAccounts => accounts.where((a) => a.isOpen).toList();

  factory Holdings.fromJson(Map<String, dynamic> data) {
    final accounts = Parse.list(data['schemeAccounts']).map(SchemeAccount.fromJson).toList();
    final summary = Parse.list(data['summary']);
    final s = summary.isEmpty ? const <String, dynamic>{} : summary.first;
    return Holdings(
      accounts: accounts,
      totalPaid: Parse.number(s['total_paid_amount']),
      totalWeight: Parse.number(s['total_paid_weight']),
      installments: Parse.integer(s['total_paid_installments']),
    );
  }
}

enum PaymentState { paid, pending, failed, other }

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.receipt,
    required this.transactionId,
    required this.amount,
    required this.metalRate,
    required this.weight,
    required this.state,
    required this.mode,
    required this.installment,
    this.date,
  });

  final String id;
  final String receipt;
  final String transactionId;
  final double amount;
  final double metalRate;
  final double weight;
  final PaymentState state;
  final String mode;
  final int installment;
  final DateTime? date;

  factory PaymentRecord.fromJson(Map<String, dynamic> j) {
    final status = Parse.integer(j['payment_status'], -1);
    return PaymentRecord(
      id: Parse.text(j['_id']),
      receipt: Parse.text(j['payment_receipt']),
      transactionId: Parse.text(j['id_transaction']),
      amount: Parse.number(j['payment_amount'] ?? j['total_amt']),
      metalRate: Parse.number(j['metal_rate']),
      weight: Parse.number(j['metal_weight']),
      state: switch (status) { 1 => PaymentState.paid, 2 => PaymentState.pending, 3 || 4 => PaymentState.failed, _ => PaymentState.other },
      mode: Parse.text(j['paymentModeName'], Parse.integer(j['payment_type']) == 2 ? 'Online' : 'Store'),
      installment: Parse.integer(j['installment'] ?? j['paid_installments']),
      date: Parse.date(j['date_payment'] ?? j['payment_date'] ?? j['createdAt']),
    );
  }
}

/// A Cashfree order created by the backend for this customer.
class PaymentOrder {
  const PaymentOrder({required this.orderId, required this.sessionId});

  final String orderId;
  final String sessionId;
}

class Wallet {
  const Wallet({required this.id, required this.earned, required this.redeemed, required this.balance});

  final String id;
  final double earned;
  final double redeemed;
  final double balance;

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        id: Parse.text(j['_id']),
        earned: Parse.number(j['total_reward_amt']),
        redeemed: Parse.number(j['redeem_amt']),
        balance: Parse.number(j['balance_amt']),
      );
}

class WalletEntry {
  const WalletEntry({required this.amount, required this.description, this.date, this.billNo});

  final double amount;
  final String description;
  final DateTime? date;
  final String? billNo;

  bool get isCredit => amount >= 0;

  factory WalletEntry.fromJson(Map<String, dynamic> j) {
    final amount = Parse.number(j['credited_amount']);
    final bill = Parse.text(j['bill_no']);
    return WalletEntry(
      amount: amount,
      description: Parse.text(j['description'] ?? j['remark'], amount >= 0 ? 'Reward credited' : 'Redeemed at store'),
      date: Parse.date(j['createdAt'] ?? j['create_date'] ?? j['date_add']),
      billNo: bill.isEmpty ? null : bill,
    );
  }
}

class WalletRate {
  const WalletRate({required this.rupeesPerPoint, required this.points});

  final double rupeesPerPoint;
  final double points;

  factory WalletRate.fromJson(Map<String, dynamic> j) =>
      WalletRate(rupeesPerPoint: Parse.number(j['rupee_per_points']), points: Parse.number(j['points'], 1));
}

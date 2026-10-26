import 'package:flutter_customer_app/core/data/models.dart';
import 'package:flutter_customer_app/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

// Shapes below are trimmed copies of real responses from the local backend.
void main() {
  test('Holdings parses /schemeaccount/mobile/schemeaccounts', () {
    final holdings = Holdings.fromJson({
      'schemeAccounts': [
        {
          '_id': '6ad8532792a31467f6520ad2',
          'total_installments': 10,
          'scheme_acc_number': 'FX00082800',
          'account_name': 'Demo Customer',
          'maturity_date': '21-09-2027',
          'paymentcount': 1,
          'active': true,
          'nextDueDate': '2026-11-21T05:52:30.915Z',
          'total_paid_amount': 2000,
          'total_paid_weight': 0.261,
          'schemestatusName': 'Open',
          'schemeName': 'Swarna Fixed 08',
          'schemeType': 1,
          'total_paid_installments': 1,
          'status': 0,
          'minAmount': 1000,
          'maxAmount': 3000,
          'monthlyPayable': 2000,
          'startDate': '2026-10-21T05:52:30.915Z',
          'overdueInstallments': 0,
          'avgMetalRate': 7650,
        },
      ],
      'summary': [
        {'total_paid_installments': 1, 'total_paid_amount': 2000, 'total_paid_weight': 0.261},
      ],
    });

    expect(holdings.totalPaid, 2000);
    expect(holdings.totalWeight, closeTo(0.261, 1e-9));
    final account = holdings.accounts.single;
    expect(account.accountNumber, 'FX00082800');
    expect(account.isOpen, isTrue);
    expect(account.progress, closeTo(0.1, 1e-9));
    expect(account.remainingInstallments, 9);
    expect(account.maturityDate, DateTime(2027, 9, 21));
    expect(holdings.openAccounts, hasLength(1));
  });

  test('Holdings tolerates a customer with no accounts', () {
    final holdings = Holdings.fromJson({'schemeAccounts': [], 'summary': []});
    expect(holdings.accounts, isEmpty);
    expect(holdings.totalPaid, 0);
  });

  test('SchemeDetail parses classification, fixed amounts and fee', () {
    final scheme = SchemeDetail.fromJson({
      '_id': '6ad751dc0a784051d6af06df',
      'scheme_name': 'Swarna Fixed 08',
      'code': 'FX0008',
      'description': 'Pay 11 monthly instalments and get the 12th free.',
      'id_classification': {'_id': '6ad751ace17bfce5f572daa0', 'name': 'Fixed', 'order': 2},
      'id_metal': {'_id': 'm1', 'metal_name': 'Gold'},
      'id_purity': {'_id': 'p24', 'purity_name': '24K'},
      'scheme_type': 1,
      'installment_type': 1,
      'total_installments': 10,
      'min_amount': 1000,
      'max_amount': 3000,
      'fixed_amounts': [1000, 1500, 2000, 2500, 3000],
      'maturity_period': 11,
      'convenience_fees': 2,
    });

    expect(scheme.classificationId, '6ad751ace17bfce5f572daa0');
    expect(scheme.commitsToAmount, isTrue);
    expect(scheme.fixedAmounts, [1000, 1500, 2000, 2500, 3000]);
    expect(scheme.purityId, 'p24');
    expect(scheme.frequency, 'Monthly');
    expect(scheme.convenienceFeeFor(1500), 30);
    expect(scheme.isDigital, isFalse);
  });

  test('RateBoard picks 24K gold as the buying rate and computes change', () {
    final rate = MetalRate.fromJson({
      'purity_id': {'_id': 'p24', 'purity_name': '24K'},
      'material_type_id': {'metal_name': 'Gold'},
      'rate': 7650,
      'updatedAt': '2026-10-20T13:42:32.354Z',
    }).withPrevious(7450);
    final silver = MetalRate.fromJson({
      'purity_id': {'_id': 'ps', 'purity_name': '999'},
      'material_type_id': {'metal_name': 'Silver'},
      'rate': 95,
    });
    final board = RateBoard([silver, rate]);

    expect(board.primaryGold?.purityId, 'p24');
    expect(board.primaryGold?.change, 200);
    expect(board.forPurity('ps')?.rate, 95);
  });

  test('PaymentRecord maps backend payment status codes', () {
    final paid = PaymentRecord.fromJson({'payment_status': 1, 'payment_amount': 2000, 'metal_weight': 0.261});
    final pending = PaymentRecord.fromJson({'payment_status': 2, 'payment_amount': 500});
    expect(paid.state, PaymentState.paid);
    expect(pending.state, PaymentState.pending);
  });

  test('formatters use Indian grouping and gram precision', () {
    expect(Fmt.money(123456.5), '₹1,23,456.50');
    expect(Fmt.grams(0.2614), '0.261 g');
    expect(Fmt.maskedMobile('9000000001'), '90••••0001');
    expect(Parse.date('21-09-2027'), DateTime(2027, 9, 21));
    expect(Parse.number('12.5'), 12.5);
    expect(Parse.text(null, '—'), '—');
  });
}

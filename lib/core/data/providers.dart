import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/session.dart';
import '../network/api_client.dart';
import 'models.dart';

/// Screen data. Each provider watches [sessionProvider], so everything is
/// discarded on sign-out and re-fetched for the next customer.
/// Refresh with `ref.invalidate(provider)` (pull-to-refresh, retry buttons).

final profileProvider = FutureProvider<CustomerProfile>((ref) {
  final session = _requireSession(ref);
  return ref.watch(repositoryProvider).fetchProfile(session.customerId);
});

final ratesProvider = FutureProvider<RateBoard>((ref) {
  final session = _requireSession(ref);
  final branch = session.branchId;
  if (branch == null || branch.isEmpty) {
    throw const ApiException('Your account is not linked to a branch, so live rates are unavailable.',
        kind: ApiFailure.rejected);
  }
  return ref.watch(repositoryProvider).fetchRates(branch);
});

final holdingsProvider = FutureProvider<Holdings>((ref) {
  _requireSession(ref);
  return ref.watch(repositoryProvider).fetchHoldings();
});

final paymentsProvider = FutureProvider.autoDispose.family<List<PaymentRecord>, String>((ref, accountId) {
  _requireSession(ref);
  return ref.watch(repositoryProvider).fetchPayments(accountId);
});

final schemesProvider = FutureProvider<List<SchemeSummary>>((ref) {
  _requireSession(ref);
  return ref.watch(repositoryProvider).fetchSchemes();
});

final schemeDetailProvider = FutureProvider.autoDispose.family<SchemeDetail, String>((ref, id) {
  return ref.watch(repositoryProvider).fetchScheme(id);
});

final digiGoldSchemeProvider = FutureProvider.autoDispose<SchemeDetail?>((ref) {
  _requireSession(ref);
  return ref.watch(repositoryProvider).fetchDigiGoldScheme();
});

class WalletOverview {
  const WalletOverview({required this.wallet, required this.history, required this.rate});

  final Wallet? wallet;
  final List<WalletEntry> history;
  final WalletRate? rate;
}

final walletProvider = FutureProvider<WalletOverview>((ref) async {
  _requireSession(ref);
  final repo = ref.watch(repositoryProvider);
  final wallet = await repo.fetchWallet();
  final results = await Future.wait([
    wallet == null ? Future.value(const <WalletEntry>[]) : repo.fetchWalletHistory(wallet.id),
    repo.fetchWalletRate().catchError((_) => null),
  ]);
  return WalletOverview(
    wallet: wallet,
    history: results[0] as List<WalletEntry>,
    rate: results[1] as WalletRate?,
  );
});

Session _requireSession(Ref ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    throw const ApiException('You are signed out.', kind: ApiFailure.sessionExpired);
  }
  return session;
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/brand_config.dart';
import '../../core/data/models.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/ui.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gateway
// ─────────────────────────────────────────────────────────────────────────────

/// How the Cashfree checkout ended, from the app's point of view.
///
/// None of these mean "paid". The SDK's success callback only says the
/// customer finished the gateway's pages; whether money moved is decided by
/// the backend asking the gateway (see `CustomerRepository.isOrderPaid`).
sealed class CheckoutResult {
  const CheckoutResult();
}

/// The customer came back from the gateway. Verify with the backend.
class CheckoutGatewayReturned extends CheckoutResult {
  const CheckoutGatewayReturned(this.orderId);

  final String orderId;
}

/// The gateway reported a cancellation or a failed attempt.
class CheckoutCancelledOrFailed extends CheckoutResult {
  const CheckoutCancelledOrFailed(this.message, {this.cancelled = false});

  /// The gateway's own wording, cleaned up; may be empty.
  final String message;
  final bool cancelled;
}

/// The payment page could not be opened (SDK or platform error).
class CheckoutSdkError extends CheckoutResult {
  const CheckoutSdkError(this.message);

  final String message;
}

/// The SDK keeps one set of callbacks for the whole app, so only one checkout
/// may be open at a time.
_PendingCheckout? _pending;

class _PendingCheckout {
  _PendingCheckout(this.orderId);

  final String orderId;
  final Completer<CheckoutResult> completer = Completer<CheckoutResult>();
  AppLifecycleListener? lifecycle;
  Timer? returnTimer;
  Timer? openTimer;

  void finish(CheckoutResult result) {
    if (completer.isCompleted) return;
    completer.complete(result);
    returnTimer?.cancel();
    openTimer?.cancel();
    lifecycle?.dispose();
    if (identical(_pending, this)) _pending = null;
  }
}

/// Opens Cashfree web checkout for [order] and completes when the customer
/// leaves it. Never throws.
///
/// Opening the same order twice while it is open returns the same future, so
/// a repeated tap can never start a second checkout.
Future<CheckoutResult> openCheckout(PaymentOrder order) {
  final current = _pending;
  if (current != null && !current.completer.isCompleted) {
    if (current.orderId == order.orderId) return current.completer.future;
    return Future.value(const CheckoutSdkError('Another payment is still open. Finish or close it, then try again.'));
  }

  final pending = _PendingCheckout(order.orderId);
  _pending = pending;

  // Android opens the gateway as a separate activity, which pauses ours. That
  // gives two safety nets so the flow can never hang on a missing callback:
  //  • back in the foreground for 10 s with no callback (e.g. the activity
  //    was recreated) → treat it as a return from the gateway. That only
  //    leads to a backend check; it never shows success on its own.
  //  • never left the app within 20 s → the page did not open.
  // On iOS the gateway is a modal over the app and the app lifecycle does not
  // change, so neither signal applies there.
  var leftApp = false;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    pending.lifecycle = AppLifecycleListener(onStateChange: (state) {
      if (state == AppLifecycleState.resumed) {
        if (!leftApp) return;
        pending.returnTimer?.cancel();
        pending.returnTimer = Timer(const Duration(seconds: 10), () {
          pending.finish(CheckoutGatewayReturned(order.orderId));
        });
      } else {
        leftApp = true;
        pending.openTimer?.cancel();
        pending.returnTimer?.cancel();
      }
    });
    pending.openTimer = Timer(const Duration(seconds: 20), () {
      if (!leftApp) {
        pending.finish(const CheckoutSdkError('The payment page did not open. You have not been charged.'));
      }
    });
  }

  void onVerify(String orderId) {
    // A late response for an earlier order can be replayed when callbacks are
    // registered; it is not about this order.
    if (orderId != order.orderId) return;
    pending.finish(CheckoutGatewayReturned(orderId));
  }

  void onError(CFErrorResponse error, String orderId) {
    final aboutThisOrder = orderId.isEmpty || orderId == 'order_id_not_found' || orderId == order.orderId;
    if (!aboutThisOrder) return;
    pending.finish(CheckoutCancelledOrFailed(_gatewayMessage(error), cancelled: _isCancellation(error)));
  }

  try {
    final session = CFSessionBuilder()
        .setEnvironment(AppConfig.cashfreeProduction ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX)
        .setOrderId(order.orderId)
        .setPaymentSessionId(order.sessionId)
        .build();
    final payment = CFWebCheckoutPaymentBuilder().setSession(session).setTheme(_checkoutTheme()).build();
    final service = CFPaymentGatewayService();

    // The SDK chains platform-channel futures without error handlers, so each
    // call runs in a guarded zone.
    //
    // Registering callbacks also replays a response the SDK kept from an
    // earlier checkout. Valid replays are filtered by order ID above; a replay
    // that fails to parse is not about this order and is ignored.
    runZonedGuarded(() => service.setCallback(onVerify, onError), (_, __) {});
    runZonedGuarded(() => service.doPayment(payment), (error, _) {
      // After the gateway was open, an unreadable answer means "outcome
      // unknown": verify with the backend. Before that, the page never opened.
      pending.finish(leftApp ? CheckoutGatewayReturned(order.orderId) : CheckoutSdkError(_sdkMessage(error)));
    });
  } catch (error) {
    pending.finish(CheckoutSdkError(_sdkMessage(error)));
  }

  return pending.completer.future;
}

CFTheme _checkoutTheme() => CFThemeBuilder()
    .setNavigationBarBackgroundColorColor(_hex(AppColors.ink))
    .setNavigationBarTextColor(_hex(AppColors.inkInverse))
    .setButtonBackgroundColor(_hex(AppColors.ink))
    .setButtonTextColor(_hex(AppColors.inkInverse))
    .setPrimaryTextColor(_hex(AppColors.ink))
    .setSecondaryTextColor(_hex(AppColors.inkSecondary))
    .setBackgroundColor(_hex(AppColors.surface))
    .build();

String _hex(Color color) => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

bool _isCancellation(CFErrorResponse e) {
  final text = '${e.getCode() ?? ''} ${e.getType() ?? ''} ${e.getMessage() ?? ''}'.toLowerCase();
  return text.contains('cancel') || text.contains('dropped') || text.contains('back pressed');
}

String _gatewayMessage(CFErrorResponse e) {
  final raw = (e.getMessage() ?? '').trim();
  if (raw.isEmpty || raw.toLowerCase() == 'something went wrong') return '';
  final sentence = raw.replaceAll('_', ' ');
  return sentence[0].toUpperCase() + sentence.substring(1);
}

String _sdkMessage(Object error) {
  if (error is MissingPluginException) return 'Online payment is not supported on this device.';
  if (error is CFException && error.message.trim().isNotEmpty) {
    return 'The payment page could not be opened (${error.message.trim().toLowerCase()}).';
  }
  if (error is PlatformException) {
    final m = error.message?.trim() ?? '';
    return m.isEmpty ? 'The payment page could not be opened.' : 'The payment page could not be opened: $m';
  }
  return 'The payment page closed unexpectedly.';
}

// ─────────────────────────────────────────────────────────────────────────────
// Checkout + verification flow
// ─────────────────────────────────────────────────────────────────────────────

/// How the customer left [PaymentStatusScreen].
enum PaymentExit {
  /// The backend confirmed the payment; close the whole flow.
  paid,

  /// Close the whole flow without a confirmed payment (pending or "Done").
  closeFlow,

  /// The attempt failed and the customer wants to review and pay again. A new
  /// order is created only when they tap Pay again.
  backToReview,
}

/// Opens the gateway for an order that already exists, then shows
/// [PaymentStatusScreen] for it. Returns how the customer left.
Future<PaymentExit> checkoutAndVerify(
  BuildContext context, {
  required PaymentOrder order,
  required String title,
  required String amountLabel,
  List<(String, String)> details = const [],
  String? successNote,
  List<ProviderOrFamily> invalidateOnPaid = const [],
}) async {
  final result = await openCheckout(order);
  if (!context.mounted) return PaymentExit.closeFlow;
  final exit = await Navigator.of(context).push<PaymentExit>(MaterialPageRoute(
    builder: (_) => PaymentStatusScreen(
      order: order,
      title: title,
      amountLabel: amountLabel,
      checkout: result,
      details: details,
      successNote: successNote,
      invalidateOnPaid: invalidateOnPaid,
    ),
  ));
  // Popped by anything other than our own buttons: the payment may still be
  // in progress, so never offer a second attempt by default.
  return exit ?? PaymentExit.closeFlow;
}

// ─────────────────────────────────────────────────────────────────────────────
// Status screen
// ─────────────────────────────────────────────────────────────────────────────

enum _Stage { verifying, paid, pending, failed, checkError }

/// Confirms an order with the backend after checkout and shows the outcome.
///
/// Success is shown only after `isOrderPaid` returns true. Pops with a
/// [PaymentExit]; the caller closes the flow or returns to its review step.
class PaymentStatusScreen extends ConsumerStatefulWidget {
  const PaymentStatusScreen({
    super.key,
    required this.order,
    required this.title,
    required this.amountLabel,
    required this.checkout,
    this.details = const [],
    this.successNote,
    this.invalidateOnPaid = const [],
  });

  final PaymentOrder order;

  /// What was paid for, e.g. "Digital gold purchase".
  final String title;

  /// The total charged, already formatted.
  final String amountLabel;

  final CheckoutResult checkout;

  /// Extra receipt rows (label, value), shown above the order ID.
  final List<(String, String)> details;

  /// Shown under a confirmed payment. Defaults to a generic line.
  final String? successNote;

  /// Refreshed once, as soon as the payment is confirmed.
  final List<ProviderOrFamily> invalidateOnPaid;

  @override
  ConsumerState<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen> {
  /// Initial verification window: immediately, then every 3 s for ~30 s.
  static const _interval = Duration(seconds: 3);
  static const _fullAttempts = 11;
  static const _recheckAttempts = 3;

  _Stage _stage = _Stage.verifying;
  bool _quickCheck = false;
  Object? _checkError;
  int _run = 0;
  bool _refreshed = false;

  bool get _gatewayReturned => widget.checkout is CheckoutGatewayReturned;

  @override
  void initState() {
    super.initState();
    if (_gatewayReturned) {
      _verify(attempts: _fullAttempts);
    } else {
      // The gateway said the attempt did not go through. One quiet check
      // guards against a stale or misreported callback; if the bank did take
      // the money we must not tell the customer it failed.
      _quickCheck = true;
      _verify(attempts: 1, fallback: _Stage.failed);
    }
  }

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  Future<void> _verify({required int attempts, _Stage? fallback}) async {
    final run = ++_run;
    if (_stage != _Stage.verifying) {
      setState(() {
        _stage = _Stage.verifying;
        _checkError = null;
      });
    }

    final repo = ref.read(repositoryProvider);
    var answered = false;
    Object? lastError;

    for (var i = 0; i < attempts; i++) {
      if (i > 0) {
        await Future<void>.delayed(_interval);
        if (!mounted || run != _run) return;
      }
      try {
        final paid = await repo.isOrderPaid(widget.order.orderId);
        if (!mounted || run != _run) return;
        if (paid) {
          _onPaid();
          return;
        }
        answered = true;
      } on ApiException catch (e) {
        if (!mounted || run != _run) return;
        lastError = e;
        // A signed-out session will not recover by polling.
        if (e.kind == ApiFailure.sessionExpired) break;
      } catch (e) {
        if (!mounted || run != _run) return;
        lastError = e;
      }
    }

    setState(() {
      if (fallback != null) {
        _stage = fallback;
      } else if (answered) {
        _stage = _Stage.pending;
      } else {
        _stage = _Stage.checkError;
        _checkError = lastError;
      }
      _quickCheck = false;
    });
  }

  void _onPaid() {
    if (!_refreshed) {
      _refreshed = true;
      for (final p in widget.invalidateOnPaid) {
        ref.invalidate(p);
      }
    }
    setState(() {
      _stage = _Stage.paid;
      _quickCheck = false;
    });
  }

  void _exit(PaymentExit exit) {
    if (_stage == _Stage.verifying) return;
    Navigator.of(context).pop(exit);
  }

  PaymentExit get _backExit => switch (_stage) {
        _Stage.paid => PaymentExit.paid,
        _Stage.failed => PaymentExit.backToReview,
        _ => PaymentExit.closeFlow,
      };

  Future<void> _copyOrderId() async {
    await Clipboard.setData(ClipboardData(text: widget.order.orderId));
    if (mounted) showAppSnack(context, 'Order ID copied');
  }

  @override
  Widget build(BuildContext context) {
    final verifying = _stage == _Stage.verifying;
    return PopScope<PaymentExit>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (verifying) {
          showAppSnack(context, 'Please wait while we confirm your payment.');
          return;
        }
        _exit(_backExit);
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('Payment'),
          automaticallyImplyLeading: false,
          leading: verifying
              ? null
              : IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _exit(_backExit),
                ),
        ),
        body: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(key: ValueKey(_stage), child: _content()),
              ),
            ),
          ),
          if (!verifying) BottomActionBar(child: _actions()),
        ]),
      ),
    );
  }

  Widget _content() {
    switch (_stage) {
      case _Stage.verifying:
        return _VerifyingView(
          quick: _quickCheck,
          amountLabel: widget.amountLabel,
          title: widget.title,
        );
      case _Stage.paid:
        return _OutcomeView(
          icon: Icons.check_rounded,
          tone: Tone.positive,
          heading: 'Payment confirmed',
          message: widget.successNote ?? 'Your account will reflect this payment shortly.',
          receipt: _receipt(),
        );
      case _Stage.pending:
        return _OutcomeView(
          icon: Icons.schedule_rounded,
          tone: Tone.caution,
          heading: 'Payment not confirmed yet',
          message: 'The bank has not confirmed this payment yet. If money was debited from your account, '
              'it will be updated here automatically once confirmed, or refunded by your bank. '
              'Please do not pay again for the same amount.',
          receipt: _receipt(),
          footnote: _supportLine(),
        );
      case _Stage.failed:
        return switch (widget.checkout) {
          CheckoutSdkError(:final message) => _OutcomeView(
              icon: Icons.close_rounded,
              tone: Tone.negative,
              heading: 'Payment not completed',
              message: message,
              secondaryMessage: 'You can try again. If this keeps happening, please contact us.',
              receipt: _receipt(),
              footnote: _supportLine(),
            ),
          CheckoutCancelledOrFailed(:final message, :final cancelled) => _OutcomeView(
              icon: Icons.close_rounded,
              tone: Tone.negative,
              heading: cancelled ? 'Payment cancelled' : 'Payment not completed',
              message: cancelled
                  ? 'The payment page was closed before the payment was completed.'
                  : 'The payment could not be completed.',
              detail: cancelled || message.isEmpty ? null : message,
              secondaryMessage: 'If any amount was debited, your bank will refund it automatically.',
              receipt: _receipt(),
            ),
          // Not reachable: a gateway return ends as paid, pending or a check error.
          CheckoutGatewayReturned() => _OutcomeView(
              icon: Icons.schedule_rounded,
              tone: Tone.caution,
              heading: 'Payment not confirmed yet',
              message: 'The bank has not confirmed this payment yet.',
              receipt: _receipt(),
            ),
        };
      case _Stage.checkError:
        final error = _checkError;
        final offline = error is ApiException && error.isConnectivity;
        return _OutcomeView(
          icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          tone: Tone.caution,
          heading: 'We couldn’t check the payment',
          message: error == null ? 'The payment status is not available right now.' : errorMessage(error),
          secondaryMessage: 'If you completed the payment, do not pay again. Check again in a moment.',
          receipt: _receipt(),
          footnote: _supportLine(),
        );
    }
  }

  Widget _receipt() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title.toUpperCase(), style: AppText.overline),
        const SizedBox(height: Space.xxs),
        Text(widget.amountLabel, style: AppText.amountXL),
        const SizedBox(height: Space.sm),
        const Divider(),
        const SizedBox(height: Space.xs),
        for (final (label, value) in widget.details) DetailRow(label, value),
        _OrderIdRow(orderId: widget.order.orderId, onCopy: _copyOrderId),
      ]),
    );
  }

  Widget _supportLine() => Text(
        'Need help? Call ${BrandConfig.supportPhone} and quote the order ID.',
        style: AppText.caption,
      );

  Widget _actions() {
    switch (_stage) {
      case _Stage.verifying:
        return const SizedBox.shrink();
      case _Stage.paid:
        return PrimaryButton(label: 'Done', onPressed: () => _exit(PaymentExit.paid));
      case _Stage.pending:
      case _Stage.checkError:
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PrimaryButton(
            label: 'Check again',
            icon: Icons.refresh_rounded,
            onPressed: () => _verify(attempts: _recheckAttempts),
          ),
          const SizedBox(height: Space.xs),
          SecondaryButton(label: 'Done', onPressed: () => _exit(PaymentExit.closeFlow)),
        ]);
      case _Stage.failed:
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PrimaryButton(label: 'Try again', onPressed: () => _exit(PaymentExit.backToReview)),
          const SizedBox(height: Space.xs),
          SecondaryButton(label: 'Done', onPressed: () => _exit(PaymentExit.closeFlow)),
        ]);
    }
  }
}

class _VerifyingView extends StatelessWidget {
  const _VerifyingView({required this.quick, required this.amountLabel, required this.title});

  final bool quick;
  final String amountLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xxxl),
      child: Semantics(
        liveRegion: true,
        child: Column(children: [
          const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: Space.xl),
          Text(
            quick ? 'Checking the payment status…' : 'Confirming your payment with the bank…',
            style: AppText.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xs),
          Text(
            quick
                ? 'This takes a moment.'
                : 'This can take up to 30 seconds. Please keep this screen open and do not pay again.',
            style: AppText.small,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xl),
          Text(amountLabel, style: AppText.amountL, textAlign: TextAlign.center),
          const SizedBox(height: Space.xxs),
          Text(title, style: AppText.small, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _OutcomeView extends StatelessWidget {
  const _OutcomeView({
    required this.icon,
    required this.tone,
    required this.heading,
    required this.message,
    required this.receipt,
    this.detail,
    this.secondaryMessage,
    this.footnote,
  });

  final IconData icon;
  final Tone tone;
  final String heading;
  final String message;
  final String? detail;
  final String? secondaryMessage;
  final Widget receipt;
  final Widget? footnote;

  @override
  Widget build(BuildContext context) {
    final (wash, ink) = switch (tone) {
      Tone.positive => (AppColors.positiveWash, AppColors.positive),
      Tone.negative => (AppColors.negativeWash, AppColors.negative),
      Tone.caution => (AppColors.cautionWash, AppColors.caution),
      Tone.gold => (AppColors.goldWash, AppColors.goldDeep),
      Tone.neutral => (AppColors.neutralWash, AppColors.inkSecondary),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: Space.md),
      Semantics(
        liveRegion: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(child: IconTile(icon, size: 52, background: wash, color: ink)),
          const SizedBox(height: Space.md),
          Semantics(header: true, child: Text(heading, style: AppText.title)),
          const SizedBox(height: Space.xs),
          Text(message, style: AppText.bodySecondary),
        ]),
      ),
      if (detail != null) ...[
        const SizedBox(height: Space.sm),
        Text('Gateway response: $detail', style: AppText.small),
      ],
      if (secondaryMessage != null) ...[
        const SizedBox(height: Space.sm),
        Text(secondaryMessage!, style: AppText.small),
      ],
      const SizedBox(height: Space.xl),
      receipt,
      if (footnote != null) ...[const SizedBox(height: Space.md), footnote!],
    ]);
  }
}

class _OrderIdRow extends StatelessWidget {
  const _OrderIdRow({required this.orderId, required this.onCopy});

  final String orderId;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: MergeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order ID', style: AppText.small),
            const SizedBox(height: 2),
            SelectableText(orderId, style: AppText.tabular(AppText.smallStrong)),
          ]),
        ),
      ),
      IconButton(
        tooltip: 'Copy order ID',
        onPressed: onCopy,
        icon: const Icon(Icons.copy_rounded, size: 20),
        color: AppColors.inkSecondary,
      ),
    ]);
  }
}

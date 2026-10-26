import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/brand_config.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/ui.dart';
import 'validators.dart';

/// Password reset: Mobile → Verify (SMS OTP) → New password.
///
/// The backend only accepts the new password once the OTP for the same
/// mobile has been verified, so each step talks to the backend before the
/// next one opens.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialMobile});

  /// Pre-fills the mobile field, e.g. with what was typed on the sign-in screen.
  final String? initialMobile;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _labels = ['Mobile', 'Verify', 'New password'];
  static const _resendSeconds = 30;

  final _mobileForm = GlobalKey<FormState>();
  final _otpForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();

  late final _mobile = TextEditingController(text: _cleanMobile(widget.initialMobile));
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  final _scroll = ScrollController();

  int _step = 0;
  bool _done = false;
  bool _submitting = false;
  bool _resending = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _info;

  /// The number the current OTP was sent to.
  String _otpMobile = '';
  int _secondsLeft = 0;
  Timer? _timer;

  static String _cleanMobile(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobile.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, _resendSeconds));
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Backend messages, lightly tidied ("Otp" → "OTP", "expired,try" → "expired, try").
  static String _tidy(String message) => message
      .replaceAll(RegExp(r'\botp\b', caseSensitive: false), 'OTP')
      .replaceAllMapped(RegExp(r',(?=[A-Za-z])'), (_) => ', ');

  static String _friendly(ApiException e) {
    final m = e.message.toLowerCase();
    if (m.contains('no user found') || m.contains('user not found')) {
      return 'No account is registered with this mobile number.';
    }
    if (m.contains('not permited') || m.contains('not permitted')) {
      return 'This code is no longer valid. Request a new OTP and try again.';
    }
    return _tidy(e.message);
  }

  // ── Step 1: send the OTP ───────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (_submitting) return;
    setState(() {
      _error = null;
      _info = null;
    });
    if (!(_mobileForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final mobile = _mobile.text.trim();
    // A code for this number is still fresh: reuse it rather than send another.
    if (mobile == _otpMobile && _secondsLeft > 0) {
      setState(() => _info = 'We’ve already sent an OTP to this number. You can request a new one in $_secondsLeft s.');
      _goTo(1);
      return;
    }

    setState(() => _submitting = true);
    try {
      final message = await ref.read(repositoryProvider).requestPasswordResetOtp(mobile);
      if (!mounted) return;
      _otp.clear();
      _otpMobile = mobile;
      setState(() => _info = _tidy(message));
      _startCountdown();
      _goTo(1);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn’t send the OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _submitting || _secondsLeft > 0) return;
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final message = await ref.read(repositoryProvider).requestPasswordResetOtp(_otpMobile);
      if (!mounted) return;
      _otp.clear();
      setState(() => _info = _tidy(message));
      _startCountdown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn’t send the OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  // ── Step 2: verify ─────────────────────────────────────────────────────────

  Future<void> _verify() async {
    if (_submitting || _resending) return;
    setState(() => _error = null);
    if (!(_otpForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    try {
      await ref.read(repositoryProvider).verifyPasswordResetOtp(mobile: _otpMobile, otp: _otp.text.trim());
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _info = null;
        _secondsLeft = 0;
      });
      _goTo(2);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn’t verify the OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Step 3: new password ───────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (_submitting) return;
    setState(() => _error = null);
    if (!(_passwordForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    try {
      await ref.read(repositoryProvider).resetPassword(mobile: _otpMobile, password: _password.text);
      TextInput.finishAutofillContext();
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn’t update your password. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _resending;

    return PopScope(
      // From the OTP step, back returns to the mobile number; elsewhere it
      // leaves the flow. Nothing leaves while a request is in flight.
      canPop: _done || (!busy && _step != 1),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || busy || _done) return;
        if (_step == 1) _goTo(0);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: _done ? _buildDone() : _buildFlow(),
      ),
    );
  }

  Widget _buildFlow() {
    final Widget content = switch (_step) {
      0 => _mobileStep(),
      1 => _otpStep(),
      _ => _passwordStep(),
    };
    final Widget action = switch (_step) {
      0 => PrimaryButton(label: 'Send OTP', loading: _submitting, onPressed: _sendOtp),
      1 => PrimaryButton(label: 'Verify', loading: _submitting, onPressed: _resending ? null : _verify),
      _ => PrimaryButton(label: 'Update password', loading: _submitting, onPressed: _resetPassword),
    };

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                StepIndicator(current: _step, labels: _labels),
                const SizedBox(height: Space.xl),
                content,
                if (_error != null) ...[
                  const SizedBox(height: Space.md),
                  _Banner(message: _error!, tone: Tone.negative),
                ],
              ]),
            ),
          ),
        ),
      ),
      BottomActionBar(child: action),
    ]);
  }

  Widget _title(String title, String body) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(title, style: AppText.title)),
      const SizedBox(height: Space.xs),
      Text(body, style: AppText.bodySecondary),
    ]);
  }

  Widget _mobileStep() {
    return Form(
      key: _mobileForm,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Forgot your password?',
            'Enter the mobile number registered with ${BrandConfig.brandDisplayName} and we’ll send you a code.'),
        const SizedBox(height: Space.xl),
        TextFormField(
          controller: _mobile,
          enabled: !_submitting,
          autofocus: _mobile.text.isEmpty,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          style: AppText.tabular(AppText.body),
          decoration: InputDecoration(
            labelText: 'Mobile number',
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
              child: Text('+91', style: AppText.body.copyWith(color: AppColors.inkSecondary)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          validator: Validators.mobile,
          onFieldSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: Space.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.sms_outlined, size: 16, color: AppColors.inkTertiary),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text('The OTP is sent by SMS to your registered mobile number.', style: AppText.caption),
          ),
        ]),
      ]),
    );
  }

  Widget _otpStep() {
    final counting = _secondsLeft > 0;
    final countdown = '0:${_secondsLeft.toString().padLeft(2, '0')}';

    return Form(
      key: _otpForm,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title('Enter the OTP', 'We sent a code by SMS to +91 $_otpMobile.'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _submitting || _resending ? null : () => _goTo(0),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.xs)),
            child: const Text('Change number'),
          ),
        ),
        if (_info != null) ...[
          const SizedBox(height: Space.xs),
          _Banner(message: _info!, tone: Tone.positive),
        ],
        const SizedBox(height: Space.lg),
        AutofillGroup(
          child: TextFormField(
            controller: _otp,
            enabled: !_submitting,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            style: AppText.amountL.copyWith(letterSpacing: 6),
            decoration: const InputDecoration(labelText: 'OTP'),
            validator: Validators.otp,
            onFieldSubmitted: (_) => _verify(),
          ),
        ),
        const SizedBox(height: Space.sm),
        Row(children: [
          Expanded(child: Text('Didn’t get the code?', style: AppText.small)),
          if (_resending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: counting || _submitting ? null : _resend,
              child: Text(
                counting ? 'Resend in $countdown' : 'Resend OTP',
                semanticsLabel: counting ? 'Resend available in $_secondsLeft seconds' : 'Resend OTP',
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _passwordStep() {
    return Form(
      key: _passwordForm,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _title('Choose a new password', 'Use at least 8 characters, with both letters and numbers.'),
          const SizedBox(height: Space.xl),
          TextFormField(
            controller: _password,
            enabled: !_submitting,
            autofocus: true,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'New password',
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: Validators.newPassword,
            onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
          ),
          const SizedBox(height: Space.md),
          TextFormField(
            controller: _confirm,
            focusNode: _confirmFocus,
            enabled: !_submitting,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              suffixIcon: IconButton(
                tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Re-enter the new password';
              if (v != _password.text) return 'Passwords don’t match';
              return null;
            },
            onFieldSubmitted: (_) => _resetPassword(),
          ),
        ]),
      ),
    );
  }

  Widget _buildDone() {
    return Column(children: [
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
            child: Semantics(
              liveRegion: true,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const IconTile(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  background: AppColors.positiveWash,
                  color: AppColors.positive,
                ),
                const SizedBox(height: Space.lg),
                Text('Password updated', style: AppText.title, textAlign: TextAlign.center),
                const SizedBox(height: Space.xs),
                Text('Sign in with your new password.', style: AppText.bodySecondary, textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
      BottomActionBar(
        child: PrimaryButton(label: 'Back to sign in', onPressed: () => Navigator.of(context).pop()),
      ),
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.tone});

  final String message;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      Tone.negative => (AppColors.negativeWash, AppColors.negative, Icons.error_outline_rounded),
      Tone.positive => (AppColors.positiveWash, AppColors.positive, Icons.check_circle_outline_rounded),
      _ => (AppColors.cautionWash, AppColors.caution, Icons.info_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message, style: AppText.small.copyWith(color: fg, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

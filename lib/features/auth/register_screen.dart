import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/brand_config.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/ui.dart';
import 'validators.dart';

/// Complete registration flow for new customers with WhatsApp OTP verification.
///
/// Flow:
/// 1. Enter Full Name, 10-digit Mobile, 4-digit MPIN, and Password.
/// 2. Backend checks for duplicate account and dispatches 6-digit OTP via WhatsApp.
///    In local development, the backend safely provides a development demo OTP.
/// 3. Customer verifies the 6-digit OTP.
/// 4. Backend creates customer account, signs JWT token, and establishes live session.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const int _resendSeconds = 30;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mpinController = TextEditingController();
  final _otpController = TextEditingController();

  final _passwordFocus = FocusNode();
  final _mpinFocus = FocusNode();

  // Wizard state: 0 = Details, 1 = WhatsApp OTP Verification
  int _step = 0;
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _resending = false;
  String? _error;
  String? _info;

  // WhatsApp OTP Delivery Metadata
  bool _isDemoMode = false;
  String? _demoOtp;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _mpinController.dispose();
    _otpController.dispose();
    _passwordFocus.dispose();
    _mpinFocus.dispose();
    super.dispose();
  }

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

  String _cleanMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  // ── Step 1: Submit Details & Request WhatsApp OTP ──────────────────────────

  Future<void> _handleRequestOtp() async {
    if (_submitting) return;
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final cleanPhone = _cleanMobile(_mobileController.text);
    try {
      final result = await ref.read(repositoryProvider).requestSignupOtp(cleanPhone);
      if (!mounted) return;

      setState(() {
        _isDemoMode = result.isDemo;
        _demoOtp = result.demoOtp;
        _step = 1;
        _error = null;
        _info = result.message;
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to send WhatsApp OTP. Please check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Step 2: Verify WhatsApp OTP & Complete Registration ────────────────────

  Future<void> _handleVerifyAndRegister() async {
    if (_submitting) return;
    final otpText = _otpController.text.trim();
    if (otpText.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit WhatsApp code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    final cleanPhone = _cleanMobile(_mobileController.text);

    try {
      // 1. Verify OTP with backend
      await ref.read(repositoryProvider).verifySignupOtp(
            mobile: cleanPhone,
            otp: otpText,
          );

      // 2. Complete Account Registration & Establish Authenticated Session
      await ref.read(authControllerProvider.notifier).completeSignUp(
            firstname: _nameController.text.trim(),
            mobile: cleanPhone,
            password: _passwordController.text,
            mpin: _mpinController.text.trim().isNotEmpty ? _mpinController.text.trim() : '1234',
          );

      TextInput.finishAutofillContext();

      if (mounted) {
        // Pop back to root so the authenticated shell displays
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Verification failed. Please check the OTP and try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Resend WhatsApp OTP ───────────────────────────────────────────────────

  Future<void> _handleResendOtp() async {
    if (_resending || _secondsLeft > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });

    final cleanPhone = _cleanMobile(_mobileController.text);
    try {
      final result = await ref.read(repositoryProvider).requestSignupOtp(cleanPhone);
      if (!mounted) return;

      setState(() {
        _isDemoMode = result.isDemo;
        _demoOtp = result.demoOtp;
        _info = 'A new code has been dispatched via WhatsApp.';
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to resend code. Please try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _fillDemoOtp(String code) {
    setState(() {
      _otpController.text = code;
      _error = null;
    });
  }

  String _friendly(ApiException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already exists') || m.contains('already registered')) {
      return 'An account already exists with this mobile number. Please sign in instead.';
    }
    if (m.contains('incorrect otp') || m.contains('invalid otp')) {
      return 'The OTP entered is incorrect. Please recheck the message received on WhatsApp.';
    }
    if (m.contains('expired')) {
      return 'This verification code has expired. Please request a new one.';
    }
    if (m.contains('wait')) {
      return e.message;
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          tooltip: 'Back',
          onPressed: () {
            if (_step > 0) {
              setState(() {
                _step = 0;
                _error = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _step == 0 ? _buildRegistrationForm() : _buildOtpVerification(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Step 1 Form Widget ────────────────────────────────────────────────────

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandMark(size: 44),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(BrandConfig.appName, style: AppText.headline),
                    Text(
                      BrandConfig.appTagline,
                      style: AppText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xxl),

          Semantics(
            header: true,
            child: Text('Create account', style: AppText.title.copyWith(fontSize: 32)),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Register for 24K digital gold and jewellery savings schemes with ${BrandConfig.brandDisplayName}.',
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: Space.xl),

          // WhatsApp Explanation Card
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.positiveWash,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: const Icon(Icons.chat_rounded, color: AppColors.positive, size: 20),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WhatsApp Verification', style: AppText.smallStrong),
                      const SizedBox(height: 2),
                      Text(
                        'A 6-digit one-time code will be sent to your WhatsApp number to verify your account securely.',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),

          // Full Name
          TextFormField(
            controller: _nameController,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name',
              hintText: 'Enter your name as in ID',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().length < 2) {
                return 'Please enter your full name (at least 2 letters)';
              }
              return null;
            },
          ),
          const SizedBox(height: Space.md),

          // Mobile Number
          TextFormField(
            controller: _mobileController,
            enabled: !_submitting,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: AppText.tabular(AppText.body),
            decoration: InputDecoration(
              labelText: 'WhatsApp Mobile number',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
                child: Text('+91', style: AppText.body.copyWith(color: AppColors.inkSecondary)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
            validator: Validators.mobile,
            onFieldSubmitted: (_) => _mpinFocus.requestFocus(),
          ),
          const SizedBox(height: Space.md),

          // 4-Digit MPIN
          TextFormField(
            controller: _mpinController,
            focusNode: _mpinFocus,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            obscureText: true,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            style: AppText.tabular(AppText.body),
            decoration: const InputDecoration(
              labelText: '4-digit MPIN',
              hintText: 'Used for quick app sign-in',
              prefixIcon: Icon(Icons.pin_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.length != 4) {
                return 'Please set a 4-digit numeric MPIN';
              }
              return null;
            },
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: Space.md),

          // Password
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            enabled: !_submitting,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Account password',
              hintText: 'Minimum 6 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            onFieldSubmitted: (_) => _handleRequestOtp(),
          ),
          const SizedBox(height: Space.lg),

          // Error banner
          if (_error != null) ...[
            _Banner(message: _error!, tone: Tone.negative),
            const SizedBox(height: Space.md),
          ],

          // Submit Button
          PrimaryButton(
            label: 'Continue to WhatsApp OTP',
            loading: _submitting,
            icon: Icons.arrow_forward_rounded,
            onPressed: _handleRequestOtp,
          ),
          const SizedBox(height: Space.xl),

          // Sign In Link
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Already have an account? ', style: AppText.bodySecondary),
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.xs)),
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Sign in'),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }

  // ── Step 2: WhatsApp OTP Verification Widget ──────────────────────────────

  Widget _buildOtpVerification() {
    final cleanPhone = _cleanMobile(_mobileController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const BrandMark(size: 44),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(BrandConfig.appName, style: AppText.headline),
                  Text('WhatsApp Verification', style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),

        Semantics(
          header: true,
          child: Text('Verify WhatsApp code', style: AppText.title.copyWith(fontSize: 30)),
        ),
        const SizedBox(height: Space.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Enter the 6-digit code sent to +91 $cleanPhone on WhatsApp.',
                style: AppText.bodySecondary,
              ),
            ),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () {
                      setState(() {
                        _step = 0;
                        _error = null;
                      });
                    },
              child: const Text('Edit number'),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),

        // Development Demo Mode Notice Banner
        if (_isDemoMode && _demoOtp != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(
              color: AppColors.goldWash,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code_rounded, size: 20, color: AppColors.goldDeep),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Development Demo Mode', style: AppText.smallStrong.copyWith(color: AppColors.goldDeep)),
                      Text('Test WhatsApp OTP: $_demoOtp', style: AppText.caption),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _fillDemoOtp(_demoOtp!),
                  child: const Text('Fill OTP'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
        ],

        if (_info != null && !_isDemoMode) ...[
          _Banner(message: _info!, tone: Tone.caution),
          const SizedBox(height: Space.md),
        ],

        // OTP Input Field
        TextFormField(
          controller: _otpController,
          enabled: !_submitting,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: AppText.headline.copyWith(
            letterSpacing: 10,
            fontSize: 28,
            color: AppColors.ink,
          ),
          decoration: const InputDecoration(
            hintText: '••••••',
            hintStyle: TextStyle(letterSpacing: 10, color: AppColors.lineStrong),
            counterText: '',
          ),
          onFieldSubmitted: (_) => _handleVerifyAndRegister(),
        ),
        const SizedBox(height: Space.md),

        // Resend WhatsApp Code Timer / Action
        Align(
          alignment: Alignment.centerRight,
          child: _secondsLeft > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Resend code in ${_secondsLeft}s',
                    style: AppText.caption.copyWith(color: AppColors.inkTertiary),
                  ),
                )
              : TextButton.icon(
                  onPressed: _resending || _submitting ? null : _handleResendOtp,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(_resending ? 'Sending…' : 'Resend OTP via WhatsApp'),
                ),
        ),

        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          _Banner(message: _error!, tone: Tone.negative),
          const SizedBox(height: Space.md),
        ] else
          const SizedBox(height: Space.sm),

        // Verify Button
        PrimaryButton(
          label: 'Verify & Create Account',
          loading: _submitting,
          icon: Icons.check_circle_outline_rounded,
          onPressed: _handleVerifyAndRegister,
        ),
        const SizedBox(height: Space.xxl),

        // Back to Details
        Center(
          child: TextButton(
            onPressed: _submitting ? null : () => setState(() => _step = 0),
            child: const Text('Change registration details'),
          ),
        ),
        const SizedBox(height: Space.xl),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.tone});

  final String message;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final negative = tone == Tone.negative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: negative ? AppColors.negativeWash : AppColors.cautionWash,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            negative ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 20,
            color: negative ? AppColors.negative : AppColors.caution,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: AppText.small.copyWith(
                color: negative ? AppColors.negative : AppColors.caution,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

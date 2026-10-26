import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/brand_config.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/ui.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'validators.dart';

/// Mobile + password sign-in against POST /api/client/customer/login.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.notice});

  /// One-off message from the previous session, e.g. "session expired".
  final String? notice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _submitting = false;
  String? _error;
  late String? _notice = widget.notice;

  @override
  void dispose() {
    _mobile.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            mobile: _mobile.text.trim(),
            password: _password.text,
          );
      TextInput.finishAutofillContext();
      // The root switches to the home shell when the auth state changes.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendly(ApiException e) {
    final m = e.message.toLowerCase();
    if (m.contains('user not found')) return 'No account is registered with this mobile number.';
    if (m.contains('incorrect password')) return 'That password is incorrect. Try again or reset it.';
    return e.message;
  }

  void _fillDemo(({String mobile, String password}) demo) {
    setState(() {
      _mobile.text = demo.mobile;
      _password.text = demo.password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final demo = AppConfig.demoLogin;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SizedBox(height: Space.xxl),
                        Row(children: [
                          const BrandMark(size: 44),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(BrandConfig.appName, style: AppText.headline),
                              Text(BrandConfig.appTagline, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: Space.xxxl),
                        Semantics(header: true, child: Text('Sign in', style: AppText.title.copyWith(fontSize: 34))),
                        const SizedBox(height: Space.xs),
                        Text('Use the mobile number registered with ${BrandConfig.brandDisplayName}.',
                            style: AppText.bodySecondary),
                        const SizedBox(height: Space.xl),
                        if (_notice != null) ...[
                          _Banner(message: _notice!, tone: Tone.caution),
                          const SizedBox(height: Space.md),
                        ],
                        TextFormField(
                          controller: _mobile,
                          enabled: !_submitting,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
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
                          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: Space.md),
                        TextFormField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !_submitting,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => ForgotPasswordScreen(initialMobile: _mobile.text.trim()),
                                    )),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        if (_error != null) ...[
                          _Banner(message: _error!, tone: Tone.negative),
                          const SizedBox(height: Space.md),
                        ] else
                          const SizedBox(height: Space.xs),
                        PrimaryButton(label: 'Sign in', loading: _submitting, onPressed: _submit),
                        if (demo != null) ...[
                          const SizedBox(height: Space.md),
                          _DemoHelper(onUse: _submitting ? null : () => _fillDemo(demo)),
                        ],
                        const SizedBox(height: Space.xl),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text("Don't have an account? ", style: AppText.bodySecondary),
                            TextButton(
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.xs)),
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                      ),
                              child: const Text('Sign up'),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.md),
                        Text(
                          'Accounts can also be opened at your nearest showroom branch. '
                          'Call ${BrandConfig.supportPhone} for assistance.',
                          style: AppText.caption,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.xl),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
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
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(
          color: negative ? AppColors.negativeWash : AppColors.cautionWash,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(negative ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 20, color: negative ? AppColors.negative : AppColors.caution),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(message,
                style: AppText.small.copyWith(color: negative ? AppColors.negative : AppColors.caution, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

/// Visible only in debug/profile builds started with the DEMO_* defines.
class _DemoHelper extends StatelessWidget {
  const _DemoHelper({required this.onUse});

  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.xs, Space.xs),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(children: [
        const Icon(Icons.code_rounded, size: 18, color: AppColors.inkTertiary),
        const SizedBox(width: Space.xs),
        Expanded(child: Text('Development build', style: AppText.caption)),
        TextButton(onPressed: onUse, child: const Text('Use demo account')),
      ]),
    );
  }
}

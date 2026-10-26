import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/customer_repository.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';
import 'session.dart';

sealed class AuthState {
  const AuthState();
}

/// The app has just started and is restoring a saved session.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class SignedOut extends AuthState {
  const SignedOut({this.notice});

  /// Shown once on the sign-in screen, e.g. "Your session has expired".
  final String? notice;
}

class SignedIn extends AuthState {
  const SignedIn(this.session);

  final Session session;
}

/// Holds the live token for the HTTP client and relays "token rejected"
/// from any request to the auth controller.
class SessionHolder {
  String? token;
  void Function()? _onInvalid;

  void notifyInvalid() => _onInvalid?.call();
}

final sessionHolderProvider = Provider<SessionHolder>((ref) => SessionHolder());

final apiClientProvider = Provider<ApiClient>((ref) {
  final holder = ref.watch(sessionHolderProvider);
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    readToken: () => holder.token,
    onSessionInvalid: holder.notifyInvalid,
  );
});

final repositoryProvider = Provider<CustomerRepository>((ref) => CustomerRepository(ref.watch(apiClientProvider)));

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in session; data providers watch this so they reset on sign-out.
final sessionProvider = Provider<Session?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is SignedIn ? state.session : null;
});

class AuthController extends Notifier<AuthState> {
  static const _storage = SecureStorageService();
  static const _expiredNotice = 'Your session has expired. Please sign in again.';

  @override
  AuthState build() {
    ref.watch(sessionHolderProvider)._onInvalid = () {
      if (state is SignedIn) unawaited(signOut(notice: _expiredNotice));
    };
    return const AuthRestoring();
  }

  SessionHolder get _holder => ref.read(sessionHolderProvider);

  /// Restores the saved session, if it is still valid. Never throws.
  Future<void> restore() async {
    String? token;
    try {
      token = await _storage.readToken();
    } catch (_) {
      // Keystore entries become unreadable after a backup restore or key
      // rotation. Start clean rather than crash.
      await _safeClear();
    }

    if (token == null || token.isEmpty) {
      state = const SignedOut();
      return;
    }

    final session = Session.fromToken(token);
    if (session == null || session.isExpired) {
      await _safeClear();
      state = SignedOut(notice: session == null ? null : _expiredNotice);
      return;
    }

    _holder.token = token;
    try {
      // Confirms with the backend that the token is still accepted.
      await ref.read(repositoryProvider).fetchProfile(session.customerId);
      state = SignedIn(session);
    } on ApiException catch (e) {
      if (e.kind == ApiFailure.sessionExpired) {
        // The client already triggered sign-out; make sure the state settles.
        await _finishSignOut(_expiredNotice);
      } else if (e.isConnectivity || e.kind == ApiFailure.server) {
        // Offline or server hiccup: keep the session; screens show retry states.
        state = SignedIn(session);
      } else {
        await _finishSignOut('We could not restore your session. Please sign in again.');
      }
    } catch (_) {
      await _finishSignOut('We could not restore your session. Please sign in again.');
    }
  }

  /// Signs in through the backend. Throws [ApiException] with the backend's
  /// message ("User not found", "Incorrect password.") on rejection.
  Future<void> signIn({required String mobile, required String password}) async {
    final token = await ref.read(repositoryProvider).signIn(mobile: mobile, password: password);
    final session = Session.fromToken(token);
    if (session == null) {
      throw const ApiException('This account cannot use the customer app.', kind: ApiFailure.rejected);
    }
    await _storage.writeToken(token);
    _holder.token = token;
    state = SignedIn(session);
  }

  /// Completes customer registration on the backend and establishes an authenticated session.
  Future<void> completeSignUp({
    required String firstname,
    required String mobile,
    required String password,
    String? mpin,
    String? idBranch,
    String? email,
  }) async {
    final token = await ref.read(repositoryProvider).signupCustomer(
          firstname: firstname,
          mobile: mobile,
          password: password,
          mpin: mpin,
          idBranch: idBranch,
          email: email,
        );
    final session = Session.fromToken(token);
    if (session == null) {
      throw const ApiException('Registration succeeded, but session could not be established. Please sign in.', kind: ApiFailure.rejected);
    }
    await _storage.writeToken(token);
    _holder.token = token;
    state = SignedIn(session);
  }

  Future<void> signOut({String? notice}) => _finishSignOut(notice);

  Future<void> _finishSignOut(String? notice) async {
    _holder.token = null;
    await _safeClear();
    state = SignedOut(notice: notice);
  }

  Future<void> _safeClear() async {
    try {
      await _storage.clear();
    } catch (_) {}
  }
}

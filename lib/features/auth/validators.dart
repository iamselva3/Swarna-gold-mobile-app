/// Form validators shared by the authentication screens.
class Validators {
  Validators._();

  static final RegExp _indianMobile = RegExp(r'^[6-9]\d{9}$');

  static String? mobile(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your mobile number';
    if (v.length != 10) return 'Mobile number must be 10 digits';
    if (!_indianMobile.hasMatch(v)) return 'Enter a valid Indian mobile number';
    return null;
  }

  static String? otp(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the OTP';
    if (!RegExp(r'^\d{4,6}$').hasMatch(v)) return 'Enter the code exactly as received';
    return null;
  }

  /// Mirrors the backend rule (more than 7 characters) and adds basic strength.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choose a password';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Use letters and numbers';
    return null;
  }
}

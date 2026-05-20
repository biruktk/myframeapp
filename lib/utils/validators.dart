/// Client-side input validation (OWASP-aligned basics). Server remains authoritative.
class Validators {
  Validators._();

  static final RegExp _email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static bool isValidEmail(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v.length > 254) return false;
    return _email.hasMatch(v);
  }

  static bool isValidPassword(String raw) {
    final v = raw;
    return v.length >= 6 && v.length <= 256;
  }

  static bool isValidDisplayName(String raw) {
    final v = raw.trim();
    return v.isNotEmpty && v.length <= 128;
  }

  static String? emailError(String raw) {
    if (raw.trim().isEmpty) return 'email_required';
    if (!isValidEmail(raw)) return 'invalid_email';
    return null;
  }

  static String? passwordError(String raw) {
    if (raw.length < 6) return 'password_length';
    if (raw.length > 256) return 'password_length';
    return null;
  }

  static String? nameError(String raw) {
    if (!isValidDisplayName(raw)) return 'invalid_name';
    return null;
  }
}

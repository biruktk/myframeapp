class ErrorSanitizer {
  static String getUserFriendlyMessage(Object? error) {
    final raw = error.toString().toLowerCase();
    if (RegExp(r'connection reset|socketexception|clientexception|connection closed|network is unreachable|broken pipe|failed host lookup').hasMatch(raw)) {
      return 'Network connection interrupted. Please check your Wi-Fi or mobile data and try again.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) return 'Upload took too long. Please try uploading fewer photos at a time.';
    if (raw.contains('413') || raw.contains('too large')) return 'Selected photos are too large. Please choose compressed or smaller images.';
    if (RegExp(r'502|503|504').hasMatch(raw)) return 'Photo service is temporarily unavailable. Please try again in a few moments.';
    return 'Failed to complete photo upload. Please try again.';
  }
}

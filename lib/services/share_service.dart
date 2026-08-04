import '../l10n/app_strings.dart';

/// Outbound share / invite copy — follows the **sender's** app language.
///
/// When UI locale is Chinese (`zh`), share payloads are Simplified Chinese.
/// Otherwise English (with other locales falling back to English for share text).
class ShareService {
  ShareService._();

  static bool _isZh(AppStrings strings) => strings.locale == AppLocale.zh;

  /// Append `lang=zh` or `lang=en` so hosted pages match the share language.
  static String withShareLang(String url, AppStrings strings) {
    final lang = _isZh(strings) ? 'zh' : 'en';
    final u = url.trim();
    if (u.isEmpty) return u;
    final re = RegExp(r'([?&])lang=[^&]*', caseSensitive: false);
    if (re.hasMatch(u)) {
      return u.replaceFirstMapped(re, (m) => '${m[1]}lang=$lang');
    }
    return u.contains('?') ? '$u&lang=$lang' : '$u?lang=$lang';
  }

  /// Backward-compatible alias (forces zh landing). Prefer [withShareLang].
  static String withZhLang(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    final re = RegExp(r'([?&])lang=[^&]*', caseSensitive: false);
    if (re.hasMatch(u)) {
      return u.replaceFirstMapped(re, (m) => '${m[1]}lang=zh');
    }
    return u.contains('?') ? '$u&lang=zh' : '$u?lang=zh';
  }

  /// Family invite share-sheet **subject / title**.
  static String familyInviteSubject(AppStrings strings, String familyName) {
    final name = familyName.trim().isEmpty ? 'MyFrame' : familyName.trim();
    if (_isZh(strings)) {
      return '加入我的 MyFrame 艺术相框家庭';
    }
    return 'Join my MyFrame Family · $name';
  }

  /// Family invite share-sheet **body** (includes code + link).
  static String familyInviteShareBody({
    required AppStrings strings,
    required String familyName,
    required String inviteCode,
    required String webUrl,
  }) {
    final code = inviteCode.trim().toUpperCase();
    final url = withShareLang(webUrl, strings);
    if (_isZh(strings)) {
      return '点击链接或输入邀请码【$code】加入我的家庭相框，一起分享精彩照片！\n$url';
    }
    return 'Use invite code [$code] or tap the link to join my MyFrame family and share photos together!\n$url';
  }

  /// Guest photo → frame share title.
  static String photoShareTitle(AppStrings strings) {
    if (_isZh(strings)) return '发送照片到我的 MyFrame 艺术相框！';
    return 'Send photos to my MyFrame art frame!';
  }

  /// SMS / share-sheet body for guest photo upload link.
  static String photoInviteShareBody({
    required AppStrings strings,
    required String shareUrl,
    String? frameName,
  }) {
    final url = withShareLang(shareUrl, strings);
    final name = (frameName ?? '').trim();
    final title = photoShareTitle(strings);
    if (_isZh(strings)) {
      if (name.isNotEmpty) {
        return '$title\n「$name」\n点击链接或扫描二维码直接发送：\n$url';
      }
      return '$title\n点击链接或扫描二维码直接发送：\n$url';
    }
    if (name.isNotEmpty) {
      return '$title\n"$name"\nTap the link or scan the QR code to send:\n$url';
    }
    return '$title\nTap the link or scan the QR code to send:\n$url';
  }

  static String photoInviteSubject(AppStrings strings, String? frameName) {
    final name = (frameName ?? '').trim();
    if (_isZh(strings)) {
      if (name.isNotEmpty) return '上传照片至 $name';
      return photoShareTitle(strings);
    }
    if (name.isNotEmpty) return 'Upload photos to $name';
    return photoShareTitle(strings);
  }
}

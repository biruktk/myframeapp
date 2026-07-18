import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_diag_log.dart';
import '../services/slideshow_style.dart';
import '../theme/app_theme.dart';

/// Persisted accent color, brightness mode, and optional language override.
class AppSettings extends ChangeNotifier {
  AppAccent accent = AppAccent.red;

  /// Default **light** (matches `ra/ui` mockup); users can still pick system/dark in Settings.
  ThemeMode themeMode = ThemeMode.light;

  /// Bigger type and slightly larger hit targets (top-right Home switch).
  bool comfortMode = false;
  bool onboardingDone = false;

  /// After first onboarding completion, show coachmark on Home **+** (add frame).
  bool pendingHomeAddFrameCoachmark = false;
  bool signedIn = false;
  String? authProvider;
  /** Bearer JWT from `/api/auth/login` · `/api/auth/register`; cleared on sign-out. */
  String authToken = '';
  String authUserId = '';

  /// True only after a successful login/register (or social auth) that stored a JWT.
  bool get hasAuthenticatedSession =>
      signedIn && authToken.trim().isNotEmpty && authUserId.trim().isNotEmpty;

  /// `null` = follow device / system locale.
  String? languageCode;
  String profileName = '';
  String accountEmail = '';
  String birthday = '';

  /// Local profile photo path (device-only until backend avatar API exists).
  String profileAvatarPath = '';
  bool notifyBirthdayReminders = true;
  bool notifyPhotoDelivered = true;
  bool notifyFamilyActivity = true;
  bool notifyFrameOffline = true;
  bool notifyLikedPhotos = false;
  bool quietHoursEnabled = false;
  String quietHoursStart = '22:00';
  String quietHoursEnd = '08:00';
  int birthdayReminderLeadDays = 1;
  bool googlePhotosConnected = true;
  bool iCloudConnected = false;
  bool homeAssistantConnected = false;
  bool googlePhotosAutoSync = true;

  /// Where processed send photos are stored: `vps`, `google_photos`, or `icloud_photos`.
  String photoStorageBackend = 'vps';
  bool autoInstallUpdates = true;
  String aiApiKey = '';

  /// `openai` or `gemini` — used for Send → AI Generate.
  String aiImageProvider = 'openai';
  String aiOpenAiApiKey = '';
  String aiGeminiApiKey = '';
  bool sms2faEnabled = false;

  String get activeAiImageApiKey => aiImageProvider == 'gemini'
      ? aiGeminiApiKey.trim()
      : aiOpenAiApiKey.trim();

  /// Shown in Account / Pro; replace with entitlements from your backend.
  bool isProMember = false;

  /// Developer diagnostics; persisted for convenience.
  bool debugModeEnabled = false;

  /// When `true`, user pauses OTA (Wi‑Fi) firmware install on the frame — wire to device API when available.
  bool stopFrameFirmwareOta = false;

  /// Opening [ImageEditorScreen] without a sticky cache uses this as the slideshow preset.
  SlideshowStyle defaultSlideshowStyle = SlideshowStyle.fade;

  /// Slideshow interval in seconds (default 3 minutes = 180s)
  int slideshowIntervalSeconds = 180;

  /// Whether to show captions on the frame (when false, captions are saved but not displayed)
  bool showCaptionsOnFrame = true;

  /// OTA is allowed only when [autoInstallUpdates] is on and the device is not in "stop firmware" mode.
  bool get isFrameOtaEnabled => autoInstallUpdates && !stopFrameFirmwareOta;

  /// Unified UI: automatic Wi‑Fi OTA when on (default); off blocks auto updates.
  bool get automaticFrameFirmwareUpdates =>
      autoInstallUpdates && !stopFrameFirmwareOta;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  static const _kAccent = 'settings_accent';
  static const _kThemeMode = 'settings_theme_mode';
  static const _kLanguage = 'settings_language_code';
  static const _kComfort = 'settings_comfort_mode';
  static const _kOnboardingDone = 'settings_onboarding_done';
  static const _kPendingHomeAddCoach = 'settings_pending_home_add_coach';
  static const _kSignedIn = 'settings_signed_in';
  static const _kAuthProvider = 'settings_auth_provider';
  static const _kAuthToken = 'settings_auth_token';
  static const _kAuthUserId = 'settings_auth_user_id';
  static const _kProfileName = 'settings_profile_name';
  static const _kAccountEmail = 'settings_account_email';
  static const _kBirthday = 'settings_birthday';
  static const _kProfileAvatar = 'settings_profile_avatar_path';
  static const _kNotifyDelivered = 'settings_notify_delivered';
  static const _kNotifyFamily = 'settings_notify_family';
  static const _kNotifyBirthday = 'settings_notify_birthday';
  static const _kNotifyOffline = 'settings_notify_offline';
  static const _kQuietEnabled = 'settings_quiet_enabled';
  static const _kQuietStart = 'settings_quiet_start';
  static const _kQuietEnd = 'settings_quiet_end';
  static const _kNotifyLikedPhotos = 'settings_notify_liked_photos';
  static const _kBirthdayLeadDays = 'settings_birthday_lead_days';
  static const _kGooglePhotosConnected = 'settings_google_photos_connected';
  static const _kICloudConnected = 'settings_icloud_connected';
  static const _kHomeAssistantConnected = 'settings_home_assistant_connected';
  static const _kGooglePhotosAutoSync = 'settings_google_photos_auto_sync';
  static const _kPhotoStorageBackend = 'settings_photo_storage_backend';
  static const _kAutoInstallUpdates = 'settings_auto_install_updates';
  static const _kAiApiKey = 'settings_ai_api_key';
  static const _kAiImageProvider = 'settings_ai_image_provider';
  static const _kAiOpenAiApiKey = 'settings_ai_openai_api_key';
  static const _kAiGeminiApiKey = 'settings_ai_gemini_api_key';
  static const _kSms2faEnabled = 'settings_sms_2fa_enabled';
  static const _kProMember = 'settings_pro_member';
  static const _kDebugModeEnabled = 'settings_debug_mode_enabled';
  static const _kStopFrameFirmwareOta =
      'settings_device_stop_frame_firmware_ota';
  static const _kDefaultSlideshow = 'settings_default_slideshow_style';
  static const _kSlideshowIntervalSeconds = 'settings_slideshow_interval_seconds';
  static const _kShowCaptionsOnFrame = 'settings_show_captions_on_frame';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final a = p.getString(_kAccent);
    accent = a == AppAccent.green.name ? AppAccent.green : AppAccent.red;

    final t = p.getString(_kThemeMode);
    themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == t,
      orElse: () => ThemeMode.light,
    );

    languageCode = p.getString(_kLanguage);
    comfortMode = p.getBool(_kComfort) ?? false;
    onboardingDone = p.getBool(_kOnboardingDone) ?? false;
    pendingHomeAddFrameCoachmark = p.getBool(_kPendingHomeAddCoach) ?? false;
    signedIn = p.getBool(_kSignedIn) ?? false;
    authProvider = p.getString(_kAuthProvider);
    authToken = p.getString(_kAuthToken) ?? '';
    authUserId = p.getString(_kAuthUserId) ?? '';
    if (signedIn && !hasAuthenticatedSession) {
      signedIn = false;
      authProvider = null;
      await p.setBool(_kSignedIn, false);
      await p.remove(_kAuthProvider);
    }
    profileName = p.getString(_kProfileName) ?? '';
    accountEmail = p.getString(_kAccountEmail) ?? '';
    birthday = p.getString(_kBirthday) ?? '';
    profileAvatarPath = p.getString(_kProfileAvatar) ?? '';
    notifyBirthdayReminders = p.getBool(_kNotifyBirthday) ?? true;
    notifyPhotoDelivered = p.getBool(_kNotifyDelivered) ?? true;
    notifyFamilyActivity = p.getBool(_kNotifyFamily) ?? true;
    notifyFrameOffline = p.getBool(_kNotifyOffline) ?? true;
    notifyLikedPhotos = p.getBool(_kNotifyLikedPhotos) ?? false;
    quietHoursEnabled = p.getBool(_kQuietEnabled) ?? false;
    quietHoursStart = p.getString(_kQuietStart) ?? '22:00';
    quietHoursEnd = p.getString(_kQuietEnd) ?? '08:00';
    birthdayReminderLeadDays = p.getInt(_kBirthdayLeadDays) ?? 1;
    googlePhotosConnected = p.getBool(_kGooglePhotosConnected) ?? true;
    iCloudConnected = p.getBool(_kICloudConnected) ?? false;
    homeAssistantConnected = p.getBool(_kHomeAssistantConnected) ?? false;
    googlePhotosAutoSync = p.getBool(_kGooglePhotosAutoSync) ?? true;
    final rawPhotoStorageBackend = p.getString(_kPhotoStorageBackend) ?? 'vps';
    photoStorageBackend = _normalizePhotoStorageBackend(rawPhotoStorageBackend);
    if (photoStorageBackend != rawPhotoStorageBackend) {
      await p.setString(_kPhotoStorageBackend, photoStorageBackend);
    }
    autoInstallUpdates = p.getBool(_kAutoInstallUpdates) ?? true;
    aiApiKey = p.getString(_kAiApiKey) ?? '';
    aiImageProvider = p.getString(_kAiImageProvider) ?? 'openai';
    aiOpenAiApiKey = p.getString(_kAiOpenAiApiKey) ?? '';
    aiGeminiApiKey = p.getString(_kAiGeminiApiKey) ?? '';
    if (aiOpenAiApiKey.isEmpty && aiApiKey.isNotEmpty) {
      aiOpenAiApiKey = aiApiKey;
    }
    sms2faEnabled = p.getBool(_kSms2faEnabled) ?? false;
    isProMember = p.getBool(_kProMember) ?? false;
    debugModeEnabled = p.getBool(_kDebugModeEnabled) ?? false;
    AppDiagLog.setDebugEnabled(debugModeEnabled);
    stopFrameFirmwareOta = p.getBool(_kStopFrameFirmwareOta) ?? false;

    final sl = p.getString(_kDefaultSlideshow);
    defaultSlideshowStyle = SlideshowStyle.values.firstWhere(
      (e) => e.name == sl,
      orElse: () => SlideshowStyle.fade,
    );
    slideshowIntervalSeconds = p.getInt(_kSlideshowIntervalSeconds) ?? 180;
    showCaptionsOnFrame = p.getBool(_kShowCaptionsOnFrame) ?? true;
    notifyListeners();
  }

  /// Call after a full [SharedPreferences.clear] (e.g. debug factory reset).
  Future<void> reload() => load();

  Future<void> setAccent(AppAccent value) async {
    accent = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAccent, value.name);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, value.name);
  }

  Future<void> setComfortMode(bool value) async {
    comfortMode = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kComfort, value);
  }

  Future<void> setLanguageCode(String? code) async {
    languageCode = code;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (code == null) {
      await p.remove(_kLanguage);
    } else {
      await p.setString(_kLanguage, code);
    }
  }

  Future<void> setProfileAvatarPath(String path) async {
    profileAvatarPath = path.trim();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (profileAvatarPath.isEmpty) {
      await p.remove(_kProfileAvatar);
    } else {
      await p.setString(_kProfileAvatar, profileAvatarPath);
    }
  }

  Future<void> setAccountProfile({
    required String name,
    required String email,
    String? birthdayValue,
  }) async {
    profileName = name.trim();
    accountEmail = email.trim();
    if (birthdayValue != null) {
      birthday = birthdayValue.trim();
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProfileName, profileName);
    await p.setString(_kAccountEmail, accountEmail);
    if (birthdayValue != null) {
      if (birthday.isEmpty) {
        await p.remove(_kBirthday);
      } else {
        await p.setString(_kBirthday, birthday);
      }
    }
  }

  Future<void> setNotificationPrefs({
    required bool photoDelivered,
    required bool familyActivity,
  }) async {
    notifyPhotoDelivered = photoDelivered;
    notifyFamilyActivity = familyActivity;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifyDelivered, photoDelivered);
    await p.setBool(_kNotifyFamily, familyActivity);
  }

  Future<void> setAdvancedNotificationPrefs({
    required bool birthdayReminders,
    required int birthdayLeadDays,
    required bool photoDelivered,
    required bool newFamilyMember,
    required bool likedPhotos,
    required bool frameOffline,
    required bool quietEnabled,
    required String quietStart,
    required String quietEnd,
  }) async {
    notifyBirthdayReminders = birthdayReminders;
    birthdayReminderLeadDays = birthdayLeadDays;
    notifyPhotoDelivered = photoDelivered;
    notifyFamilyActivity = newFamilyMember;
    notifyLikedPhotos = likedPhotos;
    notifyFrameOffline = frameOffline;
    quietHoursEnabled = quietEnabled;
    quietHoursStart = quietStart;
    quietHoursEnd = quietEnd;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifyBirthday, birthdayReminders);
    await p.setInt(_kBirthdayLeadDays, birthdayLeadDays);
    await p.setBool(_kNotifyDelivered, photoDelivered);
    await p.setBool(_kNotifyFamily, newFamilyMember);
    await p.setBool(_kNotifyLikedPhotos, likedPhotos);
    await p.setBool(_kNotifyOffline, frameOffline);
    await p.setBool(_kQuietEnabled, quietEnabled);
    await p.setString(_kQuietStart, quietStart);
    await p.setString(_kQuietEnd, quietEnd);
  }

  Future<void> setIntegrationsPrefs({
    required bool googleConnected,
    required bool iCloud,
    required bool homeAssistant,
    required bool googleAutoSync,
    String? photoStorageBackend,
  }) async {
    googlePhotosConnected = googleConnected;
    iCloudConnected = iCloud;
    homeAssistantConnected = homeAssistant;
    googlePhotosAutoSync = googleAutoSync;
    if (photoStorageBackend != null) {
      this.photoStorageBackend = _normalizePhotoStorageBackend(
        photoStorageBackend,
      );
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kGooglePhotosConnected, googleConnected);
    await p.setBool(_kICloudConnected, iCloud);
    await p.setBool(_kHomeAssistantConnected, homeAssistant);
    await p.setBool(_kGooglePhotosAutoSync, googleAutoSync);
    if (photoStorageBackend != null) {
      await p.setString(_kPhotoStorageBackend, this.photoStorageBackend);
    }
  }

  Future<void> setPhotoStorageBackend(String backend) async {
    photoStorageBackend = _normalizePhotoStorageBackend(backend);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPhotoStorageBackend, photoStorageBackend);
  }

  String _normalizePhotoStorageBackend(String backend) {
    switch (backend) {
      case 'google_drive':
        return 'google_photos';
      case 'dropbox':
        return 'icloud_photos';
      case 'google_photos':
      case 'icloud_photos':
      case 'vps':
        return backend;
      default:
        return 'vps';
    }
  }

  Future<void> setAppPreferences({
    required ThemeMode mode,
    required bool updates,
    String? apiKey,
    bool? sms2fa,
  }) async {
    themeMode = mode;
    autoInstallUpdates = updates;
    stopFrameFirmwareOta = !updates;
    if (apiKey != null) {
      aiApiKey = apiKey.trim();
      aiOpenAiApiKey = apiKey.trim();
    }
    if (sms2fa != null) sms2faEnabled = sms2fa;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, mode.name);
    await p.setBool(_kAutoInstallUpdates, updates);
    await p.setBool(_kStopFrameFirmwareOta, !updates);
    if (apiKey != null) {
      await p.setString(_kAiApiKey, aiApiKey);
      await p.setString(_kAiOpenAiApiKey, aiOpenAiApiKey);
    }
    if (sms2fa != null) await p.setBool(_kSms2faEnabled, sms2fa);
  }

  Future<void> setAiImageSettings({
    required String provider,
    required String openAiKey,
    required String geminiKey,
  }) async {
    aiImageProvider = provider == 'gemini' ? 'gemini' : 'openai';
    aiOpenAiApiKey = openAiKey.trim();
    aiGeminiApiKey = geminiKey.trim();
    aiApiKey = aiOpenAiApiKey;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAiImageProvider, aiImageProvider);
    await p.setString(_kAiOpenAiApiKey, aiOpenAiApiKey);
    await p.setString(_kAiGeminiApiKey, aiGeminiApiKey);
    await p.setString(_kAiApiKey, aiOpenAiApiKey);
  }

  Future<void> setOnboardingDone(bool value) async {
    onboardingDone = value;
    if (value) {
      pendingHomeAddFrameCoachmark = true;
    } else {
      pendingHomeAddFrameCoachmark = false;
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOnboardingDone, value);
    if (value) {
      await p.setBool(_kPendingHomeAddCoach, true);
    } else {
      await p.remove(_kPendingHomeAddCoach);
    }
  }

  Future<void> clearHomeAddFrameCoachmark() async {
    pendingHomeAddFrameCoachmark = false;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPendingHomeAddCoach);
  }

  Future<void> setSignedIn({required bool value, String? provider}) async {
    if (value && !hasAuthenticatedSession) {
      return;
    }
    signedIn = value;
    authProvider = value ? provider : null;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSignedIn, value);
    if (value && provider != null && provider.isNotEmpty) {
      await p.setString(_kAuthProvider, provider);
    } else {
      await p.remove(_kAuthProvider);
    }
    if (!value) {
      await clearAuthJwt();
    }
  }

  /// Persists JWT + marks the user signed in (required before [MainShell]).
  Future<void> completeAuthenticatedSession({
    required String token,
    required String userId,
    String provider = 'email',
  }) async {
    final cleanToken = token.trim();
    final cleanUserId = userId.trim();
    if (cleanToken.isEmpty || cleanUserId.isEmpty) return;
    authToken = cleanToken;
    authUserId = cleanUserId;
    signedIn = true;
    authProvider = provider;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAuthToken, cleanToken);
    await p.setString(_kAuthUserId, cleanUserId);
    await p.setBool(_kSignedIn, true);
    await p.setString(_kAuthProvider, provider);
  }

  /// Persists Bearer JWT returned by `/api/auth/login` or `/api/auth/register`.
  Future<void> setAuthJwt({
    required String token,
    required String userId,
  }) async {
    authToken = token.trim();
    authUserId = userId.trim();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    if (authToken.isEmpty) {
      await p.remove(_kAuthToken);
    } else {
      await p.setString(_kAuthToken, authToken);
    }
    if (authUserId.isEmpty) {
      await p.remove(_kAuthUserId);
    } else {
      await p.setString(_kAuthUserId, authUserId);
    }
  }

  Future<void> clearAuthJwt() async {
    authToken = '';
    authUserId = '';
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAuthToken);
    await p.remove(_kAuthUserId);
  }

  Future<void> setProMember(bool value) async {
    isProMember = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kProMember, value);
  }

  Future<void> setDebugModeEnabled(bool value) async {
    debugModeEnabled = value;
    AppDiagLog.setDebugEnabled(value);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDebugModeEnabled, value);
  }

  Future<void> setStopFrameFirmwareOta(bool value) async {
    stopFrameFirmwareOta = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kStopFrameFirmwareOta, value);
  }

  /// Single switch: **on** = allow automatic OTA over Wi‑Fi; **off** = block automatic updates.
  Future<void> setAutomaticFrameFirmwareUpdates(bool enabled) async {
    autoInstallUpdates = enabled;
    stopFrameFirmwareOta = !enabled;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAutoInstallUpdates, enabled);
    await p.setBool(_kStopFrameFirmwareOta, !enabled);
  }

  Future<void> setDefaultSlideshowStyle(SlideshowStyle value) async {
    defaultSlideshowStyle = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDefaultSlideshow, value.name);
  }

  Future<void> setSlideshowIntervalSeconds(int value) async {
    slideshowIntervalSeconds = value.clamp(10, 3600);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kSlideshowIntervalSeconds, slideshowIntervalSeconds);
  }

  Future<void> setShowCaptionsOnFrame(bool value) async {
    showCaptionsOnFrame = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kShowCaptionsOnFrame, value);
  }
}

/// Provides [AppSettings] to the tree (listens via [ListenableBuilder] in [main.dart]).
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    required AppSettings super.notifier,
    required super.child,
    super.key,
  });

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found');
    return scope!.notifier!;
  }
}

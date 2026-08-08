import 'package:flutter/material.dart';

import '../models/faq_item.dart';
import '../theme/app_theme.dart';

enum AppLocale { en, zh, es, fr, de, ja }

class AppStrings {
  AppStrings(this.locale);

  final AppLocale locale;

  static AppStrings of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final loc = switch (code) {
      'zh' => AppLocale.zh,
      'es' => AppLocale.es,
      'fr' => AppLocale.fr,
      'de' => AppLocale.de,
      'ja' => AppLocale.ja,
      _ => AppLocale.en,
    };
    return AppStrings(loc);
  }

  String _l6({
    required String en,
    required String zh,
    required String es,
    required String fr,
    required String de,
    required String ja,
  }) {
    return switch (locale) {
      AppLocale.zh => zh,
      AppLocale.es => es,
      AppLocale.fr => fr,
      AppLocale.de => de,
      AppLocale.ja => ja,
      _ => en,
    };
  }

  // —— General ——
  String get appName => _l6(
    en: 'MyFrame',
    zh: 'MyFrame',
    es: 'MyFrame',
    fr: 'MyFrame',
    de: 'MyFrame',
    ja: 'MyFrame',
  );
  String get skipLabel => _l6(
    en: 'Skip',
    zh: '跳过',
    es: 'Saltar',
    fr: 'Passer',
    de: 'Überspringen',
    ja: 'スキップ',
  );
  String get nextLabel => _l6(
    en: 'Next',
    zh: '下一步',
    es: 'Siguiente',
    fr: 'Suivant',
    de: 'Weiter',
    ja: '次へ',
  );
  String get getStarted => _l6(
    en: 'Get Started',
    zh: '开始使用',
    es: 'Comenzar',
    fr: 'Commencer',
    de: 'Loslegen',
    ja: 'はじめる',
  );
  String get onboardTitle1 => _l6(
    en: 'Wedding',
    zh: '婚礼',
    es: 'Boda',
    fr: 'Mariage',
    de: 'Hochzeit',
    ja: 'ウェディング',
  );
  String get onboardDesc1 => _l6(
    en: 'Relive your ceremony and reception on the frame—elegant highlights for the mantel or gift table.',
    zh: '在相框上重温婚礼与宴会瞬间，适合客厅或礼品桌展示。',
    es: 'Revive la ceremonia y la fiesta en el marco.',
    fr: 'Revivez cérémonie et fête sur le cadre.',
    de: 'Zeremonie und Feier auf dem Rahmen erleben.',
    ja: '挙式とパーティーのハイライトをフレームで。',
  );
  String get onboardTitle2 => _l6(
    en: 'Family',
    zh: '家庭',
    es: 'Familia',
    fr: 'Famille',
    de: 'Familie',
    ja: '家族',
  );
  String get onboardDesc2 => _l6(
    en: 'Keep parents and grandparents close—new photos land on their MyFrame without fuss.',
    zh: '让父母辈随时看到新照片，轻松同步到他们的 MyFrame。',
    es: 'Padres y abuelos al día: fotos nuevas en su MyFrame.',
    fr: 'Parents et grands-parents : nouvelles photos sur leur MyFrame.',
    de: 'Eltern und Großeltern: neue Fotos auf ihrem MyFrame.',
    ja: '両親や祖父母に、新しい写真をすぐ届けます。',
  );
  String get onboardTitle3 => _l6(
    en: 'Kids’ birthday',
    zh: '孩子生日',
    es: 'Cumple infantil',
    fr: 'Anniversaire enfant',
    de: 'Kindergeburtstag',
    ja: '子どもの誕生日',
  );
  String get onboardDesc3 => _l6(
    en: 'Balloons, cake, and candid moments—celebrate milestones on the wall every day.',
    zh: '气球、蛋糕与抓拍，把成长的纪念留在墙上每天看见。',
    es: 'Globos, tarta y risas en el marco todos los días.',
    fr: 'Ballons, gâteau et sourires au quotidien sur le cadre.',
    de: 'Ballons, Kuchen und Lachen — jeden Tag sichtbar.',
    ja: '風船やケーキ、思い出の一コマを毎日。',
  );
  String get onboardTitle4 => _l6(
    en: 'Pets',
    zh: '宠物',
    es: 'Mascotas',
    fr: 'Animaux',
    de: 'Haustiere',
    ja: 'ペット',
  );
  String get onboardDesc4 => _l6(
    en: 'Your cat, dog, or other companions deserve the spotlight—rotate favorite pet portraits with the family.',
    zh: '猫狗毛孩也能上墙，和家人一起轮播最爱的宠物写真。',
    es: 'Mascotas al centro: retratos favoritos en rotación.',
    fr: 'Vos compagnons mis à l’honneur en rotation.',
    de: 'Lieblingstiere im Wechsel auf dem Rahmen.',
    ja: 'ペットのお気に入り写真を家族とローテーション。',
  );
  String get onboardingLanguageHint => _l6(
    en: 'Language',
    zh: '语言',
    es: 'Idioma',
    fr: 'Langue',
    de: 'Sprache',
    ja: '言語',
  );
  String get welcomeBackTitle => _l6(
    en: 'Welcome',
    zh: '欢迎',
    es: 'Bienvenido',
    fr: 'Bienvenue',
    de: 'Willkommen',
    ja: 'ようこそ',
  );
  String get loginLabel => _l6(
    en: 'Login',
    zh: '登录',
    es: 'Iniciar sesión',
    fr: 'Connexion',
    de: 'Anmelden',
    ja: 'ログイン',
  );
  String get sessionExpiredTitle => _l6(
    en: 'Session expired',
    zh: '登录已过期',
    es: 'Sesión expirada',
    fr: 'Session expirée',
    de: 'Sitzung abgelaufen',
    ja: 'セッションの有効期限切れ',
  );
  String get sessionExpiredMessage => _l6(
    en: 'Your session has expired. Please log in again.',
    zh: '您的登录已过期，请重新登录。',
    es: 'Su sesión ha expirado. Vuelva a iniciar sesión.',
    fr: 'Votre session a expiré. Veuillez vous reconnecter.',
    de: 'Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.',
    ja: 'セッションが切れました。再度ログインしてください。',
  );
  String get registerLabel => _l6(
    en: 'Register',
    zh: '注册',
    es: 'Registrarse',
    fr: 'Inscription',
    de: 'Registrieren',
    ja: '登録',
  );
  /** One-tap demo: creates account or logs in for testing against API_BASE. */
  String get authQuickTestButton => _l6(
    en: 'Quick test (register or sign in)',
    zh: '快捷测试（注册或登录）',
    es: 'Prueba rápida',
    fr: 'Test rapide',
    de: 'Schnelltest',
    ja: 'テストで続行',
  );
  String get authBusyLabel => _l6(
    en: 'Please wait…',
    zh: '请稍候…',
    es: 'Espere…',
    fr: 'Patientez…',
    de: 'Bitte warten…',
    ja: 'お待ちください…',
  );
  String get authErrorNetwork => _l6(
    en: 'No connection, check your internet.',
    zh: '无网络连接，请检查网络。',
    es: 'Sin conexión.',
    fr: 'Pas de connexion.',
    de: 'Keine Verbindung.',
    ja: '接続がありません。',
  );
  String get authErrorServer => _l6(
    en: 'Server error, please try again.',
    zh: '服务器错误，请稍后再试。',
    es: 'Error del servidor.',
    fr: 'Erreur serveur.',
    de: 'Serverfehler.',
    ja: 'サーバーエラー。',
  );
  String get authErrorInvalidFields => _l6(
    en: 'Enter email and password (6+ characters).',
    zh: '请输入邮箱和密码（至少6位）',
    es: 'Introduce email y contraseña',
    fr: 'Email et mot de passe requis',
    de: 'E-Mail und Passwort nötig',
    ja: 'メールとパスワードを入力',
  );
  String get authErrorRegisterFields => _l6(
    en: 'Enter username, email, and password (6+ characters).',
    zh: '请输入用户名、邮箱和密码（至少6位）。',
    es: 'Usuario, email y contraseña.',
    fr: 'Nom, e-mail et mot de passe.',
    de: 'Benutzername, E-Mail und Passwort.',
    ja: 'ユーザー名・メール・パスワードを入力',
  );
  String get authErrorEmailTaken => _l6(
    en: 'That email is already registered — try Login.',
    zh: '邮箱已注册，请使用登录',
    es: 'Este email ya está registrado',
    fr: 'Email déjà utilisé',
    de: 'E-Mail schon vergeben',
    ja: 'メールは既に登録されています',
  );
  String get authErrorInvalidCredentials => _l6(
    en: 'Wrong email or password.',
    zh: '邮箱或密码错误',
    es: 'Datos incorrectos',
    fr: 'Identifiants incorrects',
    de: 'Falsche Zugangsdaten',
    ja: '認証に失敗しました',
  );
  String get authErrorEmailNotVerified => _l6(
    en: 'Please verify your email first. Check your inbox for the verification link.',
    zh: '请先验证邮箱。请查收收件箱中的验证链接。',
    es: 'Primero verifica tu correo. Revisa tu bandeja de entrada.',
    fr: 'Veuillez d\'abord vérifier votre e-mail. Consultez votre boîte de réception.',
    de: 'Bitte bestätigen Sie zuerst Ihre E-Mail. Prüfen Sie Ihren Posteingang.',
    ja: '先にメールを確認してください。受信箱の確認リンクをご確認ください。',
  );
  String get authErrorMobileAdminToken => _l6(
    en:
        'Sign-in reached the server but the mobile admin token was rejected. '
        'Set MOBILE_ADMIN_TOKEN on the VPS and rebuild the app with the same '
        'value: flutter run --dart-define=MOBILE_ADMIN_TOKEN=your_secret',
    zh: '已连接服务器，但移动应用 admin token 被拒绝。请在 VPS 设置 MOBILE_ADMIN_TOKEN，并用相同值重新编译应用。',
    es: 'El servidor rechazó el token de administración móvil.',
    fr: 'Le jeton admin mobile a été refusé par le serveur.',
    de: 'Der mobile Admin-Token wurde vom Server abgelehnt.',
    ja: 'サーバーはモバイル admin トークンを拒否しました。',
  );
  String get authErrorAppleFailed => _l6(
    en: 'Apple sign-in failed. Try again or use email login.',
    zh: 'Apple 登录失败，请重试或使用邮箱登录。',
    es: 'Error al iniciar sesión con Apple.',
    fr: 'Échec de la connexion Apple.',
    de: 'Apple-Anmeldung fehlgeschlagen.',
    ja: 'Apple ログインに失敗しました。',
  );
  String get authErrorAppleTokenRejected => _l6(
    en:
        'Apple verified on this iPhone, but the MyFrame API could not accept the token. '
        'Check Sign in with Apple is enabled for bundle com.myframe.minyuex on the server.',
    zh: '本机 Apple 验证成功，但 MyFrame 服务器未接受该令牌。请确认服务端已配置 Apple 登录。',
    es: 'Apple OK en el iPhone, pero la API MyFrame rechazó el token.',
    fr: 'Apple a validé sur l’iPhone, mais l’API MyFrame a refusé le jeton.',
    de: 'Apple auf dem iPhone OK, aber die MyFrame-API hat das Token abgelehnt.',
    ja: 'iPhone の Apple 認証は成功しましたが、MyFrame API がトークンを拒否しました。',
  );
  String get authErrorAppleServerRoute => _l6(
    en:
        'Apple sign-in route is not available on the API (POST /api/auth/apple). '
        'Update the VPS myframe-server or use email / Google sign-in.',
    zh: 'API 上未启用 Apple 登录路由（POST /api/auth/apple）。请更新 VPS 服务端或使用邮箱/Google 登录。',
    es: 'La ruta de Apple no está disponible en la API.',
    fr: 'La route Apple n’est pas disponible sur l’API.',
    de: 'Apple-Anmelderoute auf der API nicht verfügbar.',
    ja: 'API で Apple ログインルートが利用できません。',
  );
  String get authErrorWeChatFailed => _l6(
    en: 'WeChat sign-in failed. Try again or use email login.',
    zh: '微信登录失败，请重试或使用邮箱登录。',
    es: 'Error al iniciar sesión con WeChat.',
    fr: 'Échec de la connexion WeChat.',
    de: 'WeChat-Anmeldung fehlgeschlagen.',
    ja: 'WeChat ログインに失敗しました。',
  );
  String get authErrorWeChatTimeout => _l6(
    en: 'WeChat sign-in timed out. Open WeChat, approve login, then try again.',
    zh: '微信登录超时。请打开微信授权后重试。',
    es: 'Tiempo de espera agotado en WeChat.',
    fr: 'Délai WeChat dépassé.',
    de: 'WeChat-Anmeldung Zeitüberschreitung.',
    ja: 'WeChat ログインがタイムアウトしました。',
  );
  String get authErrorWeChatServerRoute => _l6(
    en:
        'WeChat login route failed on the API (POST /api/auth/wechat/login). '
        'Update the VPS myframe-server (WECHAT_APPID / WECHAT_APPSECRET) or use email / Google sign-in.',
    zh: '微信登录 API 路由失败（POST /api/auth/wechat/login）。请更新 VPS 服务端微信配置（WECHAT_APPID / WECHAT_APPSECRET）或使用邮箱/Google 登录。',
    es: 'La ruta WeChat falló en la API.',
    fr: 'La route WeChat a échoué sur l’API.',
    de: 'WeChat-Route auf der API fehlgeschlagen.',
    ja: 'API の WeChat ログインルートに失敗しました。',
  );
  String get authErrorBadResponse => _l6(
    en: 'Login server returned an invalid response. Use the MyFrame API URL (e.g. http://IP:3001), not the marketing site.',
    zh: '登录接口返回格式错误。请使用 MyFrame API 地址（如 http://IP:3001），不要用营销主页。',
    es: 'Respuesta inválida del servidor de autenticación. Use la URL de la API (http://…:3001).',
    fr: 'Réponse serveur invalide. Utilisez l’URL de l’API MyFrame (http://…:3001).',
    de: 'Ungültige Server-Antwort. Nutzen Sie die MyFrame-API-URL (http://…:3001).',
    ja: '認証サーバーの応答が不正です。MyFrame の API（http://IP:3001 など）を指定してください。',
  );
  String get authErrorPasswordLength => _l6(
    en: 'Password must be at least 6 characters.',
    zh: '密码至少 6 位',
    es: 'La contraseña debe tener al menos 6 caracteres.',
    fr: 'Le mot de passe doit contenir au moins 6 caractères.',
    de: 'Passwort mindestens 6 Zeichen.',
    ja: 'パスワードは 6 文字以上にしてください。',
  );
  String get passwordLabel => _l6(
    en: 'Password',
    zh: '密码',
    es: 'Contraseña',
    fr: 'Mot de passe',
    de: 'Passwort',
    ja: 'パスワード',
  );
  String get orContinueWith => _l6(
    en: 'or continue with',
    zh: '或使用以下方式继续',
    es: 'o continuar con',
    fr: 'ou continuer avec',
    de: 'oder fortfahren mit',
    ja: 'または次で続行',
  );
  String get continueGoogle => _l6(
    en: 'Continue with Google',
    zh: '使用 Google 继续',
    es: 'Continuar con Google',
    fr: 'Continuer avec Google',
    de: 'Mit Google fortfahren',
    ja: 'Google で続ける',
  );
  String get continueFacebook => _l6(
    en: 'Continue with Facebook',
    zh: '使用 Facebook 继续',
    es: 'Continuar con Facebook',
    fr: 'Continuer avec Facebook',
    de: 'Mit Facebook fortfahren',
    ja: 'Facebook で続ける',
  );
  String get continueWeChat => _l6(
    en: 'Continue with WeChat',
    zh: '使用微信继续',
    es: 'Continuar con WeChat',
    fr: 'Continuer avec WeChat',
    de: 'Mit WeChat fortfahren',
    ja: 'WeChat で続ける',
  );
  String get continueApple => _l6(
    en: 'Continue with Apple',
    zh: '使用 Apple 继续',
    es: 'Continuar con Apple',
    fr: 'Continuer avec Apple',
    de: 'Mit Apple fortfahren',
    ja: 'Apple で続ける',
  );
  String get authScreenTagline => _l6(
    en: 'Sign in to sync photos with your frames',
    zh: '登录后即可与相框同步照片',
    es: 'Inicia sesión para sincronizar',
    fr: 'Connectez-vous pour synchroniser',
    de: 'Anmelden, um zu synchronisieren',
    ja: 'ログインしてフレームと同期',
  );
  String get authUsernameLabel => _l6(
    en: 'Username',
    zh: '用户名',
    es: 'Usuario',
    fr: "Nom d'utilisateur",
    de: 'Benutzername',
    ja: 'ユーザー名',
  );
  String get authSocialDividerLabel => _l6(
    en: 'Third-party sign-in',
    zh: '第三方账号登录',
    es: 'Otras cuentas',
    fr: 'Autres comptes',
    de: 'Andere Konten',
    ja: 'その他のログイン',
  );
  String get authWeChatSoon => _l6(
    en: 'WeChat login is coming soon.',
    zh: '微信登录即将开放。',
    es: 'WeChat pronto.',
    fr: 'WeChat bientôt.',
    de: 'WeChat folgt in Kürze.',
    ja: 'WeChat 対応予定です。',
  );
  String get authGoogleNoIdToken => _l6(
    en: 'Could not get a Google sign-in token. Check Google Play services (Android) or try again.',
    zh: '无法获取 Google 登录凭据，请检查网络或稍后再试。',
    es: 'No se pudo obtener el token de Google.',
    fr: 'Impossible d’obtenir le jeton Google.',
    de: 'Google-Token fehlgeschlagen.',
    ja: 'Google のトークンを取得できませんでした。',
  );
  String get authGoogleNotConfigured => _l6(
    en: 'Google Sign-In is not configured yet. Add GOOGLE_SERVER_CLIENT_ID when building the app.',
    zh: 'Google 登录尚未配置。请在编译应用时添加 GOOGLE_SERVER_CLIENT_ID。',
    es: 'Google Sign-In no está configurado.',
    fr: 'Connexion Google non configurée.',
    de: 'Google-Anmeldung ist nicht konfiguriert.',
    ja: 'Google ログインは未設定です。',
  );
  String get authGoogleSignInFailed => _l6(
    en: 'Google sign-in failed. Try again or use email sign-up.',
    zh: 'Google 登录失败，请重试或使用邮箱注册。',
    es: 'Error al iniciar sesión con Google.',
    fr: 'Échec de la connexion Google.',
    de: 'Google-Anmeldung fehlgeschlagen.',
    ja: 'Google ログインに失敗しました。',
  );
  String get authGoogleCanceled => _l6(
    en: 'Google sign-in was canceled.',
    zh: '已取消 Google 登录。',
    es: 'Inicio de sesión con Google cancelado.',
    fr: 'Connexion Google annulée.',
    de: 'Google-Anmeldung abgebrochen.',
    ja: 'Google ログインがキャンセルされました。',
  );
  String get authGoogleBrowserHint => _l6(
    en: 'Could not complete Google sign-in. Check network and that the API is running, then try again.',
    zh: 'Google 登录未完成。请在 Google Cloud 的 Web 客户端「已获授权的 JavaScript 来源」中添加 API 地址（如 https://myframe.ink）后重试。',
    es: 'No se pudo completar Google. Añade el origen JavaScript de la API en Google Cloud.',
    fr: 'Connexion Google impossible. Ajoutez l’origine JavaScript de l’API dans Google Cloud.',
    de: 'Google-Anmeldung fehlgeschlagen. API-URL als JavaScript-Ursprung in Google Cloud eintragen.',
    ja: 'Google ログインを完了できませんでした。Google Cloud の Web クライアントに API の JavaScript オリジンを追加してください。',
  );
  String get authGoogleBrowserFailed => _l6(
    en: 'Could not open the browser for Google sign-in.',
    zh: '无法打开浏览器进行 Google 登录。',
    es: 'No se pudo abrir el navegador.',
    fr: 'Impossible d’ouvrir le navigateur.',
    de: 'Browser konnte nicht geöffnet werden.',
    ja: 'ブラウザを開けませんでした。',
  );
  String get authGoogleAndroidSetup => _l6(
    en:
        'Google Sign-In is not configured for this Android build.\n\n'
        'In Google Cloud Console → APIs & Services → Credentials, add:\n'
        '1) OAuth Android client — ID 824694546060-9rlpc8r18kv38t0lvdkktbeai8nn7s58…, package com.myframe.minyuex, SHA-1 68:29:F9:6E:9D:40:58:02:32:2E:21:E0:19:88:76:DD:02:9C:4B:77\n'
        '2) OAuth Web client — ID must match the app serverClientId (35227816140-is97hmj34o8h3t0erdnd0r10d1k0ajld.apps.googleusercontent.com).\n\n'
        'Save, wait ~10 minutes, then reinstall the APK.',
    zh:
        '此 Android 版本尚未配置 Google 登录。\n'
        '请在 Google Cloud → 凭据 中添加 Android OAuth（包名 com.myframe.minyuex + SHA-1），'
        '并确保 Web 客户端 ID 与应用 serverClientId 一致。保存后等待约 10 分钟再重装应用。',
    es: 'Añade cliente OAuth Android (com.myframe.minyuex + SHA-1) en Google Cloud.',
    fr: 'Ajoutez un client OAuth Android (com.myframe.minyuex + SHA-1).',
    de: 'Android-OAuth-Client (com.myframe.minyuex + SHA-1) in Google Cloud anlegen.',
    ja: 'Google Cloud で Android OAuth（com.myframe.minyuex + SHA-1）を設定してください。',
  );
  String get authAppleOnlyOnIos => _l6(
    en: 'Sign in with Apple is available on iPhone and iPad.',
    zh: '通过 Apple 登录仅在 iPhone / iPad 上提供。',
    es: 'Apple Sign In solo en iOS.',
    fr: 'Apple Sign In sur iOS uniquement.',
    de: 'Apple-Anmeldung nur unter iOS.',
    ja: 'Apple ログインは iOS でご利用いただけます。',
  );

  String get navHome => _l6(
    en: 'Home',
    zh: '首页',
    es: 'Inicio',
    fr: 'Accueil',
    de: 'Start',
    ja: 'ホーム',
  );
  String get navSend => _l6(
    en: 'Send',
    zh: '发送',
    es: 'Enviar',
    fr: 'Envoyer',
    de: 'Senden',
    ja: '送信',
  );
  String get navPlaylist => _l6(
    en: 'Playlist',
    zh: '播放列表',
    es: 'Lista',
    fr: 'Liste',
    de: 'Wiedergabe',
    ja: 'プレイリスト',
  );
  String get navFamily => _l6(
    en: 'Family',
    zh: '家庭',
    es: 'Familia',
    fr: 'Famille',
    de: 'Familie',
    ja: '家族',
  );
  String get navSettings => _l6(
    en: 'Settings',
    zh: '设置',
    es: 'Ajustes',
    fr: 'Réglages',
    de: 'Einstellungen',
    ja: '設定',
  );

  String get navMyFrames => _l6(
    en: 'My Frames',
    zh: '我的相框',
    es: 'Mis marcos',
    fr: 'Mes cadres',
    de: 'Meine Rahmen',
    ja: 'マイフレーム',
  );
  String get navGallery => _l6(
    en: 'Gallery',
    zh: '相册',
    es: 'Galería',
    fr: 'Galerie',
    de: 'Galerie',
    ja: 'ギャラリー',
  );

  String get welcomeInkTitle => _l6(
    en: 'Start using MyFrame',
    zh: '开始使用 MyFrame',
    es: 'Empieza con MyFrame',
    fr: 'Commencer avec MyFrame',
    de: 'Starte mit MyFrame',
    ja: 'MyFrame を始める',
  );
  String get welcomeInkSubtitle => _l6(
    en: 'Pair your frame, then send photos from your phone.',
    zh: '配对相框后，即可从手机发送照片。',
    es: 'Empareja el marco y envía fotos desde el móvil.',
    fr: 'Associez le cadre, puis envoyez des photos.',
    de: 'Rahmen koppeln, dann Fotos vom Handy senden.',
    ja: 'フレームとペアして、写真を送ります。',
  );
  String get onboardStepPowerTitle => _l6(
    en: 'Power On',
    zh: '开机',
    es: 'Encender',
    fr: 'Mise sous tension',
    de: 'Einschalten',
    ja: '電源',
  );
  String get onboardStepPowerBody => _l6(
    en: 'Hold power 5 seconds.',
    zh: '长按电源 5 秒。',
    es: 'Mantén encendido 5 s.',
    fr: 'Maintenez power 5 s.',
    de: 'Power 5 s halten.',
    ja: '電源を 5 秒長押し。',
  );
  String get onboardStepPairTitle => _l6(
    en: 'Pairing',
    zh: '配对',
    es: 'Emparejamiento',
    fr: 'Appairage',
    de: 'Kopplung',
    ja: 'ペア設定',
  );
  String get onboardStepPairBody => _l6(
    en: 'Scan & pair via Bluetooth.',
    zh: '蓝牙扫描并配对。',
    es: 'Escanea y empareja por Bluetooth.',
    fr: 'Scannez et associez en Bluetooth.',
    de: 'Scannen & per Bluetooth koppeln.',
    ja: 'Bluetooth でスキャン・ペア。',
  );
  String get onboardStepSendTitle => _l6(
    en: 'Send',
    zh: '发送',
    es: 'Enviar',
    fr: 'Envoyer',
    de: 'Senden',
    ja: '送信',
  );
  String get onboardStepSendBody => _l6(
    en: 'Pick photos & send to frame.',
    zh: '选照片并发送到相框。',
    es: 'Elige fotos y envía al marco.',
    fr: 'Choisissez et envoyez au cadre.',
    de: 'Fotos wählen & an Rahmen senden.',
    ja: '写真を選んでフレームへ送信。',
  );
  String get onboardingConnectNow => _l6(
    en: 'Connect Now',
    zh: '立即连接',
    es: 'Conectar ahora',
    fr: 'Connecter',
    de: 'Jetzt verbinden',
    ja: '今すぐ接続',
  );
  String get onboardingLater => _l6(
    en: 'Not now',
    zh: '稍后再说',
    es: 'Ahora no',
    fr: 'Pas maintenant',
    de: 'Nicht jetzt',
    ja: 'あとで',
  );
  String get coachAddFrameTitle => _l6(
    en: 'Add a frame',
    zh: '添加相框',
    es: 'Añadir marco',
    fr: 'Ajouter un cadre',
    de: 'Rahmen hinzufügen',
    ja: 'フレームを追加',
  );
  String get coachAddFrameBody => _l6(
    en: 'Tap + here to scan and pair a new frame.',
    zh: '点击右上角 + 扫描并配对新的相框。',
    es: 'Pulsa + para buscar y emparejar un marco nuevo.',
    fr: 'Appuyez sur + pour ajouter un cadre.',
    de: 'Tippe auf +, um einen neuen Rahmen zu koppeln.',
    ja: '右上の + から新しいフレームを追加できます。',
  );
  String get coachGotIt => _l6(
    en: 'Got it',
    zh: '知道了',
    es: 'Entendido',
    fr: 'OK',
    de: 'Alles klar',
    ja: '了解',
  );
  String get coachResend => _l6(
    en: 'Resend Email',
    zh: '重新发送',
    es: 'Reenviar correo',
    fr: 'Renvoyer l\'e-mail',
    de: 'E-Mail erneut senden',
    ja: '再送信',
  );

  String get myFramesTitle => _l6(
    en: 'My Frames',
    zh: '我的相框',
    es: 'Mis marcos',
    fr: 'Mes cadres',
    de: 'Meine Rahmen',
    ja: 'マイフレーム',
  );
  String get myFramesSubtitle => _l6(
    en: 'Send photos instantly',
    zh: '即刻传送美好照片',
    es: 'Envía fotos al instante',
    fr: 'Envoyez des photos instantanément',
    de: 'Fotos sofort senden',
    ja: '写真をすぐに送信',
  );
  String get activeFrameLabel => _l6(
    en: 'Active',
    zh: '当前',
    es: 'Activo',
    fr: 'Actif',
    de: 'Aktiv',
    ja: '使用中',
  );
  String get framesSummaryLine => _l6(
    en: '{total} Frames ({online} Online · {offline} Offline)',
    zh: '{total} 台相框（在线 {online} · 离线 {offline}）',
    es: '{total} marcos ({online} en línea · {offline} fuera)',
    fr: '{total} cadres ({online} en ligne · {offline} hors ligne)',
    de: '{total} Rahmen ({online} online · {offline} offline)',
    ja: '{total} 台（オンライン {online} · オフライン {offline}）',
  );

  String framesSummaryResolved(int total, int online, int offline) =>
      framesSummaryLine
          .replaceAll('{total}', '$total')
          .replaceAll('{online}', '$online')
          .replaceAll('{offline}', '$offline');
  String get frameModelDefault => _l6(
    en: 'artistic frame',
    zh: '艺术相框',
    es: 'marco artístico',
    fr: 'cadre artistique',
    de: 'Kunstbilderrahmen',
    ja: 'アートフレーム',
  );
  String get statusFrame => _l6(
    en: 'Frame',
    zh: '台相框',
    es: 'marco',
    fr: 'cadre',
    de: 'Rahmen',
    ja: '台',
  );
  String get statusFrames => _l6(
    en: 'Frames',
    zh: '台相框',
    es: 'marcos',
    fr: 'cadres',
    de: 'Rahmen',
    ja: '台',
  );
  String get statusOnline => _l6(
    en: 'Online',
    zh: '在线',
    es: 'En línea',
    fr: 'En ligne',
    de: 'Online',
    ja: 'オンライン',
  );
  String get statusOffline => _l6(
    en: 'Offline',
    zh: '离线',
    es: 'Fuera de línea',
    fr: 'Hors ligne',
    de: 'Offline',
    ja: 'オフライン',
  );
  String get shareToFamily => _l6(
    en: 'Share',
    zh: '分享',
    es: 'Compartir',
    fr: 'Partager',
    de: 'Teilen',
    ja: '共有',
  );
  String get galleryRecentlySentTab => _l6(
    en: 'Sent',
    zh: '已发送',
    es: 'Enviadas',
    fr: 'Envoyées',
    de: 'Gesendet',
    ja: '送信済み',
  );
  String get galleryPersonalTab => _l6(
    en: 'Personal',
    zh: '个人',
    es: 'Personal',
    fr: 'Perso',
    de: 'Persönlich',
    ja: '個人',
  );
  String get galleryAlbumsTab => _l6(
    en: 'Playlists',
    zh: '播放列表',
    es: 'Listas',
    fr: 'Playlists',
    de: 'Playlists',
    ja: 'プレイリスト',
  );
  String get galleryAddPhotos => _l6(
    en: 'Add photos',
    zh: '添加照片',
    es: 'Añadir fotos',
    fr: 'Ajouter des photos',
    de: 'Fotos hinzufügen',
    ja: '写真を追加',
  );
  String get galleryEmptyHint => _l6(
    en: 'No pictures yet. Send photos from your phone to your frame — they will appear here automatically.',
    zh: '还没有照片。将手机中的照片发送到相框后会自动显示在这里。',
    es: 'Aún no hay fotos. Envía fotos desde tu teléfono a tu marco.',
    fr: 'Pas encore de photos. Envoyez des photos depuis votre téléphone vers votre cadre.',
    de: 'Noch keine Bilder. Sende Fotos von deinem Telefon an deinen Rahmen.',
    ja: 'まだ写真がありません。スマホからフレームに写真を送信するとここに表示されます。',
  );
  String get frameDetailTitle => _l6(
    en: 'Frame detail',
    zh: '相框详情',
    es: 'Detalle',
    fr: 'Détail du cadre',
    de: 'Rahmendetails',
    ja: 'フレーム詳細',
  );
  String get deviceIdLabel => _l6(
    en: 'Device ID',
    zh: '设备 ID',
    es: 'ID de dispositivo',
    fr: 'ID appareil',
    de: 'Geräte-ID',
    ja: 'デバイス ID',
  );

  String get albumSettingsTitle => _l6(
    en: 'Album settings',
    zh: '相册设置',
    es: 'Ajustes del álbum',
    fr: 'Réglages album',
    de: 'Album-Einstellungen',
    ja: 'アルバム設定',
  );
  String get addToExistingAlbum => _l6(
    en: 'Add to Existing Playlist',
    zh: '添加到已有播放列表',
    es: 'Añadir a lista existente',
    fr: 'Ajouter à une playlist',
    de: 'Zu Playlist hinzufügen',
    ja: '既存プレイリストへ',
  );
  String get createNewAlbum => _l6(
    en: 'Create New Playlist',
    zh: '新建播放列表',
    es: 'Crear lista',
    fr: 'Créer une playlist',
    de: 'Neue Playlist',
    ja: '新規プレイリスト',
  );
  String get galleryAlbumsEmptyHint => _l6(
    en: 'Organise your pictures into playlists and send them straight to your frame. Create your first playlist to get started.',
    zh: '将照片整理成播放列表并直接发送到相框。创建第一个播放列表开始使用。',
    es: 'Organiza tus fotos en listas y envíalas directamente a tu marco. Crea tu primera lista.',
    fr: 'Organisez vos photos en playlists et envoyez-les directement à votre cadre. Créez votre première playlist.',
    de: 'Ordne deine Bilder in Playlists und sende sie direkt an deinen Rahmen. Erstelle deine erste Playlist.',
    ja: '写真をプレイリストに整理してフレームに送信しましょう。最初のプレイリストを作成してください。',
  );
  String get galleryRecentlySentEmptyHint => _l6(
    en: 'Pictures you send to your frame are saved here. Send your first photo to see it appear on this tab.',
    zh: '发送到相框的照片会保存在这里。发送第一张照片后即可在此查看。',
    es: 'Las fotos que envías a tu marco se guardan aquí. Envía tu primera foto.',
    fr: 'Les photos envoyées à votre cadre sont sauvegardées ici. Envoyez votre première photo.',
    de: 'An deinen Rahmen gesendete Bilder werden hier gespeichert. Sende dein erstes Foto.',
    ja: 'フレームに送信した写真はここに保存されます。最初の写真を送信してください。',
  );
  String get addToAlbumNoAlbumsYet => _l6(
    en: 'No playlists yet — use “Create New Playlist” in this sheet or in Gallery ▸ Playlists.',
    zh: '还没有播放列表 — 请在本页「新建播放列表」或 图库 ▸ 播放列表 中创建。',
    es: 'Aún no hay listas — créala aquí o en Galería ▸ Listas.',
    fr: 'Pas encore de playlist — créez-en une ici ou dans Galerie ▸ Playlists.',
    de: 'Noch keine Playlists — legen Sie hier oder unter Galerie ▸ Playlists an.',
    ja: 'プレイリストがありません — この画面またはギャラリー ▸ プレイリストで作成してください。',
  );
  String albumCreatedMessage(String name) => _l6(
    en: 'Playlist created: $name',
    zh: '已创建播放列表：$name',
    es: 'Lista creada: $name',
    fr: 'Playlist créée : $name',
    de: 'Playlist erstellt: $name',
    ja: 'プレイリストを作成しました: $name',
  );
  String get albumAddFromPersonal => _l6(
    en: 'Add from Personal',
    zh: '从个人库添加',
    es: 'Desde Personal',
    fr: 'Bibliothèque perso',
    de: 'Aus Persönlich',
    ja: '個人から追加',
  );
  String get albumAddNewPhotos => _l6(
    en: 'Add new photos',
    zh: '添加新照片',
    es: 'Fotos nuevas',
    fr: 'Nouvelles photos',
    de: 'Neue Fotos',
    ja: '新しい写真を追加',
  );
  String get albumPersonalLibraryEmpty => _l6(
    en: 'Add photos on the Personal tab first, then you can put them in this playlist.',
    zh: '请先在「个人」标签添加照片，再加入此播放列表。',
    es: 'Añade fotos en Personal primero.',
    fr: 'Ajoutez des photos dans l’onglet Perso.',
    de: 'Fügen Sie zuerst Fotos unter „Persönlich“ hinzu.',
    ja: '先に「個人」タブで写真を追加してください。',
  );
  String get albumNothingLeftToAdd => _l6(
    en: 'Every photo in Personal is already in this playlist.',
    zh: '个人库中的照片已全部在此播放列表中。',
    es: 'Todas las fotos de Personal ya están en la lista.',
    fr: 'Toutes les photos Perso sont déjà dans la playlist.',
    de: 'Alle Fotos aus „Persönlich“ sind bereits in der Playlist.',
    ja: '個人の写真はすべてこのプレイリストに入っています。',
  );
  String get albumSelectPhotosTitle => _l6(
    en: 'Choose photos',
    zh: '选择照片',
    es: 'Elegir fotos',
    fr: 'Choisir des photos',
    de: 'Fotos wählen',
    ja: '写真を選ぶ',
  );
  String get albumAddSelected => _l6(
    en: 'Add selected',
    zh: '添加所选',
    es: 'Añadir',
    fr: 'Ajouter',
    de: 'Hinzufügen',
    ja: '追加',
  );
  String albumAddedCount(int n) => _l6(
    en: 'Added $n photo(s) to playlist',
    zh: '已向播放列表添加 $n 张照片',
    es: 'Se añadieron $n foto(s) a la lista',
    fr: '$n photo(s) ajoutée(s) à la playlist',
    de: '$n Foto(s) zur Playlist hinzugefügt',
    ja: 'プレイリストに $n 枚追加しました',
  );
  String get albumDetailSelect => _l6(
    en: 'Select',
    zh: '选择',
    es: 'Seleccionar',
    fr: 'Sélection',
    de: 'Auswählen',
    ja: '選択',
  );
  String get albumDetailAddPhotosHint => _l6(
    en: 'Add photos',
    zh: '添加照片',
    es: 'Añadir fotos',
    fr: 'Ajouter',
    de: 'Fotos hinzufügen',
    ja: '写真を追加',
  );
  String get allPlaylistsShortcut => _l6(
    en: 'All Playlists',
    zh: '全部播放列表',
    es: 'Todas las listas',
    fr: 'Toutes les playlists',
    de: 'Alle Playlists',
    ja: 'すべてのプレイリスト',
  );
  String get playlistAddPhotosBeforeSend => _l6(
    en: 'Add photos to this playlist before sending.',
    zh: '发送前请先为此播放列表添加照片。',
    es: 'Añade fotos a esta lista antes de enviar.',
    fr: 'Ajoutez des photos avant d’envoyer.',
    de: 'Füge zuerst Fotos hinzu, bevor du sendest.',
    ja: '送信する前に写真を追加してください。',
  );
  String get albumEmptyInAlbum => _l6(
    en: 'No photos in this playlist yet. Tap + to add.',
    zh: '此播放列表还没有照片，点 + 添加。',
    es: 'Esta lista aún no tiene fotos. Pulsa +.',
    fr: 'Aucune photo. Touchez + pour ajouter.',
    de: 'Noch keine Fotos. Tippe auf +.',
    ja: 'まだ写真がありません。+ で追加。',
  );
  String get albumRemoveFromAlbumTitle => _l6(
    en: 'Remove from playlist?',
    zh: '从播放列表移除？',
    es: '¿Quitar de la lista?',
    fr: 'Retirer de la playlist ?',
    de: 'Aus Playlist entfernen?',
    ja: 'プレイリストから外しますか？',
  );
  String get albumRemoveFromAlbumBody => _l6(
    en: 'Photos stay in your Personal library. They are only removed from this playlist.',
    zh: '照片仍保留在「个人」库，仅从本播放列表移除。',
    es: 'Las fotos siguen en Personal; solo se quitan de la lista.',
    fr: 'Les photos restent dans Perso ; elles quittent seulement cette playlist.',
    de: 'Die Fotos bleiben unter „Persönlich“; sie werden nur aus dieser Playlist entfernt.',
    ja: '写真は「個人」に残り、このプレイリストからだけ外れます。',
  );
  String albumRemovedFromAlbumCount(int n) => _l6(
    en: 'Removed $n from playlist',
    zh: '已从播放列表移除 $n 张',
    es: 'Se quitaron $n de la lista',
    fr: '$n retirée(s) de la playlist',
    de: '$n aus Playlist entfernt',
    ja: 'プレイリストから $n 枚を外しました',
  );
  String albumSelectedCount(int n) => _l6(
    en: '$n selected',
    zh: '已选 $n 张',
    es: '$n seleccionadas',
    fr: '$n sélectionnée(s)',
    de: '$n ausgewählt',
    ja: '$n 枚を選択',
  );
  String get albumRenameTooltip => _l6(
    en: 'Rename playlist',
    zh: '重命名播放列表',
    es: 'Renombrar lista',
    fr: 'Renommer la playlist',
    de: 'Playlist umbenennen',
    ja: 'プレイリスト名を変更',
  );
  String get albumRenameTitle => _l6(
    en: 'Rename playlist',
    zh: '重命名播放列表',
    es: 'Renombrar lista',
    fr: 'Renommer la playlist',
    de: 'Playlist umbenennen',
    ja: 'プレイリスト名を変更',
  );
  String albumRenamedTo(String name) => _l6(
    en: 'Playlist renamed to “$name”',
    zh: '播放列表已更名为「$name」',
    es: 'Lista renombrada: «$name»',
    fr: 'Playlist renommée : « $name »',
    de: 'Playlist umbenannt in „$name“',
    ja: 'プレイリスト名を「$name」に変更しました',
  );

  String get displaySettingsSection => _l6(
    en: 'Display Settings',
    zh: '显示设置',
    es: 'Pantalla',
    fr: 'Affichage',
    de: 'Anzeige',
    ja: '表示設定',
  );
  String get displayTimeLabel => _l6(
    en: 'Display Time',
    zh: '显示时长',
    es: 'Tiempo en pantalla',
    fr: 'Durée d’affichage',
    de: 'Anzeigedauer',
    ja: '表示時間',
  );
  String get addCustomTextLabel => _l6(
    en: 'Add Custom Text',
    zh: '添加自定义文字',
    es: 'Texto personalizado',
    fr: 'Texte perso',
    de: 'Eigener Text',
    ja: 'カスタム文字',
  );
  String get showCityWeatherLabel => _l6(
    en: 'Show City and Weather',
    zh: '显示城市与天气',
    es: 'Ciudad y tiempo',
    fr: 'Ville et météo',
    de: 'Stadt & Wetter',
    ja: '都市と天気',
  );
  String get showCityWeatherDemo => _l6(
    en: 'Demo: San Francisco · 18°C (connect GPS for live data)',
    zh: '演示：旧金山 · 18°C（连接定位后显示实况）',
    es: 'Demo: San Francisco · 18 °C',
    fr: 'Démo : San Francisco · 18 °C',
    de: 'Demo: San Francisco · 18 °C',
    ja: 'デモ: サンフランシスコ · 18°C',
  );
  String get holidayReminderLabel => _l6(
    en: 'Holiday Reminder',
    zh: '节日提醒',
    es: 'Recordatorio festivo',
    fr: 'Fêtes',
    de: 'Feiertage',
    ja: '祝日リマインダー',
  );
  String get holidayGreetingLine => _l6(
    en: 'Happy holiday from MyFrame',
    zh: '来自 MyFrame 的节日问候',
    es: 'Felices fiestas',
    fr: 'Joyeuses fêtes',
    de: 'Schöne Feiertage',
    ja: 'MyFrame から节日快乐',
  );
  String get sendToFrameCta => _l6(
    en: 'Send to Frame',
    zh: '发送到相框',
    es: 'Enviar al marco',
    fr: 'Envoyer au cadre',
    de: 'An Rahmen senden',
    ja: 'フレームへ送信',
  );
  String get photosSecureFootnote => _l6(
    en: 'Your photos are secure and encrypted.',
    zh: '您的照片经过安全加密传输。',
    es: 'Tus fotos van cifradas.',
    fr: 'Vos photos sont chiffrées.',
    de: 'Ihre Fotos werden verschlüsselt übertragen.',
    ja: '写真は安全に暗号化されます。',
  );
  String get newAlbumNameHint => _l6(
    en: 'Playlist name',
    zh: '播放列表名称',
    es: 'Nombre de la lista',
    fr: 'Nom de la playlist',
    de: 'Playlist-Name',
    ja: 'プレイリスト名',
  );

  String get settingsSectionAccount => _l6(
    en: 'Account',
    zh: '账户',
    es: 'Cuenta',
    fr: 'Compte',
    de: 'Konto',
    ja: 'アカウント',
  );
  String get settingsSectionApplication => _l6(
    en: 'Application',
    zh: '应用',
    es: 'Aplicación',
    fr: 'Application',
    de: 'App',
    ja: 'アプリ',
  );
  String get settingsSectionFrame => _l6(
    en: 'Frame settings',
    zh: '相框设置',
    es: 'Ajustes del marco',
    fr: 'Réglages du cadre',
    de: 'Rahmen-Einstellungen',
    ja: 'フレーム設定',
  );
  String get settingsReconfigureFrameTitle => _l6(
    en: 'Reconfigure frame server',
    zh: '重新配置相框服务器',
    es: 'Reconfigurar servidor del marco',
    fr: 'Reconfigurer le serveur du cadre',
    de: 'Rahmen-Server neu konfigurieren',
    ja: 'フレームサーバーを再設定',
  );
  String get settingsReconfigureFrameSub => _l6(
    en: 'Connect over Bluetooth and send MQTT settings to the frame',
    zh: '通过蓝牙连接并向相框发送 MQTT 配置',
    es: 'Conecta por Bluetooth y envía la configuración MQTT',
    fr: 'Connexion Bluetooth et envoi des réglages MQTT',
    de: 'Per Bluetooth verbinden und MQTT-Einstellungen senden',
    ja: 'Bluetoothで接続しMQTT設定を送信',
  );
  String get settingsForgetFrameTitle => _l6(
    en: 'Forget frame',
    zh: '忘记相框',
    es: 'Olvidar marco',
    fr: 'Oublier le cadre',
    de: 'Rahmen vergessen',
    ja: 'フレームを解除',
  );
  String get settingsForgetFrameSub => _l6(
    en: 'Remove the paired frame from this phone',
    zh: '从本机移除已配对的相框',
    es: 'Quitar el marco emparejado de este teléfono',
    fr: 'Retirer le cadre appairé de ce téléphone',
    de: 'Gekoppelten Rahmen von diesem Gerät entfernen',
    ja: 'この端末からペアしたフレームを削除',
  );
  String get settingsForgetFrameConfirmBody => _l6(
    en: 'Remove this frame from the app? You can pair it again later.',
    zh: '从应用中移除此相框？您可以稍后重新配对。',
    es: '¿Quitar este marco de la app? Podrás emparejarlo de nuevo.',
    fr: 'Retirer ce cadre de l’app ? Vous pourrez l’appairer à nouveau.',
    de: 'Diesen Rahmen aus der App entfernen? Sie können ihn später erneut koppeln.',
    ja: 'このフレームをアプリから削除しますか？後で再度ペアできます。',
  );
  String get settingsForgetFrameConfirm => _l6(
    en: 'Forget',
    zh: '忘记',
    es: 'Olvidar',
    fr: 'Oublier',
    de: 'Vergessen',
    ja: '解除',
  );
  String get settingsSectionAi => _l6(
    en: 'AI Feature',
    zh: 'AI 功能',
    es: 'IA',
    fr: 'Fonctions IA',
    de: 'KI-Funktionen',
    ja: 'AI 機能',
  );
  String get settingsSectionHelp => _l6(
    en: 'Help',
    zh: '帮助',
    es: 'Ayuda',
    fr: 'Aide',
    de: 'Hilfe',
    ja: 'ヘルプ',
  );
  String get aiGenerateNavTitle => _l6(
    en: 'AI Generate',
    zh: 'AI 生成',
    es: 'Generar IA',
    fr: 'Génération IA',
    de: 'KI-Generierung',
    ja: 'AI 生成',
  );
  String get aiSilentModeTitle => _l6(
    en: 'AI Silent Mode Settings',
    zh: 'AI 静默模式',
    es: 'Modo silencioso IA',
    fr: 'Mode silencieux IA',
    de: 'KI-Stiller Modus',
    ja: 'AI サイレントモード',
  );
  String get aiSilentIntro => _l6(
    en: 'Silent Mode intelligently screens and selects the best photos and pushes them to your ink-screen frame.',
    zh: '静默模式会智能筛选优质照片并推送到墨水屏相框。',
    es: 'El modo silencioso selecciona y envía las mejores fotos.',
    fr: 'Le mode silencieux trie et envoie les meilleures photos.',
    de: 'Der stille Modus wählt die besten Fotos aus.',
    ja: 'サイレントモードが最適な写真を選びフレームへ送ります。',
  );
  String get comingSoonLabel => _l6(
    en: 'Coming soon',
    zh: '即将推出',
    es: 'Próximamente',
    fr: 'Bientôt disponible',
    de: 'Demnächst',
    ja: '近日公開',
  );
  String get aiSilentModeComingSoon => _l6(
    en: 'AI Silent Mode is coming soon.',
    zh: 'AI 静默模式即将推出。',
    es: 'El modo silencioso IA llegará pronto.',
    fr: 'Le mode silencieux IA arrive bientôt.',
    de: 'KI-Stiller Modus kommt demnächst.',
    ja: 'AI サイレントモードは近日公開です。',
  );
  String get silentModeToggleTitle => _l6(
    en: 'Silent Mode',
    zh: '静默模式',
    es: 'Modo silencioso',
    fr: 'Mode silencieux',
    de: 'Stiller Modus',
    ja: 'サイレントモード',
  );
  String get silentModeToggleSub => _l6(
    en: 'The AI will automatically screen, filter and push appropriate photos. You won\'t be notified for each photo.',
    zh: 'AI 会自动筛选并推送合适的照片，不会为每张照片推送通知。',
    es: 'La IA filtra y envía sin notificar cada foto.',
    fr: 'L’IA filtre et envoie sans notification à chaque photo.',
    de: 'Die KI filtert und sendet ohne Einzelbenachrichtigung.',
    ja: 'AI が自動で選別・送信します（毎回の通知はありません）。',
  );
  String get personIndexingTitle => _l6(
    en: 'Person Indexing',
    zh: '人物索引',
    es: 'Personas',
    fr: 'Indexation',
    de: 'Personen',
    ja: '人物インデックス',
  );
  String get personIndexingSub => _l6(
    en: 'Add and manage family members to help AI better understand and prioritize meaningful moments.',
    zh: '添加家庭成员，帮助 AI 更好理解重要时刻。',
    es: 'Añade familiares para que la IA priorice momentos.',
    fr: 'Ajoutez la famille pour aider l’IA.',
    de: 'Familie hinzufügen, damit die KI priorisiert.',
    ja: '家族を登録し、AI の理解を助けます。',
  );
  String get addFamilyMember => _l6(
    en: '+ Add Family Member',
    zh: '+ 添加家庭成员',
    es: '+ Miembro',
    fr: '+ Membre',
    de: '+ Mitglied',
    ja: '+ 家族を追加',
  );
  String get addAnotherFamilyMember => _l6(
    en: '+ Add Another Family Member',
    zh: '+ 再添加一位家庭成员',
    es: '+ Otro miembro',
    fr: '+ Autre membre',
    de: '+ weiteres Mitglied',
    ja: '+ さらに追加',
  );
  String get nicknameLabel => _l6(
    en: 'Nickname',
    zh: '昵称',
    es: 'Apodo',
    fr: 'Surnom',
    de: 'Spitzname',
    ja: 'ニックネーム',
  );
  String get aiBackgroundScreening => _l6(
    en: 'AI Background Screening',
    zh: 'AI 后台筛选',
    es: 'Filtrado en segundo plano',
    fr: 'Filtrage IA',
    de: 'Hintergrund-Screening',
    ja: 'AI バックグラウンド選別',
  );
  String get aiBackgroundScreeningSub => _l6(
    en: 'AI will automatically screen photos based on the settings below when Silent Mode is ON.',
    zh: '开启静默模式后，AI 将按以下设置自动筛选照片。',
    es: 'Con el modo silencioso activo, la IA filtra según lo siguiente.',
    fr: 'Avec le mode silencieux, l’IA filtre selon ces réglages.',
    de: 'Im stillen Modus filtert die KI nach diesen Regeln.',
    ja: 'サイレントモード ON で以下に従い選別します。',
  );
  String get emotionFilteringTitle => _l6(
    en: 'Emotion Filtering',
    zh: '情绪筛选',
    es: 'Emociones',
    fr: 'Émotions',
    de: 'Emotionen',
    ja: '感情フィルタ',
  );
  String get emotionFilteringSub => _l6(
    en: 'Prioritize photos with positive emotions and filter out negative or neutral expressions.',
    zh: '优先推送积极情绪照片，弱化消极或中性表情。',
    es: 'Prioriza emociones positivas.',
    fr: 'Priorise les émotions positives.',
    de: 'Positive Emotionen bevorzugen.',
    ja: 'ポジティブな表情を優先します。',
  );
  String get qualityCheckTitle => _l6(
    en: 'Quality Check',
    zh: '画质检查',
    es: 'Calidad',
    fr: 'Qualité',
    de: 'Qualität',
    ja: '画質チェック',
  );
  String get qualityCheckSub => _l6(
    en: 'Only push clear, high-quality photos and automatically filter out blurry or low-quality ones.',
    zh: '仅推送清晰高质量照片，自动过滤模糊或低质照片。',
    es: 'Solo fotos nítidas.',
    fr: 'Photos nettes uniquement.',
    de: 'Nur scharfe Fotos.',
    ja: '鮮明な写真のみ送信します。',
  );
  String get eventPushingTitle => _l6(
    en: 'Event-based Pushing',
    zh: '事件优先推送',
    es: 'Eventos',
    fr: 'Événements',
    de: 'Ereignisse',
    ja: 'イベント優先',
  );
  String get eventPushingSub => _l6(
    en: 'Prioritize photos from important days such as birthdays, festivals, and family events.',
    zh: '优先生日、节日与家庭活动等重要日子的照片。',
    es: 'Prioriza cumpleaños y fiestas.',
    fr: 'Priorise anniversaires et fêtes.',
    de: 'Geburtstage und Feiertage priorisieren.',
    ja: '誕生日や行事の写真を優先します。',
  );
  String get aiScreeningPreview => _l6(
    en: 'AI Screening Preview',
    zh: 'AI 筛选预览',
    es: 'Vista previa',
    fr: 'Aperçu',
    de: 'Vorschau',
    ja: 'プレビュー',
  );
  String get aiScreeningPreviewSub => _l6(
    en: 'View the latest AI screening results and photo statistics.',
    zh: '查看最近 AI 筛选结果与统计。',
    es: 'Estadísticas recientes.',
    fr: 'Statistiques récentes.',
    de: 'Aktuelle Statistik.',
    ja: '最新の統計を表示します。',
  );
  String get statPhotosProcessed => _l6(
    en: 'Photos Processed\n(Last 7 days)',
    zh: '处理照片数\n（近7天）',
    es: 'Procesadas\n(7 días)',
    fr: 'Traitées\n(7 j)',
    de: 'Verarbeitet\n(7 T.)',
    ja: '処理枚数\n（7日）',
  );
  String get statPhotosPushed => _l6(
    en: 'Photos Pushed',
    zh: '已推送',
    es: 'Enviadas',
    fr: 'Poussées',
    de: 'Gesendet',
    ja: '送信',
  );
  String get statPositiveEmotion => _l6(
    en: 'Positive Emotion',
    zh: '积极情绪',
    es: 'Emoción +',
    fr: 'Émotion +',
    de: 'Positiv',
    ja: 'ポジティブ感情',
  );
  String get statHighQuality => _l6(
    en: 'High Quality',
    zh: '高画质',
    es: 'Alta calidad',
    fr: 'Haute qualité',
    de: 'Hohe Qualität',
    ja: '高画質',
  );
  String get saveSettings => _l6(
    en: 'Save Settings',
    zh: '保存设置',
    es: 'Guardar',
    fr: 'Enregistrer',
    de: 'Speichern',
    ja: '設定を保存',
  );
  String get llmProviderLabel => _l6(
    en: 'LLM provider',
    zh: '大模型提供商',
    es: 'Proveedor LLM',
    fr: 'Fournisseur LLM',
    de: 'LLM-Anbieter',
    ja: 'LLM プロバイダー',
  );
  String get apiKeyLabel => _l6(
    en: 'API Key',
    zh: 'API 密钥',
    es: 'Clave API',
    fr: 'Clé API',
    de: 'API-Schlüssel',
    ja: 'API キー',
  );
  String get quietHoursSilentLabel => _l6(
    en: 'Quiet Hours',
    zh: '免打扰时段',
    es: 'Horas silencio',
    fr: 'Heures calmes',
    de: 'Ruhezeiten',
    ja: '静音時間帯',
  );
  String get apiKeysSilentLabel => _l6(
    en: 'API Keys',
    zh: 'API 密钥',
    es: 'Claves API',
    fr: 'Clés API',
    de: 'API-Schlüssel',
    ja: 'API キー',
  );

  String get cancel => _l6(
    en: 'Cancel',
    zh: '取消',
    es: 'Cancelar',
    fr: 'Annuler',
    de: 'Abbrechen',
    ja: 'キャンセル',
  );
  String get remove => _l6(
    en: 'Remove',
    zh: '移除',
    es: 'Quitar',
    fr: 'Retirer',
    de: 'Entfernen',
    ja: '解除',
  );

  // —— Language picker ——
  String get languageSystem => _l6(
    en: 'System default',
    zh: '跟随系统',
    es: 'Predeterminado',
    fr: 'Système',
    de: 'Systemstandard',
    ja: 'システムに合わせる',
  );
  String get languageEnglish => 'English';
  String get languageChinese => '中文';
  String get languageSpanish => 'Español';
  String get languageFrench => 'Français';
  String get languageGerman => 'Deutsch';
  String get languageJapanese => '日本語';

  // —— Theme ——
  String get appearanceTitle => _l6(
    en: 'Appearance',
    zh: '外观',
    es: 'Apariencia',
    fr: 'Apparence',
    de: 'Erscheinungsbild',
    ja: '外観',
  );
  String get themeLight => _l6(
    en: 'Light',
    zh: '浅色',
    es: 'Claro',
    fr: 'Clair',
    de: 'Hell',
    ja: 'ライト',
  );
  String get themeDark => _l6(
    en: 'Dark',
    zh: '深色',
    es: 'Oscuro',
    fr: 'Sombre',
    de: 'Dunkel',
    ja: 'ダーク',
  );
  String get themeSystem => _l6(
    en: 'System',
    zh: '系统',
    es: 'Sistema',
    fr: 'Système',
    de: 'System',
    ja: 'システム',
  );
  String get themeSystemSubtitle => _l6(
    en: 'Follow system appearance',
    zh: '跟随系统外观',
    es: 'Seguir apariencia del sistema',
    fr: 'Suivre l’apparence du système',
    de: 'Systemdarstellung folgen',
    ja: '端末の外観に合わせる',
  );
  String get joinFamilyBirthdayHint => _l6(
    en: 'Used for birthday reminders in your family group.',
    zh: '用于家庭群组中的生日提醒。',
    es: 'Se usa para recordatorios de cumpleaños en tu grupo familiar.',
    fr: 'Utilisé pour les rappels d’anniversaire dans votre groupe familial.',
    de: 'Für Geburtstags-Erinnerungen in Ihrer Familiengruppe.',
    ja: 'ファミリーグループの誕生日リマインダーに使用します。',
  );
  String get joinFamilyProfileSection => _l6(
    en: 'Your profile',
    zh: '你的资料',
    es: 'Tu perfil',
    fr: 'Votre profil',
    de: 'Ihr Profil',
    ja: 'プロフィール',
  );
  String get avatarChangeHint => _l6(
    en: 'Tap to change photo',
    zh: '点击更换头像',
    es: 'Toca para cambiar la foto',
    fr: 'Appuyez pour changer la photo',
    de: 'Tippen, um Foto zu ändern',
    ja: 'タップして写真を変更',
  );
  String get avatarUpdateFailed => _l6(
    en: 'Could not update profile photo.',
    zh: '无法更新头像。',
    es: 'No se pudo actualizar la foto.',
    fr: 'Impossible de mettre à jour la photo.',
    de: 'Profilfoto konnte nicht aktualisiert werden.',
    ja: 'プロフィール写真を更新できませんでした。',
  );
  String get voiceCommandsTitle => _l6(
    en: 'Voice commands',
    zh: '语音指令',
    es: 'Comandos de voz',
    fr: 'Commandes vocales',
    de: 'Sprachbefehle',
    ja: '音声コマンド',
  );
  String get voiceCommandsComingSoon => _l6(
    en: 'Coming soon — voice control is not available yet.',
    zh: '即将推出 — 语音控制暂不可用。',
    es: 'Próximamente — el control por voz aún no está disponible.',
    fr: 'Bientôt disponible — le contrôle vocal n’est pas encore disponible.',
    de: 'Demnächst — Sprachsteuerung ist noch nicht verfügbar.',
    ja: '近日対応予定 — 音声操作はまだ利用できません。',
  );
  String get themeModeSection => _l6(
    en: 'Theme mode',
    zh: '主题模式',
    es: 'Modo de tema',
    fr: 'Mode thème',
    de: 'Erscheinungsbild',
    ja: 'テーマ',
  );
  String get themeAccentSection => _l6(
    en: 'Accent color',
    zh: '强调色',
    es: 'Color de acento',
    fr: 'Couleur d’accent',
    de: 'Akzentfarbe',
    ja: 'アクセント色',
  );
  String get accentRed => _l6(
    en: 'Red accent',
    zh: '红色主题',
    es: 'Rojo',
    fr: 'Rouge',
    de: 'Rot',
    ja: '赤アクセント',
  );
  String get accentGreen => _l6(
    en: 'Green accent',
    zh: '绿色主题',
    es: 'Verde',
    fr: 'Vert',
    de: 'Grün',
    ja: '緑アクセント',
  );

  String themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => themeLight,
      ThemeMode.dark => themeDark,
      ThemeMode.system => themeSystem,
    };
  }

  String accentLabel(AppAccent accent) =>
      accent == AppAccent.green ? accentGreen : accentRed;

  // —— Home ——
  String get sdCardDetected => _l6(
    en: 'SD Card Detected',
    zh: '检测到 SD 卡',
    es: 'Tarjeta SD',
    fr: 'Carte SD',
    de: 'SD-Karte',
    ja: 'SDカードを検出',
  );
  String get tapToImport => _l6(
    en: 'Tap to import photos',
    zh: '点击导入照片',
    es: 'Toca para importar',
    fr: 'Importer des photos',
    de: 'Fotos importieren',
    ja: 'タップして写真を読み込む',
  );

  String get connected => _l6(
    en: 'Connected',
    zh: '已连接',
    es: 'Conectado',
    fr: 'Connecté',
    de: 'Verbunden',
    ja: '接続済み',
  );
  String get pairedSaved => _l6(
    en: 'Paired (saved)',
    zh: '已配对（已保存）',
    es: 'Emparejado (guardado)',
    fr: 'Appairé (enregistré)',
    de: 'Gekoppelt (gespeichert)',
    ja: 'ペア済み（保存済み）',
  );
  String get notPaired => _l6(
    en: 'Not paired',
    zh: '未配对',
    es: 'Sin emparejar',
    fr: 'Non appairé',
    de: 'Nicht gekoppelt',
    ja: '未ペア',
  );
  String get livingRoom => _l6(
    en: 'Living Room',
    zh: '客厅',
    es: 'Sala',
    fr: 'Salon',
    de: 'Wohnzimmer',
    ja: 'リビング',
  );
  String get lastPhoto => _l6(
    en: 'Last photo: 2 hours ago',
    zh: '上次照片：2 小时前',
    es: 'Última foto: hace 2 h',
    fr: 'Dernière photo : il y a 2 h',
    de: 'Letztes Foto: vor 2 Std.',
    ja: '最後の写真: 2時間前',
  );
  String get noLiveDeviceData => _l6(
    en: 'No live device data',
    zh: '暂无设备实时数据',
    es: 'Sin datos en vivo del dispositivo',
    fr: 'Aucune donnée appareil en direct',
    de: 'Keine Live-Gerätedaten',
    ja: 'ライブデバイス情報なし',
  );
  String get lastPhotoUnknown => _l6(
    en: 'never',
    zh: '从未',
    es: 'nunca',
    fr: 'jamais',
    de: 'nie',
    ja: 'なし',
  );
  String lastPhotoDynamic(String when) => _l6(
    en: 'Last photo: $when',
    zh: '上次照片：$when',
    es: 'Última foto: $when',
    fr: 'Dernière photo : $when',
    de: 'Letztes Foto: $when',
    ja: '最後の写真: $when',
  );
  String get justNow => _l6(
    en: 'just now',
    zh: '刚刚',
    es: 'ahora mismo',
    fr: 'à l’instant',
    de: 'gerade eben',
    ja: 'たった今',
  );
  String minutesAgo(int n) => _l6(
    en: '$n min ago',
    zh: '$n 分钟前',
    es: 'hace $n min',
    fr: 'il y a $n min',
    de: 'vor $n Min.',
    ja: '$n分前',
  );
  String hoursAgo(int n) => _l6(
    en: '$n h ago',
    zh: '$n 小时前',
    es: 'hace $n h',
    fr: 'il y a $n h',
    de: 'vor $n Std.',
    ja: '$n時間前',
  );
  String daysAgo(int n) => _l6(
    en: '$n d ago',
    zh: '$n 天前',
    es: 'hace $n d',
    fr: 'il y a $n j',
    de: 'vor $n Tg.',
    ja: '$n日前',
  );
  String hoursShort(int n) => _l6(
    en: '${n}h',
    zh: '${n}小时',
    es: '${n}h',
    fr: '${n}h',
    de: '${n}Std.',
    ja: '${n}時間',
  );
  String daysShort(int n) => _l6(
    en: '${n}d',
    zh: '${n}天',
    es: '${n}d',
    fr: '${n}j',
    de: '${n}Tg.',
    ja: '${n}日',
  );

  String get storage => _l6(
    en: 'Storage',
    zh: '存储',
    es: 'Almacenamiento',
    fr: 'Stockage',
    de: 'Speicher',
    ja: 'ストレージ',
  );
  String get photos => _l6(
    en: 'Photos',
    zh: '照片',
    es: 'Fotos',
    fr: 'Photos',
    de: 'Fotos',
    ja: '写真',
  );
  String get uptime => _l6(
    en: 'Uptime',
    zh: '运行',
    es: 'Activo',
    fr: 'Temps actif',
    de: 'Laufzeit',
    ja: '稼働',
  );

  String get wifiLabel => 'Wi‑Fi';
  String get bluetoothLabel => _l6(
    en: 'Bluetooth',
    zh: '蓝牙',
    es: 'Bluetooth',
    fr: 'Bluetooth',
    de: 'Bluetooth',
    ja: 'Bluetooth',
  );

  String get manageDevice => _l6(
    en: 'Manage device and pairing',
    zh: '管理设备与配对',
    es: 'Gestionar dispositivo',
    fr: 'Gérer l’appareil',
    de: 'Gerät & Kopplung',
    ja: 'デバイスとペア設定',
  );

  String get quickActions => _l6(
    en: 'Quick Actions',
    zh: '快捷操作',
    es: 'Acciones',
    fr: 'Actions rapides',
    de: 'Schnellaktionen',
    ja: 'クイック操作',
  );
  String get setupProgressTitle => _l6(
    en: 'Setup progress',
    zh: '设置进度',
    es: 'Avance',
    fr: 'Étapes',
    de: 'Einrichtung',
    ja: 'セットアップ',
  );
  String get setupStepPower => _l6(
    en: 'Power on frame',
    zh: '相框开机',
    es: 'Encender marco',
    fr: 'Allumer le cadre',
    de: 'Rahmen einschalten',
    ja: 'フレームの電源',
  );
  String get setupStepWifi => _l6(
    en: 'Connect Wi‑Fi',
    zh: '连接 Wi‑Fi',
    es: 'Conectar Wi‑Fi',
    fr: 'Connecter le Wi‑Fi',
    de: 'WLAN verbinden',
    ja: 'Wi‑Fi接続',
  );
  String get setupStepPhoto => _l6(
    en: 'Send first photo',
    zh: '发送第一张照片',
    es: 'Enviar primera foto',
    fr: 'Envoyer la première photo',
    de: 'Erstes Foto senden',
    ja: '最初の写真を送信',
  );
  String get pairBluetoothFrame => _l6(
    en: 'Pair frame (Bluetooth)',
    zh: '蓝牙配对相框',
    es: 'Emparejar por Bluetooth',
    fr: 'Appairer (Bluetooth)',
    de: 'Rahmen koppeln (Bluetooth)',
    ja: 'フレームをペア（Bluetooth）',
  );
  String get pairingHelpHome => _l6(
    en: 'Pairing help',
    zh: '配对帮助',
    es: 'Ayuda de emparejamiento',
    fr: 'Aide jumelage',
    de: 'Kopplungs-Hilfe',
    ja: 'ペアのヘルプ',
  );
  String get pair => _l6(
    en: 'Pair',
    zh: '配对',
    es: 'Emparejar',
    fr: 'Appairer',
    de: 'Koppeln',
    ja: 'ペア',
  );
  String get send => _l6(
    en: 'Send',
    zh: '发送',
    es: 'Enviar',
    fr: 'Envoyer',
    de: 'Senden',
    ja: '送信',
  );
  String get playlist => _l6(
    en: 'Playlist',
    zh: '列表',
    es: 'Lista',
    fr: 'Liste',
    de: 'Liste',
    ja: 'リスト',
  );
  String get share => _l6(
    en: 'Share',
    zh: '分享',
    es: 'Compartir',
    fr: 'Partager',
    de: 'Teilen',
    ja: '共有',
  );

  String get importPhotos => _l6(
    en: 'Import Photos',
    zh: '导入照片',
    es: 'Importar fotos',
    fr: 'Importer',
    de: 'Fotos importieren',
    ja: '写真を読み込む',
  );

  String get wifiConnectTitle => _l6(
    en: 'Wi‑Fi (uploads)',
    zh: 'Wi‑Fi 上传',
    es: 'Wi‑Fi (subida)',
    fr: 'Wi‑Fi (envoi)',
    de: 'WLAN (Upload)',
    ja: 'Wi‑Fi（送信）',
  );
  String get wifiConnectBody => _l6(
    en: 'The frame talks to the app over your home network. After you scan the pairing QR, we save the device id and (if present) a LAN address for the upload API. Sending uses Wi‑Fi when you pick “Wi‑Fi” in Send and tap Process & upload.',
    zh: '相框与手机在同一网络下，通过你保存的地址上传。扫码配对会保存设备 ID 和（如有）API 地址；在“发送”里选 Wi‑Fi 并上传即走此通道。',
    es: 'El marco usa la red de casa; el QR guarda el ID y la URL. En Enviar elige Wi‑Fi.',
    fr: 'Le cadre parle en Wi‑Fi local ; le QR mémorise l’ID et l’URL.',
    de: 'Der Rahmen nutzt euer Heimnetz; das QR speichert ID und URL fürs Hochladen.',
    ja: '同じWi‑Fi上で、QRでIDとURLを保存し、送信でWi‑Fiを選びます',
  );
  String get wifiNotPairedHint => _l6(
    en: 'Not paired yet — scan the frame’s QR in Pairing, or from here.',
    zh: '尚未配对 — 请扫描相框上的配对二维码。',
    es: 'Aún no emparejado — escanea el QR del marco.',
    fr: 'Non appairé — scannez le QR du cadre.',
    de: 'Nicht gekoppelt — Frame-QR scannen.',
    ja: '未ペア — フレームのQRをスキャン',
  );
  String get openSendWifiCta => _l6(
    en: 'Open Send (use Wi‑Fi transport)',
    zh: '打开发送（选 Wi‑Fi）',
    es: 'Abrir Enviar (Wi‑Fi)',
    fr: 'Ouvrir Envoyer (Wi‑Fi)',
    de: 'Senden öffnen (WLAN)',
    ja: '送信を開く（Wi‑Fi）',
  );
  String get scanPairingQrCta => _l6(
    en: 'Scan pairing QR',
    zh: '扫描配对二维码',
    es: 'Escanear QR de emparejamiento',
    fr: 'Scanner le QR d’appairage',
    de: 'Kopplungs-QR scannen',
    ja: 'ペア用QRをスキャン',
  );
  String get bluetoothConnectTitle => _l6(
    en: 'Connect over Bluetooth',
    zh: '通过蓝牙连接',
    es: 'Conectar por Bluetooth',
    fr: 'Connexion Bluetooth',
    de: 'Per Bluetooth verbinden',
    ja: 'Bluetoothで接続',
  );
  String bleScanMacSuffixSubtitle(String suffix4, int rssi) => _l6(
    en: 'MAC suffix $suffix4 · $rssi dBm',
    zh: 'MAC 后四位 $suffix4 · $rssi dBm',
    es: 'Sufijo MAC $suffix4 · $rssi dBm',
    fr: 'Suffixe MAC $suffix4 · $rssi dBm',
    de: 'MAC‑Suffix $suffix4 · $rssi dBm',
    ja: 'MAC下4桁 $suffix4 · $rssi dBm',
  );
  String get bluetoothConnectBody => _l6(
    en: 'MyFrame uses Bluetooth to discover the frame, connect to it, and send Wi‑Fi setup details. Keep Bluetooth and Wi‑Fi on, stay near the frame, and allow the prompts when they appear.',
    zh: 'MyFrame 使用蓝牙发现并连接相框，然后发送 Wi‑Fi 设置。请保持蓝牙和 Wi‑Fi 开启，并允许弹出的权限请求。',
    es: 'MyFrame usa Bluetooth para descubrir el marco, conectarse y enviar la configuración Wi‑Fi. Mantén Bluetooth y Wi‑Fi activos y acepta los permisos.',
    fr: 'MyFrame utilise Bluetooth pour trouver le cadre, s’y connecter et envoyer la configuration Wi‑Fi. Gardez Bluetooth et Wi‑Fi actifs et acceptez les autorisations.',
    de: 'MyFrame nutzt Bluetooth, um den Rahmen zu finden, zu verbinden und WLAN-Daten zu senden. Bluetooth und WLAN eingeschaltet lassen und Berechtigungen erlauben.',
    ja: 'MyFrameはBluetoothでフレームを検出・接続し、Wi‑Fi設定を送信します。BluetoothとWi‑Fiをオンにして権限を許可してください。',
  );
  String get openSendBluetoothCta => _l6(
    en: 'Open Send (use Bluetooth transport)',
    zh: '打开发送（选蓝牙）',
    es: 'Abrir Enviar (Bluetooth)',
    fr: 'Ouvrir Envoyer (Bluetooth)',
    de: 'Senden öffnen (Bluetooth)',
    ja: '送信を開く（Bluetooth）',
  );

  String get bleSessionBannerTitle => _l6(
    en: 'Frame connected (Bluetooth)',
    zh: '相框已连接（蓝牙）',
    es: 'Marco conectado (Bluetooth)',
    fr: 'Cadre connecté (Bluetooth)',
    de: 'Rahmen verbunden (Bluetooth)',
    ja: 'フレーム接続中（Bluetooth）',
  );
  String get bleSessionBannerSub => _l6(
    en: 'Stays on until you disconnect, switch to Wi‑Fi, or the link is lost.',
    zh: '保持连接，直到你主动断开、改用 Wi‑Fi 或连接中断。',
    es: 'Activa hasta que desconectes, uses Wi‑Fi o se pierda el enlace.',
    fr: 'Actif jusqu’à déconnexion, passage en Wi‑Fi, ou perte de liaison.',
    de: 'Bleibt, bis Trennen, Wechsel auf WLAN oder Verbindungsabbruch.',
    ja: '切断・Wi‑Fi 切替・接続喪失まで維持されます。',
  );
  String get bleDisconnect => _l6(
    en: 'Disconnect',
    zh: '断开',
    es: 'Desconectar',
    fr: 'Déconnecter',
    de: 'Trennen',
    ja: '切断',
  );
  String get choosePhotos => _l6(
    en: 'Choose photos',
    zh: '选择照片',
    es: 'Elegir fotos',
    fr: 'Choisir des photos',
    de: 'Fotos wählen',
    ja: '写真を選ぶ',
  );
  String get choosePhotosSub => _l6(
    en: 'From your library; the editor opens for each photo you select.',
    zh: '从相册选择；每张照片会依次进入编辑。',
    es: 'Desde la galería; el editor se abre para cada selección.',
    fr: 'Depuis la librairie ; l’éditeur s’ouvre pour chaque photo.',
    de: 'Aus der Mediathek — der Editor öffnet sich für jedes ausgewählte Foto.',
    ja: 'ライブラリから選んだ写真ごとに編集が開きます',
  );
  String get playlistSavedSnackbar => _l6(
    en: 'Playlist saved',
    zh: '播放列表已保存',
    es: 'Lista guardada',
    fr: 'Liste enregistrée',
    de: 'Gespeichert',
    ja: '保存しました',
  );
  String get playlistNeedPhotos => _l6(
    en: 'Pick at least one photo to create a playlist',
    zh: '请至少选择一张照片',
    es: 'Elige al menos una foto',
    fr: 'Choisis au moins une photo',
    de: 'Mindestens ein Foto wählen',
    ja: '1枚以上選んでください',
  );
  String get yourPlaylists => _l6(
    en: 'Your playlists',
    zh: '我的播放列表',
    es: 'Tus listas',
    fr: 'Vos listes',
    de: 'Eure Playlists',
    ja: 'あなたのプレイリスト',
  );
  String get removePlaylistBody => _l6(
    en: 'Delete this playlist and its saved image files in the app storage?',
    zh: '将删除此播放列表及已保存的本地图片。',
    es: '¿Borrar esta lista y archivos guardados?',
    fr: 'Supprimer cette liste et les fichiers ?',
    de: 'Playlist und lokale Dateien löschen?',
    ja: '保存画像と一覧を削除しますか？',
  );

  String get comfortMode => _l6(
    en: 'Comfort',
    zh: '舒适',
    es: 'Cómodo',
    fr: 'Confort',
    de: 'Komfort',
    ja: '見やすい',
  );
  String get comfortModeSubtitle => _l6(
    en: 'Increases text and tap targets. Matches the “elderly” controls in the design mockup.',
    zh: '增大文字和点击区域，便于长辈使用。',
    es: 'Texto y botones más grandes.',
    fr: 'Texte et zones tactiles plus grands.',
    de: 'Größerer Text und größere Tippflächen.',
    ja: '文字とタップしやすさを向上。',
  );
  String get comfortModeOn => _l6(
    en: 'Comfort mode enabled',
    zh: '已开启舒适模式',
    es: 'Modo cómodo activado',
    fr: 'Mode confort activé',
    de: 'Komfortmodus aktiviert',
    ja: '見やすいモードをオン',
  );
  String get comfortModeOff => _l6(
    en: 'Comfort mode disabled',
    zh: '已关闭舒适模式',
    es: 'Modo cómodo desactivado',
    fr: 'Mode confort désactivé',
    de: 'Komfortmodus deaktiviert',
    ja: '見やすいモードをオフ',
  );

  String deviceTitle(String deviceId, bool paired) {
    if (!paired) return deviceId;
    return _l6(
      en: '$deviceId · $connected',
      zh: '$deviceId · $connected',
      es: '$deviceId · $connected',
      fr: '$deviceId · $connected',
      de: '$deviceId · $connected',
      ja: '$deviceId · $connected',
    );
  }

  String get defaultDeviceId => 'YX-133P';

  String get pairingGuideTitle => _l6(
    en: 'Frame pairing',
    zh: '相框配对',
    es: 'Emparejar',
    fr: 'Appairage',
    de: 'Kopplung',
    ja: 'フレームのペア',
  );
  String get pairingStep1Title => _l6(
    en: 'Turn on the frame',
    zh: '打开相框',
    es: 'Enciende',
    fr: 'Allumez le cadre',
    de: 'Rahmen einschalten',
    ja: 'フレームの電源',
  );
  String get pairingStep1Body => _l6(
    en: 'Wait until the welcome screen and pairing QR are visible.',
    zh: '等待欢迎屏并显示配对二维码。',
    es: 'Espera a ver el QR.',
    fr: 'Attendez le code QR de jumelage.',
    de: 'Warten Sie auf den Begrüßungsbildschirm und das QR',
    ja: 'QRが表示されるまで待ちます',
  );
  String get pairingStep2Title => _l6(
    en: 'Scan the QR on the display',
    zh: '扫描屏幕上的码',
    es: 'Escanear el QR en pantalla',
    fr: 'Scannez le QR',
    de: 'QR am Display scannen',
    ja: '画面のQRをスキャン',
  );
  String get pairingStep2Body => _l6(
    en: 'The app stores your device id and optional upload URL (same as the product flow).',
    zh: '应用会保存设备 ID 和可选的上传地址。',
    es: 'Se guarda el ID y la URL de subida.',
    fr: 'L’appli mémorise l’ID et l’URL.',
    de: 'ID und optionale URL werden gespeichert',
    ja: 'IDと任意のURLを保存します',
  );
  String get pairingStep3Title => _l6(
    en: 'Connect to Wi‑Fi if prompted',
    zh: '按提示连接 Wi‑Fi',
    es: 'Conecta el Wi‑Fi',
    fr: 'Connectez le Wi‑Fi',
    de: 'Ggf. ins WLAN wechseln',
    ja: '案内に従いWi‑Fiへ',
  );
  String get pairingStep3Body => _l6(
    en: 'The frame and phone should be on the same home network to upload photos.',
    zh: '相框与手机通常需在同一网络以便上传照片。',
    es: 'Misma red doméstica para subir fotos',
    fr: 'Même réseau local pour l’envoi',
    de: 'Für Uploads: gleiche Heimnetzwerk',
    ja: '同一ネットワークでアップロード',
  );
  String get scanFrameQrCta => _l6(
    en: 'Scan frame QR',
    zh: '扫描相框码',
    es: 'Escanear QR',
    fr: 'Scanner le QR',
    de: 'QR scannen',
    ja: 'QRをスキャン',
  );

  String get deviceManagementTitle => _l6(
    en: 'Device & pairing',
    zh: '设备与配对',
    es: 'Dispositivo y emparejamiento',
    fr: 'Appareil & appairage',
    de: 'Gerät & Kopplung',
    ja: 'デバイスとペア',
  );
  String get deviceManagementIntro => _l6(
    en: 'Name your frame, view storage on the next firmware release, and repair pairing if you replace the display.',
    zh: '管理设备、存储信息将在固件升级后提供；可在此重新配对。',
    es: 'Gestiona y repara el emparejamiento.',
    fr: 'Gérer l’appareil et l’appairage.',
    de: 'Gerät verwalten, Kopplung reparieren.',
    ja: '管理とペアの修復',
  );
  String get pairedFrameLabel => _l6(
    en: 'Paired device',
    zh: '已配对设备',
    es: 'Dispositivo',
    fr: 'Appareil',
    de: 'Gerät',
    ja: 'ペア中',
  );
  String get pairedUrlLabel => _l6(
    en: 'Upload / API address',
    zh: '上传 / API 地址',
    es: 'Dirección API',
    fr: 'Adresse d’envoi',
    de: 'API-Adresse',
    ja: 'APIアドレス',
  );
  String get repairPairing => _l6(
    en: 'Pair frame again via Bluetooth',
    zh: '通过蓝牙重新配对相框',
    es: 'Volver a emparejar por Bluetooth',
    fr: 'Réappairer en Bluetooth',
    de: 'Erneut per Bluetooth koppeln',
    ja: 'Bluetoothで再ペア',
  );
  String get helpFaq => _l6(
    en: 'Help & tips',
    zh: '帮助与说明',
    es: 'Ayuda',
    fr: 'Aide',
    de: 'Hilfe',
    ja: 'ヘルプ',
  );
  String get helpSupportTitle => _l6(
    en: 'Help & support',
    zh: '帮助与支持',
    es: 'Ayuda y soporte',
    fr: 'Aide et support',
    de: 'Hilfe & Support',
    ja: 'ヘルプ',
  );
  String get faqSectionTitle =>
      _l6(en: 'FAQ', zh: '常见问题', es: 'FAQ', fr: 'FAQ', de: 'FAQ', ja: 'よくある質問');
  String get deviceManagementFaq => _l6(
    en: 'If the frame is replaced or reset, open Pairing and run Bluetooth discovery to connect again. Wi‑Fi uploads use the local API.',
    zh: '若更换相框或重置，请打开配对并重新进行蓝牙发现并连接。Wi‑Fi 上传走局域网 API。',
    es: 'Si cambias el marco, vuelve a emparejar por Bluetooth.',
    fr: 'Après réinitialisation, rouvrez l’appairage Bluetooth.',
    de: 'Nach einem Reset Bluetooth-Erkennung erneut starten.',
    ja: '初期化後はペア設定からBluetooth検出で再接続してください。',
  );
  String get deviceSectionFirmware => _l6(
    en: 'Firmware',
    zh: '固件',
    es: 'Firmware',
    fr: 'Micrologiciel',
    de: 'Firmware',
    ja: 'ファームウェア',
  );
  String get deviceAutomaticFirmwareTitle => _l6(
    en: 'Automatic updates',
    zh: '自动更新',
    es: 'Actualizaciones automáticas',
    fr: 'Mises à jour auto',
    de: 'Automatische Updates',
    ja: '自動アップデート',
  );
  String get deviceAutomaticFirmwareSub => _l6(
    en: 'Download and install OTA firmware over Wi‑Fi. Turn off to disable automatic updates.',
    zh: '通过 Wi‑Fi 自动下载并安装 OTA 固件。关闭后不再自动更新。',
    es: 'Descarga e instala firmware OTA por Wi‑Fi. Desactívalo para no actualizar automáticamente.',
    fr: 'Télécharge et installe le micrologiciel OTA en Wi‑Fi. Désactive pour arrêter le mode auto.',
    de: 'OTA-Firmware per WLAN laden und installieren. Aus = keine automatischen Updates.',
    ja: 'Wi‑Fi経由でOTAファームを自動取得・適用。オフにすると自動更新しません。',
  );

  /// Legacy keys kept for any remaining references; prefer [deviceAutomaticFirmwareTitle].
  String get deviceStopFirmwareOtaTitle => deviceAutomaticFirmwareTitle;
  String get deviceStopFirmwareOtaSub => deviceAutomaticFirmwareSub;
  String get deviceFirmwareOtaAppPrefsOff => _l6(
    en: 'Turn on “Automatic updates” in App preferences as well so the frame receives OTA when available.',
    zh: '请在「应用偏好」中也开启「自动更新」，相框才能在可用时接收 OTA。',
    es: 'Activa también “Actualizaciones automáticas” en Preferencias.',
    fr: 'Activez aussi les mises à jour auto dans Préférences.',
    de: 'Schalten Sie unter App-Einstellungen ebenfalls automatische Updates ein.',
    ja: 'アプリの設定でも「自動更新」をオンにしてください。',
  );
  String get appPrefsOtaDeviceStoppedHint => _l6(
    en: 'Automatic updates are off in Settings — the frame will not install OTA until you enable them.',
    zh: '设置中关闭了自动更新，相框在您重新开启之前不会安装 OTA。',
    es: 'Las actualizaciones automáticas están desactivadas en Ajustes.',
    fr: 'Les mises à jour auto sont désactivées dans les réglages.',
    de: 'Automatische Updates sind in den Einstellungen aus.',
    ja: '設定で自動アップデートがオフのため、OTAは行われません。',
  );
  String get deviceCheckUpdatesCta => _l6(
    en: 'Check for updates',
    zh: '检查更新',
    es: 'Buscar actualizaciones',
    fr: 'Vérifier les mises à jour',
    de: 'Nach Updates suchen',
    ja: '更新を確認',
  );
  String get firmwareUpdateTitle => _l6(
    en: 'Frame firmware update',
    zh: '相框固件更新',
    es: 'Actualización de firmware',
    fr: 'Mise à jour firmware',
    de: 'Firmware-Update',
    ja: 'フレームファーム更新',
  );
  String get firmwareUpdateSub => _l6(
    en: 'Check MyFrame servers for a new release and install it over Wi‑Fi on your paired frame.',
    zh: '从 MyFrame 服务器检查新版本，并通过 Wi‑Fi 安装到已配对的相框。',
    es: 'Comprueba si hay una nueva versión en MyFrame e instálala por Wi‑Fi en tu marco.',
    fr: 'Vérifie une nouvelle version sur MyFrame et installe-la en Wi‑Fi sur votre cadre.',
    de: 'Prüfe MyFrame auf eine neue Version und installiere sie per WLAN auf deinem Rahmen.',
    ja: 'MyFrameサーバーで新しいファームを確認し、ペアリング済みフレームにWi‑Fiで適用します。',
  );
  String get firmwareCurrentVersion => _l6(
    en: 'Installed',
    zh: '当前版本',
    es: 'Instalada',
    fr: 'Installée',
    de: 'Installiert',
    ja: 'インストール済み',
  );
  String get firmwareLatestVersion => _l6(
    en: 'Latest release',
    zh: '最新版本',
    es: 'Última versión',
    fr: 'Dernière version',
    de: 'Neueste Version',
    ja: '最新リリース',
  );
  String get firmwareUpToDate => _l6(
    en: 'Your frame is up to date.',
    zh: '相框已是最新版本。',
    es: 'Tu marco está actualizado.',
    fr: 'Votre cadre est à jour.',
    de: 'Dein Rahmen ist auf dem neuesten Stand.',
    ja: 'フレームは最新です。',
  );
  String get firmwareUpdateAvailable => _l6(
    en: 'A firmware update is available.',
    zh: '有新的固件可用。',
    es: 'Hay una actualización de firmware disponible.',
    fr: 'Une mise à jour firmware est disponible.',
    de: 'Ein Firmware-Update ist verfügbar.',
    ja: '新しいファームウェアがあります。',
  );
  String get firmwareInstallUpdate => _l6(
    en: 'Install update',
    zh: '安装更新',
    es: 'Instalar actualización',
    fr: 'Installer',
    de: 'Update installieren',
    ja: '更新をインストール',
  );
  String get firmwareUpdating => _l6(
    en: 'Update sent to the frame. It may reboot and take a few minutes.',
    zh: '更新已发送到相框，可能会重启并需要几分钟。',
    es: 'Actualización enviada. El marco puede reiniciarse y tardar unos minutos.',
    fr: 'Mise à jour envoyée. Le cadre peut redémarrer.',
    de: 'Update gesendet. Der Rahmen startet ggf. neu.',
    ja: '更新を送信しました。再起動に数分かかる場合があります。',
  );
  String get firmwareUpdateFailed => _l6(
    en: 'Firmware update failed. Keep the frame online and try again.',
    zh: '固件更新失败。请保持相框在线后重试。',
    es: 'La actualización falló. Mantén el marco en línea e inténtalo de nuevo.',
    fr: 'Échec de la mise à jour. Gardez le cadre en ligne.',
    de: 'Update fehlgeschlagen. Rahmen online lassen und erneut versuchen.',
    ja: '更新に失敗しました。フレームをオンラインのまま再試行してください。',
  );
  String get firmwareSignInRequired => _l6(
    en: 'Sign in to check and install frame firmware updates.',
    zh: '请先登录以检查并安装相框固件更新。',
    es: 'Inicia sesión para comprobar e instalar firmware.',
    fr: 'Connectez-vous pour gérer le firmware.',
    de: 'Melde dich an, um Firmware-Updates zu prüfen.',
    ja: 'ファーム更新にはサインインが必要です。',
  );
  String get firmwareNoDevice => _l6(
    en: 'Pair a frame first to manage firmware updates.',
    zh: '请先配对相框后再管理固件更新。',
    es: 'Empareja un marco primero.',
    fr: 'Associez d’abord un cadre.',
    de: 'Kopple zuerst einen Rahmen.',
    ja: '先にフレームをペアリングしてください。',
  );
  String get firmwareFrameOffline => _l6(
    en: 'Frame is offline. Connect it to Wi‑Fi before installing firmware.',
    zh: '相框离线。安装固件前请先连接 Wi‑Fi。',
    es: 'Marco sin conexión. Conéctalo a Wi‑Fi antes de instalar.',
    fr: 'Cadre hors ligne. Connectez-le au Wi‑Fi.',
    de: 'Rahmen offline. Vor dem Update mit WLAN verbinden.',
    ja: 'フレームがオフラインです。Wi‑Fi接続後にインストールしてください。',
  );
  String get sleepMode => _l6(
    en: 'Sleep Mode',
    zh: '休眠模式',
    es: 'Modo de suspensión',
    fr: 'Mode veille',
    de: 'Schlafmodus',
    ja: 'スリープモード',
  );
  String get sleepModeSchedule => _l6(
    en: 'Sleep Mode Schedule',
    zh: '休眠模式时间表',
    es: 'Horario de suspensión',
    fr: 'Horaire de veille',
    de: 'Schlafzeitplan',
    ja: 'スリープスケジュール',
  );
  String get sleepStartTime => _l6(
    en: 'Sleep Start Time',
    zh: '休眠开始时间',
    es: 'Hora de inicio',
    fr: 'Heure de début',
    de: 'Einschlafzeit',
    ja: 'スリープ開始時間',
  );
  String get wakeUpTime => _l6(
    en: 'Wake Up Time',
    zh: '唤醒时间',
    es: 'Hora de despertar',
    fr: 'Heure de réveil',
    de: 'Aufwachzeit',
    ja: '起床時間',
  );
  String get sleepModeHint => _l6(
    en: 'Set automatic sleep and wake times',
    zh: '设定相框自动休眠时段',
    es: 'Configure el horario automático de suspensión',
    fr: 'Définissez les heures de veille automatiques',
    de: 'Automatische Schlaf- und Aufwachzeiten festlegen',
    ja: '自動でスリープ・起床する時間を設定します',
  );
  String get sleepModeEnabled => _l6(
    en: 'Enable Sleep Mode',
    zh: '启用睡眠模式',
    es: 'Activar modo suspensión',
    fr: 'Activer le mode veille',
    de: 'Schlafmodus aktivieren',
    ja: 'スリープモードを有効にする',
  );
  String get sleepSaved => _l6(
    en: 'Sleep settings saved',
    zh: '睡眠设置已保存',
    es: 'Ajustes de suspensión guardados',
    fr: 'Paramètres de veille enregistrés',
    de: 'Schlafeinstellungen gespeichert',
    ja: 'スリープ設定を保存しました',
  );
  String get save => _l6(
    en: 'Save',
    zh: '保存',
    es: 'Guardar',
    fr: 'Enregistrer',
    de: 'Speichern',
    ja: '保存',
  );
  String get saveFailed => _l6(
    en: 'Save failed',
    zh: '保存失败',
    es: 'Error al guardar',
    fr: 'Échec de l’enregistrement',
    de: 'Speichern fehlgeschlagen',
    ja: '保存に失敗しました',
  );
  String get disabledLabel => _l6(
    en: 'Disabled',
    zh: '已禁用',
    es: 'Desactivado',
    fr: 'Désactivé',
    de: 'Deaktiviert',
    ja: '無効',
  );
  String get otaFirmwareUpdate => _l6(
    en: 'OTA Firmware Update',
    zh: 'OTA 固件更新',
    es: 'Actualización OTA',
    fr: 'Mise à jour OTA',
    de: 'OTA-Firmware-Update',
    ja: 'OTAファームウェア更新',
  );
  String get otaAutoCheckOn => _l6(
    en: 'Auto-check on',
    zh: '自动检查已开启',
    es: 'Verificación automática activada',
    fr: 'Vérification auto activée',
    de: 'Automatische Prüfung an',
    ja: '自動チェックオン',
  );
  String get otaAutoCheckOff => _l6(
    en: 'Auto-check off',
    zh: '自动检查已关闭',
    es: 'Verificación automática desactivada',
    fr: 'Vérification auto désactivée',
    de: 'Automatische Prüfung aus',
    ja: '自動チェックオフ',
  );
  String get okLabel => _l6(
    en: 'OK',
    zh: '确定',
    es: 'OK',
    fr: 'OK',
    de: 'OK',
    ja: 'OK',
  );
  String maxPhotosAllowed(int max) => _l6(
    en: 'Maximum $max photos allowed.',
    zh: '最多 $max 张照片。',
    es: 'Máximo $max fotos.',
    fr: 'Maximum $max photos.',
    de: 'Maximal $max Fotos.',
    ja: '最大$max枚までです。',
  );
  String onlyMoreAllowed(int remaining, int max) => _l6(
    en: 'Only $remaining more allowed (max $max).',
    zh: '仅能再选 $remaining 张（最多 $max）。',
    es: 'Solo $remaining más (máx $max).',
    fr: 'Seulement $remaining de plus (max $max).',
    de: 'Nur $remaining weitere (max. $max).',
    ja: 'あと$remaining枚のみ（最大$max）。',
  );
  String firmwareCheckErrorMessage(String code) {
    switch (code) {
      case 'unauthorized_admin_token':
      case 'route_not_found':
        return _l6(
          en: 'Update check is not available on the server yet. Try again after the app backend is updated.',
          zh: '服务器暂不支持固件检查，请稍后再试。',
          es: 'La comprobación de actualización no está disponible en el servidor.',
          fr: 'La vérification de mise à jour n’est pas disponible sur le serveur.',
          de: 'Update-Prüfung auf dem Server noch nicht verfügbar.',
          ja: 'サーバーでアップデート確認がまだ利用できません。',
        );
      case 'unauthorized':
      case 'auth_required':
        return firmwareSignInRequired;
      case 'frame_not_found':
        return _l6(
          en: 'This frame was not found on your account.',
          zh: '未找到该相框。',
          es: 'No se encontró este marco en tu cuenta.',
          fr: 'Ce cadre est introuvable sur votre compte.',
          de: 'Dieser Rahmen wurde in Ihrem Konto nicht gefunden.',
          ja: 'アカウントにこのフレームが見つかりません。',
        );
      default:
        return _l6(
          en: 'Could not check for updates. Pull to refresh or try again later.',
          zh: '无法检查更新，请稍后重试。',
          es: 'No se pudo comprobar actualizaciones. Inténtalo más tarde.',
          fr: 'Impossible de vérifier les mises à jour. Réessayez plus tard.',
          de: 'Update-Prüfung fehlgeschlagen. Später erneut versuchen.',
          ja: 'アップデートを確認できませんでした。後でもう一度お試しください。',
        );
    }
  }

  String get createPlaylistFlowTitle => _l6(
    en: 'New playlist',
    zh: '新建播放列表',
    es: 'Nueva lista',
    fr: 'Nouvelle liste',
    de: 'Neue Wiedergabeliste',
    ja: '新規プレイリスト',
  );
  String get playlistNameLabel => _l6(
    en: 'Playlist name',
    zh: '名称',
    es: 'Nombre',
    fr: 'Nom',
    de: 'Name',
    ja: '名前',
  );
  String get addPhotosToPlaylistCta => _l6(
    en: 'Choose photos to add',
    zh: '选择要加入的照片',
    es: 'Elegir fotos',
    fr: 'Choisir des photos',
    de: 'Fotos wählen',
    ja: '写真を選ぶ',
  );
  String get savePlaylistCta => _l6(
    en: 'Save playlist',
    zh: '保存播放列表',
    es: 'Guardar lista',
    fr: 'Enregistrer',
    de: 'Speichern',
    ja: '保存',
  );

  String get slideshowVsPlaylistTitle => _l6(
    en: 'Slideshow vs playlist',
    zh: '幻灯片与播放列表',
    es: 'Presentación vs lista',
    fr: 'Diaporama et liste',
    de: 'Diashow vs. Wiedergabeliste',
    ja: 'スライドショーとプレイリスト',
  );
  String get slideshowVsPlaylistExplain => _l6(
    en: 'Batch Slideshow sends a timed sequence to the frame. Playlist (cloud ordering and swipe on the glass) is not available in this build yet—we are focusing on a stable send pipeline first.',
    zh: '批量幻灯片是按间隔向相框推送一组照片。云端排序或在相框玻璃上左右滑动的播放列表功能尚未在本版提供，当前优先完善稳定的发送流程。',
    es: 'El modo “slideshow” por lotes envía una secuencia con tiempo. La lista tipo nube/swipe llegará después.',
    fr: 'Le diaporama par lot envoie une séquence. La liste swipe sur le cadre arrive plus tard.',
    de: 'Stapel‑Diashow sendet zeitgesteuert eine Sequenz. Cloud‑Liste/Swipe folgt später.',
    ja: '一括スライドショーは指定間隔で送ります。クラウド順序／スワイプのプレイリストは今後対応です。',
  );
  String get playlistComingSoonTitle => _l6(
    en: 'Playlist: coming soon',
    zh: '播放列表：敬请期待',
    es: 'Lista: pronto',
    fr: 'Liste : bientôt',
    de: 'Wiedergabeliste folgt bald',
    ja: 'プレイリストは近日公開',
  );
  String get playlistComingSoonBody => _l6(
    en: 'Photo ordering that you swipe left and right on the frame is under development.',
    zh: '在相框上左右滑动切换照片的顺序播放功能仍在开发中。',
    es: 'El gesto izquierda/derecha en el marco está en desarrollo.',
    fr: 'Balayage gauche/droite sur le cadre en développement.',
    de: 'Links/Rechts‑Wischen auf dem Rahmen ist in Arbeit.',
    ja: 'フレーム上の左右スワイプ切替は開発中です。',
  );

  String get displaySettingsScreenTitle => _l6(
    en: 'Display settings',
    zh: '显示设置',
    es: 'Pantalla',
    fr: 'Affichage',
    de: 'Anzeige',
    ja: '表示設定',
  );
  String get displaySettingsIntro => _l6(
    en: 'Comfort typography and slideshow refresh pacing for Preview in the app. Frame hardware display options stay on the paired device firmware.',
    zh: '阅读舒适度与应用内预览轮播间隔在此设置；相框硬件显示选项由配对设备固件决定。',
    es: 'Comodidad tipográfica e intervalos de vista previa aquí.',
    fr: 'Confort lecture et cadence de prévisualisation ici.',
    de: 'Komfort‑Text und App‑Vorschau‑Takt hier.',
    ja: '読みやすさとプレビュー間隔などはこちら。',
  );
  String get displaySettingsSub => _l6(
    en: 'Comfort mode & preview refresh',
    zh: '舒适模式与预览刷新',
    es: 'Modo confort y actualización',
    fr: 'Mode confort et rafraîchissement',
    de: 'Komfortmodus & Vorschau',
    ja: '快適モードとプレビュー更新',
  );
  String get showAllLabel => _l6(
    en: 'Show all',
    zh: '显示全部',
    es: 'Ver todo',
    fr: 'Tout afficher',
    de: 'Alle anzeigen',
    ja: 'すべて表示',
  );
  String get showLessLabel => _l6(
    en: 'Show less',
    zh: '收起',
    es: 'Ver menos',
    fr: 'Réduire',
    de: 'Weniger anzeigen',
    ja: '折りたたむ',
  );
  String get displayAutoRefreshTitle => _l6(
    en: 'Preview refresh interval',
    zh: '预览刷新间隔',
    es: 'Intervalo de vista',
    fr: 'Intervalle de prévue',
    de: 'Vorschau‑Intervall',
    ja: 'プレビュー間隔',
  );
  String displayAutoRefreshSubtitle(int minutes) => _l6(
    en: 'About every $minutes minutes (preview / mock timing).',
    zh: '约每 $minutes 分钟（预览/演示用）。',
    es: '~cada $minutes min (preview).',
    fr: '~ toutes les $minutes min.',
    de: '~alle $minutes Min.',
    ja: '約 ${minutes} 分ごと（プレビュー用）。',
  );
  String get displayAutoRefreshFootnote => _l6(
    en: 'This does not replace frame firmware timings; paired hardware may vary.',
    zh: '此设置不替代相框固件的实际节奏，已配对设备的显示可能有所不同。',
    es: 'No sustituye al firmware del marco.',
    fr: 'Ne remplace pas le cadencement du cadre.',
    de: 'Ersetzt nicht die Firmware‑Zeitplaene des Rahmens.',
    ja: 'フレーム本体のタイミングは別です。',
  );

  String get joinFamilyBirthdayLabel => _l6(
    en: 'Your birthday',
    zh: '你的生日',
    es: 'Tu cumpleaños',
    fr: 'Votre anniversaire',
    de: 'Ihr Geburtstag',
    ja: 'あなたの誕生日',
  );
  String get joinFamilyBirthdayRequired => _l6(
    en: 'Please choose your birthday to join.',
    zh: '加入家庭请先选择生日。',
    es: 'Elige tu fecha de cumpleaños.',
    fr: 'Choisissez votre date de naissance.',
    de: 'Geburtstag wählen.',
    ja: '誕生日を選んでください。',
  );
  String get notificationsQuietHoursTzFootnote => _l6(
    en: 'Quiet hours use your phone’s local clock. They do not mirror the frame’s onboard clock or server UTC.',
    zh: '勿扰时段使用手机本地时间；与相框时钟或服务器 UTC 不一定一致。',
    es: 'Usan la hora local del teléfono.',
    fr: 'Basées sur l’heure locale du téléphone.',
    de: 'Nutzen die lokale Smartphone‑Zeit.',
    ja: 'スマホの現地時間基準です。フレーム時刻とは一致しません。',
  );

  // —— Send ——
  String get sendPhotoTitle => _l6(
    en: 'Send Photo',
    zh: '发送照片',
    es: 'Enviar foto',
    fr: 'Envoyer une photo',
    de: 'Foto senden',
    ja: '写真を送る',
  );
  String get sendTabSubhead => _l6(
    en: 'Pick a photo, fine-tune it, then send in one place—no extra steps.',
    zh: '选图、调整、发送，一站式完成，无需多步操作。',
    es: 'Elige, ajusta y envía en un solo flujo, sin pasos extra.',
    fr: 'Choisis, règle et envoie en un seul parcours, sans étapes inutiles.',
    de: 'Foto wählen, anpassen, senden – alles in einem Durchlauf.',
    ja: '選ぶ・整える・送るをこの画面で。余計な手間なし。',
  );
  String get sendTabMoreWays => _l6(
    en: 'More ways to add a photo',
    zh: '更多添加方式',
    es: 'Más formas de añadir',
    fr: "Autres façons d'ajouter",
    de: 'Weitere Wege',
    ja: 'その他の追加方法',
  );
  String get sdCardOption => _l6(
    en: 'SD Card',
    zh: 'SD 卡',
    es: 'Tarjeta SD',
    fr: 'Carte SD',
    de: 'SD-Karte',
    ja: 'SDカード',
  );
  String get sdCardSub => _l6(
    en: 'Import and save to card',
    zh: '导入并保存到卡',
    es: 'Importar y guardar',
    fr: 'Importer sur la carte',
    de: 'Importieren & speichern',
    ja: 'カードへ保存',
  );
  String get gallery => _l6(
    en: 'Photo Gallery',
    zh: '相册',
    es: 'Galería',
    fr: 'Galerie',
    de: 'Galerie',
    ja: 'フォトライブラリ',
  );
  String get gallerySub => _l6(
    en: 'Choose from your phone',
    zh: '从手机选择',
    es: 'Desde el teléfono',
    fr: 'Depuis le téléphone',
    de: 'Vom Telefon',
    ja: '端末から選択',
  );
  String get takePhoto => _l6(
    en: 'Take Photo',
    zh: '拍照',
    es: 'Tomar foto',
    fr: 'Prendre une photo',
    de: 'Foto aufnehmen',
    ja: '撮影',
  );
  String get takePhotoSub => _l6(
    en: 'Capture a new photo',
    zh: '拍摄新照片',
    es: 'Nueva captura',
    fr: 'Nouvelle photo',
    de: 'Neues Foto',
    ja: '新規撮影',
  );
  String get shareLink => _l6(
    en: 'ShareLink',
    zh: '分享链接',
    es: 'Enlace',
    fr: 'Lien',
    de: 'Link',
    ja: '共有リンク',
  );
  String get shareLinkSub => _l6(
    en: 'Friends upload via link',
    zh: '好友通过链接上传',
    es: 'Subida por enlace',
    fr: 'Envoi par lien',
    de: 'Upload per Link',
    ja: 'リンクでアップロード',
  );
  String get aiGenerate => _l6(
    en: 'AI Generate',
    zh: 'AI 生成',
    es: 'IA',
    fr: 'IA',
    de: 'KI',
    ja: 'AI生成',
  );
  String get aiGenerateSub => _l6(
    en: 'Create unique art with your API key',
    zh: '使用 API 密钥生成独特作品',
    es: 'Arte único con tu clave API',
    fr: 'Art unique avec votre clé API',
    de: 'Einzigartige Kunst mit API-Schlüssel',
    ja: 'APIキーで作品を生成',
  );
  String get aiImageSettingsIntro => _l6(
    en: 'Add your OpenAI and Google Gemini (AI Studio) keys. Send → AI Generate uses the default provider below.',
    zh: '添加 OpenAI 与 Google Gemini（AI Studio）密钥。发送页的 AI 生成将使用下方默认提供商。',
    es: 'Añade claves de OpenAI y Gemini. Enviar → IA usa el proveedor predeterminado.',
    fr: 'Ajoutez vos clés OpenAI et Gemini. Envoyer → IA utilise le fournisseur par défaut.',
    de: 'OpenAI- und Gemini-Schlüssel hinzufügen. Senden → KI nutzt den Standardanbieter.',
    ja: 'OpenAI と Gemini のキーを追加。送信の AI 生成で使用します。',
  );
  String get aiImageDefaultProviderLabel => _l6(
    en: 'Default for AI Generate',
    zh: 'AI 生成默认提供商',
    es: 'Proveedor predeterminado',
    fr: 'Fournisseur par défaut',
    de: 'Standard für KI-Generierung',
    ja: 'AI生成の既定プロバイダ',
  );
  String get aiProviderOpenAi => _l6(
    en: 'OpenAI',
    zh: 'OpenAI',
    es: 'OpenAI',
    fr: 'OpenAI',
    de: 'OpenAI',
    ja: 'OpenAI',
  );
  String get aiProviderGemini => _l6(
    en: 'Gemini',
    zh: 'Gemini',
    es: 'Gemini',
    fr: 'Gemini',
    de: 'Gemini',
    ja: 'Gemini',
  );
  String get aiOpenAiKeyLabel => _l6(
    en: 'OpenAI API key',
    zh: 'OpenAI API 密钥',
    es: 'Clave API OpenAI',
    fr: 'Clé API OpenAI',
    de: 'OpenAI-API-Schlüssel',
    ja: 'OpenAI APIキー',
  );
  String get aiOpenAiKeyHint => _l6(
    en: 'sk-…',
    zh: 'sk-…',
    es: 'sk-…',
    fr: 'sk-…',
    de: 'sk-…',
    ja: 'sk-…',
  );
  String get aiGeminiKeyLabel => _l6(
    en: 'Gemini API key',
    zh: 'Gemini API 密钥',
    es: 'Clave API Gemini',
    fr: 'Clé API Gemini',
    de: 'Gemini-API-Schlüssel',
    ja: 'Gemini APIキー',
  );
  String get aiGeminiKeyHint => _l6(
    en: 'AI Studio key',
    zh: 'AI Studio 密钥',
    es: 'Clave de AI Studio',
    fr: 'Clé AI Studio',
    de: 'AI-Studio-Schlüssel',
    ja: 'AI Studio キー',
  );
  String get aiImageKeysSaved => _l6(
    en: 'AI keys saved',
    zh: 'AI 密钥已保存',
    es: 'Claves guardadas',
    fr: 'Clés enregistrées',
    de: 'KI-Schlüssel gespeichert',
    ja: 'AIキーを保存しました',
  );
  String get aiGeneratePromptTitle => _l6(
    en: 'Describe your image',
    zh: '描述你想要的图片',
    es: 'Describe tu imagen',
    fr: 'Décrivez votre image',
    de: 'Bild beschreiben',
    ja: '画像の説明',
  );
  String get aiGeneratePromptLabel => _l6(
    en: 'Prompt',
    zh: '提示词',
    es: 'Indicación',
    fr: 'Invite',
    de: 'Prompt',
    ja: 'プロンプト',
  );
  String get aiGeneratePromptConfirm => _l6(
    en: 'Generate',
    zh: '生成',
    es: 'Generar',
    fr: 'Générer',
    de: 'Generieren',
    ja: '生成',
  );
  String get aiGenerateMissingKey => _l6(
    en: 'Add your API key in Settings → AI Generate first.',
    zh: '请先在设置 → AI 生成中添加 API 密钥。',
    es: 'Añade tu clave en Ajustes → IA primero.',
    fr: 'Ajoutez votre clé dans Réglages → IA.',
    de: 'Zuerst Schlüssel unter Einstellungen → KI hinzufügen.',
    ja: '設定 → AI 生成で API キーを追加してください。',
  );
  String get aiGenerateWorking => _l6(
    en: 'Generating image…',
    zh: '正在生成图片…',
    es: 'Generando imagen…',
    fr: 'Génération…',
    de: 'Bild wird erstellt…',
    ja: '画像を生成中…',
  );
  String aiGenerateFailed(String detail) => _l6(
    en: 'Could not generate image: $detail',
    zh: '无法生成图片：$detail',
    es: 'No se pudo generar: $detail',
    fr: 'Échec de génération : $detail',
    de: 'Generierung fehlgeschlagen: $detail',
    ja: '生成に失敗しました: $detail',
  );
  String get sendSlideshowOpensPlaylist => _l6(
    en: 'Create playlists and send multiple photos',
    zh: '创建播放列表并发送多张照片',
    es: 'Crea listas y envía varias fotos',
    fr: 'Créez des listes et envoyez plusieurs photos',
    de: 'Playlists erstellen und mehrere Fotos senden',
    ja: 'プレイリストを作成して複数送信',
  );
  String get pro => 'PRO';
  String get sendGift => _l6(
    en: 'Send Gift',
    zh: '送礼',
    es: 'Regalo',
    fr: 'Cadeau',
    de: 'Geschenk',
    ja: 'ギフト',
  );
  String get sendGiftSub => _l6(
    en: 'Pick a card and send to family frame',
    zh: '选择贺卡发送到家庭相框',
    es: 'Tarjeta al marco',
    fr: 'Carte vers le cadre',
    de: 'Karte an den Rahmen',
    ja: 'カードをフレームへ',
  );

  String get sendToFrame => _l6(
    en: 'Send to frame',
    zh: '发送到相框',
    es: 'Enviar al marco',
    fr: 'Envoyer au cadre',
    de: 'An Rahmen senden',
    ja: 'フレームへ送信',
  );
  String get chooseFrameToSendHint => _l6(
    en: 'Choose which frame should receive this photo.',
    zh: '选择要接收照片的相框。',
    es: 'Elige qué marco recibirá esta foto.',
    fr: 'Choisissez le cadre qui recevra cette photo.',
    de: 'Wählen Sie den Rahmen für dieses Foto.',
    ja: 'この写真を送るフレームを選んでください。',
  );
  String get chooseTransport => _l6(
    en: 'Choose transport',
    zh: '选择传输方式',
    es: 'Elegir transporte',
    fr: 'Choisir le transport',
    de: 'Übertragung wählen',
    ja: '転送方法',
  );

  /// Image editor send section: VPS/MQTT only (no Bluetooth image pipe).
  String get editorSendVpsOnlyHelp => _l6(
    en: 'Upload runs over the internet to your server; the frame downloads the photo (MQTT). Bluetooth is not used to send pictures.',
    zh: '通过互联网上传到您的服务器，相框经 MQTT 拉取照片；蓝牙不传送图片。',
    es: 'Subida a tu servidor; el marco descarga por MQTT. Bluetooth no envía fotos.',
    fr: 'Envoi à votre serveur ; le cadre télécharge via MQTT. Pas d’images en Bluetooth.',
    de: 'Upload auf Ihren Server; Rahmen lädt per MQTT herunter. Bluetooth versendet keine Bilder.',
    ja: 'サーバーへアップロードし、MQTTでフレームが取得します。写真はBluetoothで送りません。',
  );

  String get transportLabelVps => _l6(
    en: 'Server',
    zh: '服务器',
    es: 'Servidor',
    fr: 'Serveur',
    de: 'Server',
    ja: 'サーバー',
  );

  String get pairingNeedsApiUrl => _l6(
    en:
        'The app needs your API base URL for uploads — either scan a pairing QR that includes it, '
        'or set Self-hosted MQTT in Wi‑Fi setup (same host as your VPS; we use http://that-host:3001 for uploads while MQTT stays on 1883).',
    zh: '配对需包含二维码中的服务器地址（API）。请重新扫描或配对以便上传到 VPS。',
    es: 'El emparejamiento debe incluir la URL API del código QR; vuelve a escanear.',
    fr: 'L’appairage doit inclure l’URL du serveur (QR). Re-scannez le QR.',
    de: 'Kopplung braucht die Server-URL aus dem QR (API). Bitte QR erneut scannen.',
    ja: 'ペア情報に QR の API(URL) が必要です。QR を読み取り直してください。',
  );
  String get confirmSend => _l6(
    en: 'Send to frame',
    zh: '发送到相框',
    es: 'Enviar al marco',
    fr: 'Envoyer au cadre',
    de: 'Senden',
    ja: '送信',
  );

  String get noImageSelected => _l6(
    en: 'No image selected',
    zh: '未选择图片',
    es: 'Sin imagen',
    fr: 'Aucune image',
    de: 'Kein Bild',
    ja: '画像がありません',
  );
  String shareIncomingHint(int count) => _l6(
    en: count == 1
        ? 'Shared photo — sending to your frame'
        : 'Shared $count photos — sending to your frame',
    zh: count == 1 ? '已分享照片 — 正在发送到相框' : '已分享 $count 张照片 — 正在发送到相框',
    es: count == 1
        ? 'Foto compartida — enviando al marco'
        : '$count fotos compartidas — enviando',
    fr: count == 1
        ? 'Photo partagée — envoi au cadre'
        : '$count photos partagées — envoi',
    de: count == 1
        ? 'Geteiltes Foto — wird gesendet'
        : '$count geteilte Fotos — werden gesendet',
    ja: count == 1 ? '共有された写真をフレームへ送信中' : '共有された${count}枚を送信中',
  );
  String get shareIncomingConnectFrame => _l6(
    en: 'Connect a frame first, then share again to upload.',
    zh: '请先连接相框，然后再次分享即可上传。',
    es: 'Conecta un marco primero y vuelve a compartir.',
    fr: 'Connectez un cadre, puis partagez à nouveau.',
    de: 'Zuerst Rahmen verbinden, dann erneut teilen.',
    ja: '先にフレームを接続してから、もう一度共有してください。',
  );
  String get shareSheetTitle => _l6(
    en: 'Sharing to MyFrame',
    zh: '发送到 MyFrame',
    es: 'Compartir a MyFrame',
    fr: 'Partager vers MyFrame',
    de: 'An MyFrame senden',
    ja: 'MyFrameに共有',
  );
  String get shareSheetOnePhoto => _l6(
    en: '1 Photo',
    zh: '1 张照片',
    es: '1 foto',
    fr: '1 photo',
    de: '1 Foto',
    ja: '写真 1枚',
  );
  String shareSheetNPhotos(int n) => _l6(
    en: '$n Photos',
    zh: '$n 张照片',
    es: '$n fotos',
    fr: '$n photos',
    de: '$n Fotos',
    ja: '写真 $n枚',
  );
  String get shareSheetDestination => _l6(
    en: 'Send to',
    zh: '发送到',
    es: 'Enviar a',
    fr: 'Envoyer à',
    de: 'Senden an',
    ja: '送信先',
  );
  String get shareSheetSend => _l6(
    en: 'Send',
    zh: '发送',
    es: 'Enviar',
    fr: 'Envoyer',
    de: 'Senden',
    ja: '送信',
  );
  String get shareSheetSending => _l6(
    en: 'Sending…',
    zh: '发送中…',
    es: 'Enviando…',
    fr: 'Envoi…',
    de: 'Senden…',
    ja: '送信中…',
  );
  String shareSheetSendingTo(String name) => _l6(
    en: 'Sending to $name…',
    zh: '正在发送到 $name…',
    es: 'Enviando a $name…',
    fr: 'Envoi vers $name…',
    de: 'Senden an $name…',
    ja: '$name に送信中…',
  );
  String get shareSheetPhotoSent => _l6(
    en: 'Photo Sent',
    zh: '照片已发送',
    es: 'Foto enviada',
    fr: 'Photo envoyée',
    de: 'Foto gesendet',
    ja: '写真を送信しました',
  );
  String get shareSheetPlaylistSent => _l6(
    en: 'Playlist Sent',
    zh: '播放列表已发送',
    es: 'Lista enviada',
    fr: 'Playlist envoyée',
    de: 'Playlist gesendet',
    ja: 'プレイリストを送信しました',
  );
  String get myPlaylistName => _l6(
    en: 'My Playlist',
    zh: '我的播放列表',
    es: 'Mi lista',
    fr: 'Mes favoris',
    de: 'Meine Liste',
    ja: 'マイプレイリスト',
  );
  String get shareSheetQueuedOffline => _l6(
    en: "Offline — saved, will send automatically when you're back online",
    zh: '当前离线 — 已保存，联网后自动发送',
    es: 'Sin conexión: guardado, se enviará automáticamente',
    fr: 'Hors ligne : enregistré, sera envoyé automatiquement',
    de: 'Offline — gespeichert, wird automatisch gesendet',
    ja: 'オフライン — 保存しました。接続後に自動送信します',
  );
  String get shareSheetErrorRetry => _l6(
    en: "Couldn't send. Check your network and try again.",
    zh: '发送失败，请检查网络后重试。',
    es: 'No se pudo enviar. Revisa tu conexión e inténtalo.',
    fr: 'Envoi impossible. Vérifiez votre connexion puis réessayez.',
    de: 'Senden fehlgeschlagen. Netzwerk prüfen und erneut versuchen.',
    ja: '送信できませんでした。ネットワークを確認して再試行してください。',
  );
  String get overlayOptions => _l6(
    en: 'Overlay options',
    zh: '叠加信息',
    es: 'Opciones de superposición',
    fr: 'Options de surimpression',
    de: 'Overlay-Optionen',
    ja: 'オーバーレイ設定',
  );
  String get overlayDateLabel => _l6(
    en: 'Show date',
    zh: '显示日期',
    es: 'Mostrar fecha',
    fr: 'Afficher la date',
    de: 'Datum anzeigen',
    ja: '日付を表示',
  );
  String get overlayLocationLabel => _l6(
    en: 'Show location',
    zh: '显示地点',
    es: 'Mostrar ubicación',
    fr: 'Afficher le lieu',
    de: 'Ort anzeigen',
    ja: '場所を表示',
  );
  String get overlayGreetingLabel => _l6(
    en: 'Show greeting',
    zh: '显示问候语',
    es: 'Mostrar saludo',
    fr: 'Afficher le message',
    de: 'Gruß anzeigen',
    ja: '挨拶を表示',
  );
  String get overlayCustomTextLabel => _l6(
    en: 'Custom text',
    zh: '自定义文字',
    es: 'Texto personalizado',
    fr: 'Texte personnalisé',
    de: 'Eigener Text',
    ja: 'カスタムテキスト',
  );
  String get overlayCustomTextHint => _l6(
    en: 'Happy birthday, Nana!',
    zh: '生日快乐，奶奶！',
    es: 'Feliz cumple, abuela!',
    fr: 'Joyeux anniversaire !',
    de: 'Alles Gute zum Geburtstag!',
    ja: 'お誕生日おめでとう！',
  );
  String get overlayOnPhotoHelper => _l6(
    en: 'On the photo, lines stack top to bottom: custom text, greeting, location, date.',
    zh: '照片上自上而下为：自定义文字、问候、地点、日期。',
    es: 'En la foto, de arriba abajo: texto, saludo, lugar, fecha.',
    fr: 'Sur la photo, de haut en bas : texte, accueil, lieu, date.',
    de: 'Auf dem Foto, oben nach unten: Text, Gruß, Ort, Datum.',
    ja: '写真上は上から カスタム文・あいさつ・場所・日付の順に重なります。',
  );

  String get createPlaylist => _l6(
    en: 'Create New Playlist',
    zh: '新建播放列表',
    es: 'Nueva lista',
    fr: 'Nouvelle liste',
    de: 'Neue Playlist',
    ja: '新規プレイリスト',
  );
  String get createPlaylistSub => _l6(
    en: 'Select images from gallery, then send to frame',
    zh: '从相册选择后发送到相框',
    es: 'Elige y envía al marco',
    fr: 'Choisis puis envoie',
    de: 'Wählen und an Rahmen senden',
    ja: '選んでフレームへ',
  );

  String get examplePlaylists => _l6(
    en: 'Example playlists',
    zh: '示例列表',
    es: 'Listas de ejemplo',
    fr: 'Exemples',
    de: 'Beispiele',
    ja: 'サンプル',
  );

  String photosCount(int n) => _l6(
    en: '$n photos',
    zh: '$n 张',
    es: '$n fotos',
    fr: '$n photos',
    de: '$n Fotos',
    ja: '$n 枚',
  );
  String playlistAlbumMessage(String name, int count) => _l6(
    en: '“$name” contains sample items only until the playlist API is connected. ($count items in the mockup.)',
    zh: '“$name” 当前为示例数据，待播放列表 API 对接后显示真实内容（演示 $count 项）。',
    es: '“$name” es demostración ($count).',
    fr: '“$name” : démonstration ($count)',
    de: '“$name” ist Demo ($count)',
    ja: '「$name」はデモ用（$count件）',
  );

  // —— Settings ——
  String get settingsTitle => _l6(
    en: 'Settings',
    zh: '设置',
    es: 'Ajustes',
    fr: 'Réglages',
    de: 'Einstellungen',
    ja: '設定',
  );
  String get account => _l6(
    en: 'Account',
    zh: '账户',
    es: 'Cuenta',
    fr: 'Compte',
    de: 'Konto',
    ja: 'アカウント',
  );
  String get accountSub => _l6(
    en: 'Profile, Birthday',
    zh: '资料与生日',
    es: 'Perfil',
    fr: 'Profil',
    de: 'Profil',
    ja: 'プロフィール',
  );
  String get deviceInfo => _l6(
    en: 'Device Info',
    zh: '设备信息',
    es: 'Dispositivo',
    fr: 'Appareil',
    de: 'Gerät',
    ja: 'デバイス',
  );
  String get deviceInfoSub => _l6(
    en: 'Manage paired devices, details, and pairing',
    zh: '配对与管理',
    es: 'Emparejar',
    fr: 'Appairage',
    de: 'Kopplung',
    ja: 'ペア設定',
  );
  String get notifications => _l6(
    en: 'Notifications',
    zh: '通知',
    es: 'Notificaciones',
    fr: 'Notifications',
    de: 'Benachrichtigungen',
    ja: '通知',
  );
  String get notificationsSub => _l6(
    en: 'Recent activity updates',
    zh: '最近动态更新',
    es: 'Actualizaciones de actividad reciente',
    fr: 'Mises à jour d’activité récente',
    de: 'Aktuelle Aktivitäts-Updates',
    ja: '最近のアクティビティ更新',
  );
  String get connectFrameFirst => _l6(
    en: 'Please connect a frame first.',
    zh: '请先连接相框。',
    es: 'Conecta un marco primero.',
    fr: 'Connectez d’abord un cadre.',
    de: 'Bitte zuerst einen Rahmen verbinden.',
    ja: '先にフレームを接続してください。',
  );
  String get gotItLabel => _l6(
    en: 'Got it',
    zh: '知道了',
    es: 'Entendido',
    fr: 'Compris',
    de: 'Verstanden',
    ja: '了解',
  );
  String get aiContentSafetyNotice => _l6(
    en: 'AI-generated content may be inaccurate or inappropriate. Please review before use.',
    zh: 'AI 生成内容可能不准确或不合适，使用前请仔细核对。',
    es: 'El contenido generado por IA puede ser inexacto o inapropiado. Revísalo antes de usarlo.',
    fr: 'Le contenu généré par l’IA peut être inexact ou inapproprié. Vérifiez-le avant utilisation.',
    de: 'KI-generierte Inhalte können ungenau oder unangemessen sein. Bitte vor der Nutzung prüfen.',
    ja: 'AI 生成コンテンツは不正確または不適切な場合があります。使用前にご確認ください。',
  );
  String get language => _l6(
    en: 'Language',
    zh: '语言',
    es: 'Idioma',
    fr: 'Langue',
    de: 'Sprache',
    ja: '言語',
  );
  String get integrations => _l6(
    en: 'Integrations',
    zh: '集成',
    es: 'Integraciones',
    fr: 'Intégrations',
    de: 'Integrationen',
    ja: '連携',
  );
  String get integrationsSub => _l6(
    en: 'Google, iCloud',
    zh: 'Google、iCloud',
    es: 'Google, iCloud',
    fr: 'Google, iCloud',
    de: 'Google, iCloud',
    ja: 'Google、iCloud',
  );
  String get appPreferences => _l6(
    en: 'App Preferences',
    zh: '应用偏好',
    es: 'Preferencias',
    fr: 'Préférences',
    de: 'App-Einstellungen',
    ja: 'アプリ設定',
  );
  String get appPreferencesSub => _l6(
    en: 'Theme, slideshow & frame updates',
    zh: '主题、轮播与相框更新',
    es: 'Tema, carrusel y actualizaciones',
    fr: 'Thème, diaporama et mises à jour',
    de: 'Theme, Diashow & Updates',
    ja: 'テーマ・スライドショー・更新',
  );
  String get operationLog => _l6(
    en: 'Operation Log',
    zh: '操作日志',
    es: 'Registro',
    fr: 'Journal',
    de: 'Aktivitätsprotokoll',
    ja: '操作ログ',
  );
  String get operationLogSub => _l6(
    en: 'Uploads, shares, and local activity',
    zh: '上传、分享和本地活动',
    es: 'Subidas, compartidos y actividad',
    fr: 'Envois, partages et activité',
    de: 'Uploads, Teilen und lokale Aktivität',
    ja: '送信・共有・ローカル操作',
  );
  String get notificationsClear => _l6(
    en: 'Clear',
    zh: '清除',
    es: 'Borrar',
    fr: 'Effacer',
    de: 'Leeren',
    ja: 'クリア',
  );
  String get notificationsEmptyTitle => _l6(
    en: 'No activity yet',
    zh: '暂无动态',
    es: 'Sin actividad',
    fr: 'Aucune activité',
    de: 'Noch keine Aktivität',
    ja: 'まだアクティビティがありません',
  );
  String get notificationsEmptyBody => _l6(
    en: 'When you send photos or connect cloud storage, updates appear here.',
    zh: '发送照片或连接云存储后，动态会显示在这里。',
    es: 'Al enviar fotos o conectar la nube, verás la actividad aquí.',
    fr: 'En envoyant des photos ou en connectant le cloud, l’activité s’affiche ici.',
    de: 'Beim Senden von Fotos oder Cloud-Verbindung erscheint die Aktivität hier.',
    ja: '写真を送信したりクラウドを接続すると、ここに表示されます。',
  );
  String get inAppNotifPhotoSentTitle => _l6(
    en: 'Photo sent to frame',
    zh: '照片已发送到相框',
    es: 'Foto enviada al marco',
    fr: 'Photo envoyée au cadre',
    de: 'Foto an Rahmen gesendet',
    ja: 'フレームに写真を送信',
  );
  String inAppNotifPhotoSentBody(String frameName) => _l6(
    en: frameName.isEmpty
        ? 'Your edited photo was sent to your frame.'
        : 'Your edited photo was delivered to $frameName.',
    zh: frameName.isEmpty ? '您编辑的照片已发送到相框。' : '您编辑的照片已发送到 $frameName。',
    es: frameName.isEmpty
        ? 'Tu foto editada se envió al marco.'
        : 'Tu foto editada se entregó a $frameName.',
    fr: frameName.isEmpty
        ? 'Votre photo retouchée a été envoyée au cadre.'
        : 'Votre photo retouchée a été livrée à $frameName.',
    de: frameName.isEmpty
        ? 'Ihr bearbeitetes Foto wurde an den Rahmen gesendet.'
        : 'Ihr bearbeitetes Foto wurde an $frameName geliefert.',
    ja: frameName.isEmpty
        ? '編集した写真をフレームに送信しました。'
        : '編集した写真を $frameName に送信しました。',
  );
  String get inAppNotifCloudUploadTitle => _l6(
    en: 'Saved to cloud',
    zh: '已保存到云端',
    es: 'Guardado en la nube',
    fr: 'Enregistré dans le cloud',
    de: 'In Cloud gespeichert',
    ja: 'クラウドに保存',
  );
  String inAppNotifCloudUploadBody(String provider, String fileName) => _l6(
    en: '$fileName uploaded to your $provider account.',
    zh: '$fileName 已上传到您的 $provider 账户。',
    es: '$fileName subido a tu cuenta de $provider.',
    fr: '$fileName téléversé sur votre compte $provider.',
    de: '$fileName in Ihr $provider-Konto hochgeladen.',
    ja: '$fileName を $provider アカウントにアップロードしました。',
  );
  String get inAppNotifBirthdayTitle => _l6(
    en: 'Birthday reminder',
    zh: '生日提醒',
    es: 'Recordatorio de cumpleaños',
    fr: 'Rappel d’anniversaire',
    de: 'Geburtstags-Erinnerung',
    ja: '誕生日リマインダー',
  );
  String inAppNotifBirthdayBody(String name, int daysUntil) => _l6(
    en: daysUntil <= 0
        ? '$name\'s birthday is today!'
        : '$name\'s birthday is in $daysUntil days.',
    zh: daysUntil <= 0 ? '$name 的生日是今天！' : '$name 的生日还有 $daysUntil 天。',
    es: daysUntil <= 0
        ? '¡El cumpleaños de $name es hoy!'
        : 'El cumpleaños de $name es en $daysUntil días.',
    fr: daysUntil <= 0
        ? 'C’est l’anniversaire de $name aujourd’hui !'
        : 'L’anniversaire de $name est dans $daysUntil jours.',
    de: daysUntil <= 0
        ? '$name hat heute Geburtstag!'
        : '$name hat in $daysUntil Tagen Geburtstag.',
    ja: daysUntil <= 0 ? '今日は $name の誕生日です！' : '$name の誕生日まであと $daysUntil 日です。',
  );
  String get inAppNotifOfflineTitle => _l6(
    en: 'Frame offline',
    zh: '相框离线',
    es: 'Marco sin conexión',
    fr: 'Cadre hors ligne',
    de: 'Rahmen offline',
    ja: 'フレームがオフライン',
  );
  String inAppNotifOfflineBody(String frameName) => _l6(
    en: frameName.isEmpty
        ? 'Your frame appears to be offline.'
        : '$frameName appears to be offline.',
    zh: frameName.isEmpty ? '您的相框似乎已离线。' : '$frameName 似乎已离线。',
    es: frameName.isEmpty
        ? 'Tu marco parece estar sin conexión.'
        : '$frameName parece estar sin conexión.',
    fr: frameName.isEmpty
        ? 'Votre cadre semble hors ligne.'
        : '$frameName semble hors ligne.',
    de: frameName.isEmpty
        ? 'Ihr Rahmen scheint offline zu sein.'
        : '$frameName scheint offline zu sein.',
    ja: frameName.isEmpty ? 'フレームがオフラインのようです。' : '$frameName がオフラインのようです。',
  );
  String get inAppNotifFamilyTitle => _l6(
    en: 'Family activity',
    zh: '家庭动态',
    es: 'Actividad familiar',
    fr: 'Activité familiale',
    de: 'Familienaktivität',
    ja: 'ファミリーアクティビティ',
  );
  String get inAppNotifFamilyBody => _l6(
    en: 'Something new happened in your family group.',
    zh: '您的家庭组有新动态。',
    es: 'Algo nuevo en tu grupo familiar.',
    fr: 'Nouvelle activité dans votre groupe familial.',
    de: 'Neues in Ihrer Familiengruppe.',
    ja: 'ファミリーグループに新しい動きがありました。',
  );
  String get inAppNotifOtherTitle => _l6(
    en: 'Activity',
    zh: '动态',
    es: 'Actividad',
    fr: 'Activité',
    de: 'Aktivität',
    ja: 'アクティビティ',
  );
  String get inAppNotifOtherBody => _l6(
    en: 'Something happened in MyFrame.',
    zh: 'MyFrame 中有新动态。',
    es: 'Algo ocurrió en MyFrame.',
    fr: 'Une activité dans MyFrame.',
    de: 'Etwas ist in MyFrame passiert.',
    ja: 'MyFrame で何かがありました。',
  );
  String integrationErrorGooglePhotos(String detail) => _l6(
    en: 'Google Photos: $detail',
    zh: 'Google 相册：$detail',
    es: 'Google Fotos: $detail',
    fr: 'Google Photos : $detail',
    de: 'Google Fotos: $detail',
    ja: 'Google フォト: $detail',
  );
  String integrationErrorICloud(String detail) => _l6(
    en: 'iCloud Photos: $detail',
    zh: 'iCloud 照片：$detail',
    es: 'Fotos de iCloud: $detail',
    fr: 'Photos iCloud : $detail',
    de: 'iCloud Fotos: $detail',
    ja: 'iCloud 写真: $detail',
  );
  String get integrationsCloudStorageIntro => _l6(
    en: 'Save processed frame photos to your photo cloud.',
    zh: '将处理后的相框照片保存到您的照片云端。',
    es: 'Guarda las fotos procesadas del marco en tu nube de fotos.',
    fr: 'Enregistrez les photos du cadre dans votre cloud photo.',
    de: 'Speichern Sie verarbeitete Rahmenfotos in Ihrer Fotocloud.',
    ja: '処理したフレーム写真を写真クラウドに保存します。',
  );
  String get disconnectLabel => _l6(
    en: 'Disconnect',
    zh: '断开连接',
    es: 'Desconectar',
    fr: 'Déconnecter',
    de: 'Trennen',
    ja: '切断',
  );
  String get integrationsGooglePhotosConnectedSub => _l6(
    en: 'Connected - photos save to your MyFrame album',
    zh: '已连接 - 照片保存到 MyFrame 相册',
    es: 'Conectado - fotos en el álbum MyFrame',
    fr: 'Connecté - photos dans l’album MyFrame',
    de: 'Verbunden - Fotos im MyFrame-Album',
    ja: '接続済み - MyFrame アルバムに保存',
  );
  String get integrationsICloudConnectedSub => _l6(
    en: 'Connected - iOS saves photos to Apple Photos',
    zh: '已连接 - iOS 会将照片保存到 Apple 照片',
    es: 'Conectado - iOS guarda fotos en Apple Fotos',
    fr: 'Connecté - iOS enregistre dans Photos Apple',
    de: 'Verbunden - iOS speichert in Apple Fotos',
    ja: '接続済み - iOS が Apple 写真に保存',
  );
  String get icloudPhotosUnavailable => _l6(
    en: 'iCloud Photos upload is available only on iOS. Use Google Photos on Android.',
    zh: 'iCloud 照片上传仅在 iOS 可用。Android 请使用 Google 相册。',
    es: 'Fotos de iCloud solo está disponible en iOS. Usa Google Fotos en Android.',
    fr: 'Photos iCloud est disponible uniquement sur iOS. Utilisez Google Photos sur Android.',
    de: 'iCloud Fotos ist nur unter iOS verfügbar. Nutzen Sie Google Fotos auf Android.',
    ja: 'iCloud 写真のアップロードは iOS のみ対応です。Android では Google フォトを使用してください。',
  );
  String get debugModeTitle => _l6(
    en: 'Debug Mode',
    zh: '调试模式',
    es: 'Modo depuración',
    fr: 'Mode debug',
    de: 'Debug-Modus',
    ja: 'デバッグモード',
  );
  String get debugModeSub => _l6(
    en: 'Network and diagnostics tools',
    zh: '网络和诊断工具',
    es: 'Herramientas de red y diagnóstico',
    fr: 'Outils réseau et diagnostic',
    de: 'Netzwerk- und Diagnosewerkzeuge',
    ja: 'ネットワークと診断ツール',
  );
  String get premiumTitle => _l6(
    en: 'MyFrame Pro',
    zh: 'MyFrame 专业版',
    es: 'MyFrame Pro',
    fr: 'MyFrame Pro',
    de: 'MyFrame Pro',
    ja: 'MyFrame Pro',
  );
  String get premiumSub => _l6(
    en: 'Premium features and storage',
    zh: '高级功能与存储',
    es: 'Funciones premium y almacenamiento',
    fr: 'Fonctions premium et stockage',
    de: 'Premium-Funktionen und Speicher',
    ja: 'プレミアム機能と容量',
  );
  String get plansAndStorageTitle => _l6(
    en: 'Plans & storage',
    zh: '套餐与存储',
    es: 'Planes y almacenamiento',
    fr: 'Offres et stockage',
    de: 'Tarife & Speicher',
    ja: 'プランと容量',
  );
  String get plansAndStorageSub => _l6(
    en: 'Free 300MB, Pro with more storage',
    zh: '免费 300MB，Pro 享更大空间',
    es: '300MB gratis, Pro con más almacenamiento',
    fr: '300 Mo gratuit, Pro avec plus de stockage',
    de: '300MB kostenlos, Pro mit mehr Speicher',
    ja: '無料300MB、Proは大容量',
  );
  String get helpSettingsTitle => _l6(
    en: 'Help',
    zh: '帮助',
    es: 'Ayuda',
    fr: 'Aide',
    de: 'Hilfe',
    ja: 'ヘルプ',
  );
  String get helpSettingsSub => _l6(
    en: 'FAQ, Contact',
    zh: '常见问题、联系',
    es: 'FAQ, contacto',
    fr: 'FAQ, contact',
    de: 'FAQ, Kontakt',
    ja: 'FAQ・お問い合わせ',
  );
  String get signOutLabel => _l6(
    en: 'Sign out',
    zh: '退出登录',
    es: 'Cerrar sesión',
    fr: 'Se déconnecter',
    de: 'Abmelden',
    ja: 'サインアウト',
  );
  String get signOutConfirmTitle => _l6(
    en: 'Sign out?',
    zh: '退出登录？',
    es: '¿Cerrar sesión?',
    fr: 'Se déconnecter ?',
    de: 'Abmelden?',
    ja: 'サインアウトしますか？',
  );
  String get signOutConfirmBody => _l6(
    en: 'You will need to sign in again to use cloud features.',
    zh: '退出后需重新登录以使用云端功能。',
    es: 'Deberás iniciar sesión de nuevo.',
    fr: 'Vous devrez vous reconnecter pour le cloud.',
    de: 'Sie müssen sich erneut anmelden (Cloud).',
    ja: '再度ログインが必要です。',
  );
  String get profileNameLabel => _l6(
    en: 'Profile name',
    zh: '昵称',
    es: 'Nombre de perfil',
    fr: 'Nom du profil',
    de: 'Profilname',
    ja: 'プロフィール名',
  );
  String get accountDisplayNameLabel => _l6(
    en: 'Display name',
    zh: '显示名称',
    es: 'Nombre para mostrar',
    fr: "Nom d'affichage",
    de: 'Anzeigename',
    ja: '表示名',
  );
  String get accountSaveChangesButton => _l6(
    en: 'Save changes',
    zh: '保存更改',
    es: 'Guardar cambios',
    fr: 'Enregistrer',
    de: 'Änderungen speichern',
    ja: '変更を保存',
  );
  String get proMemberFullBanner => _l6(
    en: 'PRO Member',
    zh: 'PRO 会员',
    es: 'Miembro PRO',
    fr: 'Membre PRO',
    de: 'PRO-Mitglied',
    ja: 'PRO会員',
  );
  String get emailLabel => _l6(
    en: 'Email',
    zh: '邮箱',
    es: 'Correo',
    fr: 'E-mail',
    de: 'E-Mail',
    ja: 'メール',
  );
  String get saveLabel => _l6(
    en: 'Save',
    zh: '保存',
    es: 'Guardar',
    fr: 'Enregistrer',
    de: 'Speichern',
    ja: '保存',
  );
  String get notifyPhotoDelivered => _l6(
    en: 'Photo delivered alerts',
    zh: '照片送达提醒',
    es: 'Alertas de foto entregada',
    fr: 'Alertes photo livrée',
    de: 'Hinweise: Foto zugestellt',
    ja: '写真送信完了の通知',
  );
  String get notifyFamilyActivity => _l6(
    en: 'Family activity alerts',
    zh: '家庭动态提醒',
    es: 'Alertas de actividad familiar',
    fr: 'Alertes activité famille',
    de: 'Hinweise: Familienaktivität',
    ja: '家族アクティビティ通知',
  );
  String get notifyBirthdayReminders => _l6(
    en: 'Birthday reminders',
    zh: '生日提醒',
    es: 'Recordatorios de cumpleaños',
    fr: 'Rappels anniversaire',
    de: 'Geburtstagserinnerungen',
    ja: '誕生日リマインダー',
  );
  String get notifyFrameOffline => _l6(
    en: 'Frame offline alerts',
    zh: '相框离线提醒',
    es: 'Alertas de marco sin conexión',
    fr: 'Alertes cadre hors ligne',
    de: 'Hinweise: Rahmen offline',
    ja: 'フレームオフライン通知',
  );
  String get notifyNewFamilyMember => _l6(
    en: 'New family member',
    zh: '新家庭成员',
    es: 'Nuevo miembro familiar',
    fr: 'Nouveau membre de la famille',
    de: 'Neues Familienmitglied',
    ja: '新しい家族メンバー',
  );
  String get notifyLikedPhotos => _l6(
    en: 'Liked photos',
    zh: '照片点赞提醒',
    es: 'Fotos con me gusta',
    fr: 'Photos aimées',
    de: 'Gelikte Fotos',
    ja: '写真へのいいね',
  );
  String get notifyBirthdayLeadLabel => _l6(
    en: 'Birthday lead time',
    zh: '生日提前提醒',
    es: 'Anticipación de cumpleaños',
    fr: 'Délai avant anniversaire',
    de: 'Vorlauf Geburtstag',
    ja: '誕生日の事前通知',
  );
  String birthdayLeadDays(int days) => _l6(
    en: days == 1 ? 'Remind 1 day before' : 'Remind $days days before',
    zh: days == 1 ? '提前 1 天提醒' : '提前 $days 天提醒',
    es: days == 1 ? 'Recordar 1 día antes' : 'Recordar $days días antes',
    fr: days == 1 ? 'Rappeler 1 jour avant' : 'Rappeler $days jours avant',
    de: days == 1 ? '1 Tag vorher erinnern' : '$days Tage vorher erinnern',
    ja: days == 1 ? '1日前に通知' : '$days日前に通知',
  );
  String get notifyUploadCompleteSub => _l6(
    en: 'Notify when photos arrive',
    zh: '照片到达时提醒',
    es: 'Avisar cuando llegue la foto',
    fr: 'Notifier quand la photo arrive',
    de: 'Hinweis wenn Fotos ankommen',
    ja: '写真が届いたら通知',
  );
  String get notifyDeviceOfflineSub => _l6(
    en: 'When frame disconnects',
    zh: '当相框离线时',
    es: 'Cuando el marco se desconecta',
    fr: 'Quand le cadre se déconnecte',
    de: 'Wenn der Rahmen offline ist',
    ja: 'フレーム切断時に通知',
  );
  String get notifyNewFamilyMemberSub => _l6(
    en: 'When someone joins',
    zh: '有人加入时',
    es: 'Cuando alguien se une',
    fr: 'Quand quelqu’un rejoint',
    de: 'Wenn jemand beitritt',
    ja: '誰かが参加したとき',
  );
  String get notifyLikedPhotosSub => _l6(
    en: 'When someone likes',
    zh: '有人点赞时',
    es: 'Cuando alguien da me gusta',
    fr: 'Quand quelqu’un aime',
    de: 'Wenn jemand gefällt',
    ja: '誰かがいいねしたとき',
  );
  String get notificationsSectionReminders => _l6(
    en: 'Reminders',
    zh: '提醒',
    es: 'Recordatorios',
    fr: 'Rappels',
    de: 'Erinnerungen',
    ja: 'リマインダー',
  );
  String get notificationsSectionFamily => _l6(
    en: 'Family',
    zh: '家庭',
    es: 'Familia',
    fr: 'Famille',
    de: 'Familie',
    ja: '家族',
  );
  String get notificationsSectionQuietHours => _l6(
    en: 'Quiet hours',
    zh: '免打扰时段',
    es: 'Horas de silencio',
    fr: 'Heures calmes',
    de: 'Ruhezeiten',
    ja: 'おやすみ時間',
  );
  String get quietHoursEnable => _l6(
    en: 'Enable quiet hours',
    zh: '启用免打扰',
    es: 'Activar horas de silencio',
    fr: 'Activer les heures calmes',
    de: 'Ruhezeiten aktivieren',
    ja: 'おやすみ時間を有効化',
  );
  String get quietHoursDndTitle => _l6(
    en: 'Do Not Disturb',
    zh: '勿扰模式',
    es: 'No molestar',
    fr: 'Ne pas déranger',
    de: 'Nicht stören',
    ja: '通知をオフ',
  );
  String get quietHoursStartLabel => _l6(
    en: 'Start',
    zh: '开始',
    es: 'Inicio',
    fr: 'Début',
    de: 'Start',
    ja: '開始',
  );
  String get quietHoursEndLabel =>
      _l6(en: 'End', zh: '结束', es: 'Fin', fr: 'Fin', de: 'Ende', ja: '終了');
  String get shareInviteLink => _l6(
    en: 'Share invite link',
    zh: '分享邀请链接',
    es: 'Compartir enlace de invitación',
    fr: 'Partager le lien d’invitation',
    de: 'Einladungslink teilen',
    ja: '招待リンクを共有',
  );
  String get openDeviceInfo => _l6(
    en: 'Open device info',
    zh: '打开设备信息',
    es: 'Abrir info del dispositivo',
    fr: 'Ouvrir les infos appareil',
    de: 'Geräteinfo öffnen',
    ja: 'デバイス情報を開く',
  );
  String get connectedServices => _l6(
    en: 'Connected services',
    zh: '已连接服务',
    es: 'Servicios conectados',
    fr: 'Services connectés',
    de: 'Verbundene Dienste',
    ja: '接続済みサービス',
  );
  String get autoSyncTitle => _l6(
    en: 'Auto sync',
    zh: '自动同步',
    es: 'Sincronización automática',
    fr: 'Synchronisation auto',
    de: 'Auto-Sync',
    ja: '自動同期',
  );
  String get googlePhotos => _l6(
    en: 'Google Photos',
    zh: 'Google 相册',
    es: 'Google Photos',
    fr: 'Google Photos',
    de: 'Google Fotos',
    ja: 'Googleフォト',
  );
  String get iCloudPhotos => _l6(
    en: 'iCloud Photos',
    zh: 'iCloud 相册',
    es: 'Fotos de iCloud',
    fr: 'Photos iCloud',
    de: 'iCloud Fotos',
    ja: 'iCloud写真',
  );
  String get homeAssistant => _l6(
    en: 'Home Assistant',
    zh: 'Home Assistant',
    es: 'Home Assistant',
    fr: 'Home Assistant',
    de: 'Home Assistant',
    ja: 'Home Assistant',
  );
  String get syncAutomatically => _l6(
    en: 'Sync automatically',
    zh: '自动同步',
    es: 'Sincronizar automáticamente',
    fr: 'Synchroniser automatiquement',
    de: 'Automatisch synchronisieren',
    ja: '自動同期',
  );
  String get notConnected => _l6(
    en: 'Not connected',
    zh: '未连接',
    es: 'No conectado',
    fr: 'Non connecté',
    de: 'Nicht verbunden',
    ja: '未接続',
  );
  String get connectLabel => _l6(
    en: 'Connect',
    zh: '连接',
    es: 'Conectar',
    fr: 'Connecter',
    de: 'Verbinden',
    ja: '接続',
  );
  String get googlePhotosSync => _l6(
    en: 'Google Photos Sync',
    zh: 'Google 相册同步',
    es: 'Sincronización Google Photos',
    fr: 'Sync Google Photos',
    de: 'Google Fotos Sync',
    ja: 'Googleフォト同期',
  );
  String get dailyAtNine => _l6(
    en: 'Daily at 9:00 AM',
    zh: '每天上午 9:00',
    es: 'Diario a las 9:00',
    fr: 'Tous les jours à 9h00',
    de: 'Täglich um 9:00',
    ja: '毎日 9:00',
  );
  String get prefsSectionTheme => _l6(
    en: 'Theme',
    zh: '主题',
    es: 'Tema',
    fr: 'Thème',
    de: 'Design',
    ja: 'テーマ',
  );
  String get prefsAppThemeLabel => _l6(
    en: 'App theme',
    zh: '应用主题',
    es: 'Tema de la app',
    fr: 'Thème de l’appli',
    de: 'App-Design',
    ja: 'アプリのテーマ',
  );
  String get prefsSectionAutomation => _l6(
    en: 'Automation',
    zh: '自动化',
    es: 'Automatización',
    fr: 'Automatisation',
    de: 'Automatisierung',
    ja: '自動化',
  );
  String get prefsSoftwareUpdatesFrame => _l6(
    en: 'Automatic updates (frame)',
    zh: '相框自动更新',
    es: 'Actualizaciones automáticas del marco',
    fr: 'Mises à jour auto (cadre)',
    de: 'Automatische Rahmen‑Updates',
    ja: 'フレーム自動更新',
  );
  String get prefsSoftwareUpdatesFrameSub => _l6(
    en: 'Download and install OTA firmware over Wi‑Fi when available.',
    zh: '在可用时通过 Wi‑Fi 自动下载并安装 OTA 固件。',
    es: 'Descarga e instala OTA por Wi‑Fi cuando exista.',
    fr: 'Télécharge et installe l’OTA en Wi‑Fi.',
    de: 'OTA‑Firmware per WLAN, sobald verfügbar.',
    ja: '利用可能になればWi‑FiでOTAを取得・適用します。',
  );
  String get prefsAiSupportedLlmsIntro => _l6(
    en: 'Supported LLM backends (bring your own key): OpenAI (GPT‑4o / GPT‑4.1‑mini style endpoints), Anthropic (Claude 3.x), Google AI (Gemini 1.x), Mistral.',
    zh: '兼容的云端大模型接口（自备 API Key）：OpenAI GPT 系列兼容端点、Anthropic Claude、Google Gemini、Mistral 等。',
    es: 'Modelos típicos: OpenAI API, Claude, Gemini, Mistral.',
    fr: 'Modèles courants : OpenAI, Claude, Gemini, Mistral.',
    de: 'Typische Anbieter: OpenAI, Claude, Gemini, Mistral.',
    ja: '例: OpenAI互換・Claude・Gemini・Mistral。',
  );
  String get prefsAiKeywordHints => _l6(
    en: 'Tap a preset',
    zh: '点选预设',
    es: 'Toca un preset',
    fr: 'Choisir un préréglage',
    de: 'Vorlage antippen',
    ja: 'プリセット',
  );
  String get prefsSectionAiSecurity => _l6(
    en: 'AI & security',
    zh: 'AI 与安全',
    es: 'IA y seguridad',
    fr: 'IA et sécurité',
    de: 'KI & Sicherheit',
    ja: 'AIとセキュリティ',
  );
  String get prefsAiApiKeyLabel => _l6(
    en: 'AI API key',
    zh: 'AI API 密钥',
    es: 'Clave API de IA',
    fr: 'Clé API IA',
    de: 'KI-API-Schlüssel',
    ja: 'AI APIキー',
  );
  String get prefsSaveApiKey => _l6(
    en: 'Save API key',
    zh: '保存 API 密钥',
    es: 'Guardar clave API',
    fr: 'Enregistrer la clé',
    de: 'API-Key speichern',
    ja: 'APIキーを保存',
  );
  String get prefsSms2faTitle => _l6(
    en: '2FA by SMS',
    zh: '短信双因素',
    es: '2FA por SMS',
    fr: '2FA par SMS',
    de: '2FA per SMS',
    ja: 'SMS 2段階認証',
  );
  String get prefsSms2faSub => _l6(
    en: 'Require text code on new devices',
    zh: '新设备需短信验证',
    es: 'Código SMS en dispositivos nuevos',
    fr: 'Code SMS sur nouveaux appareils',
    de: 'SMS-Code auf neuen Geräten',
    ja: '新しい端末ではSMSコードが必要',
  );
  String get accountProfileSection => _l6(
    en: 'Profile',
    zh: '资料',
    es: 'Perfil',
    fr: 'Profil',
    de: 'Profil',
    ja: 'プロフィール',
  );
  String get accountBirthdayLabel => _l6(
    en: 'Birthday',
    zh: '生日',
    es: 'Cumpleaños',
    fr: 'Anniversaire',
    de: 'Geburtstag',
    ja: '誕生日',
  );
  String get proMemberBadge =>
      _l6(en: 'PRO', zh: '专业版', es: 'PRO', fr: 'PRO', de: 'PRO', ja: 'PRO');
  String get proYouAreMember => _l6(
    en: "You're a Pro member",
    zh: '您是 Pro 会员',
    es: 'Eres Pro',
    fr: 'Vous êtes Pro',
    de: 'Sie sind Pro-Mitglied',
    ja: 'Pro会員です',
  );
  String get proValidThrough => _l6(
    en: 'Valid through Dec 31, 2026',
    zh: '有效期至 2026 年 12 月 31 日',
    es: 'Válido hasta 31/12/2026',
    fr: "Valable jusqu'au 31/12/2026",
    de: 'Gültig bis 31.12.2026',
    ja: '2026年12月31日まで有効',
  );
  String get proHeroSubtitle => _l6(
    en: 'AI image generation and expanded cloud storage',
    zh: 'AI 图像生成与更大云空间',
    es: 'IA y más almacenamiento en la nube',
    fr: 'IA et stockage cloud étendu',
    de: 'KI-Generierung und mehr Cloud-Speicher',
    ja: 'AI生成と拡張クラウド',
  );
  String get proFeatureAi => _l6(
    en: 'AI image generation (your API key)',
    zh: 'AI 生图（使用您的 API 密钥）',
    es: 'Imágenes con IA (tu clave API)',
    fr: 'Génération IA (votre clé API)',
    de: 'KI-Bilder (Ihr API-Key)',
    ja: 'APIキーでAI生成',
  );
  String get proFeaturePlaylists => _l6(
    en: 'Unlimited playlists',
    zh: '无限播放列表',
    es: 'Listas ilimitadas',
    fr: 'Listes illimitées',
    de: 'Unbegrenzte Playlists',
    ja: 'プレイリスト無制限',
  );
  String get proFeatureStorage => _l6(
    en: 'Expanded cloud storage',
    zh: '更大云存储',
    es: 'Más almacenamiento',
    fr: 'Stockage cloud étendu',
    de: 'Mehr Cloud-Speicher',
    ja: '拡張クラウド',
  );
  String get proFeaturePriority => _l6(
    en: 'Priority features & faster sync',
    zh: '优先功能与更快递送',
    es: 'Prioridad y sincronización rápida',
    fr: 'Fonctions prioritaires & sync',
    de: 'Vorrang & schnellere Synchronisierung',
    ja: '優先機能と高速同期',
  );
  String get freePlanTitle => _l6(
    en: 'Free plan',
    zh: '免费版',
    es: 'Plan gratuito',
    fr: 'Forfait gratuit',
    de: 'Kostenloses Konto',
    ja: '無料プラン',
  );
  String get freePlanStorage300 => _l6(
    en: '300MB online photo storage',
    zh: '300MB 云照片存储',
    es: '300MB en la nube',
    fr: '300 Mo en ligne',
    de: '300MB Online-Speicher',
    ja: 'オンライン300MB',
  );
  String get manageSubscription => _l6(
    en: 'Manage subscription',
    zh: '管理订阅',
    es: 'Gestionar suscripción',
    fr: 'Gérer l’abonnement',
    de: 'Abo verwalten',
    ja: 'サブスクを管理',
  );
  String get proUpgradeTitle => _l6(
    en: 'Unlock MyFrame Pro',
    zh: '解锁 MyFrame 专业版',
    es: 'Desbloquea MyFrame Pro',
    fr: 'Débloquer MyFrame Pro',
    de: 'MyFrame Pro freischalten',
    ja: 'MyFrame Pro',
  );
  String get proUpgradeBody => _l6(
    en: 'Pro unlocks more cloud storage, AI tools, and family sharing—billing will connect when the store is ready.',
    zh: '专业版可解锁更多云空间、AI 与家庭分享；应用商店支付接入后即可订阅。',
    es: 'Más nube, IA y familia; la facturación llegará pronto.',
    fr: 'Plus de stockage, IA, famille; facturation bientôt.',
    de: 'Mehr Cloud, KI, Familie — Abo folgt.',
    ja: 'クラウド、AI、家族共有。課金は近日対応',
  );
  String get subscriptionComingLater => _l6(
    en: 'In-app subscription is not connected yet.',
    zh: '应用内订阅尚未接入。',
    es: 'Suscripción aún no conectada.',
    fr: 'Abonnement pas encore connecté.',
    de: 'Abo noch nicht angebunden.',
    ja: '課金は未接続です。',
  );
  String get logLabelUploads => _l6(
    en: 'Uploads',
    zh: '上传',
    es: 'Subidas',
    fr: 'Envois',
    de: 'Uploads',
    ja: 'アップロード',
  );
  String get logLabelShared => _l6(
    en: 'Shared',
    zh: '分享',
    es: 'Compartidos',
    fr: 'Partagés',
    de: 'Geteilt',
    ja: '共有',
  );
  String get logLabelDeleted => _l6(
    en: 'Deleted',
    zh: '删除',
    es: 'Eliminados',
    fr: 'Supprimés',
    de: 'Gelöscht',
    ja: '削除',
  );
  String get logRecentEvents => _l6(
    en: 'Recent events',
    zh: '最近活动',
    es: 'Actividad reciente',
    fr: 'Activité récente',
    de: 'Aktivität',
    ja: '最近の履歴',
  );
  String get logEventPhotoSent => _l6(
    en: 'Photo sent to frame',
    zh: '照片已发送到相框',
    es: 'Foto enviada al marco',
    fr: 'Photo envoyée',
    de: 'Foto gesendet',
    ja: 'フレームに送信',
  );
  String get logEventSdImport => _l6(
    en: 'SD / import activity',
    zh: 'SD/导入',
    es: 'Actividad SD',
    fr: 'Import SD',
    de: 'SD/Aktivität',
    ja: 'SD/取り込み',
  );
  String get logEventShare => _l6(
    en: 'Invite link shared',
    zh: '已分享邀请链接',
    es: 'Enlace de invitación',
    fr: 'Lien d’invitation',
    de: 'Einladung geteilt',
    ja: '招待を共有',
  );
  String get logEventDelete => _l6(
    en: 'Item removed (local log)',
    zh: '已删除项（本地记录）',
    es: 'Eliminado (registro local)',
    fr: 'Suppression (log local)',
    de: 'Eintrag entfernt',
    ja: '削除（ローカル）',
  );
  String get logEventOther => _l6(
    en: 'Event',
    zh: '事件',
    es: 'Evento',
    fr: 'Événement',
    de: 'Ereignis',
    ja: 'イベント',
  );
  String get debugOnlySubtitle => _l6(
    en: 'For developers only',
    zh: '仅供开发者',
    es: 'Solo desarrolladores',
    fr: 'Développeurs uniquement',
    de: 'Nur für Entwickler',
    ja: '開発者向け',
  );
  String get debugCardNetwork => _l6(
    en: 'Network status',
    zh: '网络状态',
    es: 'Red',
    fr: 'Réseau',
    de: 'Netzwerk',
    ja: 'ネットワーク',
  );
  String get debugCardDevice => _l6(
    en: 'Device info',
    zh: '设备信息',
    es: 'Dispositivo',
    fr: 'Appareil',
    de: 'Gerät',
    ja: 'デバイス',
  );
  String get debugCardLogs => _l6(
    en: 'Logs',
    zh: '日志',
    es: 'Registros',
    fr: 'Journaux',
    de: 'Protokoll',
    ja: 'ログ',
  );
  String get debugLabelWifi => _l6(
    en: 'Data link',
    zh: '数据链路',
    es: 'Conexión',
    fr: 'Liaison',
    de: 'Verbindung',
    ja: '接続',
  );
  String get debugLabelServer => _l6(
    en: 'API reachability',
    zh: 'API 可达性',
    es: 'API alcanzable',
    fr: 'Accès API',
    de: 'API',
    ja: 'API到達性',
  );
  String get debugNoApi => _l6(
    en: 'No paired API',
    zh: '未配置 API',
    es: 'Sin API',
    fr: 'Pas d’API',
    de: 'Keine API',
    ja: 'API未設定',
  );
  String get debugDeviceMemory => _l6(
    en: 'Phone memory (approx.)',
    zh: '手机内存（约）',
    es: 'Memoria (aprox.)',
    fr: 'Mémoire (approx.)',
    de: 'Speicher (ca.)',
    ja: 'メモリ(概算)',
  );
  String get debugLabelSync => _l6(
    en: 'Last activity',
    zh: '最近活动',
    es: 'Última actividad',
    fr: 'Dernière activité',
    de: 'Letzte Aktivität',
    ja: '直近',
  );
  String get debugLabelErrors => _l6(
    en: 'Sync error count (local)',
    zh: '同步错误（本地）',
    es: 'Errores (local)',
    fr: 'Erreurs (local)',
    de: 'Fehler (lokal)',
    ja: 'エラー(ローカル)',
  );
  String get debugLabelCache => _l6(
    en: 'Cache (local / est.)',
    zh: '缓存（本地/估计）',
    es: 'Caché (est.)',
    fr: 'Cache (est.)',
    de: 'Cache (Schätz.)',
    ja: 'キャッシュ',
  );
  String get exportLogs => _l6(
    en: 'Export log summary',
    zh: '导出日志摘要',
    es: 'Exportar resumen',
    fr: 'Exporter le journal',
    de: 'Protokoll exportieren',
    ja: 'ログを書き出し',
  );
  String get factoryReset => _l6(
    en: 'Factory reset (local data)',
    zh: '恢复出厂（仅本地数据）',
    es: 'Restablecer datos locales',
    fr: 'Réinit. (données locales)',
    de: 'Werkszustand (lokal)',
    ja: '初期化(ローカル)',
  );
  String get factoryResetTitle => _l6(
    en: 'Erase this device’s app data?',
    zh: '清除本机应用数据？',
    es: '¿Borrar datos de la app?',
    fr: 'Effacer les données locales ?',
    de: 'App-Daten löschen?',
    ja: 'アプリのデータを消去?',
  );
  String get factoryResetBody => _l6(
    en: 'This removes pairings, settings, and local logs. It does not change your frame’s firmware.',
    zh: '将清除配对、设置与本地日志。不会影响相框固件。',
    es: 'Quita emparejamiento, ajustes y registros. No afecta al firmware del marco.',
    fr: 'Supprime jumelage, réglages et journaux. Le firmware n’est pas modifié.',
    de: 'Kopplung, Einstellungen, Logs. Firmware bleibt.',
    ja: 'ペア設定とログを消去。本体ファームは変更しません。',
  );
  String get confirmErase => _l6(
    en: 'Erase',
    zh: '清除',
    es: 'Borrar',
    fr: 'Effacer',
    de: 'Löschen',
    ja: '消去',
  );
  String get factoryResetDone => _l6(
    en: 'Local data cleared. Settings were reset to defaults.',
    zh: '本地数据已清除，设置已恢复默认。',
    es: 'Datos borrados',
    fr: 'Données effacées',
    de: 'Daten gelöscht',
    ja: 'データを消去しました',
  );
  String get helpContactUs => _l6(
    en: 'Contact us',
    zh: '联系我们',
    es: 'Contáctanos',
    fr: 'Nous contacter',
    de: 'Kontakt',
    ja: 'お問い合わせ',
  );
  String get supportEmail => _l6(
    en: 'contact@myframe.ink',
    zh: 'contact@myframe.ink',
    es: 'contact@myframe.ink',
    fr: 'contact@myframe.ink',
    de: 'contact@myframe.ink',
    ja: 'contact@myframe.ink',
  );
  String get supportEmailSub => _l6(
    en: 'Tap to open your email app',
    zh: '点击打开邮件应用',
    es: 'Toca para abrir tu correo',
    fr: 'Appuyez pour ouvrir votre messagerie',
    de: 'Tippen, um die Mail-App zu öffnen',
    ja: 'タップしてメールアプリを開く',
  );
  String get supportEmailSubject => _l6(
    en: 'MyFrame Support Request',
    zh: 'MyFrame 支持请求',
    es: 'Solicitud de soporte MyFrame',
    fr: 'Demande d’assistance MyFrame',
    de: 'MyFrame-Supportanfrage',
    ja: 'MyFrame サポートリクエスト',
  );
  String get supportEmailCopied => _l6(
    en: 'Email copied to clipboard',
    zh: '邮箱已复制到剪贴板',
    es: 'Correo copiado',
    fr: 'E-mail copié',
    de: 'E-Mail kopiert',
    ja: 'コピーしました',
  );
  String get supportEmailOpenFailed => _l6(
    en: 'Could not open email app. Address copied instead.',
    zh: '无法打开邮件应用，已改为复制邮箱地址。',
    es: 'No se pudo abrir el correo. Se copió la dirección.',
    fr: 'Impossible d’ouvrir l’app mail. Adresse copiée.',
    de: 'Mail-App nicht geöffnet. Adresse kopiert.',
    ja: 'メールアプリを開けませんでした。アドレスをコピーしました。',
  );
  String get faqUnavailableTitle => _l6(
    en: 'Help unavailable',
    zh: '帮助暂不可用',
    es: 'Ayuda no disponible',
    fr: 'Aide indisponible',
    de: 'Hilfe offline',
    ja: 'ヘルプ不可',
  );
  String get faqUnavailableBody => _l6(
    en: 'Could not load FAQs. Check your network and try again later.',
    zh: '无法加载常见问题，请检查网络后重试。',
    es: 'No se pudo cargar. Comprueba la red.',
    fr: 'Chargement impossible. Réessaie sur le réseau.',
    de: 'FAQ nicht erreichbar.',
    ja: '読み込めません',
  );
  String get noFaqEntries => _l6(
    en: 'No FAQ entries yet.',
    zh: '暂无 FAQ。',
    es: 'Aún no hay entradas',
    fr: 'Aucune FAQ',
    de: 'Noch keine FAQs',
    ja: 'FAQはまだありません',
  );
  String get loadingEllipsis => _l6(
    en: 'Loading…',
    zh: '加载中…',
    es: 'Cargando…',
    fr: 'Chargement…',
    de: 'Laden…',
    ja: '読み込み中…',
  );
  String get notAvailable =>
      _l6(en: 'N/A', zh: '无', es: 'N/D', fr: 'N/D', de: 'k. A.', ja: '—');
  String get refreshAction => _l6(
    en: 'Refresh',
    zh: '刷新',
    es: 'Actualizar',
    fr: 'Actualiser',
    de: 'Aktualisieren',
    ja: '再読み込み',
  );

  String get accountPageBody => _l6(
    en: 'Profile, birthday, and sign-in for MyFrame Cloud will connect here. For now this screen documents the product flow from the design mockup.',
    zh: '资料、生日、云端账户将连接至此；本页对应设计稿中的账户区。',
    es: 'Perfil y nube: pantalla informativa',
    fr: 'Profil et compte: écran d’info',
    de: 'Konto: Informationsbildschirm (Mockup)',
    ja: 'アカウント: 案内（モック）',
  );
  String get notificationsPageBody => _l6(
    en: 'Birthday reminders and frame alerts are planned. Toggle behaviour will be tied to the notification server in production.',
    zh: '生日提醒与相框通知将在此配置；需与服务端联调后生效。',
    es: 'Alertas de cumpleaños (planificado).',
    fr: 'Rappels anniversaire (prévu).',
    de: 'Benachrichtigungen (in Arbeit)',
    ja: '通知（実装予定）',
  );
  String get integrationsPageBody => _l6(
    en: 'Google Photos and iCloud will link here. OAuth is not yet wired in the mobile client.',
    zh: 'Google 相册、iCloud 等在此集成；移动客户端 OAuth 未接入。',
    es: 'Integraciones: pendiente de OAuth',
    fr: 'Intégrations : OAuth à venir',
    de: 'Cloud-Quellen: OAuth folgt',
    ja: '連携は今後（OAuth未接続）',
  );
  String get appPreferencesPageBody => _l6(
    en: 'Theme, app updates, API keys, and SMS 2FA match the “App Preferences” table in the mockup. Your theme and language are in Settings; update checks will use the same channel as the frame.',
    zh: '主题、语言、检查更新、API 与双因素在正式版中将与相框同通道；当前可在设置中调整外观和语言。',
    es: 'Preferencias: tema e idioma en Ajustes',
    fr: 'Préférences : thème/langue',
    de: 'Einstellungen: Erscheinung & Sprache',
    ja: '外観・言語は設定で変更可',
  );

  String get framePairing => _l6(
    en: 'Frame pairing',
    zh: '相框配对',
    es: 'Emparejar marco',
    fr: 'Appairage',
    de: 'Rahmen koppeln',
    ja: 'フレームのペア設定',
  );
  String get scanQrFromHome => _l6(
    en: 'Scan QR from the frame (Home → Pair)',
    zh: '扫描相框上的二维码（首页 → 配对）',
    es: 'Escanea el QR del marco',
    fr: 'Scannez le QR du cadre',
    de: 'QR am Rahmen scannen',
    ja: 'フレームのQRをスキャン（ホーム→ペア）',
  );
  String get clear => _l6(
    en: 'Clear',
    zh: '清除',
    es: 'Borrar',
    fr: 'Effacer',
    de: 'Löschen',
    ja: 'クリア',
  );

  String get removePairingTitle => _l6(
    en: 'Remove pairing?',
    zh: '解除配对？',
    es: '¿Quitar emparejamiento?',
    fr: 'Retirer l’appairage ?',
    de: 'Kopplung entfernen?',
    ja: 'ペアを解除しますか？',
  );
  String get removePairingBody => _l6(
    en: 'The app forgets QR pairing until you scan the frame again.',
    zh: '解除后需重新扫描相框二维码。',
    es: 'Deberás escanear de nuevo.',
    fr: 'Scannez à nouveau le cadre.',
    de: 'Erneut scannen, um zu koppeln.',
    ja: '再度QRをスキャンするまでペア情報は使えません。',
  );

  String get chooseLanguageTitle => _l6(
    en: 'Language',
    zh: '选择语言',
    es: 'Idioma',
    fr: 'Langue',
    de: 'Sprache',
    ja: '言語を選択',
  );

  // —— Pairing scan ——
  String get pairFrameTitle => _l6(
    en: 'Pair frame',
    zh: '配对相框',
    es: 'Emparejar marco',
    fr: 'Appairer le cadre',
    de: 'Rahmen koppeln',
    ja: 'フレームをペア',
  );
  String get scanDeviceTitle => _l6(
    en: 'Scan for frame',
    zh: '扫描相框设备',
    es: 'Buscar marco',
    fr: 'Scanner le cadre',
    de: 'Rahmen suchen',
    ja: 'フレームを検索',
  );
  String get scanDeviceBody => _l6(
    en: 'Tap a discovered frame to connect it to Wi‑Fi, then send photos or albums.',
    zh: '点击已发现的相框，先连接其 Wi‑Fi，然后发送照片或相册。',
    es: 'Toca un marco detectado para conectarlo al Wi‑Fi y luego enviar fotos o álbumes.',
    fr: 'Touchez un cadre trouvé pour le connecter au Wi‑Fi, puis envoyer photos/album.',
    de: 'Gefundenen Rahmen antippen, mit WLAN verbinden, danach Fotos/Alben senden.',
    ja: '見つかったフレームを選んでWi‑Fi接続すると、写真やアルバムを送れます。',
  );
  String get noDeviceFoundTitle => _l6(
    en: 'No frame found',
    zh: '未发现相框',
    es: 'No se encontró marco',
    fr: 'Aucun cadre trouvé',
    de: 'Kein Rahmen gefunden',
    ja: 'フレームが見つかりません',
  );
  String get noDeviceFoundBody => _l6(
    en: 'Keep the frame powered on and nearby, then tap refresh.',
    zh: '请确保相框开机并在附近，然后点击刷新。',
    es: 'Mantén el marco encendido y cerca, luego pulsa actualizar.',
    fr: 'Gardez le cadre allumé et proche, puis actualisez.',
    de: 'Rahmen einschalten, in der Nähe halten und aktualisieren.',
    ja: 'フレームの電源を入れて近づけ、再読み込みしてください。',
  );
  String get bluetoothNotSupported => _l6(
    en: 'Bluetooth LE is not supported on this phone',
    zh: '此手机不支持蓝牙 LE',
    es: 'Este teléfono no soporta Bluetooth LE',
    fr: 'Bluetooth LE non pris en charge',
    de: 'Bluetooth LE wird nicht unterstützt',
    ja: 'この端末はBluetooth LE未対応',
  );
  String get bluetoothPermissionDenied => _l6(
    en: 'Bluetooth permission denied',
    zh: '蓝牙权限被拒绝',
    es: 'Permiso Bluetooth denegado',
    fr: 'Permission Bluetooth refusée',
    de: 'Bluetooth-Berechtigung verweigert',
    ja: 'Bluetooth権限が拒否されました',
  );
  String get bluetoothTurnOnHint => _l6(
    en: 'Turn on Bluetooth and try again',
    zh: '请开启蓝牙后重试',
    es: 'Activa Bluetooth e inténtalo de nuevo',
    fr: 'Activez le Bluetooth puis réessayez',
    de: 'Bluetooth einschalten und erneut versuchen',
    ja: 'Bluetoothを有効にして再試行してください',
  );
  String get bleUnknownDeviceLabel => _l6(
    en: 'Unknown Device',
    zh: '未知设备',
    es: 'Dispositivo desconocido',
    fr: 'Appareil inconnu',
    de: 'Unbekanntes Gerät',
    ja: '不明なデバイス',
  );
  String get bleScanningEllipsis => _l6(
    en: 'Scanning…',
    zh: '正在扫描…',
    es: 'Buscando…',
    fr: 'Analyse…',
    de: 'Suche…',
    ja: 'スキャン中…',
  );
  String get bleStopScan => _l6(
    en: 'Stop',
    zh: '停止',
    es: 'Detener',
    fr: 'Arrêter',
    de: 'Stopp',
    ja: '停止',
  );
  String get bleRestartScan => _l6(
    en: 'Restart Scan',
    zh: '重新扫描',
    es: 'Reiniciar búsqueda',
    fr: 'Relancer la recherche',
    de: 'Scan neu starten',
    ja: 'スキャンを再開',
  );
  String get bleConnect => _l6(
    en: 'Connect',
    zh: '连接',
    es: 'Conectar',
    fr: 'Connecter',
    de: 'Verbinden',
    ja: '接続',
  );
  String get bleConnectingSpinnerLabel => _l6(
    en: 'Connecting…',
    zh: '正在连接…',
    es: 'Conectando…',
    fr: 'Connexion…',
    de: 'Verbinden…',
    ja: '接続中…',
  );
  String get bleConnectingStayNear => _l6(
    en: 'Keep the phone close to the frame until this finishes.',
    zh: '连接过程中请将手机靠近相框。',
    es: 'Mantén el teléfono cerca del marco hasta que termine.',
    fr: 'Gardez le téléphone près du cadre jusqu’à la fin.',
    de: 'Halten Sie das Telefon nah am Rahmen.',
    ja: '完了までフレームの近くに置いてください。',
  );
  String get bleConnectTimeoutMessage => _l6(
    en: 'Could not connect within 15 seconds. Stay near the frame and try again.',
    zh: '15 秒内未能连接。请靠近相框后重试。',
    es: 'No se pudo conectar en 15 s. Acércate al marco e inténtalo de nuevo.',
    fr: 'Connexion impossible en 15 s. Rapprochez-vous du cadre et réessayez.',
    de: 'Keine Verbindung innerhalb von 15 s. Näher am Rahmen erneut versuchen.',
    ja: '15秒以内に接続できませんでした。フレームのそばで再試行してください。',
  );
  String get bleTryAgain => _l6(
    en: 'Try Again',
    zh: '重试',
    es: 'Reintentar',
    fr: 'Réessayer',
    de: 'Erneut versuchen',
    ja: '再試行',
  );
  String get bleForegroundRequired => _l6(
    en: 'Bring this app to the foreground to scan for Bluetooth devices.',
    zh: '请切换到前台以扫描蓝牙设备。',
    es: 'Pon la app en primer plano para buscar Bluetooth.',
    fr: 'Mettez l’app au premier plan pour scanner le Bluetooth.',
    de: 'App in den Vordergrund holen, um Bluetooth zu scannen.',
    ja: 'Bluetoothスキャンはアプリを前面にしてください。',
  );
  String get blePermissionNearbyTitle => _l6(
    en: 'Bluetooth & location required',
    zh: '需要蓝牙与定位权限',
    es: 'Se necesitan Bluetooth y ubicación',
    fr: 'Bluetooth et localisation requis',
    de: 'Bluetooth und Standort nötig',
    ja: 'Bluetoothと位置情報が必要です',
  );
  String get blePermissionNearbyBody => _l6(
    en: 'MyFrame needs Bluetooth and location access so the phone can discover and connect to nearby BLE frames.',
    zh: 'MyFrame 需要蓝牙和定位权限，手机才能发现并连接附近的 BLE 相框。',
    es: 'MyFrame necesita Bluetooth y ubicación para descubrir y conectar marcos BLE cercanos.',
    fr: 'MyFrame a besoin du Bluetooth et de la localisation pour trouver et connecter les cadres BLE proches.',
    de: 'MyFrame benötigt Bluetooth und Standort, um BLE-Rahmen in der Nähe zu finden und zu verbinden.',
    ja: 'MyFrameが近くのBLEフレームを検出して接続するには、Bluetoothと位置情報が必要です。',
  );
  String get openBluetoothSystemSettings => _l6(
    en: 'Open Bluetooth settings',
    zh: '打开蓝牙设置',
    es: 'Abrir ajustes de Bluetooth',
    fr: 'Ouvrir les réglages Bluetooth',
    de: 'Bluetooth-Einstellungen öffnen',
    ja: 'Bluetooth設定を開く',
  );
  String get openLocationSystemSettings => _l6(
    en: 'Open Location settings',
    zh: '打开定位设置',
    es: 'Abrir ajustes de ubicación',
    fr: 'Ouvrir les réglages de localisation',
    de: 'Standort-Einstellungen öffnen',
    ja: '位置情報設定を開く',
  );
  String get openAppPermissionSettings => _l6(
    en: 'Open app permissions',
    zh: '打开应用权限',
    es: 'Abrir permisos de la app',
    fr: 'Ouvrir les autorisations de l’app',
    de: 'App-Berechtigungen öffnen',
    ja: 'アプリの権限を開く',
  );
  String get scanningFrames => _l6(
    en: 'Scanning nearby frames',
    zh: '正在扫描附近相框',
    es: 'Escaneando marcos cercanos',
    fr: 'Recherche de cadres à proximité',
    de: 'Nach Rahmen in der Nähe suchen',
    ja: '近くのフレームをスキャン中',
  );
  String get scanComplete => _l6(
    en: 'Scan complete',
    zh: '扫描完成',
    es: 'Escaneo completo',
    fr: 'Recherche terminée',
    de: 'Suche abgeschlossen',
    ja: 'スキャン完了',
  );
  String get searchingBluetoothFrames => _l6(
    en: 'Searching for MyFrame Bluetooth frames',
    zh: '正在搜索 MyFrame 蓝牙相框',
    es: 'Buscando marcos MyFrame Bluetooth',
    fr: 'Recherche de cadres MyFrame Bluetooth',
    de: 'Suche nach MyFrame Bluetooth-Rahmen',
    ja: 'MyFrame Bluetoothフレームを検索中',
  );
  String get frameNotFoundHint => _l6(
    en: 'No frames found. Make sure your frame is in pairing mode. Press and hold the button for 3 seconds until the indicator light flashes.',
    zh: '未找到相框，请确认相框处于配对模式。长按按钮 3 秒，直到指示灯闪烁。',
    es: 'No se encontraron marcos. Asegúrate de que el marco esté en modo de emparejamiento. Mantén presionado el botón durante 3 segundos hasta que el indicador parpadee.',
    fr: 'Aucun cadre trouvé. Assurez-vous que votre cadre est en mode appairage. Maintenez le bouton enfoncé pendant 3 secondes jusqu\'à ce que le voyant clignote.',
    de: 'Keine Rahmen gefunden. Stellen Sie sicher, dass sich Ihr Rahmen im Pairing-Modus befindet. Halten Sie die Taste 3 Sekunden lang gedrückt, bis die Anzeige blinkt.',
    ja: 'フレームが見つかりません。フレームがペアリングモードであることを確認してください。インジケーターが点滅するまでボタンを3秒間押し続けてください。',
  );
  String bleDebugAdvertLine(String rawName, String mac) => _l6(
    en: 'DEBUG adv: "$rawName" · $mac',
    zh: 'DEBUG 广播名: "$rawName" · $mac',
    es: 'DEBUG anuncio: "$rawName" · $mac',
    fr: 'DEBUG annonce : "$rawName" · $mac',
    de: 'DEBUG Adv: "$rawName" · $mac',
    ja: 'DEBUG 広告: "$rawName" · $mac',
  );
  String get confirmDeviceCodeTitle => _l6(
    en: 'Confirm frame code',
    zh: '确认设备验证码',
    es: 'Confirmar código del marco',
    fr: 'Confirmer le code du cadre',
    de: 'Rahmencode bestätigen',
    ja: 'フレームコードを確認',
  );
  String get confirmDeviceCodeBody => _l6(
    en: 'Enter the 4-digit code shown on the frame screen.',
    zh: '请输入相框屏幕显示的 4 位验证码。',
    es: 'Introduce el código de 4 dígitos mostrado en el marco.',
    fr: 'Entrez le code à 4 chiffres affiché sur le cadre.',
    de: 'Geben Sie den 4-stelligen Code vom Rahmen ein.',
    ja: 'フレームに表示された4桁コードを入力してください。',
  );
  String confirmDeviceCodeDevHint(String code) => _l6(
    en: 'Dev hint code: $code',
    zh: '开发调试验证码：$code',
    es: 'Código de prueba: $code',
    fr: 'Code de test : $code',
    de: 'Testcode: $code',
    ja: '開発用ヒントコード: $code',
  );
  String get deviceCodeLabel => _l6(
    en: '4-digit code',
    zh: '4 位验证码',
    es: 'Código de 4 dígitos',
    fr: 'Code à 4 chiffres',
    de: '4-stelliger Code',
    ja: '4桁コード',
  );
  String deviceCodePreview(String code) => _l6(
    en: 'Code $code',
    zh: '验证码 $code',
    es: 'Código $code',
    fr: 'Code $code',
    de: 'Code $code',
    ja: 'コード $code',
  );
  String get frameProfileTitle => _l6(
    en: 'Frame setup',
    zh: '相框设置',
    es: 'Configuración del marco',
    fr: 'Configuration du cadre',
    de: 'Rahmen-Einrichtung',
    ja: 'フレーム設定',
  );
  String get frameProfileBody => _l6(
    en: 'Name your frame and choose orientation. You can change this later.',
    zh: '设置相框名称和方向，之后可随时修改。',
    es: 'Asigna nombre y orientación al marco. Luego puedes cambiarlo.',
    fr: 'Nommez le cadre et choisissez son orientation. Modifiable plus tard.',
    de: 'Rahmen benennen und Ausrichtung wählen. Später änderbar.',
    ja: 'フレーム名と向きを設定します。後から変更できます。',
  );
  String get frameProfileNavTitle => _l6(
    en: 'Playback profile',
    zh: '播放配置',
    es: 'Perfil de reproducción',
    fr: 'Profil de lecture',
    de: 'Wiedergabeprofil',
    ja: '再生プロファイル',
  );
  String get frameProfileIntro => _l6(
    en: 'These playback defaults apply to every photo this frame receives. '
        'You can still override interval and order for individual albums.',
    zh: '以下播放设置应用于该相框收到的所有照片。单个相册仍可自定义间隔与顺序。',
    es: 'Estos ajustes se aplican a cada foto que reciba el marco. Aún puedes '
        'personalizar el intervalo y el orden de cada álbum.',
    fr: 'Ces réglages de lecture s’appliquent à chaque photo reçue par le '
        'cadre. Vous pouvez encore personnaliser intervalle et ordre par album.',
    de: 'Diese Wiedergabeeinstellungen gelten für jedes Foto dieses Rahmens. '
        'Pro Alben sind Interval und Reihenfolge weiterhin anpassbar.',
    ja: 'この再生設定はフレームが表示するすべての写真に適用されます。'
        '個別のアルバムでは間隔と順序を変更できます。',
  );
  String get frameProfileNavSub => _l6(
    en: 'Global interval, order and duration for this frame',
    zh: '该相框的全局播放间隔、顺序与时长',
    es: 'Intervalo, orden y duración globales de este marco',
    fr: 'Intervalle, ordre et durée globaux de ce cadre',
    de: 'Globaler Abstand, Reihenfolge und Dauer für diesen Rahmen',
    ja: 'このフレームの再生間隔・順序・時間を設定',
  );
  String get frameProfileSaved => _l6(
    en: 'Playback profile saved',
    zh: '播放配置已保存',
    es: 'Perfil de reproducción guardado',
    fr: 'Profil de lecture enregistré',
    de: 'Wiedergabeprofil gespeichert',
    ja: '再生プロファイルを保存しました',
  );
  String get frameProfileNeedsFrame => _l6(
    en: 'Connect a frame first to set its playback profile.',
    zh: '请先连接相框，再设置播放配置。',
    es: 'Conecta primero un marco para configurar su perfil.',
    fr: 'Connectez d’abord un cadre pour régler son profil de lecture.',
    de: 'Verbinde zuerst einen Rahmen, um sein Wiedergabeprofil einzustellen.',
    ja: 'まずフレームを接続してから再生プロファイルを設定してください。',
  );
  String get frameNameLabel => _l6(
    en: 'Frame name',
    zh: '相框名称',
    es: 'Nombre del marco',
    fr: 'Nom du cadre',
    de: 'Rahmenname',
    ja: 'フレーム名',
  );

  /// Shown in lists and overlays when the user has not set a custom [PairedFrame.frameName].
  String get frameDefaultDisplayName => _l6(
    en: 'MyFrame Frame',
    zh: 'MyFrame 相框',
    es: 'MyFrame',
    fr: 'Cadre MyFrame',
    de: 'MyFrame Rahmen',
    ja: 'MyFrame フレーム',
  );
  String get frameOrientationLabel => _l6(
    en: 'Orientation',
    zh: '显示方向',
    es: 'Orientación',
    fr: 'Orientation',
    de: 'Ausrichtung',
    ja: '向き',
  );
  String get frameOrientationPortrait => _l6(
    en: 'Portrait',
    zh: '竖屏',
    es: 'Vertical',
    fr: 'Portrait',
    de: 'Hochformat',
    ja: '縦向き',
  );
  String get frameOrientationLandscape => _l6(
    en: 'Landscape',
    zh: '横屏',
    es: 'Horizontal',
    fr: 'Paysage',
    de: 'Querformat',
    ja: '横向き',
  );
  String get finishSetupButton => _l6(
    en: 'Finish setup',
    zh: '完成设置',
    es: 'Finalizar configuración',
    fr: 'Terminer la configuration',
    de: 'Einrichtung abschließen',
    ja: '設定を完了',
  );
  String get pointAtQr => _l6(
    en: 'Deprecated scan view',
    zh: '已弃用的扫码界面',
    es: 'Escaneo en desuso',
    fr: 'Ancienne vue scanner',
    de: 'Alte Scanner-Ansicht',
    ja: '旧スキャン画面',
  );
  String get pairingQrHint => _l6(
    en: 'Bluetooth pairing saves your frame id and optional Wi‑Fi upload URL.',
    zh: '蓝牙配对会保存设备 ID 和可选的上传 API 地址。',
    es: 'El emparejamiento Bluetooth guarda el ID del marco y la URL de subida opcional.',
    fr: 'L’appairage Bluetooth enregistre l’identifiant et l’URL d’upload.',
    de: 'Bluetooth‑Kopplung speichert die Rahmen‑ID und optionale Upload‑URL.',
    ja: 'BluetoothペアでデバイスIDと任意のアップロードURLを保存します。',
  );
  String get wifiSetupTitle => _l6(
    en: 'Connect frame to Wi‑Fi',
    zh: '连接相框到 Wi‑Fi',
    es: 'Conectar marco a Wi‑Fi',
    fr: 'Connecter le cadre au Wi‑Fi',
    de: 'Rahmen mit WLAN verbinden',
    ja: 'フレームをWi‑Fiに接続',
  );
  String get wifiSetupTitleFirstPair => _l6(
    en: 'Step 1 — Connect frame to Wi‑Fi',
    zh: '步骤 1 — 将相框连接到 Wi‑Fi',
    es: 'Paso 1 — Conectar el marco a Wi‑Fi',
    fr: 'Étape 1 — Connecter le cadre au Wi‑Fi',
    de: 'Schritt 1 — Rahmen mit WLAN verbinden',
    ja: 'ステップ1 — フレームをWi‑Fiに接続',
  );
  String get wifiSetupTitleSecondPair => _l6(
    en: 'Step 2 — Connect frame to Wi‑Fi',
    zh: '步骤 2 — 将相框连接到 Wi‑Fi',
    es: 'Paso 2 — Conectar el marco a Wi‑Fi',
    fr: 'Étape 2 — Connecter le cadre au Wi‑Fi',
    de: 'Schritt 2 — Rahmen mit WLAN verbinden',
    ja: 'ステップ2 — フレームをWi‑Fiに接続',
  );
  String get wifiSetupBodyAfterServerConfig => _l6(
    en: 'Server settings were sent to the frame. Enter your Wi‑Fi network so the frame can go online and receive photos.',
    zh: '服务器设置已发送到相框。请输入 Wi‑Fi 网络，让相框上线并接收照片。',
    es: 'La configuración del servidor se envió al marco. Introduce tu red Wi‑Fi para que el marco se conecte y reciba fotos.',
    fr: 'Les paramètres serveur ont été envoyés au cadre. Saisissez votre Wi‑Fi pour que le cadre se connecte et reçoive les photos.',
    de: 'Servereinstellungen wurden an den Rahmen gesendet. WLAN eingeben, damit der Rahmen online geht und Fotos empfängt.',
    ja: 'サーバー設定をフレームに送信しました。Wi‑Fiを入力してフレームをオンラインにし、写真を受信できるようにしてください。',
  );
  String get wifiSetupBody => _l6(
    en: 'After scan, enter your network details so the frame can join Wi‑Fi and receive image uploads.',
    zh: '扫码后输入网络信息，让相框连接到 Wi‑Fi 后接收照片。',
    es: 'Después de escanear, introduce los datos de red para que el marco reciba fotos por Wi‑Fi.',
    fr: 'Après le scan, saisissez le réseau pour que le cadre reçoive les photos via Wi‑Fi.',
    de: 'Nach dem Scan WLAN-Daten eingeben, damit der Rahmen Bilder über WLAN empfangen kann.',
    ja: 'スキャン後にネットワーク情報を入力すると、フレームがWi‑Fi経由で画像を受信できます。',
  );
  String get wifiNearbyNetworksTitle => _l6(
    en: 'Nearby networks',
    zh: '附近网络',
    es: 'Redes cercanas',
    fr: 'Réseaux proches',
    de: 'Netze in der Nähe',
    ja: '近くのネットワーク',
  );
  String get wifiScanningNetworks => _l6(
    en: 'Scanning Wi‑Fi…',
    zh: '正在扫描 Wi‑Fi…',
    es: 'Buscando Wi‑Fi…',
    fr: 'Analyse Wi‑Fi…',
    de: 'WLAN wird gesucht…',
    ja: 'Wi‑Fiをスキャン中…',
  );
  String get wifiAddNetworkManually => _l6(
    en: 'Add Wi‑Fi manually',
    zh: '手动添加 Wi‑Fi',
    es: 'Añadir Wi‑Fi manualmente',
    fr: 'Ajouter un Wi‑Fi manuellement',
    de: 'WLAN manuell hinzufügen',
    ja: '手動でWi‑Fiを追加',
  );
  String get wifiRescanNetworks => _l6(
    en: 'Rescan Wi‑Fi',
    zh: '重新扫描',
    es: 'Volver a buscar',
    fr: 'Relancer le scan',
    de: 'Erneut scannen',
    ja: '再スキャン',
  );
  String get wifiIosNearbyUnavailable => _l6(
    en: 'iOS cannot list nearby Wi‑Fi networks. Use your current network below, or type the SSID manually.',
    zh: 'iOS 无法列出附近的 Wi‑Fi。请使用下方当前网络，或手动输入名称。',
    es: 'iOS no puede listar redes Wi‑Fi cercanas. Usa la red actual o escribe el nombre manualmente.',
    fr: 'iOS ne peut pas lister les Wi‑Fi à proximité. Utilisez le réseau actuel ou saisissez le SSID.',
    de: 'iOS kann nahe WLAN-Netze nicht auflisten. Aktuelles Netz nutzen oder SSID manuell eingeben.',
    ja: 'iOSでは近くのWi‑Fi一覧を取得できません。現在のネットワークを使うか、SSIDを入力してください。',
  );
  String get wifiScanPermissionHint => _l6(
    en: 'Location or Nearby Wi‑Fi permission is needed to list networks.',
    zh: '需要位置或附近 Wi‑Fi 权限才能列出网络。',
    es: 'Se necesita permiso de ubicación o Wi‑Fi cercano para listar redes.',
    fr: 'Autorisation Localisation ou Wi‑Fi à proximité requise pour lister les réseaux.',
    de: 'Standort- oder Nähe-WLAN-Berechtigung nötig, um Netze anzuzeigen.',
    ja: 'ネットワーク一覧には位置情報または付近のWi‑Fi権限が必要です。',
  );
  String get wifiTapPlusForNewNetwork => _l6(
    en: 'Tap + if your network is not listed — you can type the SSID and password.',
    zh: '若列表没有你的网络，点右上角 + 手动输入名称和密码。',
    es: 'Pulsa + si tu red no aparece para escribir SSID y contraseña.',
    fr: 'Appuyez sur + si votre réseau n’apparaît pas pour saisir SSID et mot de passe.',
    de: 'Tippe auf +, wenn dein Netz fehlt — SSID und Passwort eingeben.',
    ja: '一覧にない場合は + でSSIDとパスワードを入力できます。',
  );
  String get wifiManualEntryCollapsedHint => _l6(
    en: 'SSID and password fields are hidden — tap + above to show them, or pick a network from the list.',
    zh: '已隐藏手动输入框 — 点右上角 + 显示，或从上方列表选择网络。',
    es: 'Los campos están ocultos: pulsa + arriba o elige una red de la lista.',
    fr: 'Champs masqués : touchez + ou choisissez un réseau dans la liste.',
    de: 'Felder ausgeblendet: + tippen oder Netz aus der Liste wählen.',
    ja: '入力欄は非表示です。+で表示するか一覧から選んでください。',
  );
  String get wifiSavedPasswordConnecting => _l6(
    en: 'Using saved password from this app — connecting…',
    zh: '使用本应用已保存的密码，正在连接…',
    es: 'Usando contraseña guardada en la app — conectando…',
    fr: 'Mot de passe enregistré dans l’app — connexion…',
    de: 'Gespeichertes App-Passwort — verbinden…',
    ja: 'アプリに保存したパスワードで接続中…',
  );
  String get wifiEnterPasswordForNetwork => _l6(
    en: 'Enter the Wi‑Fi password below, then tap Connect.',
    zh: '请在下方输入 Wi‑Fi 密码后点连接。',
    es: 'Introduce la contraseña abajo y pulsa Conectar.',
    fr: 'Saisissez le mot de passe ci-dessous puis Connecter.',
    de: 'Passwort unten eingeben, dann Verbinden.',
    ja: '下にパスワードを入力して接続を押してください。',
  );
  String get wifiSsidLabel => _l6(
    en: 'Wi‑Fi name (SSID)',
    zh: 'Wi‑Fi 名称 (SSID)',
    es: 'Nombre Wi‑Fi (SSID)',
    fr: 'Nom du Wi‑Fi (SSID)',
    de: 'WLAN-Name (SSID)',
    ja: 'Wi‑Fi名 (SSID)',
  );
  String get wifiUsernameLabel => _l6(
    en: 'Username (optional)',
    zh: '用户名（可选）',
    es: 'Usuario (opcional)',
    fr: 'Nom d’utilisateur (optionnel)',
    de: 'Benutzername (optional)',
    ja: 'ユーザー名（任意）',
  );
  String get wifiPasswordLabel => _l6(
    en: 'Password',
    zh: '密码',
    es: 'Contraseña',
    fr: 'Mot de passe',
    de: 'Passwort',
    ja: 'パスワード',
  );
  String get wifiSsidRequired => _l6(
    en: 'Enter Wi‑Fi name',
    zh: '请输入 Wi‑Fi 名称',
    es: 'Introduce el nombre Wi‑Fi',
    fr: 'Entrez le nom du Wi‑Fi',
    de: 'WLAN-Name eingeben',
    ja: 'Wi‑Fi名を入力してください',
  );
  String get wifiPasswordRequired => _l6(
    en: 'Enter Wi‑Fi password',
    zh: '请输入 Wi‑Fi 密码',
    es: 'Introduce la contraseña Wi‑Fi',
    fr: 'Entrez le mot de passe Wi‑Fi',
    de: 'WLAN-Passwort eingeben',
    ja: 'Wi‑Fiパスワードを入力してください',
  );
  String get connectWifiButton => _l6(
    en: 'Connect Wi‑Fi',
    zh: '连接 Wi‑Fi',
    es: 'Conectar Wi‑Fi',
    fr: 'Connecter le Wi‑Fi',
    de: 'Mit WLAN verbinden',
    ja: 'Wi‑Fi接続',
  );
  String get connectingWifi => _l6(
    en: 'Connecting…',
    zh: '连接中…',
    es: 'Conectando…',
    fr: 'Connexion…',
    de: 'Verbinde…',
    ja: '接続中…',
  );
  String get skipForNow => _l6(
    en: 'Skip for now',
    zh: '稍后再说',
    es: 'Omitir por ahora',
    fr: 'Ignorer pour le moment',
    de: 'Jetzt überspringen',
    ja: '今はスキップ',
  );
  String wifiConnectSuccess(String ssid) => _l6(
    en: 'Connected to $ssid',
    zh: '已连接到 $ssid',
    es: 'Conectado a $ssid',
    fr: 'Connecté à $ssid',
    de: 'Mit $ssid verbunden',
    ja: '$ssid に接続しました',
  );
  String wifiLinkedStatus(String ssid) => _l6(
    en: 'Wi‑Fi linked: $ssid',
    zh: 'Wi‑Fi 已连接：$ssid',
    es: 'Wi‑Fi vinculado: $ssid',
    fr: 'Wi‑Fi lié : $ssid',
    de: 'WLAN verbunden: $ssid',
    ja: 'Wi‑Fi接続: $ssid',
  );
  String get notMyFrameQr => _l6(
    en: 'Not a MyFrame pairing QR',
    zh: '不是 MyFrame 配对码',
    es: 'No es un QR MyFrame',
    fr: 'QR MyFrame invalide',
    de: 'Kein MyFrame-QR',
    ja: 'MyFrameのQRではありません',
  );
  String get pairingWrongProduct => _l6(
    en: 'This QR is for a different product line. Use a MyFrame code from your product.',
    zh: '此码不属于本产品线，请使用 MyFrame 包装上的二维码。',
    es: 'El QR no es de esta línea. Usa el de tu MyFrame.',
    fr: 'QR d’une autre gamme. Utilisez le code MyFrame fourni.',
    de: 'Falsches Produkt. Verwenden Sie den MyFrame-Code Ihrer Verpackung.',
    ja: '別製品用のQRです。同梱のMyFrame用コードを使ってください。',
  );
  String get pairingBadIdFormat => _l6(
    en: 'This device id is not a valid MyFrame unit code (use the format on your product card, e.g. YX-133P-001).',
    zh: '设备编号格式无效，请使用产品卡上的合法编号（如 YX-133P-001）。',
    es: 'ID no válida para MyFrame (p. ej. YX-133P-001 … según tanda).',
    fr: 'Id non valide pour MyFrame (ex. YX-133P-001 …).',
    de: 'Ungültige Gerätekennung (z. B. YX-133P-001 … in dieser Auflage).',
    ja: '有効なユニットIDではありません（例: YX-133P-001 …）。',
  );
  String pairingNotInThisRun(int max) => _l6(
    en: 'This frame is not in the current product run (allowed units: 1–$max).',
    zh: '该编号不在本批次范围内（本批次 1–$max 台）。',
    es: 'Unidad fuera de esta tanda (1–$max).',
    fr: 'Cette unité n’appartient pas à cette série (1–$max).',
    de: 'Diese Nummer ist nicht in dieser Auflage (1–$max).',
    ja: 'この生産ロットの範囲外です（1–$max）。',
  );
  String cameraError(Object e) => _l6(
    en: 'Camera error: $e',
    zh: '相机错误：$e',
    es: 'Cámara: $e',
    fr: 'Caméra : $e',
    de: 'Kamera: $e',
    ja: 'カメラ: $e',
  );

  // —— Family ——
  String get familyTitle => _l6(
    en: 'Family',
    zh: '家庭',
    es: 'Familia',
    fr: 'Famille',
    de: 'Familie',
    ja: '家族',
  );
  String get familySubtitle => _l6(
    en: 'Invite family members to share photos to your frames from anywhere.',
    zh: '邀请家人加入，随时随地向相框发送照片。',
    es: 'Invita a tu familia a enviar fotos a tus marcos desde cualquier lugar.',
    fr: 'Invitez votre famille à envoyer des photos à vos cadres où qu’ils soient.',
    de: 'Lade Familienmitglieder ein, Fotos von überall an deine Rahmen zu senden.',
    ja: '家族を招待して、どこからでもフレームに写真を送れます。',
  );
  String get inviteFamily => _l6(
    en: 'Invite family',
    zh: '邀请家人',
    es: 'Invitar familia',
    fr: 'Inviter la famille',
    de: 'Familie einladen',
    ja: '家族を招待',
  );
  String get sharedFrames => _l6(
    en: 'Shared frames',
    zh: '共享相框',
    es: 'Marcos compartidos',
    fr: 'Cadres partagés',
    de: 'Geteilte Rahmen',
    ja: '共有フレーム',
  );
  String get sharedFramesBody => _l6(
    en: 'Use your invite code so everyone sends to the paired frame. Backend sync can list joined members once your account APIs are wired.',
    zh: '用邀请码让家人发送到已配对的相框；服务端联网后可同步成员列表。',
    es: 'Con el código, todos pueden enviar al marco emparejado.',
    fr: 'Avec le code, tout le monde envoie vers le cadre appairé.',
    de: 'Mit Einladungscode senden alle ans gekoppelten Rahmen.',
    ja: '招待コードで、みんながペアしたフレームに送れます。',
  );
  String get inviteLinkShareText => _l6(
    en: 'Join my family on MyFrame: https://myframe.ink/join (share from the Family tab for your code)',
    zh: '加入我的 MyFrame 家庭，请在「家庭」页分享邀请获取邀请码：https://myframe.ink/join',
    es: 'Únete en MyFrame: comparte desde Familia tu código · https://myframe.ink/join',
    fr: 'MyFrame famille : invite depuis Family · https://myframe.ink/join',
    de: 'MyFrame-Familie: Code im Tab „Family“ teilen · https://myframe.ink/join',
    ja: 'MyFrameの家族: 家族タブでコードを共有 · https://myframe.ink/join',
  );

  /// Body for SMS / share sheets — follows UI locale (zh / en).
  /// Prefer [ShareService.familyInviteShareBody] for new call sites.
  String familyInviteShareBody(
    String familyName,
    String inviteCode,
    String webUrl,
  ) {
    final code = inviteCode.trim().toUpperCase();
    final lang = locale == AppLocale.zh ? 'zh' : 'en';
    var url = webUrl.trim();
    if (url.isNotEmpty) {
      final re = RegExp(r'([?&])lang=[^&]*', caseSensitive: false);
      if (re.hasMatch(url)) {
        url = url.replaceFirstMapped(re, (m) => '${m[1]}lang=$lang');
      } else {
        url = url.contains('?') ? '$url&lang=$lang' : '$url?lang=$lang';
      }
    }
    if (locale == AppLocale.zh) {
      return '点击链接或输入邀请码【$code】加入我的家庭相框，一起分享精彩照片！\n$url';
    }
    return 'Use invite code [$code] or tap the link to join my MyFrame family and share photos together!\n$url';
  }

  String get familyInviteShareSubject => _l6(
    en: 'Join my MyFrame Family',
    zh: '加入我的 MyFrame 艺术相框家庭',
    es: 'Únete a mi familia MyFrame',
    fr: 'Rejoignez ma famille MyFrame',
    de: 'Tritt meiner MyFrame-Familie bei',
    ja: 'MyFrameの家族に参加',
  );

  String familyMemberRemoved(String name) => _l6(
    en: 'Removed $name from the family.',
    zh: '已从家庭圈移除 $name',
    es: 'Se eliminó a $name de la familia.',
    fr: '$name a été retiré(e) de la famille.',
    de: '$name wurde aus der Familie entfernt.',
    ja: '$name を家族から削除しました。',
  );

  String get familyRemoveMemberTitle => _l6(
    en: 'Remove member?',
    zh: '移除成员？',
    es: '¿Quitar miembro?',
    fr: 'Retirer le membre ?',
    de: 'Mitglied entfernen?',
    ja: 'メンバーを削除しますか？',
  );

  String familyRemoveMemberBody(String name) => _l6(
    en:
        'Unlink $name from this family? They will no longer be able to access shared frames.',
    zh: '确定要从家庭圈中移除「$name」吗？移除后对方将无法继续访问共享相框。',
    es:
        '¿Desvincular a $name de esta familia? Ya no podrá acceder a los marcos compartidos.',
    fr:
        'Dissocier $name de cette famille ? Il/elle n’aura plus accès aux cadres partagés.',
    de:
        '$name aus der Familie entfernen? Der Zugriff auf geteilte Rahmen endet.',
    ja: '$name をこの家族から外しますか？共有フレームにはアクセスできなくなります。',
  );

  String get familyRemoveMemberConfirm => _l6(
    en: 'Remove',
    zh: '确定移除',
    es: 'Quitar',
    fr: 'Retirer',
    de: 'Entfernen',
    ja: '削除する',
  );

  String get familyMembersEmptyHint => _l6(
    en: 'No other members yet. Share the invite code so family can join.',
    zh: '还没有其他成员。分享邀请码，家人即可加入。',
    es: 'Aún no hay más miembros. Comparte el código de invitación.',
    fr: 'Pas encore d’autres membres. Partagez le code d’invitation.',
    de: 'Noch keine weiteren Mitglieder. Teile den Einladungscode.',
    ja: 'まだ他のメンバーはいません。招待コードを共有してください。',
  );

  String get familyMembersNeedCloudHint => _l6(
    en: 'Create or join a cloud family to see members linked to your frames.',
    zh: '创建或加入云端家庭后，即可查看与相框关联的成员。',
    es: 'Crea o únete a una familia en la nube para ver los miembros.',
    fr: 'Créez ou rejoignez une famille cloud pour voir les membres.',
    de: 'Erstelle oder tritt einer Cloud-Familie bei, um Mitglieder zu sehen.',
    ja: 'クラウド家族を作成または参加すると、メンバーが表示されます。',
  );

  String get familyMemberUnlinkedSub => _l6(
    en: 'They can no longer access shared frames.',
    zh: '对方将无法继续访问共享相框。',
    es: 'Ya no podrá acceder a los marcos compartidos.',
    fr: 'Plus d’accès aux cadres partagés.',
    de: 'Kein Zugriff mehr auf geteilte Rahmen.',
    ja: '共有フレームにはアクセスできなくなります。',
  );

  String get familyMemberRemoveFailed => _l6(
    en: 'Could not unlink this member. Try again.',
    zh: '无法移除该成员，请重试。',
    es: 'No se pudo desvincular. Inténtalo de nuevo.',
    fr: 'Impossible de dissocier ce membre. Réessayez.',
    de: 'Mitglied konnte nicht entfernt werden. Erneut versuchen.',
    ja: 'メンバーを外せませんでした。もう一度お試しください。',
  );

  String joinFamilyDefaultLabel(String normalizedCode) {
    final tail = normalizedCode.length <= 4
        ? normalizedCode
        : normalizedCode.substring(normalizedCode.length - 4);
    return switch (locale) {
      AppLocale.zh => '家庭 …$tail',
      AppLocale.es => 'Familia …$tail',
      AppLocale.fr => 'Famille …$tail',
      AppLocale.de => 'Familie …$tail',
      AppLocale.ja => '家族 …$tail',
      _ => 'Family …$tail',
    };
  }

  String get familyYourCircle => _l6(
    en: 'Your circle',
    zh: '你的家庭圈',
    es: 'Tu círculo',
    fr: 'Votre cercle',
    de: 'Dein Kreis',
    ja: 'マイグループ',
  );
  String get familyInviteCodeLabel => _l6(
    en: 'Invite code',
    zh: '邀请码',
    es: 'Código',
    fr: 'Code',
    de: 'Code',
    ja: '招待コード',
  );
  String get familyCopyInviteCode => _l6(
    en: 'Copy code',
    zh: '复制邀请码',
    es: 'Copiar',
    fr: 'Copier',
    de: 'Kopieren',
    ja: 'コピー',
  );
  String get familyCopyInviteLink => _l6(
    en: 'Copy link',
    zh: '复制链接',
    es: 'Copiar enlace',
    fr: 'Copier le lien',
    de: 'Link kopieren',
    ja: 'リンクをコピー',
  );
  String get familyOpenInviteLink => _l6(
    en: 'Open link',
    zh: '打开链接',
    es: 'Abrir enlace',
    fr: 'Ouvrir le lien',
    de: 'Link öffnen',
    ja: 'リンクを開く',
  );
  String get familyInviteLinkCopied => _l6(
    en: 'Invite link copied',
    zh: '已复制链接',
    es: 'Enlace copiado',
    fr: 'Lien copié',
    de: 'Link kopiert',
    ja: 'リンクをコピーしました',
  );
  String get familyCouldNotOpenLink => _l6(
    en: 'Could not open link',
    zh: '无法打开链接',
    es: 'No se pudo abrir',
    fr: 'Impossible d’ouvrir',
    de: 'Link nicht geöffnet',
    ja: '開けませんでした',
  );
  String get familyCodeCopied => _l6(
    en: 'Invite code copied',
    zh: '已复制邀请码',
    es: 'Código copiado',
    fr: 'Code copié',
    de: 'Code kopiert',
    ja: 'コピーしました',
  );
  String get familyRegenerateCodeShort => _l6(
    en: 'New code',
    zh: '新邀请码',
    es: 'Nuevo código',
    fr: 'Nouveau code',
    de: 'Neuer Code',
    ja: '新コード',
  );
  String get familyRegenerateCodeTitle => _l6(
    en: 'Create a new invite code?',
    zh: '生成新邀请码？',
    es: '¿Nuevo código?',
    fr: 'Nouveau code ?',
    de: 'Neuen Code?',
    ja: '新しい招待コードを発行しますか？',
  );
  String get familyRegenerateCodeBody => _l6(
    en: 'Older links and codes will stop working. Share the new code with your family.',
    zh: '旧邀请码将失效，请重新分享给家人。',
    es: 'El código anterior dejará de funcionar.',
    fr: 'L’ancien code ne sera plus valide.',
    de: 'Der alte Code funktioniert nicht mehr.',
    ja: '古いコードは使えなくなります。',
  );
  String get familyRegenerateCodeConfirm => _l6(
    en: 'Rotate code',
    zh: '确定',
    es: 'Sí',
    fr: 'Confirmer',
    de: 'OK',
    ja: '発行',
  );
  String get familyCodeRegenerated => _l6(
    en: 'New invite code ready',
    zh: '新邀请码已生成',
    es: 'Nuevo código listo',
    fr: 'Nouveau code prêt',
    de: 'Neuer Code bereit',
    ja: '新しい招待コード',
  );

  String get joinFamilyTitle => _l6(
    en: 'Join with code',
    zh: '使用邀请码加入',
    es: 'Unirme con código',
    fr: 'Rejoindre avec code',
    de: 'Mit Code beitreten',
    ja: '招待コードで参加',
  );
  String get joinFamilyBody => _l6(
    en: 'Paste the invite code a family member shared. They can tap Share on the Family screen.',
    zh: '请输入家人在家庭页分享的邀请码。',
    es: 'Pega el código que te compartió un familiar.',
    fr: 'Collez le code reçu d’un membre.',
    de: 'Code eingeben, den die Familie geteilt hat.',
    ja: '家族から共有された招待コードを入力してください。',
  );
  String get joinFamilyHint => _l6(
    en: '8-character code',
    zh: '8 位代码',
    es: 'Código (8 caracteres)',
    fr: 'Code (8 car.)',
    de: 'Code (8 Zeichen)',
    ja: 'コード（8文字）',
  );
  String get joinFamilyConfirm => _l6(
    en: 'Join family',
    zh: '加入',
    es: 'Unirme',
    fr: 'Rejoindre',
    de: 'Beitreten',
    ja: '参加',
  );
  String get joinFamilySuccess => _l6(
    en: 'You joined the family. Shared frames will appear on Home.',
    zh: '已加入家庭。共享相框将出现在首页。',
    es: 'Te uniste. Los marcos compartidos aparecerán en Inicio.',
    fr: 'Vous avez rejoint. Les cadres partagés apparaîtront sur l’accueil.',
    de: 'Beigetreten. Geteilte Rahmen erscheinen auf dem Startbildschirm.',
    ja: '家族に参加しました。共有フレームがホームに表示されます。',
  );
  String get joinFamilySuccessTitle => _l6(
    en: 'Welcome to the family',
    zh: '已加入家庭',
    es: 'Bienvenido a la familia',
    fr: 'Bienvenue dans la famille',
    de: 'Willkommen in der Familie',
    ja: '家族へようこそ',
  );
  String get joinFamilyCodeTooShort => _l6(
    en: 'Invite codes are exactly 8 characters. Check for missing letters.',
    zh: '邀请码为 8 位字符，请检查是否漏输。',
    es: 'El código tiene exactamente 8 caracteres.',
    fr: 'Le code fait exactement 8 caractères.',
    de: 'Codes haben genau 8 Zeichen.',
    ja: '招待コードは正確に8文字です。',
  );
  String get joinFamilyCodeTooShortTitle => _l6(
    en: 'Code incomplete',
    zh: '邀请码不完整',
    es: 'Código incompleto',
    fr: 'Code incomplet',
    de: 'Code unvollständig',
    ja: 'コードが不完全',
  );
  String get joinFamilyOwnCodeHint => _l6(
    en: 'That\'s your own invite code — share it with family instead of joining here.',
    zh: '这是你自己的邀请码，请分享给家人，而不是在这里加入。',
    es: 'Ese es tu propio código — compártelo en lugar de unirte aquí.',
    fr: 'C’est votre code — partagez-le au lieu de rejoindre ici.',
    de: 'Das ist dein eigener Code — teile ihn, statt beizutreten.',
    ja: 'それは自分の招待コードです。参加せず共有してください。',
  );
  String get joinFamilyOwnCodeTitle => _l6(
    en: 'That\'s your code',
    zh: '这是你的邀请码',
    es: 'Es tu código',
    fr: 'C’est votre code',
    de: 'Dein eigener Code',
    ja: '自分のコードです',
  );
  String get joinFamilyAlreadyMember => _l6(
    en: 'You already joined this family. Shared frames should be on Home.',
    zh: '你已经加入了这个家庭。共享相框应已出现在首页。',
    es: 'Ya eres miembro. Los marcos deberían estar en Inicio.',
    fr: 'Vous êtes déjà membre. Les cadres devraient être sur l’accueil.',
    de: 'Du bist bereits Mitglied. Rahmen sollten auf dem Startbildschirm sein.',
    ja: 'すでにこの家族のメンバーです。共有フレームはホームにあります。',
  );
  String get joinFamilyAlreadyMemberTitle => _l6(
    en: 'Already joined',
    zh: '已加入',
    es: 'Ya unido',
    fr: 'Déjà membre',
    de: 'Bereits beigetreten',
    ja: 'すでに参加済み',
  );
  String get joinFamilyNetworkError => _l6(
    en: 'Couldn\'t reach the server. Check your connection and try again.',
    zh: '无法连接服务器，请检查网络后重试。',
    es: 'No se pudo conectar. Revisa tu red e inténtalo de nuevo.',
    fr: 'Serveur injoignable. Vérifiez le réseau et réessayez.',
    de: 'Server nicht erreichbar. Verbindung prüfen und erneut versuchen.',
    ja: 'サーバーに接続できません。ネットワークを確認して再試行してください。',
  );
  String get joinFamilyNetworkErrorTitle => _l6(
    en: 'Connection issue',
    zh: '网络异常',
    es: 'Problema de conexión',
    fr: 'Problème de connexion',
    de: 'Verbindungsproblem',
    ja: '接続エラー',
  );
  String get joinFamilyCodeRequired => _l6(
    en: 'Paste or type the 8-character invite code first.',
    zh: '请先粘贴或输入 8 位邀请码。',
    es: 'Primero pega o escribe el código de 8 caracteres.',
    fr: 'Collez ou saisissez d’abord le code à 8 caractères.',
    de: 'Bitte zuerst den 8‑stelligen Code eingeben.',
    ja: '先に8文字の招待コードを入力してください。',
  );
  String get joinFamilyCodeRequiredTitle => _l6(
    en: 'Code needed',
    zh: '需要邀请码',
    es: 'Código requerido',
    fr: 'Code requis',
    de: 'Code erforderlich',
    ja: 'コードが必要です',
  );
  String get joinFamilyNotFound => _l6(
    en: 'No family matches that code. Ask them to share a fresh invite or tap New code.',
    zh: '找不到该邀请码。请让对方重新分享，或点击「新邀请码」。',
    es: 'Ninguna familia coincide. Pide un código nuevo.',
    fr: 'Aucune famille trouvée. Demandez un nouveau code.',
    de: 'Keine Familie gefunden. Bitte um einen neuen Code bitten.',
    ja: '一致する家族がありません。新しいコードを共有してもらってください。',
  );
  String get joinFamilyNotFoundTitle => _l6(
    en: 'Code not found',
    zh: '邀请码无效',
    es: 'Código no encontrado',
    fr: 'Code introuvable',
    de: 'Code nicht gefunden',
    ja: 'コードが見つかりません',
  );
  String get joinFamilyInvalidCode => _l6(
    en: 'That invite code isn\'t valid. Double-check characters — O/0 and I/1 look alike.',
    zh: '邀请码无效。请核对字符（注意 O/0、I/1 易混淆）。',
    es: 'Código no válido. Revisa caracteres parecidos (O/0, I/1).',
    fr: 'Code invalide. Vérifiez les caractères (O/0, I/1).',
    de: 'Ungültiger Code. Zeichen prüfen (O/0, I/1).',
    ja: '招待コードが無効です。似た文字（O/0、I/1）を確認してください。',
  );
  String get joinFamilyInvalidCodeTitle => _l6(
    en: 'Invalid code',
    zh: '无效邀请码',
    es: 'Código inválido',
    fr: 'Code invalide',
    de: 'Ungültiger Code',
    ja: '無効なコード',
  );
  String get joinFamilyNeedLogin => _l6(
    en: 'Sign in to your MyFrame account before joining a family.',
    zh: '请先登录 MyFrame 账号，再加入家庭。',
    es: 'Inicia sesión en MyFrame antes de unirte.',
    fr: 'Connectez-vous à MyFrame avant de rejoindre.',
    de: 'Bitte bei MyFrame anmelden, bevor du beitrittst.',
    ja: '家族に参加する前に MyFrame にサインインしてください。',
  );
  String get joinFamilyNeedLoginTitle => _l6(
    en: 'Sign in required',
    zh: '需要登录',
    es: 'Inicio de sesión requerido',
    fr: 'Connexion requise',
    de: 'Anmeldung erforderlich',
    ja: 'サインインが必要です',
  );
  String get joinFamilyBirthdayRequiredTitle => _l6(
    en: 'Birthday required',
    zh: '需要生日',
    es: 'Cumpleaños requerido',
    fr: 'Date de naissance requise',
    de: 'Geburtstag erforderlich',
    ja: '誕生日が必要です',
  );
  String get familyCodeRegenerateFailedTitle => _l6(
    en: 'Couldn\'t refresh code',
    zh: '无法更新邀请码',
    es: 'No se pudo actualizar',
    fr: 'Impossible d’actualiser',
    de: 'Code nicht aktualisiert',
    ja: 'コードを更新できません',
  );
  String get familyCodeRegenerateFailed => _l6(
    en: 'We couldn\'t create a new invite code. Check your connection and try again.',
    zh: '无法生成新邀请码，请检查网络后重试。',
    es: 'No se pudo crear un código nuevo. Revisa la conexión.',
    fr: 'Impossible de créer un nouveau code. Vérifiez le réseau.',
    de: 'Neuer Code fehlgeschlagen. Verbindung prüfen.',
    ja: '新しい招待コードを作成できませんでした。接続を確認してください。',
  );
  String get familyCodeRegeneratedTitle => _l6(
    en: 'New code ready',
    zh: '新邀请码已生成',
    es: 'Nuevo código listo',
    fr: 'Nouveau code prêt',
    de: 'Neuer Code bereit',
    ja: '新しいコードの準備完了',
  );
  String get familyCloudCreateFailedTitle => _l6(
    en: 'Couldn\'t create family',
    zh: '无法创建家庭',
    es: 'No se pudo crear la familia',
    fr: 'Création impossible',
    de: 'Familie nicht erstellt',
    ja: '家族を作成できません',
  );
  String get familyCloudCreateFailed => _l6(
    en: 'Cloud family setup failed. Check login and internet, then try again.',
    zh: '云端家庭创建失败，请检查登录与网络后重试。',
    es: 'Falló la creación. Revisa inicio de sesión y red.',
    fr: 'Échec de création. Vérifiez connexion et réseau.',
    de: 'Erstellung fehlgeschlagen. Login und Netz prüfen.',
    ja: 'クラウド家族の作成に失敗しました。ログインとネットワークを確認してください。',
  );
  String get familyCloudCreateSuccessTitle => _l6(
    en: 'Family created',
    zh: '家庭已创建',
    es: 'Familia creada',
    fr: 'Famille créée',
    de: 'Familie erstellt',
    ja: '家族を作成しました',
  );
  String get familyCloudCreateSuccess => _l6(
    en: 'Your invite code is ready. Share it so family can send to your frames from anywhere.',
    zh: '邀请码已就绪。分享给家人，他们即可随时向你的相框发送照片。',
    es: 'Tu código está listo. Compártelo para que envíen fotos a tus marcos.',
    fr: 'Votre code est prêt. Partagez-le pour envoyer des photos à vos cadres.',
    de: 'Dein Code ist bereit. Teile ihn, damit Familie Fotos an deine Rahmen senden kann.',
    ja: '招待コードの準備ができました。共有すると家族がどこからでもフレームに送れます。',
  );

  String get familyCloudCreateHint => _l6(
    en: 'Create a cloud family to share your frames. Members who join can send photos to those frames from anywhere.',
    zh: '创建云端家庭以共享相框。加入的成员可随时随地向这些相框发送照片。',
    es: 'Crea una familia en la nube para compartir marcos. Los miembros pueden enviar fotos desde cualquier lugar.',
    fr: 'Créez une famille cloud pour partager vos cadres. Les membres peuvent envoyer des photos de n’importe où.',
    de: 'Cloud‑Familie erstellen, um Rahmen zu teilen. Mitglieder können von überall Fotos senden.',
    ja: 'クラウドの家族を作成してフレームを共有。メンバーはどこからでも写真を送れます。',
  );
  String get familyCloudCreateLabel => _l6(
    en: 'Create cloud family',
    zh: '创建云端家庭',
    es: 'Crear familia',
    fr: 'Créer (cloud)',
    de: 'Cloud‑Familie',
    ja: 'クラウドで作成',
  );
  String get familyCloudSynced => _l6(
    en: 'Cloud synced',
    zh: '已同步云端',
    es: 'Sincronizado',
    fr: 'Synchronisé',
    de: 'Synchronisiert',
    ja: 'クラウド同期済み',
  );

  String get familyJoinedListTitle => _l6(
    en: 'Families you joined',
    zh: '已加入的家庭',
    es: 'Familias',
    fr: 'Familles jointes',
    de: 'Beigetreten',
    ja: '参加中のグループ',
  );
  String get familyLeaveJoined => _l6(
    en: 'Leave',
    zh: '离开',
    es: 'Salir',
    fr: 'Quitter',
    de: 'Verlassen',
    ja: '退出',
  );
  String get familyLeaveCloud => _l6(
    en: 'Leave cloud family',
    zh: '退出云端家庭',
    es: 'Salir de la familia',
    fr: 'Quitter la famille cloud',
    de: 'Cloud‑Familie verlassen',
    ja: 'クラウドの家族から退出',
  );
  String get familyLeaveCloudBody => _l6(
    en: 'You will leave this family until you join or create again.',
    zh: '退出后可重新创建或加入其他家庭。',
    es: 'Volverás a estar sin grupo.',
    fr: 'Vous quitterez la famille.',
    de: 'Sie verlassen diese Familiengruppe.',
    ja: 'この家族グループから外れます。',
  );

  String get familyMembersTitle => _l6(
    en: 'Members',
    zh: '成员',
    es: 'Miembros',
    fr: 'Membres',
    de: 'Mitglieder',
    ja: 'メンバー',
  );
  String get familyRoleOwner => _l6(
    en: 'Owner',
    zh: '家长',
    es: 'Propietario',
    fr: 'Organisateur',
    de: 'Besitzer·in',
    ja: '管理者',
  );
  String get familyRoleMember => _l6(
    en: 'Member',
    zh: '成员',
    es: 'Miembro',
    fr: 'Membre',
    de: 'Mitglied',
    ja: 'メンバー',
  );
  String get familyAddMemberTitle => _l6(
    en: 'Add household name',
    zh: '添加成员称呼',
    es: 'Añadir nombre',
    fr: 'Ajouter un nom',
    de: 'Name hinzufügen',
    ja: '名前を追加',
  );
  String get familyAddMemberHint => _l6(
    en: 'Grandma · Kids room',
    zh: '例如：外公、二宝',
    es: 'Abuela · …',
    fr: 'Mamie · …',
    de: 'Oma · …',
    ja: 'おばあちゃん など',
  );
  String get familyAddMemberSave => _l6(
    en: 'Add',
    zh: '添加',
    es: 'Añadir',
    fr: 'Ajouter',
    de: 'Hinzufügen',
    ja: '追加',
  );

  String get slideshowPrefsHint => _l6(
    en: 'Default slideshow for new sends',
    zh: '新照片默认幻灯片样式',
    es: 'Diaporama por defecto',
    fr: 'Diaporama par défaut',
    de: 'Standard-Diashow',
    ja: 'デフォルトのスライドショー',
  );

  /// Playlists tab — ink album send.
  String get sendAlbumToFrame => _l6(
    en: 'Send album to frame',
    zh: '将相册发送到相框',
    es: 'Enviar álbum',
    fr: 'Envoyer l’album',
    de: 'Album senden',
    ja: 'アルバムを送信',
  );
  String get sendAlbumToFrameSub => _l6(
    en: 'Opens the editor for each photo in order (same as picking multiple from Gallery).',
    zh: '按顺序打开每张照片的编辑界面（与多选相册相同）。',
    es: 'Abre el editor foto a foto.',
    fr: 'Ouvre l’éditeur pour chaque photo.',
    de: 'Öffnet jedes Foto nacheinander.',
    ja: '写真ごとにエディタを開きます。',
  );

  String slideshowSendingProgress(int cur, int total) => _l6(
    en: 'Sending $cur of $total…',
    zh: '正在发送 $cur / $total…',
    es: 'Enviando $cur de $total…',
    fr: 'Envoi $cur / $total…',
    de: 'Sende $cur von $total…',
    ja: '送信中 $cur / $total…',
  );

  /// Compact button label: "Sending (1/3)"
  String progressSendingCount(int cur, int total) => _l6(
    en: 'Sending ($cur/$total)',
    zh: '正在发送 ($cur/$total)',
    es: 'Enviando ($cur/$total)',
    fr: 'Envoi ($cur/$total)',
    de: 'Senden ($cur/$total)',
    ja: '送信中 ($cur/$total)',
  );

  String get progressSendingPhotos => _l6(
    en: 'Sending photos',
    zh: '正在发送照片',
    es: 'Enviando fotos',
    fr: 'Envoi des photos',
    de: 'Fotos senden',
    ja: '写真を送信中',
  );

  String progressConfiguringFrame(int pct) => _l6(
    en: 'Configuring frame ($pct%)',
    zh: '正在设置相框 ($pct%)',
    es: 'Configurando marco ($pct%)',
    fr: 'Configuration du cadre ($pct%)',
    de: 'Rahmen wird eingerichtet ($pct%)',
    ja: 'フレーム設定中 ($pct%)',
  );

  String get progressConfiguringFrameBusy => _l6(
    en: 'Configuring frame',
    zh: '正在设置相框',
    es: 'Configurando marco',
    fr: 'Configuration du cadre',
    de: 'Rahmen wird eingerichtet',
    ja: 'フレーム設定中',
  );
  String get slideshowBatchTitle => _l6(
    en: 'Slideshow queue',
    zh: '幻灯片队列',
    es: 'Cola de pase',
    fr: 'File diaporama',
    de: 'Diashow‑Warteschlange',
    ja: 'スライドショー送信',
  );
  String get slideshowPickInterval => _l6(
    en: 'Interval on frame',
    zh: '相框切换间隔',
    es: 'Intervalo',
    fr: 'Intervalle',
    de: 'Intervall',
    ja: '表示間隔',
  );
  String get slideshowRunBatch => _l6(
    en: 'Pick photos & upload',
    zh: '选择照片并上传',
    es: 'Elegir y subir',
    fr: 'Choisir et envoyer',
    de: 'Fotos wählen',
    ja: '写真を選んで送信',
  );
  String slideshowBatchDone(int count) => _l6(
    en: 'Uploaded $count photos.',
    zh: '已上传 $count 张照片。',
    es: '$count fotos.',
    fr: '$count photos.',
    de: '$count Fotos.',
    ja: '${count}枚送信しました。',
  );
  String get slideshowBatchExplain => _l6(
    en: 'Pick multiple photos and upload them to your paired frame. The server rotates them on the interval you choose.',
    zh: '选择多张照片上传到已配对的相框，服务器会按你设定的间隔轮播显示。',
    es: 'Elige varias fotos y súbelas al marco; el servidor las rotará según el intervalo.',
    fr: 'Choisissez plusieurs photos ; le serveur les affiche en rotation selon l’intervalle.',
    de: 'Mehrere Fotos hochladen — der Server wechselt sie im gewählten Intervall.',
    ja: '複数の写真をペアしたフレームに送信。サーバーが間隔で切り替えます。',
  );
  String get signInRequiredForCloud => _l6(
    en: 'Sign in to sync playlists with the cloud.',
    zh: '登录后可同步云端播放列表。',
    es: 'Inicia sesión para sincronizar listas.',
    fr: 'Connectez-vous pour synchroniser les listes.',
    de: 'Anmelden für Cloud‑Playlists.',
    ja: 'クラウド同期にはサインインが必要です。',
  );
  String get playlistNoLocalSlideshow => _l6(
    en: 'No slideshow saved on this phone yet. Pick photos below to send your first queue.',
    zh: '本机尚未保存幻灯片队列，请在下方选择照片开始发送。',
    es: 'Aún no hay cola guardada. Elige fotos abajo.',
    fr: 'Aucun diaporama local. Choisissez des photos ci‑dessous.',
    de: 'Noch keine lokale Diashow. Fotos unten wählen.',
    ja: 'まだスライドショーがありません。下で写真を選んでください。',
  );
  String playlistLocalStatus(int count, String interval) => _l6(
    en: 'On this phone: $count photos · every $interval',
    zh: '本机：$count 张 · 每 $interval',
    es: 'En el teléfono: $count fotos · cada $interval',
    fr: 'Sur le téléphone : $count photos · toutes les $interval',
    de: 'Auf dem Gerät: $count Fotos · alle $interval',
    ja: '端末: ${count}枚 · $interval ごと',
  );
  String playlistCloudDeviceStatus(
    String name,
    bool online,
    int count,
    String interval,
  ) => _l6(
    en: 'Cloud · $name: ${online ? "online" : "offline"} · $count photos · $interval',
    zh: '云端 · $name：${online ? "在线" : "离线"} · $count 张 · $interval',
    es: 'Nube · $name: ${online ? "en línea" : "desconectado"} · $count · $interval',
    fr: 'Cloud · $name : ${online ? "en ligne" : "hors ligne"} · $count · $interval',
    de: 'Cloud · $name: ${online ? "online" : "offline"} · $count · $interval',
    ja: 'クラウド · $name: ${online ? "オンライン" : "オフライン"} · ${count}枚 · $interval',
  );
  String playlistPhotoCount(int count) => _l6(
    en: '$count photos',
    zh: '$count 张照片',
    es: '$count fotos',
    fr: '$count photos',
    de: '$count Fotos',
    ja: '${count}枚',
  );
  String get playlistSendToFrame => _l6(
    en: 'Send to frame',
    zh: '发送到相框',
    es: 'Enviar al marco',
    fr: 'Envoyer au cadre',
    de: 'An Rahmen senden',
    ja: 'フレームに送信',
  );
  String playlistReadyToSend(int count) => _l6(
    en: '$count photos ready — choose how often they rotate, then send.',
    zh: '已选 $count 张照片 — 选择切换间隔后发送。',
    es: '$count fotos listas — elige el intervalo y envía.',
    fr: '$count photos prêtes — choisissez l’intervalle puis envoyez.',
    de: '$count Fotos bereit — Intervall wählen und senden.',
    ja: '${count}枚の写真 — 間隔を選んで送信します。',
  );
  String get playlistAlbumsEmptyHint => _l6(
    en: 'No playlists yet. Tap “Create New Playlist” to name one, add photos, pick hours, and send.',
    zh: '还没有播放列表。点「新建播放列表」→ 命名 → 选照片 → 选间隔 → 发送。',
    es: 'Sin listas aún. Crea una, añade fotos, intervalo y envía.',
    fr: 'Aucune liste. Créez-en une, ajoutez des photos, l’intervalle, envoyez.',
    de: 'Noch keine Listen. Erstellen, Fotos, Intervall, senden.',
    ja: 'プレイリストがありません。作成して写真・間隔を選び送信。',
  );

  String get prefsSectionSendFrame => _l6(
    en: 'Frame & slideshow',
    zh: '相框与幻灯片',
    es: 'Marco',
    fr: 'Cadre',
    de: 'Rahmen',
    ja: 'フレーム',
  );
  String get prefsDefaultSlideshowLabel => _l6(
    en: 'Default slideshow style',
    zh: '默认幻灯片',
    es: 'Estilo por defecto',
    fr: 'Style par défaut',
    de: 'Diashow-Standard',
    ja: '標準スタイル',
  );

  String get pairingHelpCard => _l6(
    en: 'Pairing help',
    zh: '配对帮助',
    es: 'Ayuda de emparejamiento',
    fr: 'Aide appairage',
    de: 'Hilfe zur Kopplung',
    ja: 'ペアの手順',
  );

  // —— Slideshow ——
  String get slideshowStyle => _l6(
    en: 'Slideshow style',
    zh: '幻灯片样式',
    es: 'Estilo',
    fr: 'Diaporama',
    de: 'Diashow',
    ja: 'スライドショー',
  );
  String get styleFade => _l6(
    en: 'Fade',
    zh: '淡入淡出',
    es: 'Fundido',
    fr: 'Fondu',
    de: 'Überblendung',
    ja: 'フェード',
  );
  String get styleKenBurns => _l6(
    en: 'Ken Burns',
    zh: '推拉',
    es: 'Pan zoom',
    fr: 'Pan zoom',
    de: 'Ken Burns',
    ja: 'ケン・バーンズ',
  );
  String get styleGrid => _l6(
    en: 'Grid',
    zh: '网格',
    es: 'Cuadrícula',
    fr: 'Grille',
    de: 'Raster',
    ja: 'グリッド',
  );
  String get styleRandom => _l6(
    en: 'Random',
    zh: '随机',
    es: 'Aleatorio',
    fr: 'Aléatoire',
    de: 'Zufall',
    ja: 'ランダム',
  );

  // —— Image editor ——
  String get editTitle => _l6(
    en: 'Edit & color grade',
    zh: '编辑与调色',
    es: 'Editar y color',
    fr: 'Retouche couleur',
    de: 'Bearbeiten & Gradierung',
    ja: '編集・色調整',
  );
  String get editorSectionLook => _l6(
    en: 'Color & look',
    zh: '色彩与画面',
    es: 'Color e imagen',
    fr: 'Couleur & rendu',
    de: 'Farbe & Aussehen',
    ja: '色と見た目',
  );
  String get editorSectionSend => _l6(
    en: 'Send & caption',
    zh: '发送与叠加文字',
    es: 'Enviar y texto',
    fr: 'Envoi & légendes',
    de: 'Senden & Text',
    ja: '送信とキャプション',
  );
  String get rotateTooltip => _l6(
    en: 'Rotate',
    zh: '旋转',
    es: 'Girar',
    fr: 'Pivoter',
    de: 'Drehen',
    ja: '回転',
  );
  String get decodeError => _l6(
    en: 'Could not decode image',
    zh: '无法解码图片',
    es: 'No se puede decodificar',
    fr: 'Image illisible',
    de: 'Bild nicht lesbar',
    ja: '画像を読めません',
  );
  String get decodeErrorHint => _l6(
    en: 'Try another photo. On iPhone: Full Photos access, and wait until iCloud finishes downloading.',
    zh: '请换一张照片重试。iPhone：开启完整照片权限，并等待 iCloud 下载完成。',
    es: 'Prueba otra foto. En iPhone: acceso completo y descarga de iCloud.',
    fr: 'Réessayez avec une autre photo. iPhone : accès complet et téléchargement iCloud.',
    de: 'Andere Foto versuchen. iPhone: Voller Fotozugriff und iCloud-Download abwarten.',
    ja: '別の写真を試してください。iPhoneは写真へのフルアクセスとiCloudダウンロード完了を確認。',
  );
  String get noImage => _l6(
    en: 'No image',
    zh: '无图片',
    es: 'Sin imagen',
    fr: 'Pas d’image',
    de: 'Kein Bild',
    ja: '画像なし',
  );
  String targetFrameHint(int w, int h) => _l6(
    en: 'Target frame ${w}×$h · E-ink 6-color',
    zh: '目标相框 ${w}×$h · 六色电子墨水',
    es: 'Marco ${w}×$h · E-ink 6 colores',
    fr: 'Cadre ${w}×$h · E-ink 6 couleurs',
    de: 'Ziel ${w}×$h · E-Ink 6 Farben',
    ja: '目標 ${w}×$h · 6色Eインク',
  );
  String get brightness => _l6(
    en: 'Brightness',
    zh: '亮度',
    es: 'Brillo',
    fr: 'Luminosité',
    de: 'Helligkeit',
    ja: '明るさ',
  );
  String get contrast => _l6(
    en: 'Contrast',
    zh: '对比度',
    es: 'Contraste',
    fr: 'Contraste',
    de: 'Kontrast',
    ja: 'コントラスト',
  );
  String get saturation => _l6(
    en: 'Saturation',
    zh: '饱和度',
    es: 'Saturación',
    fr: 'Saturation',
    de: 'Sättigung',
    ja: '彩度',
  );
  String get filterLabel => _l6(
    en: 'Filter',
    zh: '滤镜',
    es: 'Filtro',
    fr: 'Filtre',
    de: 'Filter',
    ja: 'フィルター',
  );
  String get filterOriginal => _l6(
    en: 'Original',
    zh: '原图',
    es: 'Original',
    fr: 'Original',
    de: 'Original',
    ja: 'オリジナル',
  );
  String get filterGrayscale => _l6(
    en: 'Grayscale',
    zh: '灰度',
    es: 'Escala de grises',
    fr: 'Gris',
    de: 'Graustufen',
    ja: 'グレー',
  );
  String get filterSepia => _l6(
    en: 'Sepia',
    zh: '怀旧',
    es: 'Sepia',
    fr: 'Sépia',
    de: 'Sepia',
    ja: 'セピア',
  );
  String get filterWarm => _l6(
    en: 'Warm',
    zh: '暖色',
    es: 'Cálido',
    fr: 'Chaud',
    de: 'Warm',
    ja: '暖かみ',
  );
  String get filterCool =>
      _l6(en: 'Cool', zh: '冷色', es: 'Frío', fr: 'Froid', de: 'Kühl', ja: 'クール');

  String pairingLineDefault(
    String deviceId,
    String transport,
    String slideshow,
  ) => _l6(
    en: 'Pairing: default $deviceId · $transport · $slideshow',
    zh: '配对：默认 $deviceId · $transport · $slideshow',
    es: 'Emparejamiento: $deviceId · $transport · $slideshow',
    fr: 'Appairage : défaut $deviceId · $transport · $slideshow',
    de: 'Kopplung: Standard $deviceId · $transport · $slideshow',
    ja: 'ペア: 既定 $deviceId · $transport · $slideshow',
  );
  String pairingLineUnpaired(String transport, String slideshow) => _l6(
    en: 'Pairing: not paired · $transport · $slideshow',
    zh: '配对：未配对 · $transport · $slideshow',
    es: 'Emparejamiento: sin emparejar · $transport · $slideshow',
    fr: 'Appairage : non appairé · $transport · $slideshow',
    de: 'Kopplung: nicht gekoppelt · $transport · $slideshow',
    ja: 'ペア: 未設定 · $transport · $slideshow',
  );

  String pairingLinePaired(
    String deviceId,
    String? apiUrl,
    String transport,
    String slideshow,
  ) {
    final url = apiUrl != null ? ' · $apiUrl' : '';
    return _l6(
      en: 'Paired: $deviceId$url · $transport · $slideshow',
      zh: '已配对：$deviceId$url · $transport · $slideshow',
      es: 'Emparejado: $deviceId$url · $transport · $slideshow',
      fr: 'Appairé : $deviceId$url · $transport · $slideshow',
      de: 'Gekoppelt: $deviceId$url · $transport · $slideshow',
      ja: 'ペア済: $deviceId$url · $transport · $slideshow',
    );
  }

  String get working => _l6(
    en: 'Working…',
    zh: '处理中…',
    es: 'Trabajando…',
    fr: 'Traitement…',
    de: 'Bitte warten…',
    ja: '処理中…',
  );
  String get processUpload => _l6(
    en: 'Process & upload',
    zh: '处理并上传',
    es: 'Procesar y subir',
    fr: 'Traiter et envoyer',
    de: 'Verarbeiten & hochladen',
    ja: '処理してアップロード',
  );
  String get exportSdButton => _l6(
    en: 'Export for SD card',
    zh: '导出到 SD 卡',
    es: 'Exportar a la tarjeta SD',
    fr: 'Exporter (carte SD)',
    de: 'Für SD-Karte exportieren',
    ja: 'SDカード用に書き出し',
  );

  String get processingFailed => _l6(
    en: 'Processing failed',
    zh: '处理失败',
    es: 'Error al procesar',
    fr: 'Échec du traitement',
    de: 'Verarbeitung fehlgeschlagen',
    ja: '処理に失敗しました',
  );

  String sendQueueWaitForFrame(int nextIndex, int total) => _l6(
    en: 'Photo ${nextIndex - 1} of $total sent. The frame shows your latest photo — wait a few seconds before the next one.',
    zh: '第 ${nextIndex - 1}/$total 张已发送。相框显示最新一张，请稍候再发下一张。',
    es: 'Foto ${nextIndex - 1} de $total enviada. El marco muestra la última — espera unos segundos.',
    fr: 'Photo ${nextIndex - 1}/$total envoyée. Le cadre affiche la dernière — patientez.',
    de: 'Foto ${nextIndex - 1} von $total gesendet. Der Rahmen zeigt das letzte Bild — kurz warten.',
    ja: '$total 枚中 ${nextIndex - 1} 枚目を送信しました。フレームは最新の1枚を表示します。少し待ってから次へ。',
  );

  String sendQueueFrameShowsLatest(int index, int total) => _l6(
    en: 'Photo $index of $total. The frame always shows your most recent send (e‑ink can take up to a minute).',
    zh: '第 $index/$total 张。相框只显示最近发送的一张（墨水屏刷新可能需要一分钟）。',
    es: 'Foto $index de $total. El marco muestra siempre la última foto enviada.',
    fr: 'Photo $index/$total. Le cadre affiche toujours la photo la plus récente.',
    de: 'Foto $index von $total. Der Rahmen zeigt immer das zuletzt gesendete Bild.',
    ja: '$index/$total 枚目。フレームには最新の1枚だけが表示されます。',
  );

  String uploadSuccessLine(int bytes, String hashPrefix) => _l6(
    en: 'Uploaded OK ($bytes B) · SHA $hashPrefix…',
    zh: '上传成功（$bytes 字节）· SHA $hashPrefix…',
    es: 'Subido ($bytes B) · SHA $hashPrefix…',
    fr: 'Envoyé ($bytes o) · SHA $hashPrefix…',
    de: 'Hochgeladen ($bytes B) · SHA $hashPrefix…',
    ja: 'アップロード完了 ($bytes B) · SHA $hashPrefix…',
  );

  /// Play path when server sent MYFM [.bin] in MQTT (this is what the frame should GET).
  String uploadFrameMyfmBinUrl(String url) => _l6(
    en: 'Frame display file (MYFM .bin): $url',
    zh: '相框显示文件（MYFM .bin）：$url',
    es: 'Archivo para el marco (MYFM .bin): $url',
    fr: 'Fichier affiché sur le cadre (MYFM .bin) : $url',
    de: 'Anzeige für Rahmen (MYFM .bin): $url',
    ja: 'フレーム表示用（MYFM .bin）: $url',
  );

  /// When API still publishes JPEG to MQTT — e‑ink firmware often rejects it.
  String uploadFrameMqttJpegUrl(String url) => _l6(
    en: 'Frame MQTT URL (JPEG — often will not update e‑ink): $url',
    zh: '相框 MQTT URL（JPEG，墨水屏通常无法显示）：$url',
    es: 'MQTT del marco (JPEG; e‑ink suele ignorarlo): $url',
    fr: 'URL MQTT cadre (JPEG — souvent ignoré par l’e‑ink) : $url',
    de: 'MQTT für Rahmen (JPEG — E‑Ink aktualisiert oft nicht): $url',
    ja: 'フレーム MQTT（JPEG、e‑inkは表示できないことが多い）: $url',
  );

  /// JPEG kept on VPS for previews / debugging — not what MQTT should use once MYFM is enabled.
  String uploadServerJpegBackupOnly(String basename) => _l6(
    en: 'Saved on server as JPEG backup only (not the frame play file): $basename',
    zh: '服务器另存预览用 JPEG（非相框播放文件）：$basename',
    es: 'Copia JPEG en servidor (solo respaldo; no es el archivo de reproducción): $basename',
    fr: 'JPEG sauvegardé sur le serveur (aperçu seulement, pas le fichier de lecture) : $basename',
    de: 'JPEG auf Server nur als Backup (nicht die Abspielformat-Datei): $basename',
    ja: 'サーバーにJPEGを保存（プレビュー用。再生は.bin）: $basename',
  );

  String apiError(Object e) => _l6(
    en: 'API: $e',
    zh: '接口：$e',
    es: 'API: $e',
    fr: 'API : $e',
    de: 'API: $e',
    ja: 'API: $e',
  );
  String bluetoothSendOk(String details) => _l6(
    en: 'Bluetooth transfer complete${details.isNotEmpty ? ' · $details' : ''}',
    zh: '蓝牙传输完成${details.isNotEmpty ? ' · $details' : ''}',
    es: 'Transferencia Bluetooth completada${details.isNotEmpty ? ' · $details' : ''}',
    fr: 'Transfert Bluetooth terminé${details.isNotEmpty ? ' · $details' : ''}',
    de: 'Bluetooth-Transfer abgeschlossen${details.isNotEmpty ? ' · $details' : ''}',
    ja: 'Bluetooth転送が完了しました${details.isNotEmpty ? ' · $details' : ''}',
  );
  String bluetoothSendFailed(String details) => _l6(
    en: 'Bluetooth transfer failed${details.isNotEmpty ? ' · $details' : ''}',
    zh: '蓝牙传输失败${details.isNotEmpty ? ' · $details' : ''}',
    es: 'Falló la transferencia Bluetooth${details.isNotEmpty ? ' · $details' : ''}',
    fr: 'Échec du transfert Bluetooth${details.isNotEmpty ? ' · $details' : ''}',
    de: 'Bluetooth-Transfer fehlgeschlagen${details.isNotEmpty ? ' · $details' : ''}',
    ja: 'Bluetooth転送に失敗しました${details.isNotEmpty ? ' · $details' : ''}',
  );
  String get sendOfflineNoNetworkForWifi => _l6(
    en: 'No network link — connect to Wi‑Fi (or the same network as the frame) and pair a frame QR with a local address, or use Bluetooth to send to the device without a server, or export to SD card.',
    zh: '当前无网络 — 请连接与相框同网或配对含本机地址的二维码，或改用蓝牙直连发送，或使用 SD 导出，无需经服务器上传。',
    es: 'Sin red — conéctate a Wi‑Fi o empareja un QR con URL local, o usa Bluetooth sin servidor, o exporta a SD.',
    fr: 'Pas de réseau — connectez le Wi‑Fi, ou jumelez un QR local, ou Bluetooth sans serveur, ou export SD.',
    de: 'Kein Netz — WLAN verbinden, Rahmen per QR lokal, oder per Bluetooth (ohne Server) bzw. SD-Export.',
    ja: 'ネット接続なし。Wi‑Fiに接続するか、QRのローカル地址をペア、またはBluetoothでそのまま送信、SD書き出し（サーバ不要）を使えます。',
  );
  String get sendOfflineBleToFrameNoServer => _l6(
    en: 'No network — sent to the frame over Bluetooth (no server upload).',
    zh: '无网络，已通过蓝牙发到相框（未经过服务器上传）。',
    es: 'Sin red: enviado al marco por Bluetooth (sin servidor).',
    fr: 'Hors-ligne : envoyé en Bluetooth au cadre (sans serveur).',
    de: 'Kein Internet: an den Rahmen per Bluetooth (ohne Server-Upload).',
    ja: 'オフライン — Bluetoothでフレームに送信（サーバ未使用）。',
  );

  String get shareSheetSdHint => _l6(
    en: 'Share sheet opened — save the file to your SD card (e.g. DCIM/MyFrame/).',
    zh: '已打开分享 — 请将文件保存到 SD 卡（如 DCIM/MyFrame/）。',
    es: 'Compartir abierto — guarda en la SD (p. ej. DCIM/MyFrame/).',
    fr: 'Partage ouvert — enregistrez sur la carte (ex. DCIM/MyFrame/).',
    de: 'Teilen geöffnet — auf SD speichern (z. B. DCIM/MyFrame/).',
    ja: '共有を開きました — SDに保存してください（例: DCIM/MyFrame/）。',
  );

  String get sdExportSaveDialogTitle => _l6(
    en: 'Save MyFrame file (pick SD card → DCIM/MyFrame if you can)',
    zh: '保存 MyFrame 文件（可选 SD 卡 → DCIM/MyFrame）',
    es: 'Guardar archivo MyFrame (SD → DCIM/MyFrame si puedes)',
    fr: 'Enregistrer le fichier MyFrame (carte SD → DCIM/MyFrame si possible)',
    de: 'MyFrame-Datei speichern (SD-Karte → DCIM/MyFrame)',
    ja: 'MyFrameファイルを保存（SDの DCIM/MyFrame が望ましい）',
  );

  String get sdExportSavedHint => _l6(
    en: 'File saved. Use folder DCIM/MyFrame/ on the card, then put the SD card in the frame.',
    zh: '已保存。请把文件放在存储卡的 DCIM/MyFrame/，再将卡插入相框。',
    es: 'Guardado. Usa DCIM/MyFrame/ en la tarjeta e insértala en el marco.',
    fr: 'Fichier enregistré. Utilisez DCIM/MyFrame/ sur la carte, puis insérez-la dans le cadre.',
    de: 'Gespeichert. Ordner DCIM/MyFrame/ auf der Karte nutzen, dann Karte in den Rahmen stecken.',
    ja: '保存しました。カード上は DCIM/MyFrame/ に置き、カードをフレームに挿してください。',
  );

  String get sdExportCancelledHint => _l6(
    en: 'Export cancelled.',
    zh: '已取消导出。',
    es: 'Exportación cancelada.',
    fr: 'Export annulé.',
    de: 'Export abgebrochen.',
    ja: '書き出しをキャンセルしました。',
  );

  /// Built-in FAQs — fully translated; used when language is Chinese or any locale.
  List<FaqItem> get helpFaqEntries => [
    FaqItem(
      id: 'pairing',
      question: _l6(
        en: 'How do I pair my frame?',
        zh: '如何配对相框？',
        es: '¿Cómo emparejo mi marco?',
        fr: 'Comment appairer mon cadre ?',
        de: 'Wie koppelt man den Rahmen?',
        ja: 'フレームのペア方法は？',
      ),
      answer: _l6(
        en: 'Open My Frames, turn on Bluetooth, and tap your frame when it appears. The app sends server settings, then guides you through Wi‑Fi. Finish profile setup, then send your first photo.',
        zh: '打开「我的相框」，开启蓝牙，在列表中点击您的相框。应用会先发送服务器配置，再引导您连接 Wi‑Fi。完成资料设置后即可发送第一张照片。',
        es: 'Abre Mis marcos, activa Bluetooth y toca tu marco. La app envía la configuración del servidor y luego la Wi‑Fi.',
        fr: 'Ouvrez Mes cadres, activez le Bluetooth et touchez votre cadre. L’app envoie les réglages serveur puis le Wi‑Fi.',
        de: 'Öffnen Sie Meine Rahmen, Bluetooth ein, Rahmen antippen. Die App sendet Server- und WLAN-Einstellungen.',
        ja: '「マイフレーム」を開き、Bluetoothをオンにしてフレームをタップ。サーバー設定後にWi‑Fi設定へ進みます。',
      ),
    ),
    FaqItem(
      id: 'photos_not_showing',
      question: _l6(
        en: 'Photos upload but do not appear on the frame',
        zh: '照片已上传但相框不显示',
        es: 'Las fotos se suben pero no se ven en el marco',
        fr: 'Les photos sont envoyées mais n’apparaissent pas',
        de: 'Fotos werden hochgeladen, Rahmen zeigt nichts',
        ja: '送信したのにフレームに表示されない',
      ),
      answer: _l6(
        en: 'Stay near the frame on the same Wi‑Fi. In Send, wait until the app reports delivered to frame. If it fails, open Frame settings → Reconfigure frame server to refresh MQTT over Bluetooth.',
        zh: '请靠近相框并确保在同一 Wi‑Fi。发送时请等待应用显示「已送达相框」。若失败，请到相框设置 → 重新配置相框服务器，通过蓝牙刷新 MQTT。',
        es: 'Quédate cerca del marco en la misma Wi‑Fi. Espera “entregado al marco”. Si falla, reconfigura el servidor por Bluetooth.',
        fr: 'Restez près du cadre sur le même Wi‑Fi. Attendez la confirmation. Sinon, reconfigurez le serveur via Bluetooth.',
        de: 'Nahe am Rahmen im gleichen WLAN bleiben. Auf Zustellung warten. Bei Fehler: Rahmen-Server per Bluetooth neu konfigurieren.',
        ja: '同じWi‑Fiでフレームの近くにいて、配信完了を待ってください。失敗時はBluetoothでサーバー再設定。',
      ),
    ),
    FaqItem(
      id: 'send_photo',
      question: _l6(
        en: 'How do I send a single photo?',
        zh: '如何发送单张照片？',
        es: '¿Cómo envío una foto?',
        fr: 'Comment envoyer une photo ?',
        de: 'Wie sende ich ein Foto?',
        ja: '1枚の写真を送るには？',
      ),
      answer: _l6(
        en: 'Tap the center Send button, pick a photo, adjust color if you like, then tap Send. The frame downloads the image from the server over Wi‑Fi.',
        zh: '点击底部中间的「发送」，选择照片，可按需调色，然后点发送。相框会通过 Wi‑Fi 从服务器下载图片。',
        es: 'Pulsa Enviar, elige foto, ajusta y envía. El marco descarga por Wi‑Fi.',
        fr: 'Appuyez sur Envoyer, choisissez une photo, ajustez et envoyez.',
        de: 'Senden antippen, Foto wählen, anpassen, senden. Der Rahmen lädt per WLAN.',
        ja: '中央の送信から写真を選び、調整して送信。フレームがWi‑Fiで取得します。',
      ),
    ),
    FaqItem(
      id: 'playlist',
      question: _l6(
        en: 'How do playlists and slideshows work?',
        zh: '播放列表和幻灯片如何工作？',
        es: '¿Cómo funcionan las listas y el pase de diapositivas?',
        fr: 'Comment fonctionnent les listes et diaporamas ?',
        de: 'Wie funktionieren Playlists und Diashows?',
        ja: 'プレイリストとスライドショーは？',
      ),
      answer: _l6(
        en: 'Settings → Application → Playlist → Create New Playlist. Name it, add photos, choose rotation interval (1h–24h), then Send to frame. Saved playlists appear in Gallery → Albums too.',
        zh: '设置 → 应用 → 播放列表 → 新建播放列表。命名、添加照片、选择轮播间隔（1–24 小时），然后发送到相框。保存的列表也会出现在「相册 → 相册集」中。',
        es: 'Ajustes → Aplicación → Lista → Crear. Nombre, fotos, intervalo y enviar.',
        fr: 'Réglages → Application → Liste → Créer. Nom, photos, intervalle, envoyer.',
        de: 'Einstellungen → App → Playlist → Erstellen. Name, Fotos, Intervall, senden.',
        ja: '設定→アプリ→プレイリスト→新規作成。名前・写真・間隔を選び送信。',
      ),
    ),
    FaqItem(
      id: 'family',
      question: _l6(
        en: 'How do family invites work?',
        zh: '家庭邀请如何使用？',
        es: '¿Cómo funcionan las invitaciones familiares?',
        fr: 'Comment fonctionnent les invitations famille ?',
        de: 'Wie funktionieren Familieneinladungen?',
        ja: '家族招待の使い方は？',
      ),
      answer: _l6(
        en: 'Family tab shows your invite code and QR (myframe.ink/join). When someone joins, they get access to your provisioned frames and can send photos from their phone anywhere — like WeChat friend invite, without needing the frame nearby or BLE pairing.',
        zh: '「家庭」页显示邀请码和二维码（myframe.ink/join）。家人加入后即可访问您已配网的相框，随时随地从手机发送照片——类似微信好友邀请，无需靠近相框或蓝牙配对。',
        es: 'Comparte el código/QR. Al unirse, pueden enviar fotos a tus marcos desde cualquier lugar.',
        fr: 'Partagez le code/QR. Une fois rejoints, ils envoient des photos à vos cadres de n’importe où.',
        de: 'Code/QR teilen. Nach Beitritt können Mitglieder Fotos von überall an deine Rahmen senden.',
        ja: 'コード/QRを共有。参加後、メンバーはどこからでもあなたのフレームに写真を送れます。',
      ),
    ),
    FaqItem(
      id: 'language',
      question: _l6(
        en: 'How do I change the app language?',
        zh: '如何更改应用语言？',
        es: '¿Cómo cambio el idioma?',
        fr: 'Comment changer la langue ?',
        de: 'Wie ändere ich die Sprache?',
        ja: '言語を変更するには？',
      ),
      answer: _l6(
        en: 'Settings → Application → Language. Choose 中文 for Chinese, or English, Spanish, French, German, or Japanese. Help text and FAQs follow your choice.',
        zh: '设置 → 应用 → 语言。选择「中文」即可使用中文界面；也可选英语、西班牙语、法语、德语或日语。帮助与常见问题会随语言切换。',
        es: 'Ajustes → Aplicación → Idioma. Elige 中文 u otro idioma.',
        fr: 'Réglages → Application → Langue. Choisissez 中文 ou une autre langue.',
        de: 'Einstellungen → App → Sprache. Wählen Sie 中文 oder eine andere Sprache.',
        ja: '設定→アプリ→言語。中文などを選択。',
      ),
    ),
    FaqItem(
      id: 'wifi_ble',
      question: _l6(
        en: 'Bluetooth or Wi‑Fi problems during setup',
        zh: '配对时蓝牙或 Wi‑Fi 有问题',
        es: 'Problemas de Bluetooth o Wi‑Fi al configurar',
        fr: 'Problèmes Bluetooth ou Wi‑Fi à la configuration',
        de: 'Bluetooth- oder WLAN-Probleme bei der Einrichtung',
        ja: '設定時のBluetooth/Wi‑Fiの問題',
      ),
      answer: _l6(
        en: 'Keep the phone within a few feet of the frame. Grant Bluetooth and location permissions on Android. If Wi‑Fi list is empty, type the network name manually. Retry Reconfigure frame server from Settings.',
        zh: '请将手机靠近相框（几米内）。Android 请授予蓝牙和定位权限。若 Wi‑Fi 列表为空，可手动输入网络名称。可在设置的相框设置中重试「重新配置相框服务器」。',
        es: 'Acércate al marco. Concede permisos en Android. Escribe la red manualmente si hace falta.',
        fr: 'Restez près du cadre. Autorisations Bluetooth/localisation sur Android.',
        de: 'Nah am Rahmen bleiben. Android: Bluetooth- und Standortrechte. WLAN ggf. manuell eingeben.',
        ja: 'フレームの近くで。AndroidはBluetooth/位置の許可。Wi‑Fiは手入力も可。',
      ),
    ),
    FaqItem(
      id: 'sign_in',
      question: _l6(
        en: 'Which sign-in options are available?',
        zh: '有哪些登录方式？',
        es: '¿Qué opciones de inicio de sesión hay?',
        fr: 'Quelles options de connexion ?',
        de: 'Welche Anmeldeoptionen gibt es?',
        ja: 'ログイン方法は？',
      ),
      answer: _l6(
        en: 'iPhone: Apple, Google, or WeChat. Android: Google or WeChat. Sign in to sync cloud playlists and family groups across devices.',
        zh: 'iPhone：Apple、Google 或微信。Android：Google 或微信。登录后可同步云端播放列表与家庭组。',
        es: 'iPhone: Apple, Google o WeChat. Android: Google o WeChat.',
        fr: 'iPhone : Apple, Google ou WeChat. Android : Google ou WeChat.',
        de: 'iPhone: Apple, Google oder WeChat. Android: Google oder WeChat.',
        ja: 'iPhone: Apple/Google/WeChat。Android: Google/WeChat。',
      ),
    ),
    FaqItem(
      id: 'gallery_albums',
      question: _l6(
        en: 'What is the difference between Gallery and albums?',
        zh: '「相册」和「相册集」有什么区别？',
        es: '¿Diferencia entre Galería y álbumes?',
        fr: 'Différence entre Galerie et albums ?',
        de: 'Unterschied Galerie und Alben?',
        ja: 'ギャラリーとアルバムの違いは？',
      ),
      answer: _l6(
        en: 'Gallery → Personal is your full photo library on this phone. Gallery → Albums (and Playlists) are named collections you build for batch send or slideshow rotation.',
        zh: '「相册 → 个人」是本机全部照片。「相册 → 相册集」（及播放列表）是您为批量发送或幻灯片轮播创建的分组。',
        es: 'Personal = todas las fotos. Álbumes/listas = colecciones para enviar.',
        fr: 'Personnel = toutes les photos. Albums/listes = collections pour envoi.',
        de: 'Persönlich = alle Fotos. Alben/Playlists = Sammlungen zum Senden.',
        ja: '個人=全写真。アルバム/プレイリスト=送信用のまとまり。',
      ),
    ),
    FaqItem(
      id: 'firmware',
      question: _l6(
        en: 'How do firmware updates work?',
        zh: '固件如何更新？',
        es: '¿Cómo funcionan las actualizaciones de firmware?',
        fr: 'Comment fonctionnent les mises à jour firmware ?',
        de: 'Wie funktionieren Firmware-Updates?',
        ja: 'ファームウェア更新は？',
      ),
      answer: _l6(
        en: 'Settings → Frame firmware update (or Device info). Tap Check for updates, then Install update when a new release is available. The app contacts MyFrame servers and sends the update to your frame over Wi‑Fi.',
        zh: '设置 → 相框固件更新（或设备信息）。点击检查更新，有新版本时点安装更新。应用会连接 MyFrame 服务器并通过 Wi‑Fi 推送到相框。',
        es: 'Ajustes → Actualización de firmware. Pulsa Buscar actualizaciones e Instalar cuando haya una nueva versión.',
        fr: 'Réglages → Mise à jour firmware. Vérifiez puis installez quand une version est disponible.',
        de: 'Einstellungen → Firmware-Update. Prüfen und installieren, wenn verfügbar.',
        ja: '設定 → フレームファーム更新。更新を確認し、利用可能ならインストール。',
      ),
    ),
    FaqItem(
      id: 'contact',
      question: _l6(
        en: 'How do I contact support?',
        zh: '如何联系客服？',
        es: '¿Cómo contacto con soporte?',
        fr: 'Comment contacter le support ?',
        de: 'Wie erreiche ich den Support?',
        ja: 'サポートへの連絡方法は？',
      ),
      answer: _l6(
        en: 'Settings → Help → Contact us. Email contact@myframe.ink — tap to copy. Include your frame name and what you tried.',
        zh: '设置 → 帮助 → 联系我们。邮箱 contact@myframe.ink，点击可复制。请注明相框名称与已尝试的步骤。',
        es: 'Ajustes → Ayuda → Contáctanos. Email contact@myframe.ink.',
        fr: 'Réglages → Aide → Nous contacter. E-mail contact@myframe.ink.',
        de: 'Einstellungen → Hilfe → Kontakt. E-Mail contact@myframe.ink.',
        ja: '設定→ヘルプ→お問い合わせ。contact@myframe.ink',
      ),
    ),
    FaqItem(
      id: 'share_intent',
      question: _l6(
        en: 'Can I share photos from other apps into MyFrame?',
        zh: '能从其他应用分享照片到 MyFrame 吗？',
        es: '¿Puedo compartir fotos desde otras apps?',
        fr: 'Partager des photos depuis d’autres apps ?',
        de: 'Fotos aus anderen Apps teilen?',
        ja: '他アプリから写真を共有できる？',
      ),
      answer: _l6(
        en: 'Yes. In Photos or Gallery, tap Share → MyFrame. The app opens Send with your images ready to edit and upload.',
        zh: '可以。在相册或图库中点「分享」→ MyFrame，应用会打开发送页，照片可直接编辑并上传。',
        es: 'Sí. Compartir → MyFrame desde Fotos.',
        fr: 'Oui. Partager → MyFrame depuis Photos.',
        de: 'Ja. Teilen → MyFrame aus Fotos.',
        ja: 'はい。写真アプリから共有→MyFrame。',
      ),
    ),
  ];

  // ============================================================================
  // Upload Progress Messages (for frame_cloud_cast_service.dart)
  // ============================================================================

  String get uploadPreparingPhoto => _l6(
        en: 'Preparing photo…',
        zh: '准备照片中…',
        es: 'Preparando foto…',
        fr: 'Préparation de la photo…',
        de: 'Foto wird vorbereitet…',
        ja: '写真を準備中…',
      );

  String get uploadConnectingFrame => _l6(
        en: 'Connecting to your frame…',
        zh: '正在连接相框…',
        es: 'Conectando a tu marco…',
        fr: 'Connexion à votre cadre…',
        de: 'Verbindung zum Rahmen…',
        ja: 'フレームに接続中…',
      );

  String get uploadWakingFrame => _l6(
        en: 'Preparing…',
        zh: '准备中…',
        es: 'Preparando…',
        fr: 'Préparation…',
        de: 'Vorbereiten…',
        ja: '準備中…',
      );

  String get uploadWakingFrameVia => _l6(
        en: 'Preparing…',
        zh: '准备中…',
        es: 'Preparando…',
        fr: 'Préparation…',
        de: 'Vorbereiten…',
        ja: '準備中…',
      );

  String get uploadWakingConnection => _l6(
        en: 'Preparing…',
        zh: '准备中…',
        es: 'Despertando conexión…',
        fr: 'Réveil de la connexion…',
        de: 'Verbindung wird aufgeweckt…',
        ja: '接続を起動中…',
      );

  String get uploadPhotoUploading => _l6(
        en: 'Uploading photo to server…',
        zh: '上传照片到服务器…',
        es: 'Subiendo foto al servidor…',
        fr: 'Téléchargement vers le serveur…',
        de: 'Foto wird hochgeladen…',
        ja: 'サーバーにアップロード中…',
      );

  String get uploadPhotoOnline => _l6(
        en: 'Uploading photo (frame is online)…',
        zh: '上传照片（相框在线）…',
        es: 'Subiendo foto (marco en línea)…',
        fr: 'Téléchargement (cadre en ligne)…',
        de: 'Upload (Rahmen ist online)…',
        ja: 'アップロード中（フレームはオンライン）…',
      );

  String get uploadRetrying => _l6(
        en: 'Retrying upload (alternate frame ID)…',
        zh: '重试上传（备用相框 ID）…',
        es: 'Reintentando (ID alternativo)…',
        fr: 'Nouvelle tentative (ID alternatif)…',
        de: 'Wiederholung (alternative ID)…',
        ja: '再試行中（代替 ID）…',
      );

  String get uploadFrameNotConfirmed => _l6(
        en: 'Frame did not confirm MQTT — waking via HTTP and retrying…',
        zh: '相框未确认 MQTT — 通过 HTTP 唤醒并重试…',
        es: 'Marco no confirmó MQTT — despertando vía HTTP…',
        fr: 'Cadre non confirmé — réveil HTTP…',
        de: 'Rahmen nicht bestätigt — HTTP-Aufweckung…',
        ja: 'フレームが MQTT を確認しませんでした — HTTP 経由で再試行…',
      );

  String get uploadFrameOffline => _l6(
        en: 'Frame offline — waking via HTTP and retrying…',
        zh: '相框离线 — 通过 HTTP 唤醒并重试…',
        es: 'Marco sin conexión — despertando vía HTTP…',
        fr: 'Cadre hors ligne — réveil HTTP…',
        de: 'Rahmen offline — HTTP-Aufweckung…',
        ja: 'フレームがオフライン — HTTP 経由で再試行…',
      );

  String get uploadSendingAgain => _l6(
        en: 'Sending photo again…',
        zh: '再次发送照片…',
        es: 'Enviando foto nuevamente…',
        fr: 'Renvoi de la photo…',
        de: 'Foto wird erneut gesendet…',
        ja: '写真を再送信中…',
      );

  String get uploadWaitingFrame => _l6(
        en: 'Waiting for frame to refresh…',
        zh: '照片已发送 · 等待相框显示…',
        es: 'Foto enviada · esperando visualización…',
        fr: 'Photo envoyée · attente affichage…',
        de: 'Foto gesendet · warte auf Anzeige…',
        ja: '写真を送信しました · 表示待ち…',
      );

  String uploadWaitingSeconds(int seconds) => _l6(
        en: 'Waiting for frame to refresh… (${seconds}s)',
        zh: '相框正在接收照片… (${seconds}秒)',
        es: 'Marco recibiendo foto… (${seconds}s)',
        fr: 'Cadre reçoit la photo… (${seconds}s)',
        de: 'Rahmen empfängt Foto… (${seconds}s)',
        ja: 'フレームが写真を受信中… (${seconds}秒)',
      );

  String uploadUpdatingDisplay(int seconds) => _l6(
        en: 'Waiting for frame to refresh… (${seconds}s)',
        zh: '更新相框显示… (${seconds}秒)',
        es: 'Actualizando marco… (${seconds}s)',
        fr: 'Mise à jour du cadre… (${seconds}s)',
        de: 'Rahmen wird aktualisiert… (${seconds}s)',
        ja: 'フレームを更新中… (${seconds}秒)',
      );

  String uploadEinkRefreshing(int seconds) => _l6(
        en: 'Waiting for frame to refresh… (${seconds}s)',
        zh: '电子墨水屏仍在刷新 — 请稍候… (${seconds}秒)',
        es: 'E-ink refrescando — espere… (${seconds}s)',
        fr: 'E-ink actualise — patientez… (${seconds}s)',
        de: 'E-Ink aktualisiert — bitte warten… (${seconds}s)',
        ja: 'E-ink 更新中 — お待ちください… (${seconds}秒)',
      );

  String get uploadFrameDownloadStalled => _l6(
        en: 'Frame download stalled — resending…',
        zh: '相框下载停滞 — 重新发送…',
        es: 'Descarga detenida — reenviando…',
        fr: 'Téléchargement bloqué — renvoi…',
        de: 'Download gestoppt — erneut senden…',
        ja: 'ダウンロードが停止 — 再送信中…',
      );

  String get uploadDownloadFailed => _l6(
        en: 'Download failed — retrying…',
        zh: '下载失败 — 重试中…',
        es: 'Descarga falló — reintentando…',
        fr: 'Échec téléchargement — nouvelle tentative…',
        de: 'Download fehlgeschlagen — Wiederholung…',
        ja: 'ダウンロード失敗 — 再試行中…',
      );

  String get uploadFrameDownloadComplete => _l6(
        en: 'Waiting for frame to refresh…',
        zh: '相框已下载照片 — 刷新显示…',
        es: 'Foto descargada — refrescando…',
        fr: 'Photo téléchargée — rafraîchissement…',
        de: 'Foto heruntergeladen — Aktualisierung…',
        ja: '写真をダウンロード完了 — 表示を更新中…',
      );

  String get uploadEinkNote => _l6(
        en: 'E‑ink display may take up to a minute to refresh.',
        zh: '电子墨水屏刷新可能需要一分钟。',
        es: 'E-ink puede tardar hasta un minuto.',
        fr: 'E-ink peut prendre jusqu\'à une minute.',
        de: 'E-Ink kann bis zu einer Minute dauern.',
        ja: 'E-ink ディスプレイの更新には最大 1 分かかる場合があります。',
      );

  String get uploadStillRefreshing => _l6(
        en: 'Waiting for frame to refresh…',
        zh: '仍在更新相框（电子墨水可能需要一分钟）…',
        es: 'Actualizando marco (e-ink hasta un minuto)…',
        fr: 'Mise à jour en cours (e-ink jusqu\'à une minute)…',
        de: 'Aktualisierung läuft (E-Ink bis zu einer Minute)…',
        ja: 'フレームを更新中（E-ink は最大 1 分かかります）…',
      );

  // Error messages
  String get uploadErrorNoFrameId => _l6(
        en: 'No frame display ID saved. Scan the pairing QR on the frame once, then try again.',
        zh: '未保存相框显示 ID。请扫描相框上的配对二维码，然后重试。',
        es: 'ID de marco no guardado. Escanee el código QR de emparejamiento.',
        fr: 'ID d\'affichage non enregistré. Scannez le QR d\'appairage.',
        de: 'Keine Display-ID gespeichert. QR-Code scannen und erneut versuchen.',
        ja: 'フレーム表示 ID が保存されていません。ペアリング QR コードをスキャンしてください。',
      );

  String get uploadErrorMissingFrameId => _l6(
        en: 'Pairing is missing the frame display ID. Scan the frame QR once, then try again.',
        zh: '配对缺少相框显示 ID。请扫描相框二维码，然后重试。',
        es: 'Falta ID de marco. Escanee el código QR.',
        fr: 'ID manquant. Scannez le QR.',
        de: 'ID fehlt. QR-Code scannen.',
        ja: 'フレーム ID がありません。QR コードをスキャンしてください。',
      );

  // ============================================================================
  // Other Missing UI Strings
  // ============================================================================

  String get logCopied => _l6(
        en: 'Log copied',
        zh: '日志已复制',
        es: 'Registro copiado',
        fr: 'Journal copié',
        de: 'Protokoll kopiert',
        ja: 'ログをコピーしました',
      );

  String get copyAction => _l6(
        en: 'Copy',
        zh: '复制',
        es: 'Copiar',
        fr: 'Copier',
        de: 'Kopieren',
        ja: 'コピー',
      );

  String get clearAction => _l6(
        en: 'Clear',
        zh: '清除',
        es: 'Borrar',
        fr: 'Effacer',
        de: 'Löschen',
        ja: 'クリア',
      );

  String get closeAction => _l6(
        en: 'Close',
        zh: '关闭',
        es: 'Cerrar',
        fr: 'Fermer',
        de: 'Schließen',
        ja: '閉じる',
      );

  String get tryAgainAction => _l6(
        en: 'Try again',
        zh: '重试',
        es: 'Intentar de nuevo',
        fr: 'Réessayer',
        de: 'Erneut versuchen',
        ja: '再試行',
      );

  String get retryAction => _l6(
        en: 'Retry',
        zh: '重试',
        es: 'Reintentar',
        fr: 'Réessayer',
        de: 'Wiederholen',
        ja: 'リトライ',
      );

  String get continueAction => _l6(
        en: 'Continue',
        zh: '继续',
        es: 'Continuar',
        fr: 'Continuer',
        de: 'Fortfahren',
        ja: '続ける',
      );

  String get addTextButton => _l6(
        en: 'Add Text',
        zh: '添加文字',
        es: 'Añadir texto',
        fr: 'Ajouter du texte',
        de: 'Text hinzufügen',
        ja: 'テキストを追加',
      );

  String get zoomLabel => _l6(
        en: 'Zoom',
        zh: '缩放',
        es: 'Zoom',
        fr: 'Zoom',
        de: 'Zoom',
        ja: 'ズーム',
      );

  String get sizeLabel => _l6(
        en: 'Size',
        zh: '大小',
        es: 'Tamaño',
        fr: 'Taille',
        de: 'Größe',
        ja: 'サイズ',
      );

  String textSizePixels(int size) => _l6(
        en: 'Size ${size}px',
        zh: '大小 ${size}px',
        es: 'Tamaño ${size}px',
        fr: 'Taille ${size}px',
        de: 'Größe ${size}px',
        ja: 'サイズ ${size}px',
      );

  String get boldLabel => _l6(
        en: 'Bold',
        zh: '粗体',
        es: 'Negrita',
        fr: 'Gras',
        de: 'Fett',
        ja: '太字',
      );

  String get showWeatherLabel => _l6(
        en: 'Show weather',
        zh: '显示天气',
        es: 'Mostrar clima',
        fr: 'Afficher météo',
        de: 'Wetter anzeigen',
        ja: '天気を表示',
      );

  String get showDateTimeLabel => _l6(
        en: 'Show date/time',
        zh: '显示日期/时间',
        es: 'Mostrar fecha/hora',
        fr: 'Afficher date/heure',
        de: 'Datum/Uhrzeit anzeigen',
        ja: '日付/時刻を表示',
      );

  String get locationPermissionNeeded => _l6(
        en: 'Location permission is needed for live weather.',
        zh: '需要位置权限才能显示实时天气。',
        es: 'Se necesita permiso de ubicación para el clima.',
        fr: 'Permission de localisation nécessaire pour la météo.',
        de: 'Standortberechtigung für Wetter erforderlich.',
        ja: 'リアルタイム天気には位置情報の許可が必要です。',
      );

  String get weatherLoadFailed => _l6(
        en: 'Could not load weather. Check location and try again.',
        zh: '无法加载天气。请检查位置并重试。',
        es: 'No se pudo cargar el clima. Verifique la ubicación.',
        fr: 'Échec du chargement de la météo. Vérifiez la localisation.',
        de: 'Wetter konnte nicht geladen werden. Standort prüfen.',
        ja: '天気を読み込めませんでした。位置情報を確認してください。',
      );

  String get typeSomethingFirst => _l6(
        en: 'Type something first',
        zh: '请先输入内容',
        es: 'Escribe algo primero',
        fr: 'Écrivez quelque chose d\'abord',
        de: 'Geben Sie zuerst etwas ein',
        ja: '最初に何か入力してください',
      );

  String get frameNotConnected => _l6(
        en: 'Frame is not connected. Connect your frame now.',
        zh: '相框未连接。请立即连接相框。',
        es: 'Marco no conectado. Conéctelo ahora.',
        fr: 'Cadre non connecté. Connectez-le maintenant.',
        de: 'Rahmen nicht verbunden. Jetzt verbinden.',
        ja: 'フレームが接続されていません。今すぐ接続してください。',
      );

  String get preparingUploadLink => _l6(
        en: 'Preparing upload link…',
        zh: '准备上传链接…',
        es: 'Preparando enlace de carga…',
        fr: 'Préparation du lien de téléchargement…',
        de: 'Upload-Link wird vorbereitet…',
        ja: 'アップロードリンクを準備中…',
      );

  String get uploadLinkFailed => _l6(
        en: 'Could not create upload link. Try again.',
        zh: '无法创建上传链接。请重试。',
        es: 'No se pudo crear el enlace. Inténtelo de nuevo.',
        fr: 'Impossible de créer le lien. Réessayez.',
        de: 'Link konnte nicht erstellt werden. Erneut versuchen.',
        ja: 'アップロードリンクを作成できませんでした。再試行してください。',
      );

  String get photosPermissionNeeded => _l6(
        en: 'Allow Photos/Videos permission to pick images.',
        zh: '允许照片/视频权限以选择图片。',
        es: 'Permita acceso a fotos/videos para elegir imágenes.',
        fr: 'Autorisez l\'accès aux photos/vidéos pour choisir des images.',
        de: 'Erlauben Sie Zugriff auf Fotos/Videos, um Bilder auszuwählen.',
        ja: '画像を選択するには写真/ビデオの許可を許可してください。',
      );

  String get duplicatePhotosError => _l6(
        en: 'Playlist has duplicate photos — pick different images for each slot.',
        zh: '播放列表包含重复照片 — 为每个位置选择不同的图片。',
        es: 'La lista tiene fotos duplicadas — elija imágenes diferentes.',
        fr: 'Liste contient des photos en double — choisissez des images différentes.',
        de: 'Playlist enthält doppelte Fotos — wählen Sie verschiedene Bilder.',
        ja: 'プレイリストに重複した写真があります — 各スロットに異なる画像を選択してください。',
      );

  String get maxImagesAtATime => _l6(
        en: 'Max 10 images can be selected at a time.',
        zh: '一次最多选择 10 张图片。',
        es: 'Máximo 10 imágenes a la vez.',
        fr: 'Maximum 10 images à la fois.',
        de: 'Maximal 10 Bilder auf einmal.',
        ja: '一度に最大10枚まで選択できます。',
      );

  String get preparingPlaylist => _l6(
        en: 'Preparing Playlist…',
        zh: '正在准备播放列表…',
        es: 'Preparando lista…',
        fr: 'Préparation de la playlist…',
        de: 'Playlist wird vorbereitet…',
        ja: 'プレイリストを準備中…',
      );

  String albumDeleteConfirm(String name) => _l6(
        en: 'Delete "$name" and all its photos?',
        zh: '删除「$name」及其全部照片？',
        es: '¿Eliminar "$name" y todas sus fotos?',
        fr: 'Supprimer « $name » et toutes ses photos ?',
        de: '„$name“ und alle Fotos löschen?',
        ja: '「$name」とその写真をすべて削除しますか？',
      );

  /// Playlist delete confirmation (Gallery ▸ Playlists).
  String get deleteAlbumTitle => _l6(
        en: 'Delete Playlist',
        zh: '删除播放列表',
        es: 'Eliminar lista',
        fr: 'Supprimer la playlist',
        de: 'Playlist löschen',
        ja: 'プレイリストを削除',
      );

  String get deleteAlbumStopsPlaylistBody => _l6(
        en: 'Deleting the playlist will stop it on the frame.',
        zh: '删除播放列表将停止相框上的轮播。',
        es: 'Eliminar la lista detendrá la reproducción en el marco.',
        fr: 'Supprimer la playlist arrêtera la lecture sur le cadre.',
        de: 'Das Löschen der Playlist stoppt die Wiedergabe am Rahmen.',
        ja: 'プレイリストを削除するとフレーム上の再生が停止します。',
      );

  String deleteAlbumConfirmDetail(String name) => _l6(
        en: 'Delete "$name"?\n\nDeleting the playlist will stop it on the frame.',
        zh: '删除「$name」？\n\n删除播放列表将停止相框上的轮播。',
        es: '¿Eliminar "$name"?\n\nEliminar la lista detendrá la reproducción en el marco.',
        fr: 'Supprimer « $name » ?\n\nSupprimer la playlist arrêtera la lecture sur le cadre.',
        de: '„$name“ löschen?\n\nDas Löschen stoppt die Wiedergabe am Rahmen.',
        ja: '「$name」を削除しますか？\n\nプレイリストを削除するとフレーム上の再生が停止します。',
      );

  String get albumDeletedToast => _l6(
        en: 'Playlist deleted',
        zh: '播放列表已删除',
        es: 'Lista eliminada',
        fr: 'Playlist supprimée',
        de: 'Playlist gelöscht',
        ja: 'プレイリストを削除しました',
      );

  String get deletingAlbum => _l6(
        en: 'Deleting…',
        zh: '正在删除…',
        es: 'Eliminando…',
        fr: 'Suppression…',
        de: 'Wird gelöscht…',
        ja: '削除中…',
      );

  String get deletePhotoTitle => _l6(
        en: 'Delete Photo?',
        zh: '删除照片？',
        es: '¿Eliminar foto?',
        fr: 'Supprimer la photo ?',
        de: 'Foto löschen?',
        ja: '写真を削除しますか？',
      );

  String get deletePhotoAccountBody => _l6(
        en:
            'This permanently deletes the photo from your account. It is also removed from any albums. The frame display is not stopped.',
        zh: '将从账号永久删除此照片，并同步从所有相册移除。不会停止相框当前显示。',
        es:
            'Esto elimina la foto de tu cuenta y de cualquier álbum. La pantalla del marco no se detiene.',
        fr:
            'Cela supprime définitivement la photo de votre compte et de tous les albums. L’affichage du cadre n’est pas arrêté.',
        de:
            'Dies löscht das Foto dauerhaft aus dem Konto und aus allen Alben. Die Rahmenanzeige wird nicht gestoppt.',
        ja: 'アカウントとすべてのアルバムからこの写真を完全に削除します。フレーム表示は停止しません。',
      );

  String get photoDeletedToast => _l6(
        en: 'Photo deleted',
        zh: '照片已删除',
        es: 'Foto eliminada',
        fr: 'Photo supprimée',
        de: 'Foto gelöscht',
        ja: '写真を削除しました',
      );

  String get frameConnectedBanner => _l6(
        en: 'Your Frame is Connected!',
        zh: '相框已连接！',
        es: '¡Tu marco está conectado!',
        fr: 'Votre cadre est connecté !',
        de: 'Dein Rahmen ist verbunden!',
        ja: 'フレームが接続されました！',
      );

  String get frameConnectedHint => _l6(
        en: 'Give your frame a name and start sending photos.',
        zh: '为相框命名，然后开始发送照片。',
        es: 'Ponle un nombre al marco y empieza a enviar fotos.',
        fr: 'Donnez un nom à votre cadre et envoyez des photos.',
        de: 'Gib dem Rahmen einen Namen und sende Fotos.',
        ja: 'フレームに名前を付けて写真の送信を始めましょう。',
      );

  String get frameNameHintExample => _l6(
        en: 'e.g. Living Room Frame',
        zh: '例如：客厅相框',
        es: 'p. ej. Marco del salón',
        fr: 'ex. Cadre salon',
        de: 'z. B. Wohnzimmer-Rahmen',
        ja: '例：リビングのフレーム',
      );

  String get nameYourFrameTitle => _l6(
        en: 'Name Your Frame',
        zh: '命名你的相框',
        es: 'Nombra tu marco',
        fr: 'Nommez votre cadre',
        de: 'Rahmen benennen',
        ja: 'フレームに名前を付ける',
      );

  String get saveFrameProfileFailed => _l6(
        en: 'Could not save frame profile. Try again.',
        zh: '无法保存相框配置。请重试。',
        es: 'No se pudo guardar el perfil del marco. Inténtelo de nuevo.',
        fr: 'Impossible d\'enregistrer le profil du cadre. Réessayez.',
        de: 'Rahmenprofil konnte nicht gespeichert werden. Erneut versuchen.',
        ja: 'フレームプロファイルを保存できませんでした。再試行してください。',
      );

  // ── Editor tool tab labels ──
  String get cropLabel => _l6(
        en: 'Crop', zh: '裁剪', es: 'Recortar', fr: 'Recadrer', de: 'Zuschneiden', ja: 'トリミング',
      );
  String get weatherLabel => _l6(
        en: 'Weather', zh: '天气', es: 'Clima', fr: 'Météo', de: 'Wetter', ja: '天気',
      );
  String get dateLabel => _l6(
        en: 'Date', zh: '日期', es: 'Fecha', fr: 'Date', de: 'Datum', ja: '日付',
      );
  String get textLabel => _l6(
        en: 'Text', zh: '文字', es: 'Texto', fr: 'Texte', de: 'Text', ja: 'テキスト',
      );
  String get stickerLabel => _l6(
        en: 'Sticker', zh: '贴纸', es: 'Pegatina', fr: 'Autocollant', de: 'Sticker', ja: 'ステッカー',
      );
  String get borderLabel => _l6(
        en: 'Border', zh: '边框', es: 'Borde', fr: 'Bordure', de: 'Rahmen', ja: '枠線',
      );

  // ── Editor UI labels ──
  String get einkPreviewLabel => _l6(
        en: 'E-ink Preview', zh: '电子墨水预览', es: 'Vista previa E-ink', fr: 'Aperçu E-ink',
        de: 'E-Ink Vorschau', ja: 'E-inkプレビュー',
      );
  String get deleteAction => _l6(
        en: 'Delete', zh: '删除', es: 'Eliminar', fr: 'Supprimer', de: 'Löschen', ja: '削除',
      );
  String get sendLabel => _l6(
        en: 'Send', zh: '发送', es: 'Enviar', fr: 'Envoyer', de: 'Senden', ja: '送信',
      );
  String sendPlaylistLabel(int count) => _l6(
        en: 'Send Playlist ($count)', zh: '发送播放列表 ($count)', es: 'Enviar lista ($count)',
        fr: 'Envoyer la liste ($count)', de: 'Playlist senden ($count)', ja: 'プレイリストを送信 ($count)',
      );

  // ── Crop panel ──
  String get cropFree => _l6(
        en: 'Free', zh: '自由', es: 'Libre', fr: 'Libre', de: 'Frei', ja: '自由',
      );
  String get cropOriginal => _l6(
        en: 'Original', zh: '原始', es: 'Original', fr: 'Original', de: 'Original', ja: 'オリジナル',
      );
  String get cropLeft90 => _l6(
        en: 'Left 90', zh: '左转90°', es: 'Izquierda 90', fr: 'Gauche 90', de: 'Links 90', ja: '左90°',
      );
  String get cropRight90 => _l6(
        en: 'Right 90', zh: '右转90°', es: 'Derecha 90', fr: 'Droite 90', de: 'Rechts 90', ja: '右90°',
      );
  String get cropFlipH => _l6(
        en: 'Flip H', zh: '水平翻转', es: 'Voltear H', fr: 'Retourner H', de: 'Horizontal spiegeln', ja: '左右反転',
      );
  String get cropFlipV => _l6(
        en: 'Flip V', zh: '垂直翻转', es: 'Voltear V', fr: 'Retourner V', de: 'Vertikal spiegeln', ja: '上下反転',
      );
  String get cropReset => _l6(
        en: 'Reset', zh: '重置', es: 'Restablecer', fr: 'Réinitialiser', de: 'Zurücksetzen', ja: 'リセット',
      );
  String get cropDragHint => _l6(
        en: 'Drag the photo to reposition. Frame stays 3:4.',
        zh: '拖动照片调整位置。相框保持 3:4。',
        es: 'Arrastre la foto para reposicionarla. El marco permanece 3:4.',
        fr: 'Faites glisser la photo pour la repositionner. Le cadre reste en 3:4.',
        de: 'Ziehen Sie das Foto, um es neu zu positionieren. Rahmen bleibt 3:4.',
        ja: '写真をドラッグして位置を調整。フレームは 3:4 のまま。',
      );

  // ── Weather panel ──
  String get weatherOverrideTemp => _l6(
        en: 'Override temperature (optional)',
        zh: '覆盖温度（可选）',
        es: 'Anular temperatura (opcional)',
        fr: 'Température personnalisée (optionnel)',
        de: 'Temperatur überschreiben (optional)',
        ja: '気温を上書き（オプション）',
      );
  String get weatherPermissionHint => _l6(
        en: 'Turns on location permission to load live weather for your device.',
        zh: '开启位置权限以加载设备的实时天气。',
        es: 'Active el permiso de ubicación para cargar el clima en vivo.',
        fr: 'Activez l\'autorisation de localisation pour charger la météo.',
        de: 'Standortberechtigung aktivieren, um Live-Wetter zu laden.',
        ja: '位置情報の許可をオンにしてデバイスの天気を表示します。',
      );

  // ── Date panel ──
  String get dateTimeHint => _l6(
        en: 'When on, the current date and time are added at the bottom of the frame.',
        zh: '开启后，当前日期和时间将显示在相框底部。',
        es: 'Cuando está activado, la fecha y hora actuales se añaden al pie del marco.',
        fr: 'Une fois activé, la date et l\'heure actuelles sont ajoutées en bas du cadre.',
        de: 'Wenn aktiviert, werden Datum und Uhrzeit am unteren Rand des Rahmens angezeigt.',
        ja: 'オンにすると、現在の日時がフレームの下部に追加されます。',
      );

  // ── Text panel ──
  String get textHint => _l6(
        en: 'Happy BirthDay',
        zh: '生日快乐',
        es: 'Feliz cumpleaños',
        fr: 'Bon anniversaire',
        de: 'Alles Gute zum Geburtstag',
        ja: 'お誕生日おめでとう',
      );
  String get textDragHint => _l6(
        en: 'Drag text on the photo to move it.',
        zh: '拖动照片上的文字以移动位置。',
        es: 'Arrastre el texto sobre la foto para moverlo.',
        fr: 'Faites glisser le texte sur la photo pour le déplacer.',
        de: 'Ziehen Sie den Text auf dem Foto, um ihn zu verschieben.',
        ja: '写真上のテキストをドラッグして移動します。',
      );

  // ── Sticker panel ──
  String get stickerHeart => _l6(
        en: 'Heart', zh: '心形', es: 'Corazón', fr: 'Cœur', de: 'Herz', ja: 'ハート',
      );
  String get stickerStar => _l6(
        en: 'Star', zh: '星星', es: 'Estrella', fr: 'Étoile', de: 'Stern', ja: '星',
      );
  String get stickerArrow => _l6(
        en: 'Arrow', zh: '箭头', es: 'Flecha', fr: 'Flèche', de: 'Pfeil', ja: '矢印',
      );
  String get stickerBubble => _l6(
        en: 'Bubble', zh: '气泡', es: 'Burbuja', fr: 'Bulle', de: 'Blase', ja: 'バブル',
      );
  String get stickerCircle => _l6(
        en: 'Circle', zh: '圆形', es: 'Círculo', fr: 'Cercle', de: 'Kreis', ja: '円',
      );
  String get stickerTriangle => _l6(
        en: 'Triangle', zh: '三角形', es: 'Triángulo', fr: 'Triangle', de: 'Dreieck', ja: '三角形',
      );
  String get stickerHoliday => _l6(
        en: 'Holiday', zh: '节日', es: 'Festivo', fr: 'Fête', de: 'Feiertag', ja: '祝日',
      );
  String get stickerSun => _l6(
        en: 'Sun', zh: '太阳', es: 'Sol', fr: 'Soleil', de: 'Sonne', ja: '太陽',
      );
  String get stickerDragHint => _l6(
        en: 'Drag on the photo to move the sticker.',
        zh: '在照片上拖动以移动贴纸。',
        es: 'Arrastre sobre la foto para mover la pegatina.',
        fr: 'Faites glisser sur la photo pour déplacer l\'autocollant.',
        de: 'Auf dem Foto ziehen, um den Sticker zu verschieben.',
        ja: '写真上でドラッグしてステッカーを移動します。',
      );

  // ── Border options ──
  String get borderNone => _l6(
        en: 'None', zh: '无', es: 'Ninguno', fr: 'Aucun', de: 'Kein', ja: 'なし',
      );
  String get borderThinBlack => _l6(
        en: 'Thin black', zh: '细黑', es: 'Negro fino', fr: 'Noir fin', de: 'Dünn schwarz', ja: '細い黒',
      );
  String get borderThickWhite => _l6(
        en: 'Thick white', zh: '粗白', es: 'Blanco grueso', fr: 'Blanc épais', de: 'Dick weiß', ja: '太い白',
      );
  String get borderPolaroid => _l6(
        en: 'Polaroid', zh: '宝丽来', es: 'Polaroid', fr: 'Polaroid', de: 'Polaroid', ja: 'ポラロイド',
      );
  String get borderFilmStrip => _l6(
        en: 'Film strip', zh: '胶片', es: 'Tira de película', fr: 'Pellicule', de: 'Filmstreifen', ja: 'フィルム',
      );
  String get borderRounded => _l6(
        en: 'Rounded', zh: '圆角', es: 'Redondeado', fr: 'Arrondi', de: 'Abgerundet', ja: '角丸',
      );
  String get borderDouble => _l6(
        en: 'Double', zh: '双线', es: 'Doble', fr: 'Double', de: 'Doppelt', ja: '二重線',
      );

  // ── General UI ──
  String get sendingToFrame => _l6(
        en: 'Sending to frame…',
        zh: '发送到相框…',
        es: 'Enviando al marco…',
        fr: 'Envoi au cadre…',
        de: 'Sende an Rahmen…',
        ja: 'フレームに送信中…',
      );
  String get couldNotSendPhoto => _l6(
        en: 'Could not send the photo. Try again.',
        zh: '无法发送照片。请重试。',
        es: 'No se pudo enviar la foto. Inténtelo de nuevo.',
        fr: 'Impossible d\'envoyer la photo. Réessayez.',
        de: 'Foto konnte nicht gesendet werden. Erneut versuchen.',
        ja: '写真を送信できませんでした。再試行してください。',
      );
  String get bluetoothOff => _l6(
        en: 'Bluetooth is off. Turn it on to scan.',
        zh: '蓝牙已关闭。请开启蓝牙以扫描。',
        es: 'Bluetooth está apagado. Enciéndalo para escanear.',
        fr: 'Bluetooth désactivé. Activez-le pour scanner.',
        de: 'Bluetooth ist aus. Einschalten, um zu scannen.',
        ja: 'Bluetoothがオフです。スキャンするにはオンにしてください。',
      );
  String get bluetoothOffTitle => _l6(
        en: 'Bluetooth Off',
        zh: '蓝牙已关闭',
        es: 'Bluetooth apagado',
        fr: 'Bluetooth désactivé',
        de: 'Bluetooth aus',
        ja: 'Bluetoothオフ',
      );
  String get idleLabel => _l6(
        en: 'Idle', zh: '空闲', es: 'Inactivo', fr: 'Inactif', de: 'Leerlauf', ja: '待機中',
      );
  String get scanningLabel => _l6(
        en: 'Scanning…', zh: '正在扫描…', es: 'Escaneando…', fr: 'Scan…', de: 'Scannen…', ja: 'スキャン中…',
      );
  String get receivingDataLabel => _l6(
        en: 'Receiving Data', zh: '接收数据中', es: 'Recibiendo datos', fr: 'Réception de données',
        de: 'Daten empfangen', ja: 'データ受信中',
      );
  String get connectedLabel => _l6(
        en: 'Connected', zh: '已连接', es: 'Conectado', fr: 'Connecté', de: 'Verbunden', ja: '接続済み',
      );
  String get bluetoothPermissionRequired => _l6(
        en: 'Bluetooth access required on iPhone',
        zh: 'iPhone 需要蓝牙权限',
        es: 'Se requiere acceso Bluetooth en iPhone',
        fr: 'Accès Bluetooth requis sur iPhone',
        de: 'Bluetooth-Zugriff auf iPhone erforderlich',
        ja: 'iPhoneでBluetoothアクセスが必要です',
      );
  String get bluetoothPermissionBody => _l6(
        en: 'iPhone needs Bluetooth permission so MyFrame can discover nearby frames. Open iPhone Settings, allow Bluetooth for MyFrame, then restart the scan.',
        zh: 'iPhone 需要蓝牙权限，以便 MyFrame 可以发现附近的相框。打开 iPhone 设置，允许 MyFrame 使用蓝牙，然后重新开始扫描。',
        es: 'El iPhone necesita permiso de Bluetooth para que MyFrame pueda descubrir marcos cercanos.',
        fr: 'L\'iPhone a besoin de l\'autorisation Bluetooth pour que MyFrame puisse découvrir les cadres à proximité.',
        de: 'Das iPhone benötigt die Bluetooth-Berechtigung, damit MyFrame nahegelegene Rahmen erkennen kann.',
        ja: 'MyFrameが近くのフレームを検出できるようにするには、iPhoneのBluetooth許可が必要です。',
      );
  String get openIphoneSettings => _l6(
        en: 'Open iPhone Settings',
        zh: '打开 iPhone 设置',
        es: 'Abrir ajustes del iPhone',
        fr: 'Ouvrir réglages iPhone',
        de: 'iPhone-Einstellungen öffnen',
        ja: 'iPhoneの設定を開く',
      );
  // ── WiFi Provision Screen ──
  String get wifiProvisionPhoneHint => _l6(
        en: 'Select a network (or type the SSID), enter the password, then Connect — credentials are sent to the frame over Bluetooth.',
        zh: '选择网络（或输入名称），填写密码后点连接 — 凭证通过蓝牙发送到相框。',
        es: 'Elige una red (o escribe el SSID), introduce la contraseña y Conectar — se envía al marco por Bluetooth.',
        fr: 'Choisissez un réseau (ou saisissez le SSID), mot de passe, puis Connecter — envoi au cadre via Bluetooth.',
        de: 'Netz wählen (oder SSID tippen), Passwort eingeben, Verbinden — Daten gehen per Bluetooth an den Rahmen.',
        ja: 'ネットワークを選ぶ（またはSSID入力）、パスワードを入れて接続 — 認証情報はBluetoothでフレームへ送信されます。',
      );
  String get wifiCurrentNetwork => _l6(
        en: 'Current Phone Wi‑Fi',
        zh: '当前手机 Wi‑Fi',
        es: 'Wi‑Fi del teléfono',
        fr: 'Wi‑Fi du téléphone',
        de: 'WLAN dieses Telefons',
        ja: 'このスマホのWi‑Fi',
      );
  String get wifiUseNetwork => _l6(
        en: 'Use',
        zh: '使用',
        es: 'Usar',
        fr: 'Utiliser',
        de: 'Verwenden',
        ja: '使用',
      );
  String get wifiPasswordRequiredLabel => _l6(
        en: 'Password required',
        zh: '需要密码',
        es: 'Contraseña requerida',
        fr: 'Mot de passe requis',
        de: 'Passwort erforderlich',
        ja: 'パスワードが必要',
      );
  String get wifiOpenNetworkLabel => _l6(
        en: 'Open network',
        zh: '开放网络',
        es: 'Red abierta',
        fr: 'Réseau ouvert',
        de: 'Offenes Netz',
        ja: 'オープンネットワーク',
      );
  String get wifiShowPassword => _l6(
        en: 'Show',
        zh: '显示',
        es: 'Mostrar',
        fr: 'Afficher',
        de: 'Anzeigen',
        ja: '表示',
      );
  String get wifiHidePassword => _l6(
        en: 'Hide',
        zh: '隐藏',
        es: 'Ocultar',
        fr: 'Masquer',
        de: 'Verstecken',
        ja: '非表示',
      );
  String get wifiRequiredForNetwork => _l6(
        en: 'Required for this network',
        zh: '该网络需要密码',
        es: 'Requerida para esta red',
        fr: 'Requis pour ce réseau',
        de: 'Für dieses Netz erforderlich',
        ja: 'このネットワークには必須',
      );
  String get wifiLeaveBlankHint => _l6(
        en: 'Leave blank for open networks.',
        zh: '开放网络可留空。',
        es: 'Déjalo en blanco para redes abiertas.',
        fr: 'Laissez vide pour les réseaux ouverts.',
        de: 'Bei offenen Netzen leer lassen.',
        ja: 'オープンネットワークの場合は空白のままにしてください。',
      );
  String get wifiConnectingSavedPassword => _l6(
        en: 'Connecting with saved password…',
        zh: '正在使用保存的密码连接…',
        es: 'Conectando con contraseña guardada…',
        fr: 'Connexion avec mot de passe enregistré…',
        de: 'Verbindung mit gespeichertem Passwort…',
        ja: '保存済みパスワードで接続中…',
      );
  String get wifiRequiresPasswordError => _l6(
        en: 'This network requires a password.',
        zh: '该网络需要密码。',
        es: 'Esta red requiere una contraseña.',
        fr: 'Ce réseau nécessite un mot de passe.',
        de: 'Dieses Netz erfordert ein Passwort.',
        ja: 'このネットワークにはパスワードが必要です。',
      );
  String get wifiConnectionFailed => _l6(
        en: 'Connection failed. Try again.',
        zh: '连接失败。请重试。',
        es: 'Conexión fallida. Inténtelo de nuevo.',
        fr: 'Échec de connexion. Réessayez.',
        de: 'Verbindung fehlgeschlagen. Erneut versuchen.',
        ja: '接続に失敗しました。再試行してください。',
      );
  String get wifiConnectFrameFailed => _l6(
        en: 'Could not connect the frame to Wi‑Fi. Try again.',
        zh: '无法将相框连接到 Wi‑Fi。请重试。',
        es: 'No se pudo conectar el marco al Wi‑Fi. Inténtelo de nuevo.',
        fr: 'Impossible de connecter le cadre au Wi‑Fi. Réessayez.',
        de: 'Rahmen konnte nicht mit WLAN verbunden werden. Erneut versuchen.',
        ja: 'フレームをWi‑Fiに接続できませんでした。再試行してください。',
      );
  String get wifiConnectedTo => _l6(
        en: 'Connected to',
        zh: '已连接至',
        es: 'Conectado a',
        fr: 'Connecté à',
        de: 'Verbunden mit',
        ja: '接続完了',
      );
  String get wifiConnectedLabel => _l6(
        en: 'Connected',
        zh: '已连接',
        es: 'Conectado',
        fr: 'Connecté',
        de: 'Verbunden',
        ja: '接続済み',
      );
  String get wifiConnectNowLabel => _l6(
        en: 'Connect now',
        zh: '立即连接',
        es: 'Conectar ahora',
        fr: 'Connecter maintenant',
        de: 'Jetzt verbinden',
        ja: '今すぐ接続',
      );
  String get statusLabel => _l6(
        en: 'Status',
        zh: '状态',
        es: 'Estado',
        fr: 'Statut',
        de: 'Status',
        ja: 'ステータス',
      );
  String get unknownLabel => _l6(
        en: 'Unknown',
        zh: '未知',
        es: 'Desconocido',
        fr: 'Inconnu',
        de: 'Unbekannt',
        ja: '不明',
      );

  String get frameOfflineLabel => _l6(
        en: 'Frame offline',
        zh: '相框离线',
        es: 'Marco sin conexión',
        fr: 'Cadre hors ligne',
        de: 'Rahmen offline',
        ja: 'フレームオフライン',
      );
  String get frameOfflineReconnectTitle => _l6(
        en: 'Frame offline',
        zh: '相框离线',
        es: 'Marco sin conexión',
        fr: 'Cadre hors ligne',
        de: 'Rahmen offline',
        ja: 'フレームオフライン',
      );
  String get frameOfflineReconnectBody => _l6(
        en: 'Please make sure your Frame is online and connected to Wi-Fi, or check your phone\'s Wi-Fi / connection, or try reconnecting your Frame.',
        zh: '请确保相框在线并已连接 Wi-Fi，或检查手机的 Wi-Fi / 网络连接，或尝试重新连接相框。',
        es: 'Asegúrate de que tu Frame esté en línea y conectado al Wi-Fi, o revisa el Wi-Fi / conexión de tu teléfono, o intenta reconectar tu Frame.',
        fr: 'Assurez-vous que votre Frame est en ligne et connecté au Wi-Fi, ou vérifiez le Wi-Fi / la connexion de votre téléphone, ou reconnectez votre Frame.',
        de: 'Stellen Sie sicher, dass Ihr Frame online und mit WLAN verbunden ist, prüfen Sie das WLAN / die Verbindung Ihres Telefons, oder verbinden Sie Ihren Frame erneut.',
        ja: 'フレームがオンラインでWi-Fiに接続されているか、電話のWi-Fi/接続を確認するか、フレームを再接続してください。',
      );

  /// Shown when Send is tapped while the target frame is offline.
  String get frameOfflineSendBlockedBody => _l6(
        en: 'Please make sure your Frame is online and connected to Wi-Fi, or check your phone\'s Wi-Fi / connection, or try reconnecting your Frame.',
        zh: '请确保相框在线并已连接 Wi-Fi，或检查手机的 Wi-Fi / 网络连接，或尝试重新连接相框。',
        es: 'Asegúrate de que tu Frame esté en línea y conectado al Wi-Fi, o revisa el Wi-Fi / conexión de tu teléfono, o intenta reconectar tu Frame.',
        fr: 'Assurez-vous que votre Frame est en ligne et connecté au Wi-Fi, ou vérifiez le Wi-Fi / la connexion de votre téléphone, ou reconnectez votre Frame.',
        de: 'Stellen Sie sicher, dass Ihr Frame online und mit WLAN verbunden ist, prüfen Sie das WLAN / die Verbindung Ihres Telefons, oder verbinden Sie Ihren Frame erneut.',
        ja: 'フレームがオンラインでWi-Fiに接続されているか、電話のWi-Fi/接続を確認するか、フレームを再接続してください。',
      );

  // —— Email Verification ——
  String get verifyEmailTitle => _l6(
    en: 'Verify your email',
    zh: '验证邮箱',
    es: 'Verifica tu correo',
    fr: 'Vérifiez votre e-mail',
    de: 'E-Mail bestätigen',
    ja: 'メールを確認',
  );
  String get verifyEmailSent => _l6(
    en: 'We sent a verification link to your email. Check your inbox and tap the link to complete registration.',
    zh: '我们已向您的邮箱发送验证链接。请查收并点击链接完成注册。',
    es: 'Enviamos un enlace de verificación a tu correo. Revisa tu bandeja de entrada.',
    fr: 'Un lien de vérification a été envoyé à votre e-mail. Consultez votre boîte de réception.',
    de: 'Wir haben einen Bestätigungslink an Ihre E-Mail gesendet. Prüfen Sie Ihren Posteingang.',
    ja: '確認リンクをメールに送信しました。受信箱を確認してリンクをタップしてください。',
  );
  String get verifyEmailSuccess => _l6(
    en: 'Email verified!',
    zh: '邮箱已验证！',
    es: '¡Correo verificado!',
    fr: 'E-mail vérifié !',
    de: 'E-Mail bestätigt!',
    ja: 'メール確認完了！',
  );
  String get verifyEmailSuccessBody => _l6(
    en: 'Your email has been verified. You can now log in to your account.',
    zh: '您的邮箱已验证，现在可以登录您的账户。',
    es: 'Tu correo ha sido verificado. Ya puedes iniciar sesión.',
    fr: 'Votre e-mail a été vérifié. Vous pouvez maintenant vous connecter.',
    de: 'Ihre E-Mail wurde bestätigt. Sie können sich jetzt anmelden.',
    ja: 'メールが確認されました。ログインできます。',
  );
  String get verifyEmailFailed => _l6(
    en: 'Verification failed',
    zh: '验证失败',
    es: 'Verificación fallida',
    fr: 'Échec de la vérification',
    de: 'Bestätigung fehlgeschlagen',
    ja: '確認に失敗しました',
  );
  String get verifyEmailFailedBody => _l6(
    en: 'The verification link is invalid or has expired. Try registering again.',
    zh: '验证链接无效或已过期，请重新注册。',
    es: 'El enlace de verificación no es válido o ha caducado. Intenta registrarte de nuevo.',
    fr: 'Le lien de vérification est invalide ou a expiré. Essayez de vous réinscrire.',
    de: 'Der Bestätigungslink ist ungültig oder abgelaufen. Versuchen Sie, sich erneut zu registrieren.',
    ja: '確認リンクが無効または期限切れです。もう一度登録してください。',
  );

  // —— Forgot / Reset Password ——
  String get forgotPasswordTitle => _l6(
    en: 'Forgot Password',
    zh: '忘记密码',
    es: 'Olvidé mi contraseña',
    fr: 'Mot de passe oublié',
    de: 'Passwort vergessen',
    ja: 'パスワードをお忘れですか',
  );
  String get forgotPasswordDescription => _l6(
    en: 'Enter your email address and we\'ll send you a link to reset your password.',
    zh: '输入您的邮箱，我们将向您发送重置密码的链接。',
    es: 'Introduce tu correo y te enviaremos un enlace para restablecer la contraseña.',
    fr: 'Saisissez votre e-mail et nous vous enverrons un lien pour réinitialiser votre mot de passe.',
    de: 'Geben Sie Ihre E-Mail-Adresse ein, wir senden Ihnen einen Link zum Zurücksetzen des Passworts.',
    ja: 'メールアドレスを入力してください。パスワードリセット用のリンクをお送りします。',
  );
  String get forgotPasswordLink => _l6(
    en: 'Forgot password?',
    zh: '忘记密码？',
    es: '¿Olvidaste tu contraseña?',
    fr: 'Mot de passe oublié ?',
    de: 'Passwort vergessen?',
    ja: 'パスワードをお忘れですか？',
  );
  String get forgotPasswordSend => _l6(
    en: 'Send Reset Link',
    zh: '发送重置链接',
    es: 'Enviar enlace',
    fr: 'Envoyer le lien',
    de: 'Link senden',
    ja: 'リセットリンクを送信',
  );
  String get forgotPasswordSent => _l6(
    en: 'If that email is registered, a reset link has been sent. Check your inbox.',
    zh: '如果该邮箱已注册，重置链接已发送。请查看收件箱。',
    es: 'Si el correo está registrado, se ha enviado un enlace. Revisa tu bandeja de entrada.',
    fr: 'Si cet e-mail est enregistré, un lien de réinitialisation a été envoyé. Vérifiez votre boîte de réception.',
    de: 'Falls die E-Mail registriert ist, wurde ein Link gesendet. Prüfen Sie Ihren Posteingang.',
    ja: '登録されたメールアドレスの場合、リセットリンクを送信しました。受信箱をご確認ください。',
  );
  String get forgotPasswordRateLimited => _l6(
    en: 'Too many attempts. Please wait a minute and try again.',
    zh: '尝试次数过多，请稍后再试。',
    es: 'Demasiados intentos. Espera un minuto e inténtalo de nuevo.',
    fr: 'Trop de tentatives. Veuillez patienter une minute.',
    de: 'Zu viele Versuche. Bitte warten Sie eine Minute.',
    ja: '試行回数が多すぎます。しばらく待ってからもう一度お試しください。',
  );
  String get resetPasswordTitle => _l6(
    en: 'Reset Password',
    zh: '重置密码',
    es: 'Restablecer contraseña',
    fr: 'Réinitialiser le mot de passe',
    de: 'Passwort zurücksetzen',
    ja: 'パスワードをリセット',
  );
  String get resetPasswordDescription => _l6(
    en: 'Enter your new password.',
    zh: '输入您的新密码。',
    es: 'Introduce tu nueva contraseña.',
    fr: 'Saisissez votre nouveau mot de passe.',
    de: 'Geben Sie Ihr neues Passwort ein.',
    ja: '新しいパスワードを入力してください。',
  );
  String get resetPasswordConfirm => _l6(
    en: 'Confirm password',
    zh: '确认密码',
    es: 'Confirmar contraseña',
    fr: 'Confirmer le mot de passe',
    de: 'Passwort bestätigen',
    ja: 'パスワードを確認',
  );
  String get resetPasswordSubmit => _l6(
    en: 'Reset Password',
    zh: '重置密码',
    es: 'Restablecer',
    fr: 'Réinitialiser',
    de: 'Zurücksetzen',
    ja: 'リセット',
  );
  String get resetPasswordSuccess => _l6(
    en: 'Your password has been reset successfully.',
    zh: '密码已成功重置。',
    es: 'Tu contraseña se ha restablecido correctamente.',
    fr: 'Votre mot de passe a été réinitialisé.',
    de: 'Ihr Passwort wurde erfolgreich zurückgesetzt.',
    ja: 'パスワードが正常にリセットされました。',
  );
  String get resetPasswordGoToLogin => _l6(
    en: 'Go to Login',
    zh: '前往登录',
    es: 'Ir a iniciar sesión',
    fr: 'Aller à la connexion',
    de: 'Zur Anmeldung',
    ja: 'ログインへ',
  );
  String get resetPasswordInvalidToken => _l6(
    en: 'This reset link is invalid or has expired.',
    zh: '此重置链接无效或已过期。',
    es: 'Este enlace de restablecimiento no es válido o ha caducado.',
    fr: 'Ce lien de réinitialisation est invalide ou a expiré.',
    de: 'Dieser Link ist ungültig oder abgelaufen.',
    ja: 'このリセットリンクは無効または期限切れです。',
  );
  String get resetPasswordExpired => _l6(
    en: 'This reset link has expired. Request a new one.',
    zh: '此重置链接已过期，请重新申请。',
    es: 'Este enlace ha caducado. Solicita uno nuevo.',
    fr: 'Ce lien a expiré. Demandez-en un nouveau.',
    de: 'Dieser Link ist abgelaufen. Fordern Sie einen neuen an.',
    ja: 'このリセットリンクは期限切れです。新しいものをリクエストしてください。',
  );
  String get resetPasswordAlreadyUsed => _l6(
    en: 'This reset link has already been used.',
    zh: '此重置链接已被使用。',
    es: 'Este enlace ya ha sido usado.',
    fr: 'Ce lien a déjà été utilisé.',
    de: 'Dieser Link wurde bereits verwendet.',
    ja: 'このリセットリンクは既に使用されています。',
  );
  String get resetPasswordMismatch => _l6(
    en: 'Passwords do not match.',
    zh: '两次输入的密码不一致。',
    es: 'Las contraseñas no coinciden.',
    fr: 'Les mots de passe ne correspondent pas.',
    de: 'Passwörter stimmen nicht überein.',
    ja: 'パスワードが一致しません。',
  );

  // —— Playlist & Color Grade ——
  String get scanningDevice => _l6(
    en: 'Scanning device...',
    zh: '正在扫描设备...',
    es: 'Escaneando dispositivo...',
    fr: 'Recherche de l\'appareil...',
    de: 'Gerät wird gesucht...',
    ja: 'デバイスをスキャン中...',
  );
  String get createPlaylistTitle => _l6(
    en: 'Create Playlist',
    zh: '创建播放列表',
    es: 'Crear lista de reproducción',
    fr: 'Créer une playlist',
    de: 'Wiedergabeliste erstellen',
    ja: 'プレイリストを作成',
  );
  String get displayInterval => _l6(
    en: 'Display Interval',
    zh: '显示间隔',
    es: 'Intervalo de visualización',
    fr: 'Intervalle d\'affichage',
    de: 'Anzeigeintervall',
    ja: '表示間隔',
  );
  String selectedPhotos(int n) => _l6(
    en: 'Selected Photos ($n/10)',
    zh: '已选择照片 ($n/10)',
    es: 'Fotos seleccionadas ($n/10)',
    fr: 'Photos sélectionnées ($n/10)',
    de: 'Ausgewählte Fotos ($n/10)',
    ja: '選択した写真 ($n/10)',
  );
  String get addMore => _l6(
    en: 'Add More',
    zh: '添加更多',
    es: 'Añadir más',
    fr: 'Ajouter plus',
    de: 'Mehr hinzufügen',
    ja: 'さらに追加',
  );
  String get sendPlaylistToFrame => _l6(
    en: 'Send Playlist to Frame',
    zh: '发送播放列表至相框',
    es: 'Enviar lista al marco',
    fr: 'Envoyer la playlist au cadre',
    de: 'Wiedergabeliste an Rahmen senden',
    ja: 'プレイリストをフレームに送信',
  );
  String editColorGrade(int current, int total) => _l6(
    en: 'Edit & color grade ($current/$total)',
    zh: '编辑调色 ($current/$total)',
    es: 'Editar y graduar color ($current/$total)',
    fr: 'Édition et étalonnage ($current/$total)',
    de: 'Bearbeiten & Farbkorrektur ($current/$total)',
    ja: '編集＆カラーグレード ($current/$total)',
  );
  String multiImageCasting(int current, int total) => _l6(
    en: 'Multi-Image Casting ($current/$total)',
    zh: '多图投屏 ($current/$total)',
    es: 'Transmisión múltiple ($current/$total)',
    fr: 'Diffusion multi-image ($current/$total)',
    de: 'Multi-Bild-Übertragung ($current/$total)',
    ja: 'マルチ画像キャスト ($current/$total)',
  );
  String get intervalLabel => _l6(
    en: 'Interval:',
    zh: '间隔:',
    es: 'Intervalo:',
    fr: 'Intervalle :',
    de: 'Intervall:',
    ja: '間隔:',
  );
  String get playbackMode => _l6(
    en: 'Playback Mode:',
    zh: '播放模式:',
    es: 'Modo de reproducción:',
    fr: 'Mode de lecture :',
    de: 'Wiedergabemodus:',
    ja: '再生モード:',
  );
  String get sequential => _l6(
    en: 'Sequential',
    zh: '顺序播放',
    es: 'Secuencial',
    fr: 'Séquentiel',
    de: 'Nacheinander',
    ja: '順次再生',
  );
  String get randomShuffle => _l6(
    en: 'Random',
    zh: '随机播放',
    es: 'Aleatorio',
    fr: 'Aléatoire',
    de: 'Zufällig',
    ja: 'ランダム',
  );
  String get durationLabel => _l6(
    en: 'Duration:',
    zh: '时长:',
    es: 'Duración:',
    fr: 'Durée :',
    de: 'Dauer:',
    ja: '期間:',
  );
  String get unlimited => _l6(
    en: 'Unlimited',
    zh: '不限时',
    es: 'Ilimitado',
    fr: 'Illimité',
    de: 'Unbegrenzt',
    ja: '無制限',
  );
  String totalLoopTime(String time) => _l6(
    en: 'Total loop time: $time',
    zh: '总循环时长: $time',
    es: 'Tiempo total de bucle: $time',
    fr: 'Temps de boucle total : $time',
    de: 'Gesamtschleifenzeit: $time',
    ja: '合計ループ時間: $time',
  );
  String sendPlaylistN(int n) => _l6(
    en: 'Send Playlist ($n)',
    zh: '发送播放列表 ($n)',
    es: 'Enviar lista ($n)',
    fr: 'Envoyer la playlist ($n)',
    de: 'Wiedergabeliste senden ($n)',
    ja: 'プレイリストを送信 ($n)',
  );
  String get playlistSent => _l6(
    en: 'Playlist sent successfully to frame!',
    zh: '播放列表已成功发送至相框！',
    es: '¡Lista enviada correctamente al marco!',
    fr: 'Playlist envoyée avec succès au cadre !',
    de: 'Wiedergabeliste erfolgreich an Rahmen gesendet!',
    ja: 'プレイリストをフレームに送信しました！',
  );
  String uploadFailed(String e) => _l6(
    en: 'Upload failed: $e',
    zh: '上传失败: $e',
    es: 'Error de carga: $e',
    fr: 'Échec du téléchargement : $e',
    de: 'Upload fehlgeschlagen: $e',
    ja: 'アップロード失敗: $e',
  );
  String get pleaseConnectFrame => _l6(
    en: 'Please connect a frame first.',
    zh: '请先连接相框。',
    es: 'Conecta un marco primero.',
    fr: 'Veuillez d\'abord connecter un cadre.',
    de: 'Bitte zuerst einen Rahmen verbinden.',
    ja: '先にフレームを接続してください。',
  );
  String get allUploadsFailed => _l6(
    en: 'All uploads failed. Please try again.',
    zh: '所有上传失败，请重试。',
    es: 'Todas las cargas fallaron. Intenta de nuevo.',
    fr: 'Tous les téléchargements ont échoué. Veuillez réessayer.',
    de: 'Alle Uploads fehlgeschlagen. Bitte versuchen Sie es erneut.',
    ja: 'すべてのアップロードに失敗しました。もう一度お試しください。',
  );
  String get myNewPlaylist => _l6(
    en: 'My New Playlist',
    zh: '我的新播放列表',
    es: 'Mi nueva lista',
    fr: 'Ma nouvelle playlist',
    de: 'Meine neue Wiedergabeliste',
    ja: 'マイ新しいプレイリスト',
  );
  String get oneMinute => _l6(
    en: '1 Minute',
    zh: '1 分钟',
    es: '1 minuto',
    fr: '1 minute',
    de: '1 Minute',
    ja: '1分',
  );
  String nMinutes(int n) => _l6(
    en: '$n Minutes',
    zh: '$n 分钟',
    es: '$n minutos',
    fr: '$n minutes',
    de: '$n Minuten',
    ja: '$n分',
  );
  String get oneHour => _l6(
    en: '1 Hour',
    zh: '1 小时',
    es: '1 hora',
    fr: '1 heure',
    de: '1 Stunde',
    ja: '1時間',
  );

  // —— Device Details ——
  String get deviceDetails => _l6(
    en: 'Device Details',
    zh: '设备详情',
    es: 'Detalles del dispositivo',
    fr: 'Détails de l\'appareil',
    de: 'Gerätedetails',
    ja: 'デバイス詳細',
  );
  String get statusSection => _l6(
    en: 'Status',
    zh: '状态',
    es: 'Estado',
    fr: 'Statut',
    de: 'Status',
    ja: 'ステータス',
  );
  String get batteryLabel => _l6(
    en: 'Battery',
    zh: '电池',
    es: 'Batería',
    fr: 'Batterie',
    de: 'Akku',
    ja: 'バッテリー',
  );
  String get storageLabel => _l6(
    en: 'Storage',
    zh: '存储',
    es: 'Almacenamiento',
    fr: 'Stockage',
    de: 'Speicher',
    ja: 'ストレージ',
  );
  String get deviceInfoSection => _l6(
    en: 'Device Info',
    zh: '设备信息',
    es: 'Información del dispositivo',
    fr: 'Infos de l\'appareil',
    de: 'Geräteinfo',
    ja: 'デバイス情報',
  );
  String get macLabel => _l6(
    en: 'MAC',
    zh: 'MAC',
    es: 'MAC',
    fr: 'MAC',
    de: 'MAC',
    ja: 'MAC',
  );
  String get firmwareVersionLabel => _l6(
    en: 'Firmware Version',
    zh: '固件版本',
    es: 'Versión de firmware',
    fr: 'Version du firmware',
    de: 'Firmware-Version',
    ja: 'ファームウェアバージョン',
  );
  String get networkNameLabel => _l6(
    en: 'Network name',
    zh: '网络名称',
    es: 'Nombre de red',
    fr: 'Nom du réseau',
    de: 'Netzwerkname',
    ja: 'ネットワーク名',
  );
  String get lastSeenLabel => _l6(
    en: 'Last Seen',
    zh: '最后在线',
    es: 'Última vez',
    fr: 'Dernière vue',
    de: 'Zuletzt gesehen',
    ja: '最終確認',
  );
  String get wifiSignalLabel => _l6(
    en: 'WiFi Signal',
    zh: 'WiFi 信号',
    es: 'Señal WiFi',
    fr: 'Signal WiFi',
    de: 'WiFi-Signal',
    ja: 'WiFi信号',
  );
  String get disconnected => _l6(
    en: 'Disconnected',
    zh: '未连接',
    es: 'Desconectado',
    fr: 'Déconnecté',
    de: 'Getrennt',
    ja: '切断済み',
  );
  String get onlineStatus => _l6(
    en: 'Online',
    zh: '在线',
    es: 'En línea',
    fr: 'En ligne',
    de: 'Online',
    ja: 'オンライン',
  );
  String get offlineStatus => _l6(
    en: 'Offline',
    zh: '离线',
    es: 'Fuera de línea',
    fr: 'Hors ligne',
    de: 'Offline',
    ja: 'オフライン',
  );
  String get deleteDevice => _l6(
    en: 'Delete Device',
    zh: '删除设备',
    es: 'Eliminar dispositivo',
    fr: 'Supprimer l\'appareil',
    de: 'Gerät löschen',
    ja: 'デバイスを削除',
  );
  String deleteDeviceConfirm(String name) => _l6(
    en: 'Are you sure you want to remove $name from your account?',
    zh: '确定要从您的账户中移除 $name 吗？',
    es: '¿Seguro que quieres eliminar $name de tu cuenta?',
    fr: 'Voulez-vous vraiment supprimer $name de votre compte ?',
    de: 'Möchten Sie $name wirklich von Ihrem Konto entfernen?',
    ja: '$name をアカウントから削除してもよろしいですか？',
  );
  String get deleteButton => _l6(
    en: 'Delete',
    zh: '删除',
    es: 'Eliminar',
    fr: 'Supprimer',
    de: 'Löschen',
    ja: '削除',
  );

  // —— Send Screen ——
  String get cameraPermissionDenied => _l6(
    en: 'Camera permission denied. Use Gallery below or enable Camera in Settings.',
    zh: '相机权限被拒绝。请使用下方相册或在设置中启用相机。',
    es: 'Permiso de cámara denegado. Usa la galería o habilita la cámara en Ajustes.',
    fr: 'Permission caméra refusée. Utilisez la galerie ou activez la caméra dans Paramètres.',
    de: 'Kamera-Berechtigung verweigert. Verwenden Sie die Galerie oder aktivieren Sie die Kamera in den Einstellungen.',
    ja: 'カメラの許可が拒否されました。ギャラリーを使用するか、設定でカメラを有効にしてください。',
  );
  String get settingsLabel => _l6(
    en: 'Settings',
    zh: '设置',
    es: 'Ajustes',
    fr: 'Paramètres',
    de: 'Einstellungen',
    ja: '設定',
  );
  String get couldNotCreateLink => _l6(
    en: 'Could not create upload link. Try again.',
    zh: '无法创建上传链接，请重试。',
    es: 'No se pudo crear el enlace. Intenta de nuevo.',
    fr: 'Impossible de créer le lien. Réessayez.',
    de: 'Link konnte nicht erstellt werden. Versuchen Sie es erneut.',
    ja: 'アップロードリンクを作成できませんでした。もう一度お試しください。',
  );
  String get cameraPermissionHelp => _l6(
    en: 'Allow Camera permission (Settings ▸ Apps ▸ MyFrame ▸ Permissions). Or use Gallery instead.',
    zh: '允许相机权限（设置 ▸ 应用 ▸ MyFrame ▸ 权限），或使用相册。',
    es: 'Permite la cámara (Ajustes ▸ Apps ▸ MyFrame ▸ Permisos) o usa la galería.',
    fr: 'Autorisez la caméra (Paramètres ▸ Apps ▸ MyFrame ▸ Permissions) ou utilisez la galerie.',
    de: 'Kameraberechtigung erlauben (Einstellungen ▸ Apps ▸ MyFrame ▸ Berechtigungen) oder Galerie verwenden.',
    ja: 'カメラの許可を有効にする（設定 ▸ アプリ ▸ MyFrame ▸ 権限）か、ギャラリーをご利用ください。',
  );
  String get allowPhotosPermission => _l6(
    en: 'Allow Photos/Videos permission to pick images.',
    zh: '请允许访问相册以选择图片。',
    es: 'Permite el acceso a Fotos/Videos para seleccionar imágenes.',
    fr: 'Autorisez l\'accès aux Photos/Vidéos pour choisir des images.',
    de: 'Erlauben Sie Foto-/Videozugriff, um Bilder auszuwählen.',
    ja: '画像を選択するには写真/ビデオの許可を有効にしてください。',
  );

  // —— Image Editor ——
  String get sendFailedRetry => _l6(
    en: 'Image sending failed. Please try again. Make sure WiFi is connected to your frame, or delete the device and resend.',
    zh: '图片发送失败，请重试。确保相框已连接 WiFi，或删除设备后重新发送。',
    es: 'Error al enviar la imagen. Verifica la conexión WiFi o elimina el dispositivo y reenvía.',
    fr: 'Échec de l\'envoi. Vérifiez le WiFi ou supprimez l\'appareil et renvoyez.',
    de: 'Senden fehlgeschlagen. Stellen Sie sicher, dass der Rahmen mit WiFi verbunden ist, oder löschen Sie das Gerät und senden Sie erneut.',
    ja: '画像の送信に失敗しました。フレームがWiFiに接続されていることを確認するか、デバイスを削除して再送信してください。',
  );
  String get connectFrameToSend => _l6(
    en: 'Connect your frame to send this photo…',
    zh: '请连接相框以发送此照片…',
    es: 'Conecta tu marco para enviar esta foto…',
    fr: 'Connectez votre cadre pour envoyer cette photo…',
    de: 'Verbinden Sie Ihren Rahmen, um dieses Foto zu senden…',
    ja: 'この写真を送信するにはフレームを接続してください…',
  );
  String get frameConnectionCancelled => _l6(
    en: 'Frame connection cancelled.',
    zh: '相框连接已取消。',
    es: 'Conexión cancelada.',
    fr: 'Connexion annulée.',
    de: 'Rahmenverbindung abgebrochen.',
    ja: 'フレーム接続がキャンセルされました。',
  );
  String get noFramePaired => _l6(
    en: 'No frame paired yet. Scan a frame to continue.',
    zh: '尚未配对相框。请扫描相框以继续。',
    es: 'No hay marco emparejado. Escanea un marco para continuar.',
    fr: 'Aucun cadre appairé. Scannez un cadre pour continuer.',
    de: 'Kein Rahmen gekoppelt. Scannen Sie einen Rahmen, um fortzufahren.',
    ja: 'フレームがペアリングされていません。フレームをスキャンしてください。',
  );
  String get iosBleOnlyHint => _l6(
    en: 'This iPhone pairing has only an iOS Bluetooth UUID, not the frame display ID. Scan the frame pairing QR once, then try upload again.',
    zh: '此 iPhone 仅配对到蓝牙 UUID，未获取相框显示 ID。请扫描相框配对二维码，然后重试上传。',
    es: 'Este iPhone tiene solo un UUID Bluetooth. Escanea el QR de emparejamiento e intenta de nuevo.',
    fr: 'Cet iPhone n\'a qu\'un UUID Bluetooth. Scannez le QR d\'appairage et réessayez.',
    de: 'Dieses iPhone hat nur eine Bluetooth-UUID. Scannen Sie den QR-Code zur Kopplung und versuchen Sie es erneut.',
    ja: 'このiPhoneはBluetooth UUIDのみを持っています。フレームのペアリングQRをスキャンしてから再試行してください。',
  );
  String get completeWifiBeforeSending => _l6(
    en: 'Complete Wi‑Fi setup before sending photos…',
    zh: '请先完成 WiFi 设置再发送照片…',
    es: 'Completa la configuración WiFi antes de enviar…',
    fr: 'Terminez la configuration WiFi avant d\'envoyer…',
    de: 'Schließen Sie die Wi‑Fi-Einrichtung ab, bevor Sie Fotos senden…',
    ja: '写真を送信する前にWiFi設定を完了してください…',
  );
  String get preparingImage => _l6(
    en: 'Preparing image for frame…',
    zh: '正在为相框准备图片…',
    es: 'Preparando imagen para el marco…',
    fr: 'Préparation de l\'image pour le cadre…',
    de: 'Bild wird für den Rahmen vorbereitet…',
    ja: 'フレーム用に画像を準備中…',
  );
  String get exportFailed => _l6(
    en: 'Export failed. Try again.',
    zh: '导出失败，请重试。',
    es: 'Error de exportación. Intenta de nuevo.',
    fr: 'Échec de l\'export. Réessayez.',
    de: 'Export fehlgeschlagen. Versuchen Sie es erneut.',
    ja: 'エクスポートに失敗しました。もう一度お試しください。',
  );
  String get backTooltip => _l6(
    en: 'Back',
    zh: '返回',
    es: 'Atrás',
    fr: 'Retour',
    de: 'Zurück',
    ja: '戻る',
  );
  String get originalLabel => _l6(
    en: 'Original',
    zh: '原图',
    es: 'Original',
    fr: 'Original',
    de: 'Original',
    ja: 'オリジナル',
  );
  String get contrastLabel => _l6(
    en: 'Contrast',
    zh: '对比度',
    es: 'Contraste',
    fr: 'Contraste',
    de: 'Kontrast',
    ja: 'コントラスト',
  );
  String get vividLabel => _l6(
    en: 'Vivid',
    zh: '鲜艳',
    es: 'Vívido',
    fr: 'Vif',
    de: 'Lebendig',
    ja: 'ビビッド',
  );
  String get vintageLabel => _l6(
    en: 'Vintage',
    zh: '复古',
    es: 'Vintage',
    fr: 'Vintage',
    de: 'Vintage',
    ja: 'ビンテージ',
  );
  String get coolLabel => _l6(
    en: 'Cool',
    zh: '冷色',
    es: 'Frío',
    fr: 'Froid',
    de: 'Kühl',
    ja: 'クール',
  );
  String get bwLabel => _l6(
    en: 'B/W',
    zh: '黑白',
    es: 'ByN',
    fr: 'N&B',
    de: 'S/W',
    ja: 'モノクロ',
  );
  String get adjustmentsLabel => _l6(
    en: 'Adjustments',
    zh: '调整',
    es: 'Ajustes',
    fr: 'Réglages',
    de: 'Anpassungen',
    ja: '調整',
  );
  String get brightnessLabel => _l6(
    en: 'Brightness',
    zh: '亮度',
    es: 'Brillo',
    fr: 'Luminosité',
    de: 'Helligkeit',
    ja: '明るさ',
  );
  String get saturationLabel => _l6(
    en: 'Saturation',
    zh: '饱和度',
    es: 'Saturación',
    fr: 'Saturation',
    de: 'Sättigung',
    ja: '彩度',
  );
  String get dateHelperText => _l6(
    en: 'When on, the current date and time are added at the bottom of the frame.',
    zh: '开启后，当前日期和时间将显示在相框底部。',
    es: 'Cuando está activado, la fecha y hora se añaden en la parte inferior.',
    fr: 'Quand activé, la date et l\'heure s\'affichent en bas du cadre.',
    de: 'Wenn aktiviert, werden Datum und Uhrzeit am unteren Rand des Rahmens angezeigt.',
    ja: 'オンにすると、現在の日時がフレームの下部に追加されます。',
  );
  String get happyBirthdayHint => _l6(
    en: 'Happy BirthDay',
    zh: '生日快乐',
    es: 'Feliz Cumpleaños',
    fr: 'Joyeux Anniversaire',
    de: 'Alles Gute zum Geburtstag',
    ja: 'お誕生日おめでとう',
  );
  String get addText => _l6(
    en: 'Add Text',
    zh: '添加文字',
    es: 'Añadir texto',
    fr: 'Ajouter du texte',
    de: 'Text hinzufügen',
    ja: 'テキストを追加',
  );
  String get previewHint => _l6(
    en: 'Preview uses black, white, yellow, red, blue, and green only.',
    zh: '预览仅使用黑、白、黄、红、蓝、绿色。',
    es: 'La vista previa usa solo negro, blanco, amarillo, rojo, azul y verde.',
    fr: 'L\'aperçu utilise uniquement le noir, blanc, jaune, rouge, bleu et vert.',
    de: 'Die Vorschau verwendet nur Schwarz, Weiß, Gelb, Rot, Blau und Grün.',
    ja: 'プレビューでは黒、白、黄、赤、青、緑のみを使用します。',
  );
  String get closeLabel => _l6(
    en: 'Close',
    zh: '关闭',
    es: 'Cerrar',
    fr: 'Fermer',
    de: 'Schließen',
    ja: '閉じる',
  );
  String get previewOfEditedPhoto => _l6(
    en: 'Preview of your edited photo.',
    zh: '编辑后照片预览。',
    es: 'Vista previa de la foto editada.',
    fr: 'Aperçu de votre photo éditée.',
    de: 'Vorschau Ihres bearbeiteten Fotos.',
    ja: '編集した写真のプレビュー。',
  );
  String get sentSuccessfully => _l6(
    en: 'Sent Successfully!',
    zh: '发送成功！',
    es: '¡Enviado con éxito!',
    fr: 'Envoyé avec succès !',
    de: 'Erfolgreich gesendet!',
    ja: '送信成功！',
  );
  String toFrame(String name) => _l6(
    en: 'to $name',
    zh: '至 $name',
    es: 'a $name',
    fr: 'à $name',
    de: 'an $name',
    ja: '$name へ',
  );
  String get frameIsRefreshing => _l6(
    en: 'Frame is refreshing…',
    zh: '相框正在刷新…',
    es: 'El marco se está actualizando…',
    fr: 'Le cadre se rafraîchit…',
    de: 'Rahmen wird aktualisiert…',
    ja: 'フレームを更新中…',
  );
  String get intervalPrefix => _l6(
    en: 'Interval: ',
    zh: '间隔: ',
    es: 'Intervalo: ',
    fr: 'Intervalle : ',
    de: 'Intervall: ',
    ja: '間隔: ',
  );
  String get castActivity => _l6(
    en: 'Cast activity',
    zh: '投屏活动',
    es: 'Actividad de transmisión',
    fr: 'Activité de diffusion',
    de: 'Übertragungsaktivität',
    ja: 'キャストアクティビティ',
  );
  String get copyLog => _l6(
    en: 'Copy log',
    zh: '复制日志',
    es: 'Copiar registro',
    fr: 'Copier le journal',
    de: 'Protokoll kopieren',
    ja: 'ログをコピー',
  );
  String get frameCast => _l6(
    en: 'Frame cast',
    zh: '相框投屏',
    es: 'Transmisión al marco',
    fr: 'Diffusion vers le cadre',
    de: 'Rahmenübertragung',
    ja: 'フレームキャスト',
  );
  String slideshowPublishStatus(int code, String body) => _l6(
    en: 'Slideshow publish returned $code. Playlist will not auto-advance. $body',
    zh: '幻灯片发布返回 $code。播放列表将不会自动轮播。$body',
    es: 'La publicación devolvió $code. La lista no avanzará automáticamente. $body',
    fr: 'La publication a renvoyé $code. La liste n\'avancera pas automatiquement. $body',
    de: 'Veröffentlichung gab $code zurück. Wiedergabeliste wird nicht automatisch fortgesetzt. $body',
    ja: 'スライドショーの公開が $code を返しました。プレイリストは自動的に進みません。$body',
  );
  String slideshowPublishError(String e) => _l6(
    en: 'Slideshow publish error: $e',
    zh: '幻灯片发布错误: $e',
    es: 'Error de publicación: $e',
    fr: 'Erreur de publication : $e',
    de: 'Fehler bei der Veröffentlichung: $e',
    ja: 'スライドショー公開エラー: $e',
  );
}

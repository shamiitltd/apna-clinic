enum AppEnvironment { development, staging, production }

class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final String version;
  final String googleClientId;
  final String appBaseUrl;
  final bool enableSyntheticDemoData;
  final List<String> googleOAuthScopes;
  final bool useMockAuth;

  // Firebase Configuration & Platform Account
  final String firebaseApiKey;
  final String firebaseAuthDomain;
  final String firebaseProjectId;
  final String firebaseStorageBucket;
  final String firebaseMessagingSenderId;
  final String firebaseAppId;
  final String accountRegistrationUrl;

  const AppConfig({
    required this.environment,
    required this.appName,
    required this.version,
    required this.googleClientId,
    required this.appBaseUrl,
    this.enableSyntheticDemoData = false,
    this.googleOAuthScopes = const [
      'openid',
      'email',
      'profile',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets',
    ],
    this.useMockAuth = false,
    this.firebaseApiKey = '',
    this.firebaseAuthDomain = '',
    this.firebaseProjectId = '',
    this.firebaseStorageBucket = '',
    this.firebaseMessagingSenderId = '',
    this.firebaseAppId = '',
    this.accountRegistrationUrl = 'https://apnaclinic.in/register',
  });

  static AppConfig current = const AppConfig(
    environment: AppEnvironment.development,
    appName: 'Apna Clinic',
    version: '1.0.0',
    googleClientId: String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: ''),
    appBaseUrl: String.fromEnvironment('APP_BASE_URL', defaultValue: 'http://localhost:8080'),
    enableSyntheticDemoData: false,
    googleOAuthScopes: [
      'openid',
      'email',
      'profile',
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets',
    ],
    useMockAuth: false,
    firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY', defaultValue: ''),
    firebaseAuthDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'apna-clinic-96541.firebaseapp.com',
    ),
    firebaseProjectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'apna-clinic-96541',
    ),
    firebaseStorageBucket: String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
      defaultValue: 'apna-clinic-96541.firebasestorage.app',
    ),
    firebaseMessagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '543911993529',
    ),
    firebaseAppId: String.fromEnvironment(
      'FIREBASE_APP_ID',
      defaultValue: '1:543911993529:web:aee5950d6f96b28f1c3b68',
    ),
    accountRegistrationUrl: String.fromEnvironment(
      'ACCOUNT_REGISTRATION_URL',
      defaultValue: 'https://apnaclinic.in/register',
    ),
  );

  bool get isProduction => environment == AppEnvironment.production;
  bool get isDevelopment => environment == AppEnvironment.development;
  bool get hasFirebaseConfig => firebaseApiKey.isNotEmpty && firebaseProjectId.isNotEmpty;

  /// Parses .env format text into a key-value map
  static Map<String, String> parseEnv(String content) {
    final result = <String, String>{};
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final idx = trimmed.indexOf('=');
      if (idx > 0) {
        final key = trimmed.substring(0, idx).trim();
        var val = trimmed.substring(idx + 1).trim();
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        result[key] = val;
      }
    }
    return result;
  }

  /// Creates an AppConfig initialized from an environment map (e.g. from .env)
  static AppConfig fromEnvMap(Map<String, String> env) {
    final envName = env['APP_ENV']?.toLowerCase();
    final appEnv = envName == 'production'
        ? AppEnvironment.production
        : envName == 'staging'
            ? AppEnvironment.staging
            : AppEnvironment.development;

    return AppConfig(
      environment: appEnv,
      appName: env['APP_NAME'] ?? current.appName,
      version: current.version,
      googleClientId: env['GOOGLE_CLIENT_ID'] ?? current.googleClientId,
      appBaseUrl: env['APP_BASE_URL'] ?? current.appBaseUrl,
      enableSyntheticDemoData: env['DEMO_DATA'] != 'false',
      googleOAuthScopes: current.googleOAuthScopes,
      useMockAuth: env['USE_MOCK_AUTH'] == 'true',
      firebaseApiKey: env['FIREBASE_API_KEY'] ?? current.firebaseApiKey,
      firebaseAuthDomain: env['FIREBASE_AUTH_DOMAIN'] ?? current.firebaseAuthDomain,
      firebaseProjectId: env['FIREBASE_PROJECT_ID'] ?? current.firebaseProjectId,
      firebaseStorageBucket: env['FIREBASE_STORAGE_BUCKET'] ?? current.firebaseStorageBucket,
      firebaseMessagingSenderId: env['FIREBASE_MESSAGING_SENDER_ID'] ?? current.firebaseMessagingSenderId,
      firebaseAppId: env['FIREBASE_APP_ID'] ?? current.firebaseAppId,
      accountRegistrationUrl: env['ACCOUNT_REGISTRATION_URL'] ?? current.accountRegistrationUrl,
    );
  }

  /// Initializes current AppConfig from an environment map
  static void initializeFromEnv(Map<String, String> env) {
    current = fromEnvMap(env);
  }

  AppConfig copyWith({
    AppEnvironment? environment,
    String? appName,
    String? version,
    String? googleClientId,
    String? appBaseUrl,
    bool? enableSyntheticDemoData,
    List<String>? googleOAuthScopes,
    bool? useMockAuth,
    String? firebaseApiKey,
    String? firebaseAuthDomain,
    String? firebaseProjectId,
    String? firebaseStorageBucket,
    String? firebaseMessagingSenderId,
    String? firebaseAppId,
    String? accountRegistrationUrl,
  }) {
    return AppConfig(
      environment: environment ?? this.environment,
      appName: appName ?? this.appName,
      version: version ?? this.version,
      googleClientId: googleClientId ?? this.googleClientId,
      appBaseUrl: appBaseUrl ?? this.appBaseUrl,
      enableSyntheticDemoData:
          enableSyntheticDemoData ?? this.enableSyntheticDemoData,
      googleOAuthScopes: googleOAuthScopes ?? this.googleOAuthScopes,
      useMockAuth: useMockAuth ?? this.useMockAuth,
      firebaseApiKey: firebaseApiKey ?? this.firebaseApiKey,
      firebaseAuthDomain: firebaseAuthDomain ?? this.firebaseAuthDomain,
      firebaseProjectId: firebaseProjectId ?? this.firebaseProjectId,
      firebaseStorageBucket: firebaseStorageBucket ?? this.firebaseStorageBucket,
      firebaseMessagingSenderId:
          firebaseMessagingSenderId ?? this.firebaseMessagingSenderId,
      firebaseAppId: firebaseAppId ?? this.firebaseAppId,
      accountRegistrationUrl:
          accountRegistrationUrl ?? this.accountRegistrationUrl,
    );
  }
}

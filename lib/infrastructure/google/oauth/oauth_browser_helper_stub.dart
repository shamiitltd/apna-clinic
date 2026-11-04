// Apna Clinic - OAuth Browser Helper (VM / Native / Test Stub)

class OAuthCallbackData {
  final String? code;
  final String? accessToken;
  final String? idToken;
  final String? tokenType;
  final int? expiresIn;
  final String? state;
  final String? error;
  final String? errorDescription;

  const OAuthCallbackData({
    this.code,
    this.accessToken,
    this.idToken,
    this.tokenType,
    this.expiresIn,
    this.state,
    this.error,
    this.errorDescription,
  });

  bool get hasToken => accessToken != null && accessToken!.isNotEmpty;
  bool get hasCode => code != null && code!.isNotEmpty;
  bool get hasError => error != null && error!.isNotEmpty;
  bool get isEmpty => !hasToken && !hasCode && !hasError;
}

class OAuthBrowserHelper {
  static void launchAuthUrl(String url) {
    // No-op in test/stub environment
  }

  static String getCurrentOrigin() => '';

  static OAuthCallbackData getCallbackData() {
    return const OAuthCallbackData();
  }

  static String? getRedirectCode() {
    return null;
  }

  static String? getRedirectState() {
    return null;
  }

  static String? getRedirectAccessToken() {
    return null;
  }

  static String? getRedirectIdToken() {
    return null;
  }

  static void clearUrlParams() {
    // No-op in test/stub environment
  }
}

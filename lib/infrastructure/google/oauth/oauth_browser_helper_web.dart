// Apna Clinic - OAuth Browser Helper (Web Implementation)
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
  /// Navigates the browser window to the Google OAuth authorization URL
  static void launchAuthUrl(String url) {
    html.window.location.href = url;
  }

  /// Returns the current browser origin (e.g. http://localhost:8080)
  static String getCurrentOrigin() {
    try {
      final origin = html.window.location.origin;
      if (origin.isNotEmpty && origin != 'null') {
        return origin;
      }
    } catch (_) {}
    return '';
  }

  static Map<String, String> _extractParams(String raw) {
    final map = <String, String>{};
    if (raw.isEmpty) return map;

    final segments = raw.split(RegExp(r'[;&]'));
    for (final seg in segments) {
      var item = seg.trim();
      final qIdx = item.indexOf('?');
      if (qIdx >= 0) {
        item = item.substring(qIdx + 1);
      }
      final hIdx = item.indexOf('#');
      if (hIdx >= 0) {
        item = item.substring(hIdx + 1);
      }
      final eqIdx = item.indexOf('=');
      if (eqIdx > 0) {
        try {
          var key = Uri.decodeQueryComponent(item.substring(0, eqIdx).trim());
          final val = Uri.decodeQueryComponent(item.substring(eqIdx + 1).trim());
          // Strip any leading routing artifacts such as '/', '#', '?'
          while (key.startsWith('/') || key.startsWith('#') || key.startsWith('?') || key.startsWith('!')) {
            key = key.substring(1);
          }
          if (key.isNotEmpty && val.isNotEmpty) {
            map[key] = val;
          }
        } catch (_) {}
      }
    }
    return map;
  }

  /// Extracts all OAuth callback parameters returned in query or fragment
  static OAuthCallbackData getCallbackData() {
    try {
      final loc = html.window.location;
      final params = <String, String>{};

      final search = loc.search;
      if (search != null && search.isNotEmpty) {
        params.addAll(_extractParams(search));
      }
      final hash = loc.hash;
      if (hash.isNotEmpty) {
        params.addAll(_extractParams(hash));
      }
      final href = loc.href;
      if (params.isEmpty && href.isNotEmpty) {
        params.addAll(_extractParams(href));
      }

      final expiresInStr = params['expires_in'];
      final expiresIn = expiresInStr != null ? int.tryParse(expiresInStr) : null;

      return OAuthCallbackData(
        code: params['code'],
        accessToken: params['access_token'],
        idToken: params['id_token'],
        tokenType: params['token_type'],
        expiresIn: expiresIn,
        state: params['state'],
        error: params['error'],
        errorDescription: params['error_description'],
      );
    } catch (_) {
      return const OAuthCallbackData();
    }
  }

  /// Extracts the OAuth authorization code returned in the URL
  static String? getRedirectCode() => getCallbackData().code;

  /// Extracts the OAuth state token returned in the URL
  static String? getRedirectState() => getCallbackData().state;

  /// Extracts direct access token returned in URL fragment
  static String? getRedirectAccessToken() => getCallbackData().accessToken;

  /// Extracts direct ID token returned in URL fragment
  static String? getRedirectIdToken() => getCallbackData().idToken;

  /// Strips OAuth callback parameters from browser address bar history to prevent replay
  static void clearUrlParams() {
    try {
      final loc = html.window.location;
      final cleanUrl = '${loc.protocol}//${loc.host}${loc.pathname}#/';
      html.window.history.replaceState(null, '', cleanUrl);
    } catch (_) {}
  }
}

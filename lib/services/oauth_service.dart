import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/oauth_config.dart';

/// Thrown when a refresh token has stopped working — expected roughly every
/// 7 days per account while the OAuth consent screen is in Testing mode.
/// The caller's job is to flag that account for reconnect, not to crash.
class ReconnectRequiredException implements Exception {
  ReconnectRequiredException(this.email);
  final String email;

  @override
  String toString() => 'Reconnect required for $email';
}

/// Thrown when the browser was dismissed before Google sent us back.
class SignInCancelledException implements Exception {
  @override
  String toString() =>
      'Sign-in was closed before it finished. Nothing was linked.';
}

class LinkedAccountTokens {
  const LinkedAccountTokens({
    required this.email,
    required this.name,
    required this.accessToken,
    required this.refreshToken,
  });

  final String email;
  final String? name;
  final String accessToken;
  final String? refreshToken;
}

/// Runs OAuth 2.0 Authorization Code + PKCE against Google using a
/// **loopback redirect** (`http://127.0.0.1:<port>`) rather than a custom
/// URI scheme.
///
/// Google is retiring custom URI schemes for mobile OAuth clients: with a
/// custom scheme, consent completed but Google silently navigated the
/// browser to google.com instead of ever invoking the redirect, so the app
/// never received an authorization code. A loopback redirect avoids the
/// scheme entirely — the app opens a short-lived HTTP server on localhost,
/// and Google redirects the browser straight to it.
///
/// No backend and no client secret: PKCE secures the code exchange.
class OAuthService {
  const OAuthService();

  static const _callbackTimeout = Duration(minutes: 5);

  /// Opening the browser backgrounds this app, and Android then freezes the
  /// process — which would leave the loopback socket open but unattended, so
  /// the redirect times out. A foreground service holds the process awake for
  /// the duration of the flow only.
  static const _keepAlive = MethodChannel('drivebiryani/signin_keepalive');

  /// Opens the Google sign-in flow for a new (or re-added) account and
  /// returns its tokens plus profile info. `access_type=offline` +
  /// `prompt=consent` force Google to issue a refresh token every time,
  /// not just on the very first consent ever granted to this app.
  Future<LinkedAccountTokens> linkAccount() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await _setKeepAlive(true);
    try {
      final redirectUri = 'http://127.0.0.1:${server.port}';
      final verifier = _randomUrlSafe(64);
      final state = _randomUrlSafe(24);

      final authUrl = Uri.parse(OAuthConfig.authorizationEndpoint).replace(
        queryParameters: {
          'client_id': OAuthConfig.clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': OAuthConfig.scopes.join(' '),
          'code_challenge': _codeChallenge(verifier),
          'code_challenge_method': 'S256',
          'access_type': 'offline',
          'prompt': 'consent',
          'state': state,
        },
      );

      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the browser for Google sign-in.');
      }

      final code = await _awaitCallback(server, state);
      final tokens = await _exchangeCode(code, verifier, redirectUri);

      final accessToken = tokens['access_token'] as String?;
      if (accessToken == null) {
        throw Exception('Google did not return an access token.');
      }

      final profile = await _fetchProfile(accessToken);
      return LinkedAccountTokens(
        email: profile['email'] as String,
        name: profile['name'] as String?,
        accessToken: accessToken,
        refreshToken: tokens['refresh_token'] as String?,
      );
    } finally {
      await server.close(force: true);
      await _setKeepAlive(false);
    }
  }

  Future<void> _setKeepAlive(bool active) async {
    if (!Platform.isAndroid) return;
    try {
      await _keepAlive.invokeMethod(active ? 'start' : 'stop');
    } on PlatformException {
      // Losing the keep-alive only risks a timed-out redirect, which the
      // flow already reports cleanly — it isn't worth failing sign-in over.
    } on MissingPluginException {
      // Older build without the native side; fall through.
    }
  }

  /// Waits for Google to redirect the browser back to our loopback server,
  /// then answers the browser with a page telling the person they can
  /// return to the app.
  Future<String> _awaitCallback(HttpServer server, String expectedState) async {
    final HttpRequest request;
    try {
      request = await server.first.timeout(_callbackTimeout);
    } on TimeoutException {
      throw SignInCancelledException();
    }

    final params = request.uri.queryParameters;
    final error = params['error'];
    final code = params['code'];
    final returnedState = params['state'];

    final ok = error == null && code != null && returnedState == expectedState;
    await _respond(request, ok: ok, error: error);

    if (error != null) {
      if (error == 'access_denied') throw SignInCancelledException();
      throw Exception('Google returned an error: $error');
    }
    if (code == null) throw SignInCancelledException();
    if (returnedState != expectedState) {
      // Mismatched state means this response isn't the one we started, so
      // it can't be trusted to belong to this sign-in.
      throw Exception('Sign-in response did not match this request.');
    }
    return code;
  }

  Future<void> _respond(
    HttpRequest request, {
    required bool ok,
    String? error,
  }) async {
    final title = ok ? 'Account linked' : 'Sign-in did not finish';
    final message = ok
        ? 'You can close this tab and go back to DriveBiryani.'
        : 'Nothing was linked. Close this tab and try again in DriveBiryani.';
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>$title</title>
<style>
  body { margin:0; min-height:100vh; display:flex; align-items:center;
         justify-content:center; background:#171D19; color:#F1EEE4;
         font-family:-apple-system,system-ui,sans-serif; text-align:center; }
  .card { padding:2rem; max-width:22rem; }
  h1 { font-size:1.25rem; margin:0 0 .6rem; color:${ok ? '#D2A24C' : '#C15D53'}; }
  p { margin:0; font-size:.95rem; line-height:1.5; color:#93A093; }
</style></head>
<body><div class="card"><h1>$title</h1><p>$message</p></div></body></html>
''');
    await request.response.close();
  }

  Future<Map<String, dynamic>> _exchangeCode(
    String code,
    String verifier,
    String redirectUri,
  ) async {
    final res = await http.post(
      Uri.parse(OAuthConfig.tokenEndpoint),
      body: {
        'client_id': OAuthConfig.clientId,
        'client_secret': OAuthConfig.clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Token exchange failed (${res.statusCode}): ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Exchanges a stored refresh token for a fresh access token. Throws
  /// [ReconnectRequiredException] when Google reports `invalid_grant` —
  /// the expected outcome once the 7-day testing-mode window has passed.
  Future<String> refreshAccessToken({
    required String email,
    required String refreshToken,
  }) async {
    final res = await http.post(
      Uri.parse(OAuthConfig.tokenEndpoint),
      body: {
        'client_id': OAuthConfig.clientId,
        'client_secret': OAuthConfig.clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (res.statusCode == 400 || res.statusCode == 401) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['error'] == 'invalid_grant') {
        throw ReconnectRequiredException(email);
      }
      throw Exception('Token refresh failed: ${res.body}');
    }
    if (res.statusCode != 200) {
      throw Exception('Token refresh failed (${res.statusCode}).');
    }

    final token = (jsonDecode(res.body) as Map<String, dynamic>)['access_token'];
    if (token is! String) throw ReconnectRequiredException(email);
    return token;
  }

  Future<Map<String, dynamic>> _fetchProfile(String accessToken) async {
    final res = await http.get(
      Uri.parse(OAuthConfig.userInfoEndpoint),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch account profile (${res.statusCode}).');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String _randomUrlSafe(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String _codeChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

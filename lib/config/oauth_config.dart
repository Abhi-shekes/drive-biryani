/// OAuth client for DriveBiryani, registered in Google Cloud Console
/// project `drivebiryani-app`.
class OAuthConfig {
  OAuthConfig._();

  // A "Desktop app" client, because it is the only client type Google still
  // accepts a loopback redirect from. Android- and iOS-type clients were both
  // tried first and rejected: Google is retiring custom URI schemes for
  // mobile clients, and with those the browser silently landed on google.com
  // after consent instead of ever handing the authorization code back.
  static const clientId =
      '423805419395-8le7rknp8nscjljgmk14friu16o56chu.apps.googleusercontent.com';

  // Google's token endpoint requires this for desktop/installed clients.
  // It is not a confidential credential — Google documents that installed
  // apps cannot keep a secret, and PKCE is what actually protects the code
  // exchange. See https://developers.google.com/identity/protocols/oauth2/native-app
  //
  // Kept out of source anyway (GitHub's secret scanner flags GOCSPX- values
  // regardless of that nuance) — pass it at build time:
  //   flutter run --dart-define=OAUTH_CLIENT_SECRET=GOCSPX-...
  static const clientSecret = String.fromEnvironment('OAUTH_CLIENT_SECRET');

  // No fixed redirect URI: the app binds a loopback HTTP server on a free
  // port at sign-in time and uses `http://127.0.0.1:<port>`. See
  // services/oauth_service.dart for why custom URI schemes were abandoned.

  static const authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const userInfoEndpoint =
      'https://www.googleapis.com/oauth2/v3/userinfo';

  // drive.metadata.readonly is enough for search (name, type, modified time,
  // link) without requesting full file-content access.
  static const scopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.metadata.readonly',
  ];
}

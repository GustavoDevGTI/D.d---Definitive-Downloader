/// Platforms whose captured media may need the user's own session. Public
/// posts work without it; private, restricted or age-gated ones ask for it.
/// The session is created only in the app's private login window.
enum CapturePlatform {
  instagram(
      label: 'Instagram',
      domains: ['instagram.com'],
      loginUrl: 'https://www.instagram.com/accounts/login/',
      cookieUrls: ['https://www.instagram.com/'],
      sessionCookie: 'sessionid',
      ownBrands: ['instagram']),
  twitter(
      label: 'X',
      domains: ['x.com', 'twitter.com'],
      loginUrl: 'https://x.com/i/flow/login',
      cookieUrls: ['https://x.com/'],
      sessionCookie: 'auth_token',
      ownBrands: ['twitter', 'x']),
  tiktok(
      label: 'TikTok',
      domains: ['tiktok.com'],
      loginUrl: 'https://www.tiktok.com/login/phone-or-email/email',
      cookieUrls: ['https://www.tiktok.com/'],
      sessionCookie: 'sessionid',
      ownBrands: ['tiktok']),
  facebook(
      label: 'Facebook',
      domains: ['facebook.com', 'fb.watch'],
      loginUrl: 'https://www.facebook.com/login/',
      cookieUrls: ['https://www.facebook.com/'],
      sessionCookie: 'c_user',
      ownBrands: ['facebook']);

  const CapturePlatform(
      {required this.label,
      required this.domains,
      required this.loginUrl,
      required this.cookieUrls,
      required this.sessionCookie,
      required this.ownBrands});
  final String label, loginUrl, sessionCookie;
  final List<String> domains, cookieUrls;

  /// Names of this platform itself: its own buttons stay enabled in the page.
  final List<String> ownBrands;

  String get domain => domains.first;

  static CapturePlatform? named(Object? name) =>
      values.where((platform) => platform.name == name).firstOrNull;

  static CapturePlatform? forUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri == null
        ? null
        : values.where((platform) => platform.owns(uri)).firstOrNull;
  }

  bool ownsHost(String host) {
    final value = host.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    return domains.any((d) => value == d || value.endsWith('.$d'));
  }

  bool owns(Uri? uri) => uri != null && ownsHost(uri.host);

  /// Main-frame pages the login window may show.
  bool allowsNavigation(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      owns(uri);

  /// Signing in through another company's account leaves the window.
  bool isExternalSignIn(Uri? uri) =>
      uri != null &&
      !owns(uri) &&
      const {
        'www.facebook.com',
        'm.facebook.com',
        'facebook.com',
        'accounts.google.com',
        'appleid.apple.com',
        'x.com',
        'twitter.com',
        'api.twitter.com',
        'www.instagram.com',
      }.contains(uri.host);
}

/// The page needs a session of [platform]. [rejected]: the session sent was
/// not accepted, so it must be discarded.
class CaptureLoginRequired implements Exception {
  const CaptureLoginRequired(this.platform, {this.rejected = false});
  final CapturePlatform platform;
  final bool rejected;
  @override
  String toString() =>
      'O ${platform.label} pediu login para liberar este conteúdo.';
}

/// One cookie of a captured session, as the engine accepts it.
class SessionCookie {
  const SessionCookie(
      {required this.name,
      required this.value,
      required this.domain,
      this.path = '/',
      this.expires});
  final String name, value, domain, path;

  /// Seconds since the epoch; null for a session cookie.
  final int? expires;

  static final _name = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');
  static final _value = RegExp(r'^[\x21-\x3a\x3c-\x7e]{0,4096}$');

  bool belongsTo(CapturePlatform platform) =>
      _name.hasMatch(name) &&
      _value.hasMatch(value) &&
      path.startsWith('/') &&
      path.length <= 256 &&
      platform.ownsHost(domain);

  Map<String, Object?> toJson() => {
        'name': name,
        'value': value,
        'domain': domain,
        'path': path,
        'expires': expires
      };

  static SessionCookie? fromJson(Object? row) {
    if (row is! Map) return null;
    final name = row['name'], value = row['value'], domain = row['domain'];
    final path = row['path'] ?? '/', expires = row['expires'];
    if (name is! String ||
        value is! String ||
        domain is! String ||
        path is! String ||
        (expires != null && expires is! int)) {
      return null;
    }
    return SessionCookie(
        name: name,
        value: value,
        domain: domain,
        path: path,
        expires: expires as int?);
  }
}

/// Keeps only valid cookies of [platform], its session cookie first, at most
/// 60 and about 20 000 characters, and requires the session cookie.
List<SessionCookie>? platformSession(
    CapturePlatform platform, Iterable<SessionCookie> cookies) {
  final valid = cookies.where((cookie) => cookie.belongsTo(platform)).toList()
    ..sort((a, b) => (b.name == platform.sessionCookie ? 1 : 0)
        .compareTo(a.name == platform.sessionCookie ? 1 : 0));
  final kept = <SessionCookie>[];
  var size = 0;
  for (final cookie in valid) {
    final weight = cookie.name.length + cookie.value.length + 64;
    if (kept.length == 60 || size + weight > 20000) continue;
    kept.add(cookie);
    size += weight;
  }
  final signedIn = kept.any((cookie) =>
      cookie.name == platform.sessionCookie && cookie.value.isNotEmpty);
  return signedIn ? List.unmodifiable(kept) : null;
}

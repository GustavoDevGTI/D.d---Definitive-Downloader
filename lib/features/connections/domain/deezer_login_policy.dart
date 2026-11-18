abstract final class DeezerLoginPolicy {
  static bool isDeezer(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      (uri.host == 'deezer.com' || uri.host.endsWith('.deezer.com'));
  static bool allowNavigation(Uri? uri) => isDeezer(uri);

  static bool isExternalSignIn(Uri? uri) => const {
        'accounts.google.com',
        'www.facebook.com',
        'm.facebook.com',
        'appleid.apple.com',
      }.contains(uri?.host);
  static String? session(Uri? page, String? value) => isDeezer(page) &&
          value != null &&
          RegExp(r'^[A-Za-z0-9_-]{80,2048}$').hasMatch(value)
      ? value
      : null;
}

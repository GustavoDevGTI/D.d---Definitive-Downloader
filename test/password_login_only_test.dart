import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/web/password_login_only.dart';
import 'package:definitive_downloader/features/audio_capture/domain/capture_login.dart';
import 'package:definitive_downloader/features/connections/presentation/deezer_login_controls.dart';

String _blocked(String script) =>
    RegExp(r'new RegExp\("([^"]*)"').firstMatch(script)!.group(1)!;

void main() {
  test('bloqueio de login social roda só nos domínios HTTPS da plataforma', () {
    final instagram = passwordLoginOnly(CapturePlatform.instagram.domains,
        ownBrands: CapturePlatform.instagram.ownBrands);
    expect(instagram, contains("location.protocol !== 'https:'"));
    expect(instagram, contains('const hosts = ["instagram.com"]'));
    expect(instagram, contains(socialSignInBlocker));
    // Deezer keeps the same installer, which blocks every provider by default.
    expect(deezerLoginControlInstaller, socialSignInBlocker);
    expect(deezerLoginControls, contains('const hosts = ["deezer.com"]'));
    for (final provider in ['google', 'facebook', 'apple', 'instagram']) {
      expect(_blocked(deezerLoginControls), contains(provider));
    }
  });

  test('a marca da própria plataforma continua habilitada', () {
    String blockedFor(CapturePlatform platform) => _blocked(
        passwordLoginOnly(platform.domains, ownBrands: platform.ownBrands));
    final facebook = blockedFor(CapturePlatform.facebook);
    expect(facebook, isNot(contains('facebook')));
    expect(facebook, contains('google'));
    final x = blockedFor(CapturePlatform.twitter);
    expect(x, isNot(contains('twitter')));
    expect(x, isNot(contains(r'\\bx')));
    expect(x, contains('google'));
    expect(x, contains('apple'));
    expect(blockedFor(CapturePlatform.instagram), contains('facebook'));
    expect(blockedFor(CapturePlatform.instagram), isNot(contains('instagram')));
    expect(blockedFor(CapturePlatform.tiktok), contains('facebook'));
    expect(passwordLoginOnly(CapturePlatform.twitter.domains),
        contains('const hosts = ["x.com","twitter.com"]'));
  });

  test('plataformas de captura reconhecem os próprios domínios', () {
    final cases = {
      'https://x.com/a/status/1': CapturePlatform.twitter,
      'https://twitter.com/a/status/1': CapturePlatform.twitter,
      'https://www.tiktok.com/@a/video/1': CapturePlatform.tiktok,
      'https://vm.tiktok.com/x/': CapturePlatform.tiktok,
      'https://www.facebook.com/reel/1': CapturePlatform.facebook,
      'https://fb.watch/abc/': CapturePlatform.facebook,
      'https://www.instagram.com/reel/a/': CapturePlatform.instagram,
      'https://bsky.app/profile/a/post/b': null,
      'https://www.pinterest.com/pin/1/': null,
      'https://xx.com/a': null,
      'https://facebook.com.evil.test/a': null,
    };
    cases.forEach((url, platform) =>
        expect(CapturePlatform.forUrl(url), platform, reason: url));
    expect(
        CapturePlatform.facebook
            .isExternalSignIn(Uri.parse('https://www.facebook.com/login')),
        isFalse,
        reason: 'A própria página do Facebook não é login externo.');
    expect(
        CapturePlatform.instagram
            .isExternalSignIn(Uri.parse('https://www.facebook.com/login')),
        isTrue);
  });

  test('sessão mantém o cookie de login mesmo com muitos cookies', () {
    final cookies = [
      for (var i = 0; i < 80; i++)
        SessionCookie(name: 'c$i', value: 'v' * 300, domain: '.tiktok.com'),
      const SessionCookie(
          name: 'sessionid', value: 'abc', domain: '.tiktok.com'),
    ];
    final session = platformSession(CapturePlatform.tiktok, cookies)!;
    expect(session.first.name, 'sessionid');
    expect(session.length, lessThanOrEqualTo(60));
    expect(
        session.fold<int>(
            0, (total, c) => total + c.name.length + c.value.length),
        lessThan(20000));
    expect(
        platformSession(CapturePlatform.twitter, [
          const SessionCookie(
              name: 'auth_token', value: 'x', domain: '.twitter.com')
        ]),
        isNotNull);
  });
}
